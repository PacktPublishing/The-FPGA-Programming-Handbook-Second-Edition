LIBRARY IEEE, XPM;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;
use IEEE.math_real.all;
use XPM.vcomponents.all;
use WORK.vga_pkg.all;

entity vga is
  port (clk           : in    std_logic;
        vga_hsync     : out   std_logic;
        vga_vsync     : out   std_logic;
        vga_rgb       : out   std_logic_vector(11 downto 0);

        SW            : in    std_logic_vector(4 downto 0); -- Switches to configure resolution
        button_c      : in    std_logic; -- Center button
        cpu_resetn    : in    std_logic; -- When pressed, reset

        ddr2_addr     : out   std_logic_vector(12 downto 0);
        ddr2_ba       : out   std_logic_vector(2 downto 0);
        ddr2_cas_n    : out   std_logic;
        ddr2_ck_n     : out   std_logic_vector(0 downto 0);
        ddr2_ck_p     : out   std_logic_vector(0 downto 0);
        ddr2_cke      : out   std_logic_vector(0 downto 0);
        ddr2_ras_n    : out   std_logic;
        ddr2_we_n     : out   std_logic;
        ddr2_dq       : inout std_logic_vector(15 downto 0);
        ddr2_dqs_n    : inout std_logic_vector(1 downto 0);
        ddr2_dqs_p    : inout std_logic_vector(1 downto 0);
        ddr2_cs_n     : out   std_logic_vector(0 downto 0);
        ddr2_dm       : out std_logic_vector(1 downto 0);
        ddr2_odt      : out   std_logic_vector(0 downto 0));
end entity vga;

