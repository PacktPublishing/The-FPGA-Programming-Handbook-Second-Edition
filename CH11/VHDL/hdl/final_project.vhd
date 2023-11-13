-- final_project.vhd
-- ------------------------------------
-- Final project top level
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- The final project wraps a PS/2 interface, a VGA and also audio

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

library xpm;
use XPM.vcomponents.all;

use WORK.counting_buttons_pkg.all;
use WORK.temp_pkg.all;
use WORK.vga_pkg.all;

entity final_project is
  port (
    clk        : in    std_logic;
    vga_hsync  : out   std_logic;
    vga_vsync  : out   std_logic;
    vga_rgb    : out   std_logic_vector(11 downto 0);

    SW         : in    std_logic_vector(4 downto 0); -- Switches to configure resolutiontion
    button_c   : in    std_logic; -- Center button
    cpu_resetn : in    std_logic; -- When pressed, reset

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
    ddr2_odt   : out   std_logic_vector(0 downto 0);

    ps2_clk    : inout std_logic;
    ps2_data   : inout std_logic;

    TMP_SCL    : inout std_logic;
    TMP_SDA    : inout std_logic;
    TMP_INT    : inout std_logic;
    TMP_CT     : inout std_logic;

    -- Microphone interface
    m_clk      : out   std_logic;
    m_lr_sel   : out   std_logic;
    m_data     : in    std_logic;

    LED        : out   std_logic_vector(0 downto 0));
end entity final_project;

