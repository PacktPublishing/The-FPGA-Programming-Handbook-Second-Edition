-- vga.vhd
-- ------------------------------------
-- Top level of the VGA Display controller
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- Simple VGA controller capable of multiple resolutions and corresponding
-- character generator to display the current mode.

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;
use IEEE.math_real.all;

library xpm;
use XPM.vcomponents.all;

use WORK.vga_pkg.all;

entity vga is
  port(
    clk        : in    std_logic;
    vga_hsync  : out   std_logic;
    vga_vsync  : out   std_logic;
    vga_rgb    : out   std_logic_vector(11 downto 0); -- 4:4:4
    SW         : in    std_logic_vector(4 downto 0); -- Switches to configure resolution
    button_c   : in    std_logic;       -- Center button (high active)
    cpu_resetn : in    std_logic;       -- When pressed, reset
    --
    ddr2_addr  : out   std_logic_vector(12 downto 0);
    ddr2_ba    : out   std_logic_vector(2 downto 0);
    ddr2_cas_n : out   std_logic;
    ddr2_ck_n  : out   std_logic_vector(0 downto 0);
    ddr2_ck_p  : out   std_logic_vector(0 downto 0);
    ddr2_cke   : out   std_logic_vector(0 downto 0);
    ddr2_ras_n : out   std_logic;
    ddr2_we_n  : out   std_logic;
    ddr2_dq    : inout std_logic_vector(15 downto 0);
    ddr2_dqs_n : inout std_logic_vector(1 downto 0);
    ddr2_dqs_p : inout std_logic_vector(1 downto 0);
    ddr2_cs_n  : out   std_logic_vector(0 downto 0);
    ddr2_dm    : out   std_logic_vector(1 downto 0);
    ddr2_odt   : out   std_logic_vector(0 downto 0)
  );
end entity vga;

