-- vga_pkg.vhd
-- ------------------------------------
-- Pakcage file for the VGA to clean up the architecture.
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- Component instantiations
-- Resolution constants, display table and addresses.
-- Function for looking up register values

library IEEE;
use IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;

package vga_pkg is

  component sys_pll
    port(
      clk_out1 : out std_logic;
      clk_out2 : out std_logic;
      locked   : out std_logic;
      clk_in1  : in  std_logic
    );
  end component;

  component pix_clk
    port(
      -- System interface
      s_axi_aclk    : in  std_logic;
      s_axi_aresetn : in  std_logic;
      -- AXI Write address channel signals
      s_axi_awaddr  : in  std_logic_vector(10 downto 0);
      s_axi_awvalid : in  std_logic;
      s_axi_awready : out std_logic;
      -- AXI Write data channel signals
      s_axi_wdata   : in  std_logic_vector(31 downto 0);
      s_axi_wstrb   : in  std_logic_vector(3 downto 0);
      s_axi_wvalid  : in  std_logic;
      s_axi_wready  : out std_logic;
      -- AXI Write response channel signals
      s_axi_bresp   : out std_logic_vector(1 downto 0);
      s_axi_bvalid  : out std_logic;
      s_axi_bready  : in  std_logic;
      -- AXI Read address channel signals
      s_axi_araddr  : in  std_logic_vector(10 downto 0);
      s_axi_arvalid : in  std_logic;
      s_axi_arready : out std_logic;
      -- AXI Read address channel signals
      s_axi_rdata   : out std_logic_vector(31 downto 0);
      s_axi_rresp   : out std_logic_vector(1 downto 0);
      s_axi_rvalid  : out std_logic;
      s_axi_rready  : in  std_logic;
      -- Clock out ports
      clk_out1      : out std_logic;
      -- Status and control signals
      locked        : out std_logic;
      -- Clock in ports
      clk_in1       : in  std_logic
    );
  end component;

  component ddr2_vga is
    Port(
      ddr2_dq             : inout STD_LOGIC_VECTOR(15 downto 0);
      ddr2_dqs_n          : inout STD_LOGIC_VECTOR(1 downto 0);
      ddr2_dqs_p          : inout STD_LOGIC_VECTOR(1 downto 0);
      ddr2_addr           : out   STD_LOGIC_VECTOR(12 downto 0);
      ddr2_ba             : out   STD_LOGIC_VECTOR(2 downto 0);
      ddr2_ras_n          : out   STD_LOGIC;
      ddr2_cas_n          : out   STD_LOGIC;
      ddr2_we_n           : out   STD_LOGIC;
      ddr2_ck_p           : out   STD_LOGIC_VECTOR(0 to 0);
      ddr2_ck_n           : out   STD_LOGIC_VECTOR(0 to 0);
      ddr2_cke            : out   STD_LOGIC_VECTOR(0 to 0);
      ddr2_cs_n           : out   STD_LOGIC_VECTOR(0 to 0);
      ddr2_dm             : out   STD_LOGIC_VECTOR(1 downto 0);
      ddr2_odt            : out   STD_LOGIC_VECTOR(0 to 0);
      sys_clk_i           : in    STD_LOGIC;
      clk_ref_i           : in    STD_LOGIC;
      ui_clk              : out   STD_LOGIC;
      ui_clk_sync_rst     : out   STD_LOGIC;
      mmcm_locked         : out   STD_LOGIC;
      aresetn             : in    STD_LOGIC;
      app_sr_req          : in    STD_LOGIC;
      app_ref_req         : in    STD_LOGIC;
      app_zq_req          : in    STD_LOGIC;
      app_sr_active       : out   STD_LOGIC;
      app_ref_ack         : out   STD_LOGIC;
      app_zq_ack          : out   STD_LOGIC;
      s_axi_awid          : in    STD_LOGIC_VECTOR(3 downto 0);
      s_axi_awaddr        : in    STD_LOGIC_VECTOR(26 downto 0);
      s_axi_awlen         : in    STD_LOGIC_VECTOR(7 downto 0);
      s_axi_awsize        : in    STD_LOGIC_VECTOR(2 downto 0);
      s_axi_awburst       : in    STD_LOGIC_VECTOR(1 downto 0);
      s_axi_awlock        : in    STD_LOGIC_VECTOR(0 to 0);
      s_axi_awcache       : in    STD_LOGIC_VECTOR(3 downto 0);
      s_axi_awprot        : in    STD_LOGIC_VECTOR(2 downto 0);
      s_axi_awqos         : in    STD_LOGIC_VECTOR(3 downto 0);
      s_axi_awvalid       : in    STD_LOGIC;
      s_axi_awready       : out   STD_LOGIC;
      s_axi_wdata         : in    STD_LOGIC_VECTOR(127 downto 0);
      s_axi_wstrb         : in    STD_LOGIC_VECTOR(15 downto 0);
      s_axi_wlast         : in    STD_LOGIC;
      s_axi_wvalid        : in    STD_LOGIC;
      s_axi_wready        : out   STD_LOGIC;
      s_axi_bready        : in    STD_LOGIC;
      s_axi_bid           : out   STD_LOGIC_VECTOR(3 downto 0);
      s_axi_bresp         : out   STD_LOGIC_VECTOR(1 downto 0);
      s_axi_bvalid        : out   STD_LOGIC;
      s_axi_arid          : in    STD_LOGIC_VECTOR(3 downto 0);
      s_axi_araddr        : in    STD_LOGIC_VECTOR(26 downto 0);
      s_axi_arlen         : in    STD_LOGIC_VECTOR(7 downto 0);
      s_axi_arsize        : in    STD_LOGIC_VECTOR(2 downto 0);
      s_axi_arburst       : in    STD_LOGIC_VECTOR(1 downto 0);
      s_axi_arlock        : in    STD_LOGIC_VECTOR(0 to 0);
      s_axi_arcache       : in    STD_LOGIC_VECTOR(3 downto 0);
      s_axi_arprot        : in    STD_LOGIC_VECTOR(2 downto 0);
      s_axi_arqos         : in    STD_LOGIC_VECTOR(3 downto 0);
      s_axi_arvalid       : in    STD_LOGIC;
      s_axi_arready       : out   STD_LOGIC;
      s_axi_rready        : in    STD_LOGIC;
      s_axi_rid           : out   STD_LOGIC_VECTOR(3 downto 0);
      s_axi_rdata         : out   STD_LOGIC_VECTOR(127 downto 0);
      s_axi_rresp         : out   STD_LOGIC_VECTOR(1 downto 0);
      s_axi_rlast         : out   STD_LOGIC;
      s_axi_rvalid        : out   STD_LOGIC;
      init_calib_complete : out   STD_LOGIC;
      sys_rst             : in    STD_LOGIC
    );
  end component ddr2_vga;

  type resolution_t is record
    divide_count        : unsigned(7 downto 0);
    mult_integer        : unsigned(15 downto 8);
    mult_fraction       : unsigned(25 downto 16);
    divide_integer      : unsigned(7 downto 0);
    divide_fraction     : unsigned(17 downto 0);
    horiz_display_start : unsigned(11 downto 0);
    horiz_display_width : unsigned(11 downto 0);
    horiz_sync_width    : unsigned(11 downto 0);
    horiz_total_width   : unsigned(11 downto 0);
    vert_display_start  : unsigned(11 downto 0);
    vert_display_width  : unsigned(11 downto 0);
    vert_sync_width     : unsigned(11 downto 0);
    vert_total_width    : unsigned(11 downto 0);
    hpol                : std_logic;
    vpol                : std_logic;
    pitch               : unsigned(12 downto 0);
  end record;

  type resolution_array is array (natural range <>) of resolution_t;

  constant RESOLUTION : resolution_array(0 to 17) := (
    (
      -- 25.18 Mhz 640x480 @ 60Hz
      divide_count        => 8d"9",
      mult_integer        => 8d"50",
      mult_fraction       => 10d"000",
      divide_integer      => 8d"44",
      divide_fraction     => 18d"125",
      horiz_display_start => 12d"47",   -- BP - 1
      horiz_display_width => 12d"640",
      horiz_sync_width    => 12d"96",
      horiz_total_width   => 12d"799",  -- 800 - 1
      vert_display_start  => 12d"32",   -- 33 - 1
      vert_display_width  => 12d"480",
      vert_sync_width     => 12d"2",
      vert_total_width    => 12d"524",  -- 525 - 1
      hpol                => '0',
      vpol                => '0',
      pitch               => to_unsigned(5 * 16, 13) -- 5 rows at 1bpp
      -- res_text[0] => "  zH06 @ 084x046",
    ),
    (                                   -- 31.5Mhz 640x480 @ 72 Hz
      divide_count        => 8d"8",
      mult_integer        => 8d"39",
      mult_fraction       => 10d"375",
      divide_integer      => 8d"31",
      divide_fraction     => 18d"250",
      horiz_display_start => 12d"127",
      horiz_display_width => 12d"640",
      horiz_sync_width    => 12d"40",
      horiz_total_width   => 12d"831",
      vert_display_start  => 12d"27",
      vert_display_width  => 12d"480",
      vert_sync_width     => 12d"3",
      vert_total_width    => 12d"519",
      hpol                => '0',
      vpol                => '0',
      pitch               => to_unsigned(5 * 16, 13) -- 5 rows at 1bpp
      -- res_text[1]                        => "  zH27 @ 084x046",
    ),
    (                                   -- 31.5Mhz 640x480 @ 75 Hz
      divide_count        => 8d"8",
      mult_integer        => 8d"39",
      mult_fraction       => 10d"375",
      divide_integer      => 8d"31",
      divide_fraction     => 18d"250",
      horiz_display_start => 12d"47",
      horiz_display_width => 12d"640",
      horiz_sync_width    => 12d"96",
      horiz_total_width   => 12d"800",
      vert_display_start  => 12d"31",
      vert_display_width  => 12d"480",
      vert_sync_width     => 12d"2",
      vert_total_width    => 12d"520",
      hpol                => '0',
      vpol                => '0',
      pitch               => to_unsigned(5 * 16, 13) -- 5 rows at 1bpp
      -- res_text[2]                        => "  zH57 @ 084x046",
    ),
    (                                   -- 36 Mhz 640x480 @ 85 Hz
      divide_count        => 8d"5",
      mult_integer        => 8d"24",
      mult_fraction       => 10d"750",
      divide_integer      => 8d"27",
      divide_fraction     => 18d"500",
      horiz_display_start => 12d"111",
      horiz_display_width => 12d"640",
      horiz_sync_width    => 12d"48",
      horiz_total_width   => 12d"831",
      vert_display_start  => 12d"23",
      vert_display_width  => 12d"480",
      vert_sync_width     => 12d"3",
      vert_total_width    => 12d"508",
      hpol                => '0',
      vpol                => '0',
      pitch               => to_unsigned(5 * 16, 13) -- 5 rows at 1bpp
      -- res_text[3]                        => "  zH58 @ 084x046",
    ),
    (                                   -- 40 Mhz 800x600 @ 60 Hz
      divide_count        => 8d"1",
      mult_integer        => 8d"5",
      mult_fraction       => 10d"000",
      divide_integer      => 8d"20",
      divide_fraction     => 18d"000",
      horiz_display_start => 12d"87",
      horiz_display_width => 12d"800",
      horiz_sync_width    => 12d"128",
      horiz_total_width   => 12d"1055",
      vert_display_start  => 12d"22",
      vert_display_width  => 12d"600",
      vert_sync_width     => 12d"4",
      vert_total_width    => 12d"627",
      hpol                => '1',
      vpol                => '1',
      pitch               => to_unsigned(7 * 16, 13) -- 6.25 rows at 1bpp
      -- res_text[4]                        => "  zH06 @ 006x008",
    ),
    (                                   -- 49.5 Mhz 800x600 @ 75 Hz
      divide_count        => 8d"5",
      mult_integer        => 8d"24",
      mult_fraction       => 10d"750",
      divide_integer      => 8d"20",
      divide_fraction     => 18d"000",
      horiz_display_start => 12d"159",
      horiz_display_width => 12d"800",
      horiz_sync_width    => 12d"80",
      horiz_total_width   => 12d"1055",
      vert_display_start  => 12d"20",
      vert_display_width  => 12d"600",
      vert_sync_width     => 12d"2",
      vert_total_width    => 12d"624",
      hpol                => '1',
      vpol                => '1',
      pitch               => to_unsigned(7 * 16, 13) -- 6.25 rows at 1bpp
      -- res_text[5]                        => "  zH57 @ 006x008",
    ),
    (                                   -- 50 Mhz 800x600 @ 72 Hz
      divide_count        => 8d"1",
      mult_integer        => 8d"5",
      mult_fraction       => 10d"000",
      divide_integer      => 8d"20",
      divide_fraction     => 18d"000",
      horiz_display_start => 12d"63",
      horiz_display_width => 12d"800",
      horiz_sync_width    => 12d"120",
      horiz_total_width   => 12d"1039",
      vert_display_start  => 12d"22",
      vert_display_width  => 12d"600",
      vert_sync_width     => 12d"6",
      vert_total_width    => 12d"665",
      hpol                => '1',
      vpol                => '1',
      pitch               => to_unsigned(7 * 16, 13) -- 6.25 rows at 1bpp
      -- res_text[6]                        => "  zH27 @ 006x008",
    ),
    (                                   -- 56.25 Mhz 800x600 @ 85 Hz
      divide_count        => 8d"2",
      mult_integer        => 8d"10",
      mult_fraction       => 10d"125",
      divide_integer      => 8d"18",
      divide_fraction     => 18d"000",
      horiz_display_start => 12d"151",
      horiz_display_width => 12d"800",
      horiz_sync_width    => 12d"64",
      horiz_total_width   => 12d"1047",
      vert_display_start  => 12d"26",
      vert_display_width  => 12d"600",
      vert_sync_width     => 12d"3",
      vert_total_width    => 12d"630",
      hpol                => '1',
      vpol                => '1',
      pitch               => to_unsigned(7 * 16, 13) -- 6.25 rows at 1bpp
      -- res_text[7]                        => "  zH58 @ 006x008",
    ),
    (                                   -- 65 Mhz 1024x768 @ 60 Hz
      divide_count        => 8d"10",
      mult_integer        => 8d"50",
      mult_fraction       => 10d"375",
      divide_integer      => 8d"15",
      divide_fraction     => 18d"500",
      horiz_display_start => 12d"159",
      horiz_display_width => 12d"1024",
      horiz_sync_width    => 12d"136",
      horiz_total_width   => 12d"1339",
      vert_display_start  => 12d"28",
      vert_display_width  => 12d"768",
      vert_sync_width     => 12d"6",
      vert_total_width    => 12d"805",
      hpol                => '0',
      vpol                => '0',
      pitch               => to_unsigned(8 * 16, 13) -- res_text[8]                        => " zH06 @ 867x4201",
    ),
    (                                   -- 75 Mhz 1024x768 @ 70 Hz
      divide_count        => 8d"8",
      mult_integer        => 8d"40",
      mult_fraction       => 10d"125",
      divide_integer      => 8d"13",
      divide_fraction     => 18d"375",
      horiz_display_start => 12d"143",
      horiz_display_width => 12d"1024",
      horiz_sync_width    => 12d"136",
      horiz_total_width   => 12d"1327",
      vert_display_start  => 12d"28",
      vert_display_width  => 12d"768",
      vert_sync_width     => 12d"6",
      vert_total_width    => 12d"805",
      hpol                => '0',
      vpol                => '0',
      pitch               => to_unsigned(8 * 16, 13) -- res_text[9]                        => " zH07 @ 867x4201",
    ),
    (                                   -- 78.75 Mhz 1024x768 @ 75 Hz
      divide_count        => 8d"8",
      mult_integer        => 8d"39",
      mult_fraction       => 10d"375",
      divide_integer      => 8d"12",
      divide_fraction     => 18d"500",
      horiz_display_start => 12d"175",
      horiz_display_width => 12d"1024",
      horiz_sync_width    => 12d"96",
      horiz_total_width   => 12d"1311",
      vert_display_start  => 12d"27",
      vert_display_width  => 12d"768",
      vert_sync_width     => 12d"3",
      vert_total_width    => 12d"799",
      hpol                => '1',
      vpol                => '1',
      pitch               => to_unsigned(8 * 16, 13) -- res_text[10]                       => " zH57 @ 867x4201",
    ),
    (                                   -- 94.5 Mhz 1024x768 @ 85 Hz
      divide_count        => 8d"5",
      mult_integer        => 8d"23",
      mult_fraction       => 10d"625",
      divide_integer      => 8d"10",
      divide_fraction     => 18d"000",
      horiz_display_start => 12d"207",
      horiz_display_width => 12d"1024",
      horiz_sync_width    => 12d"96",
      horiz_total_width   => 12d"1375",
      vert_display_start  => 12d"35",
      vert_display_width  => 12d"768",
      vert_sync_width     => 12d"3",
      vert_total_width    => 12d"807",
      hpol                => '1',
      vpol                => '1',
      pitch               => to_unsigned(8 * 16, 13) -- res_text[11]                       => " zH58 @ 867x4201",
    ),
    (                                   -- 108 Mhz 1280x1024 @ 60 Hz
      divide_count        => 8d"2",
      mult_integer        => 8d"10",
      mult_fraction       => 10d"125",
      divide_integer      => 8d"9",
      divide_fraction     => 18d"375",
      horiz_display_start => 12d"247",
      horiz_display_width => 12d"1280",
      horiz_sync_width    => 12d"112",
      horiz_total_width   => 12d"1688",
      vert_display_start  => 12d"37",
      vert_display_width  => 12d"1024",
      vert_sync_width     => 12d"3",
      vert_total_width    => 12d"1066",
      hpol                => '1',
      vpol                => '1',
      pitch               => to_unsigned(10 * 16, 13) -- res_text[12]                       => "zH06 @ 4201x0821",
    ),
    (                                   -- 135 Mhz 1280x1024 @ 75 Hz
      divide_count        => 8d"2",
      mult_integer        => 8d"10",
      mult_fraction       => 10d"125",
      divide_integer      => 8d"7",
      divide_fraction     => 18d"500",
      horiz_display_start => 12d"247",
      horiz_display_width => 12d"1280",
      horiz_sync_width    => 12d"144",
      horiz_total_width   => 12d"1688",
      vert_display_start  => 12d"37",
      vert_display_width  => 12d"1024",
      vert_sync_width     => 12d"3",
      vert_total_width    => 12d"1066",
      hpol                => '1',
      vpol                => '1',
      pitch               => to_unsigned(10 * 16, 13) -- res_text[13]                       => "zH57 @ 4201x0821",
    ),
    (                                   -- 157.5 Mhz 1280x1024 @ 85 Hz
      divide_count        => 8d"8",
      mult_integer        => 8d"39",
      mult_fraction       => 10d"375",
      divide_integer      => 8d"6",
      divide_fraction     => 18d"250",
      horiz_display_start => 12d"223",
      horiz_display_width => 12d"1280",
      horiz_sync_width    => 12d"160",
      horiz_total_width   => 12d"1728",
      vert_display_start  => 12d"043",
      vert_display_width  => 12d"1024",
      vert_sync_width     => 12d"3",
      vert_total_width    => 12d"1072",
      hpol                => '1',
      vpol                => '1',
      pitch               => to_unsigned(10 * 16, 13) -- res_text[14]                       => "zH58 @ 4201x0821",
    ),
    (                                   -- 162 Mhz 1600x1200 @ 60 Hz
      divide_count        => 8d"2",
      mult_integer        => 8d"10",
      mult_fraction       => 10d"125",
      divide_integer      => 8d"6",
      divide_fraction     => 18d"250",
      horiz_display_start => 12d"303",
      horiz_display_width => 12d"1600",
      horiz_sync_width    => 12d"192",
      horiz_total_width   => 12d"2160",
      vert_display_start  => 12d"45",
      vert_display_width  => 12d"1200",
      vert_sync_width     => 12d"3",
      vert_total_width    => 12d"1250",
      hpol                => '1',
      vpol                => '1',
      pitch               => to_unsigned(13 * 16, 13) -- 12.5
      -- res_text[15]                       => "zH06 @ 0021x0061",
    ),
    (                                   -- 195 Mhz 1920x1200 @ 60 Hz
      divide_count        => 8d"1",
      mult_integer        => 8d"4",
      mult_fraction       => 10d"875",
      divide_integer      => 8d"5",
      divide_fraction     => 18d"000",
      horiz_display_start => 12d"399",
      horiz_display_width => 12d"1920",
      horiz_sync_width    => 12d"200",
      horiz_total_width   => 12d"2616",
      vert_display_start  => 12d"35",
      vert_display_width  => 12d"1200",
      vert_sync_width     => 12d"3",
      vert_total_width    => 12d"1242",
      hpol                => '1',
      vpol                => '1',
      pitch               => to_unsigned(15 * 16, 13) -- res_text[16]                       => "zH06 @ 0021x0291",
    ),
    (                                   -- 195 Mhz 1920x1200 @ 60 Hz
      divide_count        => 8d"8",
      mult_integer        => 8d"37",
      mult_fraction       => 10d"125",
      divide_integer      => 8d"6",
      divide_fraction     => 18d"250",
      horiz_display_start => 12d"147",
      horiz_display_width => 12d"1920",
      horiz_sync_width    => 12d"44",
      horiz_total_width   => 12d"2199",
      vert_display_start  => 12d"3",
      vert_display_width  => 12d"1080",
      vert_sync_width     => 12d"5",
      vert_total_width    => 12d"1124",
      hpol                => '1',
      vpol                => '1',
      pitch               => to_unsigned(15 * 16, 13) -- res_text[17]                       => "zH06 @ 0801x0291")
    )
  );

  --REVIEW type res_text_capt_t is array (natural range <>) of character;
  --REVIEW  type res_text_t is array (natural range <>) of res_text_capt_t;
  type res_text_t is array (natural range <>) of string(16 downto 1);

  --  constant RES_TEXT : res_text_t(0 to 17)(15 downto 0) := (
  constant RES_TEXT : res_text_t(0 to 17) := (
    "  zH06 @ 084x046",
    "  zH27 @ 084x046",
    "  zH57 @ 084x046",
    "  zH58 @ 084x046",
    "  zH06 @ 006x008",
    "  zH07 @ 006x008",
    "  zH57 @ 006x008",
    "  zH58 @ 006x008",
    " zH06 @ 867x4201",
    " zH07 @ 867x4201",
    " zH57 @ 867x4201",
    " zH58 @ 867x4201",
    "zH06 @ 4201x0821",
    "zH57 @ 4201x0821",
    "zH58 @ 4201x0821",
    "zH06 @ 0021x0061",
    "zH06 @ 0021x0291",
    "zH06 @ 0801x0291"
  );

  type addr_array_t is array (natural range <>) of std_logic_vector(11 downto 0);

  constant ADDR_ARRAY : addr_array_t(0 to 31) := (
    -- pix_clk MMCM addresses
    x"200", x"204", x"208", x"20C", x"210", x"214", x"218", x"21C",
    x"220", x"224", x"228", x"22C", x"230", x"234", x"238", x"23C",
    x"240", x"244", x"248", x"24C", x"250", x"254", x"258", x"25C",
    -- vga_core register addresses
    x"000", x"004", x"008", x"00C", x"010", x"100", x"104", x"108");

  function resolution_lookup(sw_capt : in integer range 0 to 17; wr_count : in integer range 0 to 31) return std_logic_vector;

  function get_res_char(sw_capt : integer range 0 to 17; x : integer range 0 to 15) return character;

end package vga_pkg;

package body vga_pkg is

  function get_res_char(sw_capt : integer range 0 to 17; x : integer range 0 to 15) return character is
  begin
    return RES_TEXT(sw_capt)(x + 1);    -- x + 1 because VHDL strings start at index 1
  end function;

  function resolution_lookup(sw_capt : in integer range 0 to 17; wr_count : in integer range 0 to 31) return std_logic_vector is
    variable s_axi_wdata : std_logic_vector(31 downto 0);
  begin
    case wr_count is
      when 0                                   => s_axi_wdata := std_logic_vector(6d"0" & RESOLUTION(sw_capt).mult_fraction & RESOLUTION(sw_capt).mult_integer & RESOLUTION(sw_capt).divide_count);
      when 1 | 3 | 6  | 9  | 12 | 15 | 18 | 21 => s_axi_wdata := (others => '0');
      when 5 | 8 | 11 | 14 | 17 | 20           => s_axi_wdata := x"0000000A";
      when 4 | 7 | 10 | 13 | 16 | 19 | 22      => s_axi_wdata := x"0000C350";
      when 2                                   => s_axi_wdata := std_logic_vector("000000" & RESOLUTION(sw_capt).divide_fraction & RESOLUTION(sw_capt).divide_integer);
      when 23                                  => s_axi_wdata := x"00000003";
      when 24                                  => s_axi_wdata := std_logic_vector(4d"0" & RESOLUTION(sw_capt).horiz_display_width & 4d"0" & RESOLUTION(sw_capt).horiz_display_start);
      when 25                                  => s_axi_wdata := std_logic_vector(4d"0" & RESOLUTION(sw_capt).horiz_total_width & 4d"0" & RESOLUTION(sw_capt).horiz_sync_width);
      when 26                                  => s_axi_wdata := std_logic_vector(4d"0" & RESOLUTION(sw_capt).vert_display_width & 4d"0" & RESOLUTION(sw_capt).vert_display_start);
      when 27                                  => s_axi_wdata := std_logic_vector(4d"0" & RESOLUTION(sw_capt).vert_total_width & 4d"0" & RESOLUTION(sw_capt).vert_sync_width);
      when 28                                  => s_axi_wdata := 30d"0" & RESOLUTION(sw_capt).hpol & RESOLUTION(sw_capt).vpol;
      when 29                                  => s_axi_wdata := (others => '0');
      when 30                                  => s_axi_wdata := std_logic_vector(19d"0" & RESOLUTION(sw_capt).pitch);
      when 31                                  => s_axi_wdata := x"00000001";
      when others =>
    end case;
    return s_axi_wdata;
  end function;

end package body vga_pkg;