architecture rtl of final_project is

  -- Constants
  constant MMCM_REGISTER_COUNT  : natural                      := 24;
  constant VGA_REGISTER_COUNT   : natural                      := 8;
  constant TOTAL_REGISTER_COUNT : natural                      := MMCM_REGISTER_COUNT + VGA_REGISTER_COUNT;
  constant MMCM_IDX             : natural                      := 0;
  constant VGA_IDX              : natural                      := 1;
  constant CHAR_ROWS            : natural                      := 8; -- number of rows in character bitmap
  constant RES_TEXT_LENGTH      : natural                      := RES_TEXT(0)'length; -- 16
  constant AXI4_OKAY            : std_logic_vector(1 downto 0) := "00";
  constant PS2_DEPTH            : integer                      := 8;
  constant AMP_DEPTH            : integer                      := 1024;

  -- types
  type ps2_t is record
    data  : std_logic_vector(7 downto 0);
    error : std_logic;
  end record;

  type cfg_state_t is (
    CFG_IDLE0, CFG_IDLE1, CFG_WR0, CFG_WR1, CFG_WR2, CFG_MMCM_WAIT_BRESP, CFG_MMCM_WAIT_LOCKED,
    CFG_WR3, CFG_WR31, CFG_WR4, CFG_WR5, CFG_VGA_WAIT_BRESP);

  type pdm_data_t is record
    address : std_logic_vector(8 downto 0);
    data    : std_logic_vector(127 downto 0);
  end record;

  type wave_sm_t is (WAVE_IDLE, WAVE_READ0, WAVE_READ1);

  type char_x_t is array (natural range <>) of integer range 0 to RES_TEXT_LENGTH - 1;

  type text_sm_t is (TEXT_IDLE, TEXT_CLR0, TEXT_CLR1, TEXT_CLR2,
                     TEXT_CLR_WAIT_BRESP, TEXT_WRITE_WAIT_BRESP,
                     TEXT_WRITE0, TEXT_WRITE1, TEXT_WRITE2,
                     TEXT_WRITE3, TEXT_WRITE4);

  type slv2_array_t is array (natural range <>) of std_logic_vector(1 downto 0);
  type res_text_capt_t is array (natural range <>) of character;

  -- Registered signals with initial values
  signal ps2_data_store            : res_text_capt_t(PS2_DEPTH*2-1 downto 0) := (others => ' ');
  signal ps2_toggle                : std_logic := '0';
  signal ps2_sync                  : std_logic_vector(2 downto 0) := "000";
  signal update_ps2                : std_logic := '0';
  signal clear_ps2                 : std_logic := '0';
  signal s_axi_awaddr              : std_logic_vector(11 downto 0)            := (others => '0'); -- [clk200 domain]
  signal s_axi_awvalid             : std_logic_vector(1 downto 0)             := (others => '0'); -- 0: pix_clk, 1: vga_core [clk200 domain]
  signal s_axi_wdata               : std_logic_vector(31 downto 0)            := (others => '0'); -- [clk200 domain]
  signal s_axi_wvalid              : std_logic_vector(1 downto 0)             := (others => '0'); -- 0: pix_clk, 1: vga_core [clk200 domain]
  signal char_index                : natural range 0 to 255                   := 0; -- character index (ASCII code) in text_rom [ui_clk domain]
  signal char_y                    : natural range 0 to CHAR_ROWS - 1         := 0; -- character row index [ui_clk domain]
  signal s_ddr_awaddr              : unsigned(26 downto 0)                    := (others => '0'); -- [ui_clk domain]
  signal s_ddr_awlen               : std_logic_vector(7 downto 0)             := (others => '0'); -- [ui_clk domain]
  signal s_ddr_awsize              : std_logic_vector(2 downto 0)             := "100"; -- 16 bytes in transfer [ui_clk domain]
  signal s_ddr_awburst             : std_logic_vector(1 downto 0)             := "01"; -- [ui_clk domain]
  signal s_ddr_awlock              : std_logic_vector(0 downto 0)             := "0"; -- [ui_clk domain]
  signal s_ddr_awcache             : std_logic_vector(3 downto 0)             := (others => '0'); -- [ui_clk domain]
  signal s_ddr_awprot              : std_logic_vector(2 downto 0)             := (others => '0'); -- [ui_clk domain]
  signal s_ddr_awqos               : std_logic_vector(3 downto 0)             := (others => '0'); -- [ui_clk domain]
  signal s_ddr_awvalid             : std_logic                                := '0'; -- [ui_clk domain]
  signal s_ddr_wdata               : std_logic_vector(127 downto 0)           := (others => '0'); -- [ui_clk domain]
  signal s_ddr_wstrb               : std_logic_vector(15 downto 0)            := (others => '0'); -- [ui_clk domain]
  signal s_ddr_wlast               : std_logic                                := '0'; -- [ui_clk domain]
  signal s_ddr_wvalid              : std_logic                                := '0'; -- [ui_clk domain]
  signal s_ddr_bready              : std_logic                                := '0'; -- [ui_clk domain]
  signal cfg_state                 : cfg_state_t                              := CFG_IDLE0; -- [clk200 domain]
  signal button_sync               : std_logic_vector(2 downto 0)             := "000"; -- [ui_clk domain]
  signal sw_capt                   : integer range 0 to RESOLUTION'length - 1 := 0; -- [clk200 domain]
  signal wr_count                  : integer range 0 to TOTAL_REGISTER_COUNT  := 0; -- AXI4-lite write transaction counter [clk200 domain]
  signal update_text               : std_logic                                := '0'; -- [clk200 domain]
  signal update_text_sync          : std_logic_vector(2 downto 0)             := "000"; -- [ui_clk domain]
  signal update_temp               : std_logic                                := '0'; -- [ui_clk domain]
  signal update_temp_capt          : std_logic                                := '0'; -- [ui_clk domain]
  signal update_temp_sync          : std_logic_vector(2 downto 0)             := "000"; -- [ui_clk domain]
  signal text_sm                   : text_sm_t                                := TEXT_IDLE; -- [ui_clk domain]
  signal total_page                : unsigned(24 downto 0)                    := (others => '0'); -- [ui_clk domain]
  signal char_x                    : char_x_t(2 downto 0)                     := (others => 0); -- NOTE: could be a variable [ui_clk domain]
  signal pix_clk_locked_clk200_old : std_logic                                := '0'; -- [clk200 domain]
  signal vga_sync_toggle_sync      : std_logic_vector(2 downto 0)             := "000";
  signal pdm_push                  : std_logic                                := '0';
  signal pdm_pop                   : std_logic                                := '0';
  signal ftemp                     : std_logic                                := '0'; -- 0 = celsius, 1 = Fahrenheit
  signal amplitude_store           : array_t(AMP_DEPTH-1 downto 0)(6 downto 0) := (others => "0000000");
  signal amp_rd, amp_wr            : integer range 0 to AMP_DEPTH             := 0;
  signal rd_count                  : integer range 0 to 256                   := 0;
  signal wave_sm                   : wave_sm_t                                := WAVE_IDLE;
  signal capt_text                 : res_text_capt_t(15 downto 0)             := (others => ' ');

  -- Unregistered signals without initial values
  signal sys_pll_locked        : std_logic;
  signal locked                : std_logic; -- pix_clk locked
  signal rst200                : std_logic;
  signal s_axi_awready         : std_logic_vector(1 downto 0); -- 0: pix_clk, 1: vga_core
  signal s_axi_wready          : std_logic_vector(1 downto 0); -- 0: pix_clk, 1: vga_core
  signal s_axi_bvalid          : std_logic_vector(1 downto 0);
  signal s_axi_bready          : std_logic_vector(1 downto 0);
  signal s_axi_bresp           : slv2_array_t(1 downto 0);
  signal vga_clk               : std_logic;
  signal mc_clk                : std_logic; -- 325 MHz
  signal clk200                : std_logic;
  signal char_slice            : std_logic_vector(7 downto 0);
  signal ui_clk                : std_logic; -- 325/4 = 81.25 MHz
  signal ui_clk_sync_rst       : std_logic;
  signal s_ddr_awid            : std_logic_vector(3 downto 0);
  signal s_ddr_awready         : std_logic;
  signal s_ddr_wready          : std_logic;
  signal s_ddr_bid             : std_logic_vector(3 downto 0);
  signal s_ddr_bresp           : std_logic_vector(1 downto 0);
  signal s_ddr_bvalid          : std_logic;
  signal s_ddr_arid            : std_logic_vector(3 downto 0);
  signal s_ddr_araddr          : std_logic_vector(26 downto 0);
  signal s_ddr_arlen           : std_logic_vector(7 downto 0);
  signal s_ddr_arsize          : std_logic_vector(2 downto 0);
  signal s_ddr_arburst         : std_logic_vector(1 downto 0);
  signal s_ddr_arlock          : std_logic_vector(0 downto 0);
  signal s_ddr_arcache         : std_logic_vector(3 downto 0);
  signal s_ddr_arprot          : std_logic_vector(2 downto 0);
  signal s_ddr_arqos           : std_logic_vector(3 downto 0);
  signal s_ddr_arvalid         : std_logic;
  signal s_ddr_arready         : std_logic;
  signal s_ddr_rid             : std_logic_vector(3 downto 0);
  signal s_ddr_rdata           : std_logic_vector(127 downto 0);
  signal s_ddr_rresp           : std_logic_vector(1 downto 0);
  signal s_ddr_rlast           : std_logic;
  signal s_ddr_rvalid          : std_logic;
  signal s_ddr_rready          : std_logic;
  signal int_vga_rgb           : std_logic_vector(23 downto 0);
  signal vga_rst               : std_logic;
  signal pix_clk_locked_clk200 : std_logic;
  signal init_calib_complete   : std_logic; -- @suppress "signal init_calib_complete is never read"
  signal ps2_data_capt         : ps2_t;
  signal vga_sync_toggle       : std_logic;
  signal pdm_din               : pdm_data_t;
  constant pdm_length : integer := pdm_din.address'length + pdm_din.data'length;
  signal pdm_dout_fifo         : std_logic_vector(pdm_length-1 downto 0);
  signal pdm_dout              : pdm_data_t;
  signal pdm_empty             : std_logic;
  signal ps2_rx_data           : std_logic_vector(7 downto 0);
  signal ps2_rx_valid          : std_logic;
  signal ps2_rx_err            : std_logic;
  signal amplitude             : unsigned(6 downto 0);
  signal amplitude_valid       : std_logic;
  signal amp_data              : std_logic_vector(6 downto 0);
  signal capt_temp             : array_t(15 downto 0)(7 downto 0);
  signal y_offset              : integer;
  signal char_ps2              : natural range 0 to 255                   := 0; -- character index (ASCII code) in text_rom [ui_clk domain]

  -- Attributes
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of button_sync : signal is "TRUE";
  attribute ASYNC_REG of update_text_sync : signal is "TRUE";
  attribute ASYNC_REG of update_temp_sync : signal is "TRUE";
  attribute ASYNC_REG of ps2_sync : signal is "TRUE";
  attribute ASYNC_REG of vga_sync_toggle_sync : signal is "TRUE";

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
  attribute MARK_DEBUG of pdm_empty, pdm_pop, pdm_dout : signal is "TRUE";