architecture rtl of vga is

  -- Constants
  constant MMCM_REGISTER_COUNT  : natural := 24;
  constant VGA_REGISTER_COUNT   : natural := 8;
  constant TOTAL_REGISTER_COUNT : natural := MMCM_REGISTER_COUNT + VGA_REGISTER_COUNT;
  constant MMCM_IDX             : natural := 0;
  constant VGA_IDX              : natural := 1;
  constant CHAR_ROWS            : natural := 8; -- number of rows in character bitmap
  constant RES_TEXT_LENGTH      : natural := RES_TEXT(0)'length; -- 16

  -- Types
  type cfg_state_t is (
    CFG_IDLE0, CFG_IDLE1, CFG_WR0, CFG_WR1, CFG_WR2,
    CFG_WR3, CFG_WR3a, CFG_WR4, CFG_WR5); --, WRITE_TEXT); REVIEW: need WRITE_TEXT?

  type text_sm_t is (
    TEXT_IDLE, TEXT_CLR0, TEXT_CLR1, TEXT_CLR2,
    TEXT_WRITE0, TEXT_WRITE1, TEXT_WRITE2,
    TEXT_WRITE3, TEXT_WRITE4);          -- TODO: not used, TEXT_WRITE5);

  type char_x_t is array (natural range <>) of integer range 0 to RES_TEXT_LENGTH - 1;

  -- Registered signals with initial values
  -- TODO: add clock domains
  signal s_axi_awaddr     : std_logic_vector(11 downto 0)            := (others => '0');
  signal s_axi_awvalid    : std_logic_vector(1 downto 0)             := (others => '0'); -- 0: pix_clk, 1: vga_core
  signal s_axi_wdata      : std_logic_vector(31 downto 0);
  signal s_axi_wvalid     : std_logic_vector(1 downto 0)             := (others => '0'); -- 0: pix_clk, 1: vga_core
  signal pll_rst          : std_logic                                := '0';
  signal char_index       : natural range 0 to 255                   := 0; -- character index (ASCII code) in text_rom
  signal char_y           : natural range 0 to CHAR_ROWS - 1         := 0; -- character row index
  signal app_sr_req       : std_logic                                := '0';
  signal app_ref_req      : std_logic                                := '0';
  signal app_zq_req       : std_logic                                := '0';
  signal s_ddr_awaddr     : unsigned(26 downto 0)                    := (others => '0');
  signal s_ddr_awlen      : std_logic_vector(7 downto 0)             := (others => '0');
  signal s_ddr_awsize     : std_logic_vector(2 downto 0)             := "100"; -- 16 bytes in transfer
  signal s_ddr_awburst    : std_logic_vector(1 downto 0)             := "01";
  signal s_ddr_awlock     : std_logic_vector(0 downto 0)             := "0";
  signal s_ddr_awcache    : std_logic_vector(3 downto 0)             := (others => '0');
  signal s_ddr_awprot     : std_logic_vector(2 downto 0)             := (others => '0');
  signal s_ddr_awqos      : std_logic_vector(3 downto 0)             := (others => '0');
  signal s_ddr_awvalid    : std_logic                                := '0';
  signal s_ddr_wdata      : std_logic_vector(127 downto 0)           := (others => '0');
  signal s_ddr_wstrb      : std_logic_vector(15 downto 0)            := (others => '0');
  signal s_ddr_wlast      : std_logic                                := '0';
  signal s_ddr_wvalid     : std_logic                                := '0';
  signal cfg_state        : cfg_state_t                              := CFG_IDLE0;
  signal button_sync      : std_logic_vector(2 downto 0)             := "000";
  signal sw_capt          : integer range 0 to RESOLUTION'length - 1 := 0; -- [clk200 domain] 
  signal wr_count         : integer range 0 to TOTAL_REGISTER_COUNT  := 0; -- AXI4-lite write transaction counter
  signal update_text      : std_logic                                := '0'; -- [clk200 domain]
  signal update_text_sync : std_logic_vector(2 downto 0)             := "000"; -- [ui_clk domain]
  signal text_sm          : text_sm_t                                := TEXT_IDLE;
  signal total_page       : unsigned(24 downto 0)                    := (others => '0');
  signal char_x           : char_x_t(2 downto 0)                     := (others => 0); -- TODO: could be a variable

  -- Unregistered signals without initial values
  signal sys_pll_locked      : std_logic;
  signal pix_clk_locked      : std_logic;
  signal rst200              : std_logic;
  signal s_axi_awready       : std_logic_vector(1 downto 0); -- 0: pix_clk, 1: vga_core
  signal s_axi_wready        : std_logic_vector(1 downto 0); -- 0: pix_clk, 1: vga_core
  signal vga_clk             : std_logic;
  signal init_calib_complete : std_logic;
  signal vga_hblank          : std_logic;
  signal vga_vblank          : std_logic;
  signal mc_clk              : std_logic; -- 325 MHz 
  signal clk200              : std_logic;
  signal char_slice          : std_logic_vector(7 downto 0);
  signal ui_clk              : std_logic; -- TODO MHz
  signal ui_clk_sync_rst     : std_logic;
  signal mmcm_locked         : std_logic;
  signal aresetn             : std_logic;
  signal app_sr_active       : std_logic;
  signal app_ref_ack         : std_logic;
  signal app_zq_ack          : std_logic;
  signal s_ddr_awid          : std_logic_vector(3 downto 0);
  signal s_ddr_awready       : std_logic;
  signal s_ddr_wready        : std_logic;
  signal s_ddr_bid           : std_logic_vector(3 downto 0);
  signal s_ddr_bresp         : std_logic_vector(1 downto 0);
  signal s_ddr_bvalid        : std_logic;
  signal s_ddr_bready        : std_logic;
  signal s_ddr_arid          : std_logic_vector(3 downto 0);
  signal s_ddr_araddr        : std_logic_vector(26 downto 0);
  signal s_ddr_arlen         : std_logic_vector(7 downto 0);
  signal s_ddr_arsize        : std_logic_vector(2 downto 0);
  signal s_ddr_arburst       : std_logic_vector(1 downto 0);
  signal s_ddr_arlock        : std_logic_vector(0 downto 0);
  signal s_ddr_arcache       : std_logic_vector(3 downto 0);
  signal s_ddr_arprot        : std_logic_vector(2 downto 0);
  signal s_ddr_arqos         : std_logic_vector(3 downto 0);
  signal s_ddr_arvalid       : std_logic;
  signal s_ddr_arready       : std_logic;
  signal s_ddr_rid           : std_logic_vector(3 downto 0);
  signal s_ddr_rdata         : std_logic_vector(127 downto 0);
  signal s_ddr_rresp         : std_logic_vector(1 downto 0);
  signal s_ddr_rlast         : std_logic;
  signal s_ddr_rvalid        : std_logic;
  signal s_ddr_rready        : std_logic;
  signal int_vga_rgb         : std_logic_vector(23 downto 0);

  -- Attributes
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of button_sync : signal is "TRUE";
  attribute ASYNC_REG of update_text_sync : signal is "TRUE";

  attribute MARK_DEBUG : string;
  attribute MARK_DEBUG of s_ddr_araddr : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_arlen : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_arvalid : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_arready : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_rdata : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_rlast : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_rvalid : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_rready : signal is "TRUE";
  attribute MARK_DEBUG of cfg_state : signal is "TRUE";
  attribute MARK_DEBUG of update_text_sync : signal is "TRUE";
  attribute MARK_DEBUG of text_sm : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_awaddr : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_awlen : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_awvalid : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_awready : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_wdata : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_wstrb : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_wlast : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_wvalid : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_wready : signal is "TRUE";