architecture rtl of vga is

  attribute MARK_DEBUG       : string;
  attribute ASYNC_REG        : string;
  signal vga_clk             : std_logic;
  signal init_calib_complete : std_logic;
  signal vga_hblank          : std_logic;
  signal vga_vblank          : std_logic;
  signal mc_clk              : std_logic;
  signal clk200              : std_logic;
  signal s_axi_awaddr        : std_logic_vector(11 downto 0);
  signal s_axi_awvalid       : std_logic_vector(1 downto 0);
  signal s_axi_awready       : std_logic_vector(1 downto 0);
  signal s_axi_wdata         : std_logic_vector(31 downto 0);
  signal s_axi_wvalid        : std_logic_vector(1 downto 0);
  signal s_axi_wready        : std_logic_vector(1 downto 0);
  signal locked              : std_logic;
  signal pll_rst             : std_logic;
  signal char_index          : std_logic_vector(7 downto 0);
  signal char_y              : unsigned(2 downto 0);
  signal char_slice          : std_logic_vector(7 downto 0);
  signal ui_clk              : std_logic;
  signal ui_clk_sync_rst     : std_logic;
  signal mmcm_locked         : std_logic;
  signal aresetn             : std_logic := '1';
  signal app_sr_req          : std_logic := '0';
  signal app_ref_req         : std_logic := '0';
  signal app_zq_req          : std_logic := '0';
  signal app_sr_active       : std_logic;
  signal app_ref_ack         : std_logic;
  signal app_zq_ack          : std_logic;
  signal s_ddr_awid          : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ddr_awaddr        : unsigned(26 downto 0);
  signal s_ddr_awlen         : std_logic_vector(7 downto 0) := (others => '0');
  signal s_ddr_awsize        : std_logic_vector(2 downto 0) := "100";
  signal s_ddr_awburst       : std_logic_vector(1 downto 0) := "01";
  signal s_ddr_awlock        : std_logic_vector(0 downto 0) := "0";
  signal s_ddr_awcache       : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ddr_awprot        : std_logic_vector(2 downto 0) := (others => '0');
  signal s_ddr_awqos         : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ddr_awvalid       : std_logic := '0';
  signal s_ddr_awready       : std_logic;
  signal s_ddr_wdata         : std_logic_vector(127 downto 0);
  signal s_ddr_wstrb         : std_logic_vector(15 downto 0) := (others => '0');
  signal s_ddr_wlast         : std_logic := '0';
  signal s_ddr_wvalid        : std_logic := '0';
  signal s_ddr_wready        : std_logic;
  attribute MARK_DEBUG of s_ddr_awaddr : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_awlen : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_awvalid : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_awready : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_wdata : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_wstrb : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_wlast : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_wvalid : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_wready : signal is "TRUE";
  signal s_ddr_bid           : std_logic_vector(3 downto 0);
  signal s_ddr_bresp         : std_logic_vector(1 downto 0);
  signal s_ddr_bvalid        : std_logic;
  signal s_ddr_bready        : std_logic := '1';
  signal s_ddr_arid          : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ddr_araddr        : std_logic_vector(26 downto 0);
  signal s_ddr_arlen         : std_logic_vector(7 downto 0);
  signal s_ddr_arsize        : std_logic_vector(2 downto 0) := "100"; -- 16 bytes
  signal s_ddr_arburst       : std_logic_vector(1 downto 0) := "01";  -- incrementing
  signal s_ddr_arlock        : std_logic_vector(0 downto 0);
  signal s_ddr_arcache       : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ddr_arprot        : std_logic_vector(2 downto 0) := (others => '0');
  signal s_ddr_arqos         : std_logic_vector(3 downto 0) := (others => '0');
  signal s_ddr_arvalid       : std_logic;
  signal s_ddr_arready       : std_logic;
  signal s_ddr_rid           : std_logic_vector(3 downto 0);
  signal s_ddr_rdata         : std_logic_vector(127 downto 0);
  signal s_ddr_rresp         : std_logic_vector(1 downto 0);
  signal s_ddr_rlast         : std_logic;
  signal s_ddr_rvalid        : std_logic;
  signal s_ddr_rready        : std_logic;
  attribute MARK_DEBUG of s_ddr_araddr : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_arlen : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_arvalid : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_arready : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_rdata : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_rlast : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_rvalid : signal is "TRUE";
  attribute MARK_DEBUG of s_ddr_rready : signal is "TRUE";
  signal int_vga_rgb         : std_logic_vector(23 downto 0);
  signal rp_vector           : unsigned(12 downto 0);

  signal res_text_capt : res_text_capt_t(15 downto 0) := (others => ' ');

  type cfg_state_t is (CFG_IDLE0, CFG_IDLE1, CFG_WR0, CFG_WR1, CFG_WR2,
                       CFG_WR3, CFG_WR4, CFG_WR5, WRITE_TEXT);
  signal cfg_state : cfg_state_t := CFG_IDLE0;
  attribute MARK_DEBUG of cfg_state : signal is "TRUE";

  signal disp_addr : std_logic_vector(31 downto 0);

  signal button_sync : std_logic_vector(2 downto 0) := "000";
  attribute ASYNC_REG of button_sync : signal is "TRUE";
  signal sw_capt : integer range 0 to 17;
  signal wr_count : integer range 0 to 31;

  signal last_write : std_logic_vector(1 downto 0);
  signal update_text : std_logic := '0';
  signal update_text_sync : std_logic_vector(2 downto 0) := "000";
  attribute MARK_DEBUG of update_text_sync : signal is "TRUE";
  attribute ASYNC_REG of update_text_sync : signal is "TRUE";
  signal done : std_logic;

  type text_sm_t is (TEXT_IDLE, TEXT_CLR0, TEXT_CLR1, TEXT_CLR2,
                     TEXT_WRITE0, TEXT_WRITE1, TEXT_WRITE2,
                     TEXT_WRITE3, TEXT_WRITE4, TEXT_WRITE5);
  signal text_sm : text_sm_t := TEXT_IDLE;
  attribute MARK_DEBUG of text_sm : signal is "TRUE";

  signal total_page : unsigned(25 downto 0);
  signal real_pitch : unsigned(12 downto 0);
  type char_x_t is array (natural range <>) of unsigned(3 downto 0);
  signal char_x : char_x_t(2 downto 0);
  signal aexpr1 : std_logic_vector(2 downto 0);
  signal aexpr2 : std_logic_vector(1 downto 0);
  signal aexpr3 : std_logic_vector(1 downto 0);
  signal aexpr4 : std_logic_vector(2 downto 0);
  signal aexpr5 : std_logic_vector(1 downto 0);
  signal aexpr6 : std_logic_vector(1 downto 0);