begin

  ------------------------------------------------------------------------------
  -- System clock PLL
  ------------------------------------------------------------------------------

  u_sys_clk : sys_pll
    port map(
      clk_out1 => clk200,
      clk_out2 => mc_clk,               -- 325 MHz
      locked   => sys_pll_locked,
      clk_in1  => clk
    );

  -- 200 MHz reset synchronizer
  u_rst200_sync : xpm_cdc_async_rst
    generic map(
      DEST_SYNC_FF    => 4,             -- DECIMAL; range: 2-10
      INIT_SYNC_FF    => 0,             -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
      RST_ACTIVE_HIGH => 1              -- DECIMAL; 0=active low reset, 1=active high reset
    )
    port map(
      src_arst  => not sys_pll_locked,  -- 1-bit input: Source asynchronous reset signal.
      dest_clk  => clk200,              -- 1-bit input: Destination clock.
      dest_arst => rst200               -- 1-bit output: src_arst asynchronous reset signal synchronized to destination clock domain
    );

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
      s_axi_bresp   => s_axi_bresp(MMCM_IDX),
      s_axi_bvalid  => s_axi_bvalid(MMCM_IDX),
      s_axi_bready  => s_axi_bready(MMCM_IDX),
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
      locked        => locked,
      -- Clock in ports
      clk_in1       => clk200
    );

  -- Generate vga_rst
  u_vga_rst_sync : xpm_cdc_async_rst
    generic map(
      DEST_SYNC_FF    => 2,             -- DECIMAL; range: 2-10
      INIT_SYNC_FF    => 0,             -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
      RST_ACTIVE_HIGH => 1              -- DECIMAL; 0=active low reset, 1=active high reset
    )
    port map(
      src_arst  => not locked,          -- 1-bit input: Source asynchronous reset signal.
      dest_clk  => vga_clk,             -- 1-bit input: Destination clock.
      dest_arst => vga_rst              -- 1-bit output: src_arst asynchronous reset signal synchronized to destination clock domain
    );

  u_pix_clk_locked_sync : xpm_cdc_single
    generic map(
      DEST_SYNC_FF   => 4,              -- DECIMAL; range: 2-10
      INIT_SYNC_FF   => 0,              -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
      SIM_ASSERT_CHK => 0,              -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
      SRC_INPUT_REG  => 0               -- DECIMAL; 0=do not register input, 1=register input
    )
    port map(
      src_clk  => '0',                  -- 1-bit input: optional; required when SRC_INPUT_REG = 1
      src_in   => locked,               -- 1-bit input: Input signal to be synchronized to dest_clk domain.
      dest_clk => clk200,               -- 1-bit input: Clock signal for the destination clock domain.
      dest_out => pix_clk_locked_clk200 -- 1-bit output: src_in synchronized to the destination clock domain. This output is registered.
    );

  ------------------------------------------------------------------------------
  -- Text character bitmap ROM
  ------------------------------------------------------------------------------

  u_text_rom : entity work.text_rom
    port map(
      clock      => ui_clk,             -- Clock
      index      => std_logic_vector(to_unsigned(char_index, 8)), -- Character Index
      sub_index  => std_logic_vector(to_unsigned(char_y, 3)), -- Y position in character
      bitmap_out => char_slice          -- 8 bit horizontal slice of character
    );

  ------------------------------------------------------------------------------
  -- DDR2 Controller
  ------------------------------------------------------------------------------

  s_ddr_awid    <= (others => '0');
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
      mmcm_locked         => open,
      aresetn             => not ui_clk_sync_rst, -- Input reset to the AXI Shim and it should be in synchronous with FPGA logic clock.
      --aresetn             => '1', -- Input reset to the AXI Shim and it should be in synchronous with FPGA logic clock.
      app_sr_req          => '0',
      app_ref_req         => '0',
      app_zq_req          => '0',
      app_sr_active       => open,
      app_ref_ack         => open,
      app_zq_ack          => open,
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
      sys_rst             => '1');      -- asynchronous system reset input

  ------------------------------------------------------------------------------
  -- VGA Controller
  ------------------------------------------------------------------------------

  u_vga_core : entity work.vga_core
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
      reg_wstrb   => (others => '1'),
      reg_bready  => s_axi_bready(VGA_IDX),
      reg_bvalid  => s_axi_bvalid(VGA_IDX),
      reg_bresp   => s_axi_bresp(VGA_IDX),
      reg_arvalid => '0',
      reg_arready => open,
      reg_araddr  => (others => '0'),
      reg_rready  => '1',
      reg_rvalid  => open,
      reg_rdata   => open,
      reg_rresp   => open,
      -- Master memory
      mem_clk     => ui_clk,
      mem_reset   => ui_clk_sync_rst,
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
      -- VGA output
      vga_clk     => vga_clk,
      vga_rst     => vga_rst,
      vga_hsync   => vga_hsync,
      vga_hblank  => open,
      vga_vsync   => vga_vsync,
      vga_vblank  => open,
      vga_rgb     => int_vga_rgb,
      vga_sync_toggle => vga_sync_toggle
    );

  vga_rgb <= int_vga_rgb(23 downto 20) & int_vga_rgb(15 downto 12) & int_vga_rgb(7 downto 4);

  -- Temperature sensor
  u_i2c_wrapper : entity work.i2c_wrapper
    generic map (CLK_PER          => 5)
    port map    (clk              => clk200,

                 TMP_SCL          => TMP_SCL,
                 TMP_SDA          => TMP_SDA,
                 TMP_INT          => TMP_INT,
                 TMP_CT           => TMP_CT,

                 ftemp            => ftemp,

                 update_temp      => update_temp,
                 capt_temp        => capt_temp);

  -- Audio data
  u_pdm_inputs : entity work.pdm_inputs
    generic map (CLK_FREQ         => 200)    -- Mhz
    port map    (clk              => clk200,

                 -- Microphone interface
                 m_clk            => m_clk,
                 m_clk_en         => open,
                 m_data           => m_data,

                 -- Amplitude outputs
                 amplitude        => amplitude,
                 amplitude_valid  => amplitude_valid);

  -- PS/2 interface
  u_ps2_host : entity work.ps2_host
    generic map (CLK_PER          => 5,
                 CYCLES           => 32)
    port map    (clk              => clk200,
                 reset            => rst200,

                 ps2_clk          => ps2_clk,
                 ps2_data         => ps2_data,

                 tx_valid         => '0',
                 tx_data          => x"00",

                 rx_data          => ps2_rx_data,
                 rx_user          => ps2_rx_err,
                 rx_valid         => ps2_rx_valid,
                 rx_ready         => '1');

  u_xpm_fifo_async : xpm_fifo_async
    generic map(FIFO_WRITE_DEPTH => 512, WRITE_DATA_WIDTH => pdm_length, READ_DATA_WIDTH => pdm_length, READ_MODE => "fwft")
        port map(sleep         => '0',
                 rst           => rst200,
                 wr_clk        => clk200,
                 wr_en         => pdm_push,
                 din           => pdm_din.address & pdm_din.data,
                 rd_clk        => ui_clk,
                 rd_en         => pdm_pop,
                 dout          => pdm_dout_fifo,
                 empty         => pdm_empty,
                 injectsbiterr => '0',
                 injectdbiterr => '0');

  pdm_dout.data <= pdm_dout_fifo(pdm_dout.data'length-1 downto 0);
  pdm_dout.address <= pdm_dout_fifo(pdm_length-1 downto pdm_dout.data'length);

  ------------------------------------------------------------------------------
  -- PLL and VGA Configuration FSM
  ------------------------------------------------------------------------------

  config_fsm : process(clk200)
    -- Helper variables
    variable sw_int : integer range 0 to 31;
  begin
    if rising_edge(clk200) then
      if rst200 = '1' then
        button_sync               <= (others => '0');
        wr_count                  <= 0;
        cfg_state                 <= CFG_IDLE0;
        update_text               <= '0';
        sw_capt                   <= 0;
        s_axi_awvalid             <= (others => '0');
        s_axi_awaddr              <= (others => '0');
        s_axi_wvalid              <= (others => '0');
        s_axi_wdata               <= (others => '0');
        s_axi_bready              <= (others => '0');
        pix_clk_locked_clk200_old <= '0';
      else
        pix_clk_locked_clk200_old <= pix_clk_locked_clk200;

        -- Synchronize the center button signal
        button_sync <= button_sync(1 downto 0) & button_c;

        case cfg_state is

          -- Initial state
          when CFG_IDLE0 =>
            button_sync(2 downto 1) <= "10"; -- force programming on startup
            update_text             <= not update_text;
            wr_count                <= 0;
            cfg_state               <= CFG_IDLE1;

          -- Wait for config trigger (center button press)
          when CFG_IDLE1 =>
            assert wr_count = 0 severity failure;
            s_axi_awvalid(MMCM_IDX) <= '0';
            s_axi_wvalid(MMCM_IDX)  <= '0';
            if button_sync(2 downto 1) = "10" then
              update_text             <= not update_text; -- we can start writing the text as we are updating
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
            if s_axi_awready(MMCM_IDX) = '1' and s_axi_wready(MMCM_IDX) = '1' then
              s_axi_awvalid(MMCM_IDX) <= '0';
              s_axi_wvalid(MMCM_IDX)  <= '0';
              s_axi_bready(MMCM_IDX)  <= '1';
              cfg_state               <= CFG_MMCM_WAIT_BRESP;
            elsif s_axi_awready(MMCM_IDX) then
              s_axi_awvalid(MMCM_IDX) <= '0';
              cfg_state               <= CFG_WR1;
            elsif s_axi_wready(MMCM_IDX) then
              s_axi_wvalid(MMCM_IDX) <= '0';
              cfg_state              <= CFG_WR2;
            end if;

          -- Load MMCM registers, wait for wready
          when CFG_WR1 =>
            if s_axi_wready(MMCM_IDX) then
              s_axi_wvalid(MMCM_IDX) <= '0';
              s_axi_bready(MMCM_IDX) <= '1';
              cfg_state              <= CFG_MMCM_WAIT_BRESP;
            end if;

          -- Load MMCM registers, wait for awready
          when CFG_WR2 =>
            if s_axi_awready(MMCM_IDX) then
              s_axi_awvalid(MMCM_IDX) <= '0';
              s_axi_bready(MMCM_IDX)  <= '1';
              cfg_state               <= CFG_MMCM_WAIT_BRESP;
            end if;

          -- Load MMCM registers, wait for write response
          when CFG_MMCM_WAIT_BRESP =>
            assert s_axi_bready(MMCM_IDX) = '1' severity failure;
            if s_axi_bvalid(MMCM_IDX) then
              assert s_axi_bresp(MMCM_IDX) = AXI4_OKAY severity failure;
              s_axi_bready(MMCM_IDX) <= '0';
              if wr_count = MMCM_REGISTER_COUNT then
                cfg_state <= CFG_MMCM_WAIT_LOCKED;
              else
                s_axi_awvalid(MMCM_IDX) <= '1';
                s_axi_wvalid(MMCM_IDX)  <= '1';
                cfg_state               <= CFG_WR0;
                s_axi_awaddr            <= ADDR_ARRAY(wr_count);
                s_axi_wdata             <= resolution_lookup(sw_capt, wr_count);
                wr_count                <= wr_count + 1;
              end if;
            end if;

          -- Load MMCM registers, wait until MMCM has re-locked and vga_clock is valid
          when CFG_MMCM_WAIT_LOCKED =>
            if pix_clk_locked_clk200 = '1' and pix_clk_locked_clk200_old = '0' then
              cfg_state <= CFG_WR3;
            end if;

          -- Load VGA registers
          when CFG_WR3 =>
            s_axi_awvalid(VGA_IDX) <= '1';
            s_axi_wvalid(VGA_IDX)  <= '1';
            cfg_state              <= CFG_WR31;
            s_axi_awaddr           <= ADDR_ARRAY(wr_count);
            s_axi_wdata            <= resolution_lookup(sw_capt, wr_count);
            wr_count               <= wr_count + 1;

          -- Load VGA registers: wait for awready and/or wready
          when CFG_WR31 =>
            if s_axi_awready(VGA_IDX) = '1' and s_axi_wready(VGA_IDX) = '1' then
              s_axi_awvalid(VGA_IDX) <= '0';
              s_axi_wvalid(VGA_IDX)  <= '0';
              s_axi_bready(VGA_IDX)  <= '1';
              cfg_state              <= CFG_VGA_WAIT_BRESP;
            elsif s_axi_awready(VGA_IDX) then
              s_axi_awvalid(VGA_IDX) <= '0';
              cfg_state              <= CFG_WR4;
            elsif s_axi_wready(VGA_IDX) then
              s_axi_wvalid(VGA_IDX) <= '0';
              cfg_state             <= CFG_WR5;
            end if;

          -- Load VGA registers: got awready, wait for wready
          when CFG_WR4 =>
            if s_axi_wready(VGA_IDX) then
              s_axi_wvalid(VGA_IDX) <= '0';
              s_axi_bready(VGA_IDX) <= '1';
              cfg_state             <= CFG_VGA_WAIT_BRESP;
            end if;

          -- Load VGA registers: got wready, wait for awready
          when CFG_WR5 =>
            if s_axi_awready(VGA_IDX) then
              s_axi_awvalid(VGA_IDX) <= '0';
              s_axi_bready(VGA_IDX)  <= '1';
              cfg_state              <= CFG_VGA_WAIT_BRESP;
            end if;

          -- Load VGA registers, wait for write response
          when CFG_VGA_WAIT_BRESP =>
            assert s_axi_bready(VGA_IDX) = '1' severity failure;
            if s_axi_bvalid(VGA_IDX) then
              assert s_axi_bresp(VGA_IDX) = AXI4_OKAY severity failure;
              s_axi_bready(VGA_IDX) <= '0';
              if wr_count = TOTAL_REGISTER_COUNT then
                wr_count  <= 0;
                cfg_state <= CFG_IDLE1;
              else
                cfg_state <= CFG_WR3;
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
    -- Registered state variables
    variable pitch : unsigned(12 downto 0);

    -- Helper variables
    variable sw_int          : integer range 0 to 31;
    variable wdata_bit_index : integer range 0 to 127;
  begin
    if rising_edge(ui_clk) then
      if ui_clk_sync_rst then
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
        s_ddr_bready     <= '0';
        --
        char_x           <= (others => 0);
        char_y           <= 0;
        text_sm          <= TEXT_IDLE;
        char_index       <= 0;
        total_page       <= (others => '0');
        pdm_pop          <= '0';

      else
        -- Defaults:
        s_ddr_awlen   <= 8d"0";
        s_ddr_awsize  <= "100";         -- 16 bytes in transfer
        s_ddr_awburst <= "01";          -- INCR burst type
        s_ddr_awlock  <= "0";           -- normal access
        s_ddr_awcache <= "0000";
        s_ddr_awprot  <= "000";
        s_ddr_awqos   <= "0000";
        pdm_pop       <= '0';

        -- Synchronize update_text toggle into ui_clk domain
        update_text_sync <= update_text_sync(1 downto 0) & update_text;
        update_temp_sync <= update_temp_sync(1 downto 0) & update_temp;
        if xor(update_temp_sync(2 downto 1)) then
          update_temp_capt <= '1';
        end if;

        -- Resolution character index delay line
        char_x(1) <= char_x(0);
        char_x(2) <= char_x(1);

        case text_sm is

          -- Clear screen: wait for update_text toggle
          when TEXT_IDLE =>
            char_x        <= (others => 0);
            char_y        <= 0;
            if xor(update_text_sync(2 downto 1)) then
              sw_int        := to_integer(unsigned(SW)); -- the switch encodes the VGA resolution
              sw_int        := minimum(RESOLUTION'length - 1, sw_int); -- saturate at the highest resolution index
              pitch         := get_pitch(RESOLUTION(sw_capt).horiz_display_width);
              -- Compute total image size
              total_page    <= RESOLUTION(sw_int).vert_display_width * pitch;
              -- Write 0x0 starting at DDR address 0x0
              y_offset      <= 0;
              s_ddr_awaddr  <= (others => '0');
              s_ddr_awvalid <= '1';
              s_ddr_wdata   <= (others => '0');
              s_ddr_wstrb   <= (others => '1');
              s_ddr_wlast   <= '1';
              s_ddr_wvalid  <= '1';
              char_index    <= character'pos(get_res_char(sw_capt, 1)); -- get ASCII code for the current character
              for i in 0 to 15 loop
                capt_text(i)   <= get_res_char(sw_capt, i);
              end loop;
              text_sm       <= TEXT_CLR0;
            elsif update_ps2 then
              -- We'll start the PS2 output on line 10
              y_offset      <= 10 * to_integer(unsigned(pitch));
              clear_ps2     <= '1';
              char_index    <= char_ps2;
              capt_text     <= ps2_data_store;
              s_ddr_awvalid <= '0';
              s_ddr_wvalid  <= '0';
              text_sm       <= TEXT_WRITE0;
            elsif update_temp_capt then
              -- We'll start the temperature output on line 18
              y_offset         <= 18 * to_integer(unsigned(pitch));
              update_temp_capt <= '0';
              --char_index       <= to_integer(unsigned(capt_temp(0)));
              char_index    <= to_integer(unsigned(capt_temp(0)));
              for i in 0 to 15 loop
                capt_text(i)   <= character'val(to_integer(unsigned(capt_temp(i))));
              end loop;
              s_ddr_awvalid    <= '0';
              s_ddr_wvalid     <= '0';
              text_sm          <= TEXT_WRITE0;
            elsif not pdm_empty then
              pdm_pop          <= '1';
              char_y           <= 7; -- Force only one line to be written
              --update_temp_capt <= '0';
              s_ddr_awvalid    <= '1';
              s_ddr_awaddr     <= "00000" & (unsigned(pdm_dout.address) * pitch);
              s_ddr_wvalid     <= '1';
              s_ddr_wdata      <= pdm_dout.data;
              text_sm          <= TEXT_WRITE2;
            end if;

          -- Clear screen: wait for s_ddr_awready and/or s_ddr_wready
          when TEXT_CLR0 =>
            if s_ddr_awready and s_ddr_wready then
              s_ddr_awvalid <= '0';
              s_ddr_wvalid  <= '0';
              s_ddr_bready  <= '1';
              text_sm       <= TEXT_CLR_WAIT_BRESP;
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
              s_ddr_bready <= '1';
              text_sm      <= TEXT_CLR_WAIT_BRESP;
            end if;

          -- Clear screen: got s_ddr_wready, wait for s_ddr_awready
          when TEXT_CLR2 =>
            if s_ddr_awready then
              s_ddr_awvalid <= '0';
              s_ddr_bready  <= '1';
              text_sm       <= TEXT_CLR_WAIT_BRESP;
            end if;

          -- Clear screen: wait for write response
          when TEXT_CLR_WAIT_BRESP =>
            assert s_ddr_bready severity failure;
            if s_ddr_bvalid then
              s_ddr_bready <= '0';
              assert s_ddr_bresp = AXI4_OKAY severity failure;
              assert s_ddr_bid = 4x"0" severity failure;
              assert total_page mod BYTES_PER_PAGE = 0 severity failure;
              if s_ddr_awaddr = total_page - BYTES_PER_PAGE then
                text_sm <= TEXT_WRITE0;
              else
                s_ddr_bready  <= '0';
                s_ddr_awaddr  <= s_ddr_awaddr + BYTES_PER_PAGE;
                s_ddr_awvalid <= '1';
                s_ddr_wvalid  <= '1';
                text_sm       <= TEXT_CLR0;
              end if;
            end if;

          -- Write resolution text:
          --  * address first character in current row (char_y)
          when TEXT_WRITE0 =>
            assert char_x = (0, 0, 0) severity failure;
            --char_index <= character'pos(get_res_char(sw_capt, char_x(0))); -- get ASCII code for the current character
            char_index <= character'pos(capt_text(char_x(0))); -- get ASCII code for the current character
            char_x(0)  <= char_x(0) + 1;
            text_sm    <= TEXT_WRITE1;

          -- Write resolution text:
          --  * save current character row (char_slice)
          --  * address next character in current row
          when TEXT_WRITE1 =>
            --char_index   <= character'pos(get_res_char(sw_capt, char_x(0))); -- get ASCII code for the current character
            char_index <= character'pos(capt_text(char_x(0))); -- get ASCII code for the current character
            if char_x(0) < RES_TEXT_LENGTH - 1 then
              char_x(0) <= char_x(0) + 1;
            end if;
            -- Update write data word with the current character slice
            wdata_bit_index                                         := char_x(2) * 8;
            s_ddr_wdata(wdata_bit_index + 7 downto wdata_bit_index) <= char_slice;
            -- Write data word is complete: issue AXI4 write transaction
            if char_x(2) = RES_TEXT_LENGTH - 1 then
              s_ddr_awvalid <= '1';
              s_ddr_awaddr  <= resize(to_unsigned(char_y, 3) * pitch + y_offset, s_ddr_awaddr'length);
              s_ddr_wvalid  <= '1';
              s_ddr_wstrb   <= (others => '1');
              s_ddr_wlast   <= '1';
              text_sm       <= TEXT_WRITE2;
            end if;

          -- Write resolution text: wait for s_ddr_awready and/or s_ddr_wready
          when TEXT_WRITE2 =>
            if s_ddr_awready and s_ddr_wready then
              s_ddr_awvalid <= '0';
              s_ddr_wvalid  <= '0';
              s_ddr_bready  <= '1';
              text_sm       <= TEXT_WRITE_WAIT_BRESP;
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
              s_ddr_bready <= '1';
              text_sm      <= TEXT_WRITE_WAIT_BRESP;
            end if;

          -- Write resolution text: got s_ddr_wready, wait for s_ddr_awready
          when TEXT_WRITE4 =>
            if s_ddr_awready then
              s_ddr_awvalid <= '0';
              s_ddr_bready  <= '1';
              text_sm       <= TEXT_WRITE_WAIT_BRESP;
            end if;

          -- Write resolution text: wait for write response
          when TEXT_WRITE_WAIT_BRESP =>
            assert s_ddr_bready severity failure;
            if s_ddr_bvalid then
              assert s_ddr_bresp = AXI4_OKAY severity failure;
              s_ddr_bready <= '0';
              if char_y = CHAR_ROWS - 1 then
                text_sm <= TEXT_IDLE;
              else
                char_x  <= (others => 0);
                char_y  <= char_y + 1;  -- proceed with next character row
                text_sm <= TEXT_WRITE0;
              end if;
            end if;

        end case;
      end if;
    end if;
  end process;

  char_ps2 <= character'pos(ps2_data_store(0));

  -- toggle sync and capture the data
  process (clk200)
  begin
    if rising_edge(clk200) then
      if ps2_rx_valid then
        ps2_toggle    <=  not ps2_toggle;
        ps2_data_capt <= (data => ps2_rx_data, error => ps2_rx_err);
        case ps2_rx_data is
          when x"2B" =>
            ftemp <= '1'; -- F = fahrenheit
          when x"21" =>
            ftemp <= '0'; -- C = celsius
          when others =>
        end case;
      end if;
    end if;
  end process;

  -- synchronize data on the UI clock
  process (ui_clk)
  begin
    if rising_edge(ui_clk) then
      ps2_sync <= ps2_sync(1 downto 0) &  ps2_toggle;

      if clear_ps2 then
        update_ps2 <= '0';
      end if;
      if xor(ps2_sync(2 downto 1)) then
        update_ps2 <= '1';
        for i in PS2_DEPTH-1 downto 0 loop
          if i = 0 then
            for j in 1 downto 0 loop
              case ps2_data_capt.data(j*4+3 downto j*4) is
                when x"0" => ps2_data_store(i*2+j) <= '0';
                when x"1" => ps2_data_store(i*2+j) <= '1';
                when x"2" => ps2_data_store(i*2+j) <= '2';
                when x"3" => ps2_data_store(i*2+j) <= '3';
                when x"4" => ps2_data_store(i*2+j) <= '4';
                when x"5" => ps2_data_store(i*2+j) <= '5';
                when x"6" => ps2_data_store(i*2+j) <= '6';
                when x"7" => ps2_data_store(i*2+j) <= '7';
                when x"8" => ps2_data_store(i*2+j) <= '8';
                when x"9" => ps2_data_store(i*2+j) <= '9';
                when x"A" => ps2_data_store(i*2+j) <= 'A';
                when x"B" => ps2_data_store(i*2+j) <= 'B';
                when x"C" => ps2_data_store(i*2+j) <= 'C';
                when x"D" => ps2_data_store(i*2+j) <= 'D';
                when x"E" => ps2_data_store(i*2+j) <= 'E';
                when x"F" => ps2_data_store(i*2+j) <= 'F';
                when others =>
              end case;
            end loop;
          else
            ps2_data_store(i*2+1 downto i*2) <= ps2_data_store((i-1)*2+1 downto (i-1)*2);
          end if;
        end loop;
      end if;
    end if;
  end process;

  -- data storage
  -- Setup a storage buffer for amplitudes. Make it large enough that we can
  -- window into it and it remains stable
  process (clk200)
  begin
    if rising_edge(clk200) then
      if amplitude_valid then
        amplitude_store(amp_wr) <= std_logic_vector(amplitude);
        amp_wr                  <= amp_wr + 1;
      end if;
      amp_data <= amplitude_store(amp_rd);
    end if;
  end process;

  process (clk200)
  begin
    if rising_edge(clk200) then
      vga_sync_toggle_sync <= vga_sync_toggle_sync(1 downto 0) & vga_sync_toggle;
      pdm_push <= '0';
      case wave_sm is
        when WAVE_IDLE =>
          if xor(vga_sync_toggle_sync(2 downto 1)) then
            -- get the amplitude data from behind the write pointer
            -- by 256 samples
            amp_rd   <= amp_wr - 256;
            rd_count <= 0;
            wave_sm  <= WAVE_READ0;
          end if;
        when WAVE_READ0 =>
          -- address to ram valid this cycle
          amp_rd   <= amp_rd + 1;
          rd_count <= rd_count + 1;
          wave_sm  <= WAVE_READ1;
        when WAVE_READ1 =>
          -- address to ram valid this cycle
          amp_rd           <= amp_rd + 1;
          rd_count         <= rd_count + 1;
          pdm_push         <= '1';
          pdm_din.address  <= std_logic_vector(to_unsigned(31 + rd_count, pdm_din.address'length));
          pdm_din.data     <= (others => '0');
          pdm_din.data(to_integer(unsigned(amp_data))) <= '1';
          if rd_count = 256 then wave_sm <= WAVE_IDLE; end if;
      end case;
    end if;
  end process;

end architecture rtl;
