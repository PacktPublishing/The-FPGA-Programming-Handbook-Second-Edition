-- components_pkg.vhd
-- ------------------------------------
-- Module to store component instances to clean up the architecture
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann

library IEEE;
use IEEE.std_logic_1164.all;

package components_pkg is

  component sys_pll
    port(
      clk_out1 : out std_logic;
      clk_out2 : out std_logic;
      locked   : out std_logic;
      clk_in1  : in  std_logic);
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

end package components_pkg;
