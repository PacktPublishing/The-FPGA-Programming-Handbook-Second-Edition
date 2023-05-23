-- vga_pkg.vhd
-- ------------------------------------
-- Pakcage file for the VGA to clean up the architecture.
-- ------------------------------------
-- Author : Frank Bruno
-- Component instantiations
-- Resolution constants, display table and addresses.
-- Function for looking up register values
library IEEE;
use IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;
package vga_pkg is
  component sys_pll
    port
     (-- Clock in ports
      -- Clock out ports
      clk_out1          : out    std_logic;
      clk_out2          : out    std_logic;
      clk_in1           : in     std_logic);
  end component;
  component pix_clk
    port (
      -- System interface
      s_axi_aclk      : in  std_logic;
      s_axi_aresetn   : in  std_logic;
      -- AXI Write address channel signals
      s_axi_awaddr    : in  std_logic_vector(10 downto 0);
      s_axi_awvalid   : in  std_logic;
      s_axi_awready   : out std_logic;
      -- AXI Write data channel signals
      s_axi_wdata     : in  std_logic_vector(31 downto 0);
      s_axi_wstrb     : in  std_logic_vector(3 downto 0);
      s_axi_wvalid    : in  std_logic;
      s_axi_wready    : out std_logic;
      -- AXI Write response channel signals
      s_axi_bresp     : out std_logic_vector(1 downto 0);
      s_axi_bvalid    : out std_logic;
      s_axi_bready    : in  std_logic;
      -- AXI Read address channel signals
      s_axi_araddr    : in  std_logic_vector(10 downto 0);
      s_axi_arvalid   : in  std_logic;
      s_axi_arready   : out std_logic;
      -- AXI Read address channel signals
      s_axi_rdata     : out std_logic_vector(31 downto 0);
      s_axi_rresp     : out std_logic_vector(1 downto 0);
      s_axi_rvalid    : out std_logic;
      s_axi_rready    : in  std_logic;
      -- Clock out ports
      clk_out1          : out    std_logic;
      -- Status and control signals
      locked            : out    std_logic;
      -- Clock in ports
      clk_in1           : in     std_logic
      );
  end component;
  component ddr2_vga is
    Port (
      ddr2_dq : inout STD_LOGIC_VECTOR ( 15 downto 0 );
      ddr2_dqs_n : inout STD_LOGIC_VECTOR ( 1 downto 0 );
      ddr2_dqs_p : inout STD_LOGIC_VECTOR ( 1 downto 0 );
      ddr2_addr : out STD_LOGIC_VECTOR ( 12 downto 0 );
      ddr2_ba : out STD_LOGIC_VECTOR ( 2 downto 0 );
      ddr2_ras_n : out STD_LOGIC;
      ddr2_cas_n : out STD_LOGIC;
      ddr2_we_n : out STD_LOGIC;
      ddr2_ck_p : out STD_LOGIC_VECTOR ( 0 to 0 );
      ddr2_ck_n : out STD_LOGIC_VECTOR ( 0 to 0 );
      ddr2_cke : out STD_LOGIC_VECTOR ( 0 to 0 );
      ddr2_cs_n : out STD_LOGIC_VECTOR ( 0 to 0 );
      ddr2_dm : out STD_LOGIC_VECTOR ( 1 downto 0 );
      ddr2_odt : out STD_LOGIC_VECTOR ( 0 to 0 );
      sys_clk_i : in STD_LOGIC;
      clk_ref_i : in STD_LOGIC;
      ui_clk : out STD_LOGIC;
      ui_clk_sync_rst : out STD_LOGIC;
      mmcm_locked : out STD_LOGIC;
      aresetn : in STD_LOGIC;
      app_sr_req : in STD_LOGIC;
      app_ref_req : in STD_LOGIC;
      app_zq_req : in STD_LOGIC;
      app_sr_active : out STD_LOGIC;
      app_ref_ack : out STD_LOGIC;
      app_zq_ack : out STD_LOGIC;
      s_axi_awid : in STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_awaddr : in STD_LOGIC_VECTOR ( 26 downto 0 );
      s_axi_awlen : in STD_LOGIC_VECTOR ( 7 downto 0 );
      s_axi_awsize : in STD_LOGIC_VECTOR ( 2 downto 0 );
      s_axi_awburst : in STD_LOGIC_VECTOR ( 1 downto 0 );
      s_axi_awlock : in STD_LOGIC_VECTOR ( 0 to 0 );
      s_axi_awcache : in STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_awprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
      s_axi_awqos : in STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_awvalid : in STD_LOGIC;
      s_axi_awready : out STD_LOGIC;
      s_axi_wdata : in STD_LOGIC_VECTOR ( 127 downto 0 );
      s_axi_wstrb : in STD_LOGIC_VECTOR ( 15 downto 0 );
      s_axi_wlast : in STD_LOGIC;
      s_axi_wvalid : in STD_LOGIC;
      s_axi_wready : out STD_LOGIC;
      s_axi_bready : in STD_LOGIC;
      s_axi_bid : out STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_bresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
      s_axi_bvalid : out STD_LOGIC;
      s_axi_arid : in STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_araddr : in STD_LOGIC_VECTOR ( 26 downto 0 );
      s_axi_arlen : in STD_LOGIC_VECTOR ( 7 downto 0 );
      s_axi_arsize : in STD_LOGIC_VECTOR ( 2 downto 0 );
      s_axi_arburst : in STD_LOGIC_VECTOR ( 1 downto 0 );
      s_axi_arlock : in STD_LOGIC_VECTOR ( 0 to 0 );
      s_axi_arcache : in STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_arprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
      s_axi_arqos : in STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_arvalid : in STD_LOGIC;
      s_axi_arready : out STD_LOGIC;
      s_axi_rready : in STD_LOGIC;
      s_axi_rid : out STD_LOGIC_VECTOR ( 3 downto 0 );
      s_axi_rdata : out STD_LOGIC_VECTOR ( 127 downto 0 );
      s_axi_rresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
      s_axi_rlast : out STD_LOGIC;
      s_axi_rvalid : out STD_LOGIC;
      init_calib_complete : out STD_LOGIC;
      sys_rst : in STD_LOGIC
      );
  end component ddr2_vga;
  component text_rom is
    port (clock      : in  std_logic;
          index      : in  std_logic_vector(7 downto 0);
          sub_index  : in  std_logic_vector(2 downto 0);

          bitmap_out : out std_logic_vector(7 downto 0));
  end component text_rom;
  component vga_core is
    port (-- Register address
      reg_clk        : in  std_logic;
      reg_reset      : in  std_logic;

      reg_awvalid    : in  std_logic;
      reg_awready    : out std_logic;
      reg_awaddr     : in  std_logic_vector(11 downto 0);

      reg_wvalid     : in  std_logic;
      reg_wready     : out std_logic;
      reg_wdata      : in  std_logic_vector(31 downto 0);
      reg_wstrb      : in  std_logic_vector(3 downto 0);

      reg_bready     : in  std_logic;
      reg_bvalid     : out std_logic;
      reg_bresp      : out std_logic_vector(1 downto 0);

      reg_arvalid    : in  std_logic;
      reg_arready    : out std_logic;
      reg_araddr     : in  std_logic_vector(11 downto 0);

      reg_rready     : in  std_logic;
      reg_rvalid     : out std_logic;
      reg_rdata      : out std_logic_vector(31 downto 0);
      reg_rresp      : out std_logic_vector(1 downto 0);

      -- Master memory
      mem_clk        : in  std_logic;
      mem_reset      : in  std_logic;

      mem_arid       : out std_logic_vector(3 downto 0);
      mem_araddr     : out std_logic_vector(26 downto 0);
      mem_arlen      : out std_logic_vector(7 downto 0);
      mem_arsize     : out std_logic_vector(2 downto 0);
      mem_arburst    : out std_logic_vector(1 downto 0);
      mem_arlock     : out std_logic;
      mem_arvalid    : out std_logic;
      mem_arready    : in  std_logic;

      mem_rready     : out std_logic;
      mem_rid        : in  std_logic_vector(3 downto 0);
      mem_rdata      : in  std_logic_vector(127 downto 0);
      mem_rresp      : in  std_logic_vector(1 downto 0);
      mem_rlast      : in  std_logic;
      mem_rvalid     : in  std_logic;

      vga_clk        : in  std_logic;
      vga_hsync      : out std_logic;
      vga_hblank     : out std_logic;
      vga_vsync      : out std_logic;
      vga_vblank     : out std_logic;
      vga_rgb        : out std_logic_vector(23 downto 0));
  end component vga_core;
    type resolution_t is record
    divide_count        : integer range 0 to 255; --std_logic_vector(7 downto 0);
    mult_integer        : integer range 0 to 255; --std_logic_vector(15 downto 8);
    mult_fraction       : integer range 0 to 1023; --std_logic_vector(25 downto 16);
    divide_integer      : integer range 0 to 255; --std_logic_vector(7 downto 0);
    divide_fraction     : integer range 0 to 262143; --std_logic_vector(17 downto 0);
    horiz_display_start : integer range 0 to 4095; --std_logic_vector(11 downto 0);
    horiz_display_width : integer range 0 to 4095; --std_logic_vector(11 downto 0);
    horiz_sync_width    : integer range 0 to 4095; --std_logic_vector(11 downto 0);
    horiz_total_width   : integer range 0 to 4095; --std_logic_vector(11 downto 0);
    vert_display_start  : integer range 0 to 4095; --std_logic_vector(11 downto 0);
    vert_display_width  : integer range 0 to 4095; --std_logic_vector(11 downto 0);
    vert_sync_width     : integer range 0 to 4095; --std_logic_vector(11 downto 0);
    vert_total_width    : integer range 0 to 4095; --std_logic_vector(11 downto 0);
    hpol                : std_logic;
    vpol                : std_logic;
    pitch               : integer range 0 to 8191; --std_logic_vector(12 downto 0);
  end record;
  type resolution_array is array (natural range <>) of resolution_t;
  constant resolution : resolution_array(0 to 17) := (
    -- 25.18 Mhz 640x480 @ 60Hz
    (divide_count         => 9, --x"09", --std_logic_vector(to_unsigned(9, divide_count'length)),
     mult_integer         => 50, --x"32", --std_logic_vector(to_unsigned(50, mult_integer'length)),
     mult_fraction        => 0, --"0000000000", -- std_logic_vector(to_unsigned(000, mult_fraction'length)),
     divide_integer       => 44, --x"2C", -- std_logic_vector(to_unsigned(44, divide_integer'length)),
     divide_fraction      => 125, --"000000000001111101", --std_logic_vector(to_unsigned(125, divide_fraction'length)),
     horiz_display_start  => 47, --x"02F", --std_logic_vector(to_unsigned(47, horiz_display_start'length)), -- BP -1
     horiz_display_width  => 640, --x"280", --std_logic_vector(to_unsigned(640, horiz_display_width'length)),
     horiz_sync_width     => 96, --x"060", --std_logic_vector(to_unsigned(96, horiz_sync_width'length)),
     horiz_total_width    => 799, --x"31F", --std_logic_vector(to_unsigned(799, horiz_total_width'length)), -- -1
     vert_display_start   => 32, --x"020", --std_logic_vector(to_unsigned(32, vert_display_start'length)), -- -1
     vert_display_width   => 480, --x"1E0", --std_logic_vector(to_unsigned(480, vert_display_width'length)),
     vert_sync_width      => 2, --x"002", --std_logic_vector(to_unsigned(2, vert_sync_width'length)),
     vert_total_width     => 524, --x"20C", --std_logic_vector(to_unsigned(524, vert_total_width'length)), -- -1
     hpol                 => '0',
     vpol                 => '0',
     pitch                => 5*16), --"0000001010000"), -- std_logic_vector(to_unsigned(5*16, pitch'length))), -- 5 rows at 1bpp
    -- 31.5Mhz 640x480 @ 72 Hz
    (divide_count         => 8, --x"08", --std_logic_vector(to_unsigned(8, divide_count'length)),
     mult_integer         => 39, --x"27", --std_logic_vector(to_unsigned(39, mult_integer'length)),
     mult_fraction        => 375, --"0101110111", --std_logic_vector(to_unsigned(375, mult_fraction'length)),
     divide_integer       => 31, --x"1F", --std_logic_vector(to_unsigned(31, divide_integer'length)),
     divide_fraction      => 250, --"000000000011111010", --std_logic_vector(to_unsigned(250, divide_fraction'length)),
     horiz_display_start  => 127, --x"07F", --std_logic_vector(to_unsigned(127, horiz_display_start'length)), -- BP -1
     horiz_display_width  => 640, --x"280", --std_logic_vector(to_unsigned(640, horiz_display_width'length)),
     horiz_sync_width     => 40, --x"028", --std_logic_vector(to_unsigned(40, horiz_sync_width'length)),
     horiz_total_width    => 831, --x"33F", --std_logic_vector(to_unsigned(831, horiz_total_width'length)), -- -1
     vert_display_start   => 27, --x"01B", --std_logic_vector(to_unsigned(27, vert_display_start'length)), -- -1
     vert_display_width   => 480, --x"1E0", --std_logic_vector(to_unsigned(480, vert_display_width'length)),
     vert_sync_width      => 3, --x"003", --std_logic_vector(to_unsigned(3, vert_sync_width'length)),
     vert_total_width     => 519, --x"207", --std_logic_vector(to_unsigned(519, vert_total_width'length)), -- -1
     hpol                 => '0',
     vpol                 => '0',
     pitch                => 5*16), --"0000001010000"), --std_logic_vector(to_unsigned(5*16, pitch'length))), -- 5 rows at 1bpp
    -- 31.5Mhz 640x480 @ 75 Hz
    (divide_count         => 8, --std_logic_vector(to_unsigned(8, divide_count'length)),
     mult_integer         => 39, --std_logic_vector(to_unsigned(39, mult_integer'length)),
     mult_fraction        => 375, --std_logic_vector(to_unsigned(375, mult_fraction'length)),
     divide_integer       => 31, --std_logic_vector(to_unsigned(31, divide_integer'length)),
     divide_fraction      => 250, --std_logic_vector(to_unsigned(250, divide_fraction'length)),
     horiz_display_start  => 47, --std_logic_vector(to_unsigned(47, horiz_display_start'length)), -- BP -1
     horiz_display_width  => 640, --std_logic_vector(to_unsigned(640, horiz_display_width'length)),
     horiz_sync_width     => 96, --std_logic_vector(to_unsigned(96, horiz_sync_width'length)),
     horiz_total_width    => 800, --std_logic_vector(to_unsigned(800, horiz_total_width'length)), -- -1
     vert_display_start   => 31, --std_logic_vector(to_unsigned(31, vert_display_start'length)), -- -1
     vert_display_width   => 480, --std_logic_vector(to_unsigned(480, vert_display_width'length)),
     vert_sync_width      => 2, --std_logic_vector(to_unsigned(2, vert_sync_width'length)),
     vert_total_width     => 520, --std_logic_vector(to_unsigned(520, vert_total_width'length)), -- -1
     hpol                 => '0',
     vpol                 => '0',
     pitch                => 5*16), --std_logic_vector(to_unsigned(5*16, pitch'length))), -- 5 rows at 1bpp
    -- 36 Mhz 640x480 @ 85 Hz
    (divide_count         => 5,--std_logic_vector(to_unsigned(5, divide_count'length)),
     mult_integer         => 24,--std_logic_vector(to_unsigned(24, mult_integer'length)),
     mult_fraction        => 750,--std_logic_vector(to_unsigned(750, mult_fraction'length)),
     divide_integer       => 27,--std_logic_vector(to_unsigned(27, divide_integer'length)),
     divide_fraction      => 500,--std_logic_vector(to_unsigned(500, divide_fraction'length)),
     horiz_display_start  => 111,--std_logic_vector(to_unsigned(111, horiz_display_start'length)), -- BP -1
     horiz_display_width  => 640,--std_logic_vector(to_unsigned(640, horiz_display_width'length)),
     horiz_sync_width     => 48,--std_logic_vector(to_unsigned(48, horiz_sync_width'length)),
     horiz_total_width    => 831,--std_logic_vector(to_unsigned(831, horiz_total_width'length)), -- -1
     vert_display_start   => 23,--std_logic_vector(to_unsigned(23, vert_display_start'length)), -- -1
     vert_display_width   => 480,--std_logic_vector(to_unsigned(480, vert_display_width'length)),
     vert_sync_width      => 3,--std_logic_vector(to_unsigned(3, vert_sync_width'length)),
     vert_total_width     => 508,--std_logic_vector(to_unsigned(508, vert_total_width'length)), -- -1
     hpol                 => '0',
     vpol                 => '0',
     pitch                => 5*16),--std_logic_vector(to_unsigned(5*16, pitch'length))), -- 5 rows at 1bpp
    -- 40 Mhz 800x600 @ 60 Hz
    (divide_count         => 1,--std_logic_vector(to_unsigned(1, divide_count'length)),
     mult_integer         => 5,--std_logic_vector(to_unsigned(5, mult_integer'length)),
     mult_fraction        => 000,--std_logic_vector(to_unsigned(000, mult_fraction'length)),
     divide_integer       => 20,--std_logic_vector(to_unsigned(20, divide_integer'length)),
     divide_fraction      => 000,--std_logic_vector(to_unsigned(000, divide_fraction'length)),
     horiz_display_start  => 87,--std_logic_vector(to_unsigned(87, horiz_display_start'length)), -- BP -1
     horiz_display_width  => 800,--std_logic_vector(to_unsigned(800, horiz_display_width'length)),
     horiz_sync_width     => 128,--std_logic_vector(to_unsigned(128, horiz_sync_width'length)),
     horiz_total_width    => 1055,--std_logic_vector(to_unsigned(1055, horiz_total_width'length)), -- -1
     vert_display_start   => 22,--std_logic_vector(to_unsigned(22, vert_display_start'length)), -- -1
     vert_display_width   => 600,--std_logic_vector(to_unsigned(600, vert_display_width'length)),
     vert_sync_width      => 4,--std_logic_vector(to_unsigned(4, vert_sync_width'length)),
     vert_total_width     => 627,--std_logic_vector(to_unsigned(627, vert_total_width'length)), -- -1
     hpol                 => '1',
     vpol                 => '1',
     pitch                => 7*16),--std_logic_vector(to_unsigned(7*16, pitch'length))), -- 5 rows at 1bpp
    -- 49.5 Mhz 800x600 @ 75 Hz
    (divide_count         => 5,--std_logic_vector(to_unsigned(5, divide_count'length)),
     mult_integer         => 24,--std_logic_vector(to_unsigned(24, mult_integer'length)),
     mult_fraction        => 750,--std_logic_vector(to_unsigned(750, mult_fraction'length)),
     divide_integer       => 20,--std_logic_vector(to_unsigned(20, divide_integer'length)),
     divide_fraction      => 000,--std_logic_vector(to_unsigned(000, divide_fraction'length)),
     horiz_display_start  => 159,--std_logic_vector(to_unsigned(159, horiz_display_start'length)), -- BP -1
     horiz_display_width  => 800,--std_logic_vector(to_unsigned(800, horiz_display_width'length)),
     horiz_sync_width     => 80,--std_logic_vector(to_unsigned(80, horiz_sync_width'length)),
     horiz_total_width    => 1055,--std_logic_vector(to_unsigned(1055, horiz_total_width'length)), -- -1
     vert_display_start   => 20,--std_logic_vector(to_unsigned(20, vert_display_start'length)), -- -1
     vert_display_width   => 600,--std_logic_vector(to_unsigned(600, vert_display_width'length)),
     vert_sync_width      => 2,--std_logic_vector(to_unsigned(2, vert_sync_width'length)),
     vert_total_width     => 624,--std_logic_vector(to_unsigned(624, vert_total_width'length)), -- -1
     hpol                 => '1',
     vpol                 => '1',
     pitch                => 7*16),--std_logic_vector(to_unsigned(7*16, pitch'length))), -- 5 rows at 1bpp
    -- 50 Mhz 800x600 @ 72 Hz
    (divide_count         => 1,--std_logic_vector(to_unsigned(1, divide_count'length)),
     mult_integer         => 5,--std_logic_vector(to_unsigned(5, mult_integer'length)),
     mult_fraction        => 000,--std_logic_vector(to_unsigned(000, mult_fraction'length)),
     divide_integer       => 20,--std_logic_vector(to_unsigned(20, divide_integer'length)),
     divide_fraction      => 000,--std_logic_vector(to_unsigned(000, divide_fraction'length)),
     horiz_display_start  => 63,--std_logic_vector(to_unsigned(63, horiz_display_start'length)), -- BP -1
     horiz_display_width  => 800,--std_logic_vector(to_unsigned(800, horiz_display_width'length)),
     horiz_sync_width     => 120,--std_logic_vector(to_unsigned(120, horiz_sync_width'length)),
     horiz_total_width    => 1039,--std_logic_vector(to_unsigned(1039, horiz_total_width'length)), -- -1
     vert_display_start   => 22,--std_logic_vector(to_unsigned(22, vert_display_start'length)), -- -1
     vert_display_width   => 600,--std_logic_vector(to_unsigned(600, vert_display_width'length)),
     vert_sync_width      => 6,--std_logic_vector(to_unsigned(6, vert_sync_width'length)),
     vert_total_width     => 665,--std_logic_vector(to_unsigned(665, vert_total_width'length)), -- -1
     hpol                 => '1',
     vpol                 => '1',
     pitch                => 7*16),--std_logic_vector(to_unsigned(7*16, pitch'length))), -- 5 rows at 1bpp
    -- 56.25 Mhz 800x600 @ 85 Hz
    (divide_count         => 2,--std_logic_vector(to_unsigned(2, divide_count'length)),
     mult_integer         => 10,--std_logic_vector(to_unsigned(10, mult_integer'length)),
     mult_fraction        => 125,--std_logic_vector(to_unsigned(125, mult_fraction'length)),
     divide_integer       => 18,--std_logic_vector(to_unsigned(18, divide_integer'length)),
     divide_fraction      => 000,--std_logic_vector(to_unsigned(000, divide_fraction'length)),
     horiz_display_start  => 151,--std_logic_vector(to_unsigned(151, horiz_display_start'length)), -- BP -1
     horiz_display_width  => 800,--std_logic_vector(to_unsigned(800, horiz_display_width'length)),
     horiz_sync_width     => 64,--std_logic_vector(to_unsigned(64, horiz_sync_width'length)),
     horiz_total_width    => 1047,--std_logic_vector(to_unsigned(1047, horiz_total_width'length)), -- -1
     vert_display_start   => 26,--std_logic_vector(to_unsigned(26, vert_display_start'length)), -- -1
     vert_display_width   => 600,--std_logic_vector(to_unsigned(600, vert_display_width'length)),
     vert_sync_width      => 3,--std_logic_vector(to_unsigned(3, vert_sync_width'length)),
     vert_total_width     => 630,--std_logic_vector(to_unsigned(630, vert_total_width'length)), -- -1
     hpol                 => '1',
     vpol                 => '1',
     pitch                => 7*16),--std_logic_vector(to_unsigned(7*16, pitch'length))), -- 5 rows at 1bpp
    -- 65 Mhz 1024x768 @ 60 Hz
    (divide_count         => 10,--std_logic_vector(to_unsigned(10, divide_count'length)),
     mult_integer         => 50,--std_logic_vector(to_unsigned(50, mult_integer'length)),
     mult_fraction        => 375,--std_logic_vector(to_unsigned(375, mult_fraction'length)),
     divide_integer       => 15,--std_logic_vector(to_unsigned(15, divide_integer'length)),
     divide_fraction      => 500,--std_logic_vector(to_unsigned(500, divide_fraction'length)),
     horiz_display_start  => 159,--std_logic_vector(to_unsigned(159, horiz_display_start'length)), -- BP -1
     horiz_display_width  => 1024,--std_logic_vector(to_unsigned(1024, horiz_display_width'length)),
     horiz_sync_width     => 136,--std_logic_vector(to_unsigned(136, horiz_sync_width'length)),
     horiz_total_width    => 1339,--std_logic_vector(to_unsigned(1339, horiz_total_width'length)), -- -1
     vert_display_start   => 28,--std_logic_vector(to_unsigned(28, vert_display_start'length)), -- -1
     vert_display_width   => 768,--std_logic_vector(to_unsigned(768, vert_display_width'length)),
     vert_sync_width      => 6,--std_logic_vector(to_unsigned(6, vert_sync_width'length)),
     vert_total_width     => 805,--std_logic_vector(to_unsigned(805, vert_total_width'length)), -- -1
     hpol                 => '0',
     vpol                 => '0',
     pitch                => 8*16),--std_logic_vector(to_unsigned(8*16, pitch'length))), -- 5 rows at 1bpp
    -- 75 Mhz 1024x768 @ 70 Hz
    (divide_count         => 8,--std_logic_vector(to_unsigned(8, divide_count'length)),
     mult_integer         => 40,--std_logic_vector(to_unsigned(40, mult_integer'length)),
     mult_fraction        => 125,--std_logic_vector(to_unsigned(125, mult_fraction'length)),
     divide_integer       => 13,--std_logic_vector(to_unsigned(13, divide_integer'length)),
     divide_fraction      => 375,--std_logic_vector(to_unsigned(375, divide_fraction'length)),
     horiz_display_start  => 143,--std_logic_vector(to_unsigned(143, horiz_display_start'length)), -- BP -1
     horiz_display_width  => 1024,--std_logic_vector(to_unsigned(1024, horiz_display_width'length)),
     horiz_sync_width     => 136,--std_logic_vector(to_unsigned(136, horiz_sync_width'length)),
     horiz_total_width    => 1327,--std_logic_vector(to_unsigned(1327, horiz_total_width'length)), -- -1
     vert_display_start   => 28,--std_logic_vector(to_unsigned(28, vert_display_start'length)), -- -1
     vert_display_width   => 768,--std_logic_vector(to_unsigned(768, vert_display_width'length)),
     vert_sync_width      => 6,--std_logic_vector(to_unsigned(6, vert_sync_width'length)),
     vert_total_width     => 805,--std_logic_vector(to_unsigned(805, vert_total_width'length)), -- -1
     hpol                 => '0',
     vpol                 => '0',
     pitch                => 8*16),--std_logic_vector(to_unsigned(8*16, pitch'length))), -- 5 rows at 1bpp
    -- 78.75 Mhz 1024x768 @ 75 Hz
    (divide_count         => 8,--std_logic_vector(to_unsigned(8, divide_count'length)),
     mult_integer         => 39,--std_logic_vector(to_unsigned(39, mult_integer'length)),
     mult_fraction        => 375,--std_logic_vector(to_unsigned(375, mult_fraction'length)),
     divide_integer       => 12,--std_logic_vector(to_unsigned(12, divide_integer'length)),
     divide_fraction      => 500,--std_logic_vector(to_unsigned(500, divide_fraction'length)),
     horiz_display_start  => 175,--std_logic_vector(to_unsigned(175, horiz_display_start'length)), -- BP -1
     horiz_display_width  => 1024,--std_logic_vector(to_unsigned(1024, horiz_display_width'length)),
     horiz_sync_width     => 96,--std_logic_vector(to_unsigned(96, horiz_sync_width'length)),
     horiz_total_width    => 1311,--std_logic_vector(to_unsigned(1311, horiz_total_width'length)), -- -1
     vert_display_start   => 27,--std_logic_vector(to_unsigned(27, vert_display_start'length)), -- -1
     vert_display_width   => 768,--std_logic_vector(to_unsigned(768, vert_display_width'length)),
     vert_sync_width      => 3,--std_logic_vector(to_unsigned(3, vert_sync_width'length)),
     vert_total_width     => 799,--std_logic_vector(to_unsigned(799, vert_total_width'length)), -- -1
     hpol                 => '1',
     vpol                 => '1',
     pitch                => 8*16),--std_logic_vector(to_unsigned(8*16, pitch'length))), -- 5 rows at 1bpp
    -- 94.5 Mhz 1024x768 @ 85 Hz
    (divide_count         => 5,--std_logic_vector(to_unsigned(5, divide_count'length)),
     mult_integer         => 23,--std_logic_vector(to_unsigned(23, mult_integer'length)),
     mult_fraction        => 625,--std_logic_vector(to_unsigned(625, mult_fraction'length)),
     divide_integer       => 10,--std_logic_vector(to_unsigned(10, divide_integer'length)),
     divide_fraction      => 000,--std_logic_vector(to_unsigned(000, divide_fraction'length)),
     horiz_display_start  => 207,--std_logic_vector(to_unsigned(207, horiz_display_start'length)), -- BP -1
     horiz_display_width  => 1024,--std_logic_vector(to_unsigned(1024, horiz_display_width'length)),
     horiz_sync_width     => 96,--std_logic_vector(to_unsigned(96, horiz_sync_width'length)),
     horiz_total_width    => 1375,--std_logic_vector(to_unsigned(1375, horiz_total_width'length)), -- -1
     vert_display_start   => 35,--std_logic_vector(to_unsigned(35, vert_display_start'length)), -- -1
     vert_display_width   => 768,--std_logic_vector(to_unsigned(768, vert_display_width'length)),
     vert_sync_width      => 3,--std_logic_vector(to_unsigned(3, vert_sync_width'length)),
     vert_total_width     => 807,--std_logic_vector(to_unsigned(807, vert_total_width'length)), -- -1
     hpol                 => '1',
     vpol                 => '1',
     pitch                => 8*16),--std_logic_vector(to_unsigned(8*16, pitch'length))), -- 5 rows at 1bpp
    -- 108 Mhz 1280x1024 @ 60 Hz
    (divide_count         => 2,--std_logic_vector(to_unsigned(2, divide_count'length)),
     mult_integer         => 10,--std_logic_vector(to_unsigned(10, mult_integer'length)),
     mult_fraction        => 125,--std_logic_vector(to_unsigned(125, mult_fraction'length)),
     divide_integer       => 9,--std_logic_vector(to_unsigned(9, divide_integer'length)),
     divide_fraction      => 375,--std_logic_vector(to_unsigned(375, divide_fraction'length)),
     horiz_display_start  => 247,--std_logic_vector(to_unsigned(247, horiz_display_start'length)), -- BP -1
     horiz_display_width  => 1280,--std_logic_vector(to_unsigned(1280, horiz_display_width'length)),
     horiz_sync_width     => 112,--std_logic_vector(to_unsigned(112, horiz_sync_width'length)),
     horiz_total_width    => 1688,--std_logic_vector(to_unsigned(1688, horiz_total_width'length)), -- -1
     vert_display_start   => 37,--std_logic_vector(to_unsigned(37, vert_display_start'length)), -- -1
     vert_display_width   => 1024,--std_logic_vector(to_unsigned(1024, vert_display_width'length)),
     vert_sync_width      => 3,--std_logic_vector(to_unsigned(3, vert_sync_width'length)),
     vert_total_width     => 1066,--std_logic_vector(to_unsigned(1066, vert_total_width'length)), -- -1
     hpol                 => '1',
     vpol                 => '1',
     pitch                => 10*16),--std_logic_vector(to_unsigned(10*16, pitch'length))), -- 5 rows at 1bpp
    -- 135 Mhz 1280x1024 @ 75 Hz
    (divide_count         => 2,--std_logic_vector(to_unsigned(2, divide_count'length)),
     mult_integer         => 10,--std_logic_vector(to_unsigned(10, mult_integer'length)),
     mult_fraction        => 125,--std_logic_vector(to_unsigned(125, mult_fraction'length)),
     divide_integer       => 7,--std_logic_vector(to_unsigned(7, divide_integer'length)),
     divide_fraction      => 500,--std_logic_vector(to_unsigned(500, divide_fraction'length)),
     horiz_display_start  => 247,--std_logic_vector(to_unsigned(247, horiz_display_start'length)), -- BP -1
     horiz_display_width  => 1280,--std_logic_vector(to_unsigned(1280, horiz_display_width'length)),
     horiz_sync_width     => 144,--std_logic_vector(to_unsigned(144, horiz_sync_width'length)),
     horiz_total_width    => 1688,--std_logic_vector(to_unsigned(1688, horiz_total_width'length)), -- -1
     vert_display_start   => 37,--std_logic_vector(to_unsigned(37, vert_display_start'length)), -- -1
     vert_display_width   => 1024,--std_logic_vector(to_unsigned(1024, vert_display_width'length)),
     vert_sync_width      => 3,--std_logic_vector(to_unsigned(3, vert_sync_width'length)),
     vert_total_width     => 1066,--std_logic_vector(to_unsigned(1066, vert_total_width'length)), -- -1
     hpol                 => '1',
     vpol                 => '1',
     pitch                => 10*16),--std_logic_vector(to_unsigned(10*16, pitch'length))), -- 5 rows at 1bpp
    -- 157.5 Mhz 1280x1024 @ 85 Hz
    (divide_count         => 8,--std_logic_vector(to_unsigned(8, divide_count'length)),
     mult_integer         => 39,--std_logic_vector(to_unsigned(39, mult_integer'length)),
     mult_fraction        => 375,--std_logic_vector(to_unsigned(375, mult_fraction'length)),
     divide_integer       => 6,--std_logic_vector(to_unsigned(6, divide_integer'length)),
     divide_fraction      => 250,--std_logic_vector(to_unsigned(250, divide_fraction'length)),
     horiz_display_start  => 223,--std_logic_vector(to_unsigned(223, horiz_display_start'length)), -- BP -1
     horiz_display_width  => 1280,--std_logic_vector(to_unsigned(1280, horiz_display_width'length)),
     horiz_sync_width     => 160,--std_logic_vector(to_unsigned(160, horiz_sync_width'length)),
     horiz_total_width    => 1728,--std_logic_vector(to_unsigned(1728, horiz_total_width'length)), -- -1
     vert_display_start   => 43,--std_logic_vector(to_unsigned(43, vert_display_start'length)), -- -1
     vert_display_width   => 1024,--std_logic_vector(to_unsigned(1024, vert_display_width'length)),
     vert_sync_width      => 3,--std_logic_vector(to_unsigned(3, vert_sync_width'length)),
     vert_total_width     => 1072,--std_logic_vector(to_unsigned(1072, vert_total_width'length)), -- -1
     hpol                 => '1',
     vpol                 => '1',
     pitch                => 10*16),--std_logic_vector(to_unsigned(10*16, pitch'length))), -- 5 rows at 1bpp
    -- 162 Mhz 1600x1200 @ 60 Hz
    (divide_count         => 2,--std_logic_vector(to_unsigned(2, divide_count'length)),
     mult_integer         => 10,--std_logic_vector(to_unsigned(10, mult_integer'length)),
     mult_fraction        => 125,--std_logic_vector(to_unsigned(125, mult_fraction'length)),
     divide_integer       => 6,--std_logic_vector(to_unsigned(6, divide_integer'length)),
     divide_fraction      => 250,--std_logic_vector(to_unsigned(250, divide_fraction'length)),
     horiz_display_start  => 303,--std_logic_vector(to_unsigned(303, horiz_display_start'length)), -- BP -1
     horiz_display_width  => 1600,--std_logic_vector(to_unsigned(1600, horiz_display_width'length)),
     horiz_sync_width     => 192,--std_logic_vector(to_unsigned(192, horiz_sync_width'length)),
     horiz_total_width    => 2160,--std_logic_vector(to_unsigned(2160, horiz_total_width'length)), -- -1
     vert_display_start   => 45,--std_logic_vector(to_unsigned(45, vert_display_start'length)), -- -1
     vert_display_width   => 1200,--std_logic_vector(to_unsigned(1200, vert_display_width'length)),
     vert_sync_width      => 3,--std_logic_vector(to_unsigned(3, vert_sync_width'length)),
     vert_total_width     => 1250,--std_logic_vector(to_unsigned(1250, vert_total_width'length)), -- -1
     hpol                 => '1',
     vpol                 => '1',
     pitch                => 13*16),--std_logic_vector(to_unsigned(13*16, pitch'length))), -- 5 rows at 1bpp
    -- 195 Mhz 1920x1200 @ 60 Hz
    (divide_count         => 1,--std_logic_vector(to_unsigned(1, divide_count'length)),
     mult_integer         => 4,--std_logic_vector(to_unsigned(4, mult_integer'length)),
     mult_fraction        => 875,--std_logic_vector(to_unsigned(875, mult_fraction'length)),
     divide_integer       => 5,--std_logic_vector(to_unsigned(5, divide_integer'length)),
     divide_fraction      => 000,--std_logic_vector(to_unsigned(000, divide_fraction'length)),
     horiz_display_start  => 339,--std_logic_vector(to_unsigned(339, horiz_display_start'length)), -- BP -1
     horiz_display_width  => 1920,--std_logic_vector(to_unsigned(1920, horiz_display_width'length)),
     horiz_sync_width     => 200,--std_logic_vector(to_unsigned(200, horiz_sync_width'length)),
     horiz_total_width    => 2616,--std_logic_vector(to_unsigned(2616, horiz_total_width'length)), -- -1
     vert_display_start   => 35,--std_logic_vector(to_unsigned(35, vert_display_start'length)), -- -1
     vert_display_width   => 1200,--std_logic_vector(to_unsigned(1200, vert_display_width'length)),
     vert_sync_width      => 3,--std_logic_vector(to_unsigned(3, vert_sync_width'length)),
     vert_total_width     => 1242,--std_logic_vector(to_unsigned(1242, vert_total_width'length)), -- -1
     hpol                 => '1',
     vpol                 => '1',
     pitch                => 15*16),--std_logic_vector(to_unsigned(15*16, pitch'length))), -- 5 rows at 1bpp
    -- 195 Mhz 1920x1200 @ 60 Hz
    (divide_count         => 8,--std_logic_vector(to_unsigned(8, divide_count'length)),
     mult_integer         => 37,--std_logic_vector(to_unsigned(37, mult_integer'length)),
     mult_fraction        => 125,--std_logic_vector(to_unsigned(125, mult_fraction'length)),
     divide_integer       => 6,--std_logic_vector(to_unsigned(6, divide_integer'length)),
     divide_fraction      => 250,--std_logic_vector(to_unsigned(250, divide_fraction'length)),
     horiz_display_start  => 147,--std_logic_vector(to_unsigned(147, horiz_display_start'length)), -- BP -1
     horiz_display_width  => 1920,--std_logic_vector(to_unsigned(1920, horiz_display_width'length)),
     horiz_sync_width     => 44,--std_logic_vector(to_unsigned(44, horiz_sync_width'length)),
     horiz_total_width    => 2199,--std_logic_vector(to_unsigned(2199, horiz_total_width'length)), -- -1
     vert_display_start   => 3,--std_logic_vector(to_unsigned(3, vert_display_start'length)), -- -1
     vert_display_width   => 1080,--std_logic_vector(to_unsigned(1080, vert_display_width'length)),
     vert_sync_width      => 5,--std_logic_vector(to_unsigned(5, vert_sync_width'length)),
     vert_total_width     => 1124,--std_logic_vector(to_unsigned(1124, vert_total_width'length)), -- -1
     hpol                 => '1',
     vpol                 => '1',
     pitch                => 15*16));--std_logic_vector(to_unsigned(15*16, pitch'length)))); -- 5 rows at 1bpp

  type res_text_capt_t is array (natural range <>) of character;
  type res_text_t is array (natural range <>) of res_text_capt_t;
  constant res_text : res_text_t(0 to 17)(15 downto 0) :=
    ((' ',' ','z','H','0','6',' ','@',' ','0','8','4','x','0','4','6'),
     (' ',' ','z','H','2','7',' ','@',' ','0','8','4','x','0','4','6'),
     (' ',' ','z','H','5','7',' ','@',' ','0','8','4','x','0','4','6'),
     (' ',' ','z','H','5','8',' ','@',' ','0','8','4','x','0','4','6'),
     (' ',' ','z','H','0','6',' ','@',' ','0','0','6','x','0','0','8'),
     (' ',' ','z','H','0','7',' ','@',' ','0','0','6','x','0','0','8'),
     (' ',' ','z','H','5','7',' ','@',' ','0','0','6','x','0','0','8'),
     (' ',' ','z','H','5','8',' ','@',' ','0','0','6','x','0','0','8'),
     (' ','z','H','0','6',' ','@',' ','8','6','7','x','4','2','0','1'),
     (' ','z','H','0','7',' ','@',' ','8','6','7','x','4','2','0','1'),
     (' ','z','H','5','7',' ','@',' ','8','6','7','x','4','2','0','1'),
     (' ','z','H','5','8',' ','@',' ','8','6','7','x','4','2','0','1'),
     ('z','H','0','6',' ','@',' ','4','2','0','1','x','0','8','2','1'),
     ('z','H','5','7',' ','@',' ','4','2','0','1','x','0','8','2','1'),
     ('z','H','5','8',' ','@',' ','4','2','0','1','x','0','8','2','1'),
     ('z','H','0','6',' ','@',' ','0','0','2','1','x','0','0','6','1'),
     ('z','H','0','6',' ','@',' ','0','0','2','1','x','0','2','9','1'),
     ('z','H','0','6',' ','@',' ','0','8','0','1','x','0','2','9','1'));

  type addr_array_t is array (natural range <>) of std_logic_vector(11 downto 0);
  constant addr_array : addr_array_t(0 to 31) :=
    (x"200", x"204", x"208", x"20C", x"210", x"214", x"218", x"21C",
     x"220", x"224", x"228", x"22C", x"230", x"234", x"238", x"23C",
     x"240", x"244", x"248", x"24C", x"250", x"254", x"258", x"25C",
     x"000", x"004", x"008", x"00C", x"010", x"100", x"104", x"108");

  function resolution_lookup(sw_capt  : in integer range 0 to 17; wr_count : in integer range 0 to 31; resolution : resolution_array(0 to 17)) return std_logic_vector;
end package vga_pkg;

package body vga_pkg is

  function resolution_lookup(sw_capt : in integer range 0 to 17; wr_count : in integer range 0 to 31; resolution : resolution_array(0 to 17)) return std_logic_vector is
    variable s_axi_wdata : std_logic_vector(31 downto 0);
  begin
    case wr_count is
      when 1 | 3 | 6  | 9  | 12 | 15 | 18 | 21 => s_axi_wdata := (others => '0');
      when 5 | 8 | 11 | 14 | 17 | 20           => s_axi_wdata := x"0000000A";
      when 4 | 7 | 10 | 13 | 16 | 19 | 22      => s_axi_wdata := x"0000C350";
      when 2 => s_axi_wdata := "000000" &
                               std_logic_vector(to_unsigned(resolution(sw_capt).divide_fraction , 18)) &
                               std_logic_vector(to_unsigned(resolution(sw_capt).divide_integer, 8));
      when 23 => s_axi_wdata := x"00000003";
      when 24 => s_axi_wdata := x"0" &
                                std_logic_vector(to_unsigned(resolution(sw_capt).horiz_display_width, 12)) &
                                x"0" &
                                std_logic_vector(to_unsigned(resolution(sw_capt).horiz_display_start, 12));
      when 25 => s_axi_wdata := x"0" &
                                std_logic_vector(to_unsigned(resolution(sw_capt).horiz_total_width, 12)) &
                                x"0" &
                                std_logic_vector(to_unsigned(resolution(sw_capt).horiz_sync_width, 12));
      when 26 => s_axi_wdata := x"0" &
                                std_logic_vector(to_unsigned(resolution(sw_capt).vert_display_width, 12)) &
                                x"0" &
                                std_logic_vector(to_unsigned(resolution(sw_capt).vert_display_start, 12));
      when 27 => s_axi_wdata := x"0" &
                                std_logic_vector(to_unsigned(resolution(sw_capt).vert_total_width, 12)) &
                                x"0" &
                                std_logic_vector(to_unsigned(resolution(sw_capt).vert_sync_width, 12));
      when 28 => s_axi_wdata := x"0000" & x"00" & "000000" &
                                resolution(sw_capt).hpol &
                                resolution(sw_capt).vpol;
      when 29 => s_axi_wdata := (others => '0');
      when 30 => s_axi_wdata := x"0000" & "000" & std_logic_vector(to_unsigned(resolution(sw_capt).pitch, 13));
      when 31 => s_axi_wdata := x"00000001";
      when others =>
    end case;
    return s_axi_wdata;
  end function;

end package body vga_pkg;