begin

  ------------------------------------------------------------------------------
  -- System clock PLL
  ------------------------------------------------------------------------------

  u_sys_clk : sys_pll
    port map(
      clk_out1 => clk200,
      clk_out2 => mc_clk,
      locked   => sys_pll_locked,       -- TODO: add locked output
      clk_in1  => clk
    );

  -- TOOD: add reset synchronizer
  rst200 <= not sys_pll_locked;

  ------------------------------------------------------------------------------
  -- Pixel clock PLL
  ------------------------------------------------------------------------------

  u_clk : pix_clk
    port map(
      s_axi_aclk    => clk200,
      s_axi_aresetn => '1',
      s_axi_awaddr  => s_axi_awaddr(10 downto 0),
      s_axi_awvalid => s_axi_awvalid(0),
      s_axi_awready => s_axi_awready(MMCM_IDX),
      s_axi_wdata   => s_axi_wdata,
      s_axi_wstrb   => x"F",
      s_axi_wvalid  => s_axi_wvalid(0),
      s_axi_wready  => s_axi_wready(MMCM_IDX),
      s_axi_bresp   => open,            -- TODO: connect
      s_axi_bvalid  => open,            -- TODO: connect
      s_axi_bready  => '1',
      s_axi_araddr  => (others => '0'),
      s_axi_arvalid => '0',
      s_axi_arready => open,
      s_axi_rdata   => open,
      s_axi_rresp   => open,
      s_axi_rvalid  => open,
      s_axi_rready  => '1',
      -- Clock out ports
      clk_out1      => vga_clk,
      -- Status and control signals
      locked        => pix_clk_locked,
      -- Clock in ports
      clk_in1       => clk200
    );

  ------------------------------------------------------------------------------
  -- Text character bitmap ROM
  ------------------------------------------------------------------------------

  u_text_rom : text_rom
    port map(
      clock      => ui_clk,             -- Clock
      index      => std_logic_vector(to_unsigned(char_index, 8)), -- Character Index
      sub_index  => std_logic_vector(to_unsigned(char_y, 3)), -- Y position in character
      bitmap_out => char_slice          -- 8 bit horizontal slice of character
    );

  ------------------------------------------------------------------------------
  -- DDR2 Controller
  ------------------------------------------------------------------------------

  aresetn       <= '1';                 -- TODO: drive reset signal
  s_ddr_awid    <= (others => '0');
  s_ddr_bready  <= '1';
  s_ddr_arcache <= (others => '0');
  s_ddr_arprot  <= (others => '0');
  s_ddr_arqos   <= (others => '0');

  u_ddr2_vga : ddr2_vga
    port map(
      -- Memory interface ports
      ddr2_addr           => ddr2_addr,
      ddr2_ba             => ddr2_ba,
      ddr2_cas_n          => ddr2_cas_n,
      ddr2_ck_n           => ddr2_ck_n(0 downto 0),
      ddr2_ck_p           => ddr2_ck_p(0 downto 0),
      ddr2_cke            => ddr2_cke(0 downto 0),
      ddr2_ras_n          => ddr2_ras_n,
      ddr2_we_n           => ddr2_we_n,
      ddr2_dq             => ddr2_dq,
      ddr2_dqs_n          => ddr2_dqs_n,
      ddr2_dqs_p          => ddr2_dqs_p,
      init_calib_complete => init_calib_complete,
      ddr2_cs_n           => ddr2_cs_n(0 downto 0),
      ddr2_dm             => ddr2_dm,
      ddr2_odt            => ddr2_odt(0 downto 0),
      -- Application interface ports
      ui_clk              => ui_clk,
      ui_clk_sync_rst     => ui_clk_sync_rst,
      mmcm_locked         => mmcm_locked,
      aresetn             => aresetn,
      app_sr_req          => app_sr_req,
      app_ref_req         => app_ref_req,
      app_zq_req          => app_zq_req,
      app_sr_active       => app_sr_active,
      app_ref_ack         => app_ref_ack,
      app_zq_ack          => app_zq_ack,
      -- Slave Interface Write Address Ports
      s_axi_awid          => s_ddr_awid,
      s_axi_awaddr        => std_logic_vector(s_ddr_awaddr),
      s_axi_awlen         => s_ddr_awlen,
      s_axi_awsize        => s_ddr_awsize,
      s_axi_awburst       => s_ddr_awburst,
      s_axi_awlock        => s_ddr_awlock(0 downto 0),
      s_axi_awcache       => s_ddr_awcache,
      s_axi_awprot        => s_ddr_awprot,
      s_axi_awqos         => s_ddr_awqos,
      s_axi_awvalid       => s_ddr_awvalid,
      s_axi_awready       => s_ddr_awready,
      -- Slave Interface Write Data Ports
      s_axi_wdata         => s_ddr_wdata,
      s_axi_wstrb         => s_ddr_wstrb,
      s_axi_wlast         => s_ddr_wlast,
      s_axi_wvalid        => s_ddr_wvalid,
      s_axi_wready        => s_ddr_wready,
      -- Slave Interface Write Response Ports
      s_axi_bid           => s_ddr_bid,
      s_axi_bresp         => s_ddr_bresp,
      s_axi_bvalid        => s_ddr_bvalid,
      s_axi_bready        => s_ddr_bready,
      -- Slave Interface Read Address Ports
      s_axi_arid          => s_ddr_arid,
      s_axi_araddr        => s_ddr_araddr,
      s_axi_arlen         => s_ddr_arlen,
      s_axi_arsize        => s_ddr_arsize,
      s_axi_arburst       => s_ddr_arburst,
      s_axi_arlock        => s_ddr_arlock(0 downto 0),
      s_axi_arcache       => s_ddr_arcache,
      s_axi_arprot        => s_ddr_arprot,
      s_axi_arqos         => s_ddr_arqos,
      s_axi_arvalid       => s_ddr_arvalid,
      s_axi_arready       => s_ddr_arready,
      -- Slave Interface Read Data Ports
      s_axi_rid           => s_ddr_rid,
      s_axi_rdata         => s_ddr_rdata,
      s_axi_rresp         => s_ddr_rresp,
      s_axi_rlast         => s_ddr_rlast,
      s_axi_rvalid        => s_ddr_rvalid,
      s_axi_rready        => s_ddr_rready,
      -- System Clock Ports
      sys_clk_i           => mc_clk,
      -- Reference Clock Ports
      clk_ref_i           => clk200,
      sys_rst             => '0');

  ------------------------------------------------------------------------------
  -- VGA Controller
  ------------------------------------------------------------------------------

  u_vga_core : vga_core
    port map(
      -- Register address
      reg_clk     => clk200,
      reg_reset   => rst200,
      reg_awvalid => s_axi_awvalid(VGA_IDX),
      reg_awready => s_axi_awready(VGA_IDX),
      reg_awaddr  => s_axi_awaddr,
      reg_wvalid  => s_axi_wvalid(VGA_IDX),
      reg_wready  => s_axi_wready(VGA_IDX),
      reg_wdata   => s_axi_wdata,
      reg_wstrb   => "1111",
      reg_bready  => '1',
      reg_bvalid  => open,              -- FIXME reg_bvalid,        -- REVIEW: not waiting for write response?
      reg_bresp   => open,              -- FIXME reg_bresp,
      reg_arvalid => '0',
      reg_arready => open,
      reg_araddr  => (others => '0'),
      reg_rready  => '1',
      reg_rvalid  => open,
      reg_rdata   => open,
      reg_rresp   => open,
      -- Master memory
      mem_clk     => ui_clk,
      mem_reset   => '0',
      mem_arid    => s_ddr_arid,
      mem_araddr  => s_ddr_araddr,
      mem_arlen   => s_ddr_arlen,
      mem_arsize  => s_ddr_arsize,
      mem_arburst => s_ddr_arburst,
      mem_arlock  => s_ddr_arlock(0),
      mem_arvalid => s_ddr_arvalid,
      mem_arready => s_ddr_arready,
      mem_rready  => s_ddr_rready,
      mem_rid     => s_ddr_rid,
      mem_rdata   => s_ddr_rdata,
      mem_rresp   => s_ddr_rresp,
      mem_rlast   => s_ddr_rlast,
      mem_rvalid  => s_ddr_rvalid,
      vga_clk     => vga_clk,
      vga_hsync   => vga_hsync,
      vga_hblank  => vga_hblank,
      vga_vsync   => vga_vsync,
      vga_vblank  => vga_vblank,
      vga_rgb     => int_vga_rgb
    );

  vga_rgb <= int_vga_rgb(23 downto 20) & int_vga_rgb(15 downto 12) & int_vga_rgb(7 downto 4);

  ------------------------------------------------------------------------------
  -- PLL and VGA Configuration FSM
  ------------------------------------------------------------------------------

  config_fsm : process(clk200)
    -- Helper variables
    variable sw_int : integer range 0 to 31;
  begin
    if rising_edge(clk200) then
      -- TODO: add all resets
      if rst200 = '1' then
        button_sync   <= (others => '0');
        wr_count      <= 0;
        pll_rst       <= '1';           -- TODO: pll_rst is not connected
        cfg_state     <= CFG_IDLE0;
        update_text   <= '0';
        sw_capt       <= 0;
        s_axi_awvalid <= (others => '0');
        s_axi_awaddr  <= (others => '0');
        s_axi_wvalid  <= (others => '0');
        s_axi_wdata   <= (others => '0');

      else

        -- Synchronize the center button signal
        button_sync <= button_sync(1 downto 0) & button_c;

        pll_rst <= '1';                 -- REVIEW: need this?

        case cfg_state is

          -- Initial state
          when CFG_IDLE0 =>
            update_text <= not update_text;
            wr_count    <= 0;
            cfg_state   <= CFG_IDLE1;

          -- Wait for config trigger (center button press)
          when CFG_IDLE1 =>
            assert wr_count = 0 severity failure;
            s_axi_awvalid(MMCM_IDX) <= '0';
            s_axi_wvalid(MMCM_IDX)  <= '0';
            if button_sync(2 downto 1) = "10" then -- REVIEW: falling edge?
              update_text             <= not update_text; -- we can start writing the text as we are updating
              pll_rst                 <= '0';
              s_axi_awvalid(MMCM_IDX) <= '1';
              s_axi_awaddr            <= ADDR_ARRAY(wr_count);
              s_axi_wvalid(MMCM_IDX)  <= '1';
              sw_int                  := to_integer(unsigned(SW)); -- the switch encodes the VGA resolution
              sw_int                  := minimum(RESOLUTION'length - 1, sw_int); -- saturate at the highest resolution index
              sw_capt                 <= sw_int;
              s_axi_wdata             <= resolution_lookup(sw_int, wr_count);
              wr_count                <= 1;
              cfg_state               <= CFG_WR0;
            end if;

          -- Load MMCM registers
          when CFG_WR0 =>
            pll_rst <= '0';
            if s_axi_awready(MMCM_IDX) = '1' and s_axi_wready(MMCM_IDX) = '1' then
              if wr_count = MMCM_REGISTER_COUNT then
                s_axi_awvalid <= "00";
                s_axi_wvalid  <= "00";
                cfg_state     <= CFG_WR3;
              else
                s_axi_awvalid <= "01";
                s_axi_wvalid  <= "01";
                s_axi_awaddr  <= ADDR_ARRAY(wr_count);
                s_axi_wdata   <= resolution_lookup(sw_capt, wr_count);
                wr_count      <= wr_count + 1;
              end if;
            elsif s_axi_awready(MMCM_IDX) then
              s_axi_awvalid <= "00";
              cfg_state     <= CFG_WR1;
            elsif s_axi_wready(MMCM_IDX) then
              s_axi_wvalid <= "00";
              cfg_state    <= CFG_WR2;
            end if;

          -- Load MMCM registers, wait for wready
          when CFG_WR1 =>
            pll_rst <= '0';
            if s_axi_wready(MMCM_IDX) then
              s_axi_wvalid <= "00";
              if wr_count = MMCM_REGISTER_COUNT then
                cfg_state <= CFG_WR3;
              else
                s_axi_awvalid <= "01";
                s_axi_wvalid  <= "01";
                cfg_state     <= CFG_WR0;
                s_axi_awaddr  <= ADDR_ARRAY(wr_count);
                s_axi_wdata   <= resolution_lookup(sw_capt, wr_count);
                wr_count      <= wr_count + 1;
              end if;
            end if;

          -- Load MMCM registers, wait for awready
          when CFG_WR2 =>
            pll_rst <= '0';
            if s_axi_awready(MMCM_IDX) then
              s_axi_awvalid <= "00";
              if wr_count = MMCM_REGISTER_COUNT then
                cfg_state <= CFG_WR3;
              else
                s_axi_awvalid <= "01";
                s_axi_wvalid  <= "01";
                cfg_state     <= CFG_WR0;
                s_axi_awaddr  <= ADDR_ARRAY(wr_count);
                s_axi_wdata   <= resolution_lookup(sw_capt, wr_count);
                wr_count      <= wr_count + 1;
              end if;
            end if;

          when CFG_WR3 =>
            s_axi_awvalid <= "10";
            s_axi_wvalid  <= "10";
            cfg_state     <= CFG_WR3a;
            s_axi_awaddr  <= ADDR_ARRAY(wr_count);
            s_axi_wdata   <= resolution_lookup(sw_capt, wr_count);
            wr_count      <= wr_count + 1;

          -- Load VGA registers
          when CFG_WR3a =>
            pll_rst <= '0';
            -- last_write(1) & s_axi_awready(VGA_IDX) & s_axi_wready(VGA_IDX);
            if s_axi_awready(VGA_IDX) = '1' and s_axi_wready(VGA_IDX) = '1' then
              if wr_count = TOTAL_REGISTER_COUNT then
                s_axi_awvalid <= "00";
                s_axi_wvalid  <= "00";
                wr_count      <= 0;
                cfg_state     <= CFG_IDLE1;
              else
                wr_count      <= wr_count + 1;
                s_axi_awvalid <= "10";
                s_axi_wvalid  <= "10";
                s_axi_awaddr  <= ADDR_ARRAY(wr_count);
                s_axi_wdata   <= resolution_lookup(sw_capt, wr_count);
              end if;
            elsif s_axi_awready(VGA_IDX) then
              s_axi_awvalid <= "00";
              cfg_state     <= CFG_WR4;
            elsif s_axi_wready(VGA_IDX) then
              s_axi_wvalid <= "00";
              cfg_state    <= CFG_WR5;
            end if;

          -- Load VGA registers: got awready(1), wait for wready(1)
          when CFG_WR4 =>
            pll_rst <= '0';
            if s_axi_wready(VGA_IDX) then
              s_axi_wvalid <= "00";
              if wr_count = TOTAL_REGISTER_COUNT then
                wr_count  <= 0;
                cfg_state <= CFG_IDLE1;
              else
                s_axi_awvalid <= "10";
                s_axi_wvalid  <= "10";
                cfg_state     <= CFG_WR3a;
                s_axi_awaddr  <= ADDR_ARRAY(wr_count);
                s_axi_wdata   <= resolution_lookup(sw_capt, wr_count);
                wr_count      <= wr_count + 1;
              end if;
            end if;

          -- Load VGA registers: got wready(1), wait for awready(1)
          when CFG_WR5 =>
            pll_rst <= '0';
            if s_axi_awready(VGA_IDX) then
              s_axi_awvalid <= "00";
              if wr_count = TOTAL_REGISTER_COUNT then
                wr_count  <= 0;
                cfg_state <= CFG_IDLE1;
              else
                s_axi_awvalid <= "10";
                s_axi_wvalid  <= "10";
                cfg_state     <= CFG_WR3a;
                s_axi_awaddr  <= ADDR_ARRAY(wr_count);
                s_axi_wdata   <= resolution_lookup(sw_capt, wr_count);
                wr_count      <= wr_count + 1;
              end if;
            end if;

        end case;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Text Display FSM
  -- 1. Clear screen
  -- 2. Draw the text on the first 8 scanlines
  ------------------------------------------------------------------------------

  text_fsm : process(ui_clk)
    -- Registered variables
    variable real_pitch : unsigned(12 downto 0) := (others => '0');

    -- Helper variables
    variable sw_int          : integer range 0 to 31;
    variable wdata_bit_index : integer range 0 to 127;
  begin
    if rising_edge(ui_clk) then
      if ui_clk_sync_rst then
        real_pitch       := (others => '0');
        update_text_sync <= (others => '0');
        --
        s_ddr_awvalid    <= '0';
        s_ddr_awlen      <= 8d"0";
        s_ddr_awsize     <= "100";      -- 16 bytes in transfer
        s_ddr_awburst    <= "01";       -- INCR burst type
        s_ddr_awlock     <= "0";        -- normal access
        s_ddr_awcache    <= "0000";
        s_ddr_awprot     <= "000";
        s_ddr_awqos      <= "0000";
        s_ddr_awaddr     <= (others => '0');
        s_ddr_wvalid     <= '0';
        s_ddr_wdata      <= (others => '0');
        s_ddr_wstrb      <= (others => '0');
        s_ddr_wlast      <= '0';
        --
        char_x           <= (others => 0);
        char_y           <= 0;
        text_sm          <= TEXT_IDLE;
        char_index       <= 0;
        total_page       <= (others => '0');

      else
        -- Defaults:
        s_ddr_awlen   <= 8d"0";
        s_ddr_awsize  <= "100";         -- 16 bytes in transfer
        s_ddr_awburst <= "01";          -- INCR burst type
        s_ddr_awlock  <= "0";           -- normal access
        s_ddr_awcache <= "0000";
        s_ddr_awprot  <= "000";
        s_ddr_awqos   <= "0000";

        -- Synchronize update_text toggle into ui_clk domain
        update_text_sync <= update_text_sync(1 downto 0) & update_text;

        -- Resolution character index delay line
        char_x(1) <= char_x(0);
        char_x(2) <= char_x(1);

        case text_sm is

          -- Clear screen: wait for update_text toggle
          when TEXT_IDLE =>
            if xor(update_text_sync(2 downto 1)) then
              sw_int        := to_integer(unsigned(SW)); -- the switch encodes the VGA resolution
              sw_int        := minimum(RESOLUTION'length - 1, sw_int); -- saturate at the highest resolution index
              -- Round up the line pitch to the next multiple of 16 bytes
              if RESOLUTION(sw_capt).pitch mod 16 /= 0 then
                real_pitch := (RESOLUTION(sw_capt).pitch + 15) and 13x"1FF0";
              else
                real_pitch := RESOLUTION(sw_capt).pitch;
              end if;
              -- Compute total image size
              total_page    <= RESOLUTION(sw_int).vert_display_width * real_pitch;
              -- Write 0x0 starting at DDR address 0x0
              s_ddr_awaddr  <= (others => '0');
              s_ddr_awvalid <= '1';

              s_ddr_wdata  <= (others => '0');
              s_ddr_wstrb  <= (others => '1');
              s_ddr_wlast  <= '1';
              s_ddr_wvalid <= '1';
              --
              -- REVIEW char_index    <= character'pos(get_res_char(sw_capt, 0));
              char_x       <= (others => 0);
              char_y       <= 0;
              text_sm      <= TEXT_CLR0;
            end if;

          -- Clear screen: wait for s_ddr_awready and/or s_ddr_wready
          when TEXT_CLR0 =>
            if s_ddr_awready and s_ddr_wready then
              s_ddr_awvalid <= '0';
              s_ddr_wvalid  <= '0';
              if s_ddr_awaddr >= total_page then -- FIXME: this code write to address total_page!!!
                text_sm <= TEXT_WRITE0;
              else
                s_ddr_awaddr  <= s_ddr_awaddr + 16;
                s_ddr_awvalid <= '1';
                s_ddr_wvalid  <= '1';
                text_sm       <= TEXT_CLR0;
              end if;
            elsif s_ddr_awready then
              s_ddr_awvalid <= '0';
              text_sm       <= TEXT_CLR1;
            elsif s_ddr_wready then
              s_ddr_wvalid <= '0';
              text_sm      <= TEXT_CLR2;
            end if;

          -- Clear screen: got s_ddr_awready, wait for s_ddr_wready
          when TEXT_CLR1 =>
            if s_ddr_wready then
              s_ddr_wvalid <= '0';
              if s_ddr_awaddr >= total_page then
                text_sm <= TEXT_WRITE0;
              else
                s_ddr_awaddr  <= s_ddr_awaddr + 16;
                s_ddr_awvalid <= '1';
                s_ddr_wvalid  <= '1';   -- REVIEW: where does the wdata come from?
                text_sm       <= TEXT_CLR0;
              end if;
            end if;

          -- Clear screen: got s_ddr_wready, wait for s_ddr_awready
          when TEXT_CLR2 =>
            if s_ddr_awready then
              s_ddr_awvalid <= '0';
              if s_ddr_awaddr >= total_page then
                text_sm <= TEXT_WRITE0;
              else
                s_ddr_awaddr  <= s_ddr_awaddr + 16;
                s_ddr_awvalid <= '1';
                s_ddr_wvalid  <= '1';
                text_sm       <= TEXT_CLR0;
              end if;
            end if;

          -- Write resolution text:
          --  * address first character in current row (char_y)
          when TEXT_WRITE0 =>
            assert char_x = (0, 0, 0) severity failure;
            char_index <= character'pos(get_res_char(sw_capt, char_x(0))); -- get ASCII code for the current character
            char_x(0)  <= char_x(0) + 1;
            text_sm    <= TEXT_WRITE1;

          -- Write resolution text:
          --  * save current character row (char_slice)
          --  * address next character in current row
          when TEXT_WRITE1 =>
            char_index                                              <= character'pos(get_res_char(sw_capt, char_x(0))); -- get ASCII code for the current character
            if char_x(0) < RES_TEXT_LENGTH - 1 then
              char_x(0) <= char_x(0) + 1;
            end if;
            -- Update write data word with the current character slice
            wdata_bit_index                                         := char_x(2) * 8;
            s_ddr_wdata(wdata_bit_index + 7 downto wdata_bit_index) <= char_slice;
            -- Write data word is complete: issue AXI4 write transaction
            if char_x(2) = RES_TEXT_LENGTH - 1 then
              s_ddr_awvalid <= '1';
              s_ddr_awaddr  <= resize(to_unsigned(char_y, 3) * real_pitch, s_ddr_awaddr'length);
              s_ddr_wvalid  <= '1';
              s_ddr_wstrb   <= (others => '1');
              s_ddr_wlast   <= '1';
              text_sm       <= TEXT_WRITE2;
            end if;

          -- Write resolution text: wait for s_ddr_awready and/or s_ddr_wready
          -- TODO: evaluate write response?
          when TEXT_WRITE2 =>
            if s_ddr_awready and s_ddr_wready then
              s_ddr_awvalid <= '0';
              s_ddr_wvalid  <= '0';
              if char_y = CHAR_ROWS - 1 then
                text_sm <= TEXT_IDLE;
              else
                char_x  <= (others => 0);
                char_y  <= char_y + 1;  -- proceed with next character row
                text_sm <= TEXT_WRITE0;
              end if;
            elsif s_ddr_awready then
              s_ddr_awvalid <= '0';
              text_sm       <= TEXT_WRITE3;
            elsif s_ddr_wready then
              s_ddr_wvalid <= '0';
              text_sm      <= TEXT_WRITE4;
            end if;

          -- Write resolution text: got s_ddr_awready, wait for s_ddr_wready
          when TEXT_WRITE3 =>
            if s_ddr_wready then
              s_ddr_wvalid <= '0';
              if char_y = CHAR_ROWS - 1 then
                text_sm <= TEXT_IDLE;
              else
                char_x  <= (others => 0);
                char_y  <= char_y + 1;  -- proceed with next character row
                text_sm <= TEXT_WRITE0;
              end if;
            end if;

          -- Write resolution text: got s_ddr_wready, wait for s_ddr_awready
          when TEXT_WRITE4 =>
            if s_ddr_awready then
              s_ddr_awvalid <= '0';
              if char_y = CHAR_ROWS - 1 then
                text_sm <= TEXT_IDLE;
              else
                char_x  <= (others => 0);
                char_y  <= char_y + 1;  -- proceed with next character row
                text_sm <= TEXT_WRITE0;
              end if;
            end if;

          when others =>                -- REVIEW: TEXT_WRITE5?
            null;
        end case;
      end if;
    end if;
  end process;
end architecture rtl;