begin
  u_sys_clk : sys_pll
    port map (
     clk_out1         => clk200,
     clk_out2         => mc_clk,
     clk_in1          => clk);


  u_clk : pix_clk
    port map (
     s_axi_aclk       => clk200,
     s_axi_aresetn    => '1',
     s_axi_awaddr     => s_axi_awaddr(10 downto 0),
     s_axi_awvalid    => s_axi_awvalid(0),
     s_axi_awready    => s_axi_awready(0),
     s_axi_wdata      => s_axi_wdata,
     s_axi_wstrb      => x"F",
     s_axi_wvalid     => s_axi_wvalid(0),
     s_axi_wready     => s_axi_wready(0),
     s_axi_bready     => '1',
     s_axi_araddr     => (others => '0'),
     s_axi_arvalid    => '0',
     s_axi_rready     => '1',

     -- Clock out ports
     clk_out1         => vga_clk,
     -- Status and control signals
     locked           => locked,
     -- Clock in ports
     clk_in1          => clk200
     );


  u_text_rom : text_rom
    port map (
     clock            => ui_clk,      -- Clock
     index            => char_index,  -- Character Index
     sub_index        => std_logic_vector(char_y),      -- Y position in character

     bitmap_out       => char_slice); -- 8 bit horizontal slice of character

  u_ddr2_vga : ddr2_vga
    port map (
     -- Memory interface ports
     ddr2_addr                      => ddr2_addr,
     ddr2_ba                        => ddr2_ba,
     ddr2_cas_n                     => ddr2_cas_n,
     ddr2_ck_n                      => ddr2_ck_n(0 downto 0),
     ddr2_ck_p                      => ddr2_ck_p(0 downto 0),
     ddr2_cke                       => ddr2_cke(0 downto 0),
     ddr2_ras_n                     => ddr2_ras_n,
     ddr2_we_n                      => ddr2_we_n,
     ddr2_dq                        => ddr2_dq,
     ddr2_dqs_n                     => ddr2_dqs_n,
     ddr2_dqs_p                     => ddr2_dqs_p,
     init_calib_complete            => init_calib_complete,

     ddr2_cs_n                      => ddr2_cs_n(0 downto 0),
     ddr2_dm                        => ddr2_dm,
     ddr2_odt                       => ddr2_odt(0 downto 0),
     -- Application interface ports
     ui_clk                         => ui_clk,
     ui_clk_sync_rst                => ui_clk_sync_rst,
     mmcm_locked                    => mmcm_locked,
     aresetn                        => aresetn,
     app_sr_req                     => app_sr_req,
     app_ref_req                    => app_ref_req,
     app_zq_req                     => app_zq_req,
     app_sr_active                  => app_sr_active,
     app_ref_ack                    => app_ref_ack,
     app_zq_ack                     => app_zq_ack,
     -- Slave Interface Write Address Ports
     s_axi_awid                     => s_ddr_awid,
     s_axi_awaddr                   => std_logic_vector(s_ddr_awaddr),
     s_axi_awlen                    => s_ddr_awlen,
     s_axi_awsize                   => s_ddr_awsize,
     s_axi_awburst                  => s_ddr_awburst,
     s_axi_awlock                   => s_ddr_awlock(0 downto 0),
     s_axi_awcache                  => s_ddr_awcache,
     s_axi_awprot                   => s_ddr_awprot,
     s_axi_awqos                    => s_ddr_awqos,
     s_axi_awvalid                  => s_ddr_awvalid,
     s_axi_awready                  => s_ddr_awready,
     -- Slave Interface Write Data Ports
     s_axi_wdata                    => s_ddr_wdata,
     s_axi_wstrb                    => s_ddr_wstrb,
     s_axi_wlast                    => s_ddr_wlast,
     s_axi_wvalid                   => s_ddr_wvalid,
     s_axi_wready                   => s_ddr_wready,
     -- Slave Interface Write Response Ports
     s_axi_bid                      => s_ddr_bid,
     s_axi_bresp                    => s_ddr_bresp,
     s_axi_bvalid                   => s_ddr_bvalid,
     s_axi_bready                   => s_ddr_bready,
     -- Slave Interface Read Address Ports
     s_axi_arid                     => s_ddr_arid,
     s_axi_araddr                   => s_ddr_araddr,
     s_axi_arlen                    => s_ddr_arlen,
     s_axi_arsize                   => s_ddr_arsize,
     s_axi_arburst                  => s_ddr_arburst,
     s_axi_arlock                   => s_ddr_arlock(0 downto 0),
     s_axi_arcache                  => s_ddr_arcache,
     s_axi_arprot                   => s_ddr_arprot,
     s_axi_arqos                    => s_ddr_arqos,
     s_axi_arvalid                  => s_ddr_arvalid,
     s_axi_arready                  => s_ddr_arready,
     -- Slave Interface Read Data Ports
     s_axi_rid                      => s_ddr_rid,
     s_axi_rdata                    => s_ddr_rdata,
     s_axi_rresp                    => s_ddr_rresp,
     s_axi_rlast                    => s_ddr_rlast,
     s_axi_rvalid                   => s_ddr_rvalid,
     s_axi_rready                   => s_ddr_rready,
     -- System Clock Ports
     sys_clk_i                      => mc_clk,
     -- Reference Clock Ports
     clk_ref_i                      => clk200,
     sys_rst                        => '0');

  u_vga_core : vga_core
    port map (
     -- Register address
     reg_clk      => clk200,
     reg_reset    => ui_clk_sync_rst,

     reg_awvalid  => s_axi_awvalid(1),
     reg_awready  => s_axi_awready(1),
     reg_awaddr   => s_axi_awaddr,

     reg_wvalid   => s_axi_wvalid(1),
     reg_wready   => s_axi_wready(1),
     reg_wdata    => s_axi_wdata,
     reg_wstrb    => "1111",

     reg_bready   => '1',

     reg_arvalid  => '0',
     reg_araddr   => (others => '0'),

     reg_rready   => '1',

     -- Master memory
     mem_clk      => ui_clk,
     mem_reset    => '0',

     mem_arid     => s_ddr_arid,
     mem_araddr   => s_ddr_araddr,
     mem_arlen    => s_ddr_arlen,
     mem_arsize   => s_ddr_arsize,
     mem_arburst  => s_ddr_arburst,
     mem_arlock   => s_ddr_arlock(0),
     mem_arvalid  => s_ddr_arvalid,
     mem_arready  => s_ddr_arready,

     mem_rready   => s_ddr_rready,
     mem_rid      => s_ddr_arid,
     mem_rdata    => s_ddr_rdata,
     mem_rresp    => s_ddr_rresp,
     mem_rlast    => s_ddr_rlast,
     mem_rvalid   => s_ddr_rvalid,

     vga_clk      => vga_clk,
     vga_hsync    => vga_hsync,
     vga_hblank   => vga_hblank,
     vga_vsync    => vga_vsync,
     vga_vblank   => vga_vblank,
     vga_rgb      => int_vga_rgb);

  vga_rgb <= int_vga_rgb(23 downto 20) & int_vga_rgb(15 downto 12) & int_vga_rgb(7 downto 4);

  aexpr1 <= last_write(0) & s_axi_awready(0) & s_axi_wready(0);
  aexpr2 <= last_write(0) & s_axi_wready(0);
  aexpr2 <= last_write(0) & s_axi_awready(0);
  aexpr4 <= last_write(1) & s_axi_awready(1) & s_axi_wready(1);
  aexpr5 <= last_write(1) & s_axi_wready(1);
  aexpr6 <= last_write(1) & s_axi_awready(1);
  -- Clock reconfiguration
  process (clk200)
    variable sw_int : integer range 0 to 17;
  begin
    if rising_edge(clk200) then
      button_sync    <= button_sync(1 downto 0) & button_c;
      if wr_count = 24 then
        last_write(0)  <= '1';
      else
        last_write(0)  <= '0';
      end if;
      if wr_count = 31 then
        last_write(1)  <= '1';
      else
        last_write(1)  <= '0';
      end if;
      pll_rst        <= '1';
      case cfg_state is
        when CFG_IDLE0 =>
          update_text   <= not update_text;
          cfg_state     <= CFG_IDLE1;
        when CFG_IDLE1 =>
          wr_count      <= 0;
          s_axi_awvalid <= "00";
          s_axi_wvalid  <= "00";
          if button_sync(2 downto 1) = "10" then
            -- We can start writing the text as we are updating
            update_text   <= not update_text;
            pll_rst       <= '0';
            wr_count      <= 1;
            s_axi_awvalid <= "01";
            s_axi_awaddr  <= addr_array(0);
            s_axi_wvalid  <= "01";
            sw_int        := to_integer(unsigned(SW));
            s_axi_wdata   <= "000000" &
                             std_logic_vector(to_unsigned(resolution(sw_int).mult_fraction, 10)) &
                             std_logic_vector(to_unsigned(resolution(sw_int).mult_integer, 8)) &
                             std_logic_vector(to_unsigned(resolution(sw_int).divide_count, 8));
            sw_capt       <= sw_int;
            cfg_state     <= CFG_WR0;
          end if;
        when CFG_WR0 =>
          pll_rst       <= '0';
          case aexpr1 is
            when "111" =>
              s_axi_awvalid <= "00";
              s_axi_wvalid  <= "00";
              cfg_state     <= CFG_WR3;
            when "011" =>
              wr_count      <= wr_count + 1;
              s_axi_awvalid <= "01";
              s_axi_wvalid  <= "01";
              s_axi_awaddr  <= addr_array(wr_count);
              s_axi_wdata   <= resolution_lookup(sw_capt, wr_count, resolution);
            when "010" | "110" =>
              s_axi_awvalid <= "01";
              cfg_state     <= CFG_WR1;
            when "001" | "101" =>
              s_axi_wvalid  <= "01";
              cfg_state     <= CFG_WR2;
            when others =>
          end case;
        when CFG_WR1 =>
          pll_rst       <= '0';
          case aexpr2 is
            when "11" =>
              s_axi_awvalid <= "00";
              s_axi_wvalid  <= "00";
              cfg_state     <= CFG_WR3;
            when "01" =>
              wr_count      <= wr_count + 1;
              s_axi_awvalid <= "01";
              s_axi_wvalid  <= "01";
              cfg_state     <= CFG_WR0;
              s_axi_awaddr  <= addr_array(wr_count);
              s_axi_wdata   <= resolution_lookup(sw_capt, wr_count, resolution);
            when others =>
          end case;
        when CFG_WR2 =>
          pll_rst       <= '0';
          case aexpr3 is
            when "11" =>
              s_axi_awvalid <= "00";
              s_axi_wvalid  <= "00";
              cfg_state     <= CFG_WR3;
            when "01" =>
              wr_count      <= wr_count + 1;
              s_axi_awvalid <= "01";
              s_axi_wvalid  <= "01";
              cfg_state     <= CFG_WR0;
              s_axi_awaddr  <= addr_array(wr_count);
              s_axi_wdata   <= resolution_lookup(sw_capt, wr_count, resolution);
            when others =>
          end case;
        when CFG_WR3 =>
          pll_rst       <= '0';
          case aexpr4 is
            when "111" =>
              wr_count      <= 0;
              s_axi_awvalid <= "00";
              s_axi_wvalid  <= "00";
              cfg_state     <= CFG_IDLE1;
            when "011" =>
              wr_count      <= wr_count + 1;
              s_axi_awvalid <= "10";
              s_axi_wvalid  <= "10";
              s_axi_awaddr  <= addr_array(wr_count);
              s_axi_wdata   <= resolution_lookup(sw_capt, wr_count, resolution);
            when "010" | "110" =>
              s_axi_awvalid <= "10";
              cfg_state     <= CFG_WR1;
            when "001" | "101" =>
              s_axi_wvalid  <= "10";
              cfg_state     <= CFG_WR2;
            when others =>
          end case;
        when CFG_WR4 =>
          pll_rst       <= '0';
          case aexpr5 is
            when "11" =>
              wr_count      <= 0;
              s_axi_awvalid <= "00";
              s_axi_wvalid  <= "00";
              cfg_state     <= CFG_IDLE1;
            when "01" =>
              wr_count      <= wr_count + 1;
              s_axi_awvalid <= "10";
              s_axi_wvalid  <= "10";
              cfg_state     <= CFG_WR0;
              s_axi_awaddr  <= addr_array(wr_count);
              s_axi_wdata   <= resolution_lookup(sw_capt, wr_count, resolution);
            when others =>
          end case;
        when CFG_WR5 =>
          pll_rst       <= '0';
          case aexpr6 is
            when "11" =>
              wr_count      <= 0;
              s_axi_awvalid <= "00";
              s_axi_wvalid  <= "00";
              cfg_state     <= CFG_IDLE1;
            when "01" =>
              wr_count      <= wr_count + 1;
              s_axi_awvalid <= "10";
              s_axi_wvalid  <= "10";
              cfg_state     <= CFG_WR0;
              s_axi_awaddr  <= addr_array(wr_count);
              s_axi_wdata   <= resolution_lookup(sw_capt, wr_count, resolution);
            when others =>
          end case;
        when others =>
      end case;
    end if;
  end process;

  -- State machine to load initial text
  -- 1. Clear screen
  -- 2. Draw the text on the first 8 scanlines
  rp_vector <= to_unsigned(resolution(sw_capt).pitch, 13);

  process (ui_clk)
    variable char : character;
    variable char1 : character;
    variable expr1 : std_logic_vector(2 downto 0);
    variable expr2 : std_logic_vector(1 downto 0);
    variable expr3 : std_logic_vector(1 downto 0);
    variable expr4 : std_logic_vector(2 downto 0);
    variable expr5 : std_logic_vector(1 downto 0);
    variable expr6 : std_logic_vector(1 downto 0);
    variable index : integer range 0 to 127;
  begin
    if rising_edge(ui_clk) then
      char  := res_text(sw_capt)(0);
      char1 := res_text(sw_capt)(to_integer(unsigned(char_x(0))));
      expr1 := done & s_ddr_awready & s_ddr_wready;
      expr2 := done & s_ddr_wready;
      expr3 := done & s_ddr_awready;
      expr4 := and(char_y) & s_ddr_awready & s_ddr_wready;
      expr5 := and(char_y) & s_ddr_wready;
      expr6 := and(char_y) & s_ddr_awready;
      index := to_integer(unsigned(char_x(2)))*8;
      update_text_sync <= update_text_sync(1 downto 0) & update_text;
      s_ddr_awvalid    <= '0';
      if s_ddr_awaddr >= total_page then
        done <= '1';
      else
        done <= '0';
      end if;

      char_x(1)        <= char_x(0);
      char_x(2)        <= char_x(1);
      if or(rp_vector(3 downto 0)) then
        real_pitch       <= rp_vector(12 downto 4) & "0000" + 1;
      else
        real_pitch       <= rp_vector(12 downto 4) & "0000";
      end if;

      case text_sm is
        when TEXT_IDLE =>
          if xor(update_text_sync(2 downto 1)) then
            -- Clear the screen
            res_text_capt <= res_text(sw_capt);
            total_page <= "00" & (to_unsigned(resolution(sw_capt).vert_display_width, 12) *
                          real_pitch(11 downto 0));
            s_ddr_awaddr  <= (others => '0');
            s_ddr_awvalid <= '1';
            s_ddr_wdata   <= (others => '0');
            s_ddr_wstrb   <= (others => '1');
            s_ddr_wlast   <= '1';
            s_ddr_wvalid  <= '1';
            char_index    <= std_logic_vector(to_unsigned(character'pos(char), 8));
            for i in 0 to 2 loop
              char_x(i)   <= (others => '0');
            end loop;
            char_y        <= (others => '0');
            text_sm       <= TEXT_CLR0;
          end if;
        when TEXT_CLR0 =>
          case expr1 is
            when "111" =>
              s_ddr_awvalid <= '0';
              s_ddr_wvalid  <= '0';
              text_sm       <= TEXT_WRITE0;
            when "011" =>
              s_ddr_awaddr  <= s_ddr_awaddr + 16;
              s_ddr_awvalid <= '1';
              s_ddr_wvalid  <= '1';
              text_sm       <= TEXT_CLR0;
            when "010" =>
              s_ddr_awvalid <= '0';
              s_ddr_wvalid  <= '1';
              text_sm       <= TEXT_CLR1;
            when "001" =>
              s_ddr_awvalid <= '1';
              s_ddr_wvalid  <= '0';
              text_sm       <= TEXT_CLR2;
            when others =>
          end case;
        when TEXT_CLR1 =>
          case expr2 is
            when "11" =>
              s_ddr_awvalid <= '0';
              s_ddr_wvalid  <= '0';
              text_sm       <= TEXT_WRITE0;
            when "01" =>
              s_ddr_awaddr  <= s_ddr_awaddr + 16;
              s_ddr_awvalid <= '1';
              s_ddr_wvalid  <= '1';
              text_sm       <= TEXT_CLR0;
            when others =>
          end case;
        when TEXT_CLR2 =>
          case expr3 is
            when "11" =>
              s_ddr_awvalid <= '0';
              s_ddr_wvalid  <= '0';
              text_sm       <= TEXT_WRITE0;
            when "01" =>
              s_ddr_awaddr  <= s_ddr_awaddr + 16;
              s_ddr_awvalid <= '1';
              s_ddr_wvalid  <= '1';
              text_sm       <= TEXT_CLR0;
            when others =>
          end case;
        when TEXT_WRITE0 =>
          char_index        <= std_logic_vector(to_unsigned(character'pos(char1), 8));
          char_x(0)         <= char_x(0) + 1;
          text_sm           <= TEXT_WRITE1;
        when TEXT_WRITE1 =>
          char_x(0)                   <= char_x(0) + 1;
          char_index                  <= std_logic_vector(to_unsigned(character'pos(char1), 8));
          s_ddr_wdata(index+7 downto index) <= char_slice;
          s_ddr_awaddr                <= x"000" & (char_y * real_pitch(11 downto 0));
          if and(char_x(2)) then
            s_ddr_awvalid <= '1';
            s_ddr_wvalid  <= '1';
            text_sm       <= TEXT_WRITE2;
          else
            text_sm       <= TEXT_WRITE1;
          end if;
        when TEXT_WRITE2 =>
          case expr4 is
            when "111" =>
              s_ddr_awvalid <= '0';
              s_ddr_wvalid  <= '0';
              text_sm       <= TEXT_IDLE;
            when "011" =>
              for i in 0 to 2 loop
                char_x(i)   <= (others => '0');
              end loop;
              char_y        <= char_y + 1;
              s_ddr_awvalid <= '0';
              s_ddr_wvalid  <= '0';
              text_sm       <= TEXT_WRITE0;
            when "010" =>
              s_ddr_awvalid <= '0';
              s_ddr_wvalid  <= '1';
              text_sm       <= TEXT_WRITE3;
            when "001" =>
              s_ddr_awvalid <= '1';
              s_ddr_wvalid  <= '0';
              text_sm       <= TEXT_WRITE4;
            when others =>
          end case;
        when TEXT_WRITE3 =>
          case expr5 is
            when "11" =>
              s_ddr_awvalid <= '0';
              s_ddr_wvalid  <= '0';
              text_sm       <= TEXT_IDLE;
            when "01" =>
              for i in 0 to 2 loop
                char_x(i)   <= (others => '0');
              end loop;
              char_y        <= char_y + 1;
              s_ddr_awvalid <= '0';
              s_ddr_wvalid  <= '0';
              text_sm       <= TEXT_WRITE0;
            when others =>
          end case;
        when TEXT_WRITE4 =>
          case expr6 is
            when "11" =>
              s_ddr_awvalid <= '0';
              s_ddr_wvalid  <= '0';
              text_sm       <= TEXT_IDLE;
            when "01" =>
              for i in 0 to 2 loop
                char_x(i)   <= (others => '0');
              end loop;
              char_y        <= char_y + 1;
              s_ddr_awvalid <= '0';
              s_ddr_wvalid  <= '0';
              text_sm       <= TEXT_WRITE0;
            when others =>
          end case;
        when others =>
      end case;
    end if;
  end process;
end architecture rtl;
