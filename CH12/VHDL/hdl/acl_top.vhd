-- acl_top.vhd
-- ------------------------------------
-- Top level of connection to ACL
-- ------------------------------------
-- Author : Frank Bruno
LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;
use IEEE.math_real.all;
USE WORK.counting_buttons_pkg.all;

entity acl_top is
  generic (NUM_SEGMENTS : integer := 8);
  port (
    clk        : in std_logic;
    CPU_RESETN : in std_logic;

    anode      : out std_logic_vector(NUM_SEGMENTS-1 downto 0);
    cathode    : out std_logic_vector(7 downto 0);

    -- SPI Port
    int1       : in std_logic; -- Interrupt 1 (not currently used)
    int2       : in std_logic; -- Interrupt 2 (not currently used)
    CSn        : out std_logic; -- Chip select to ACL
    SCLK       : out std_logic; -- Clock to ACL chip
    MOSI       : out std_logic; -- Data to ACL chip
    MISO       : in std_logic); -- Data from ACL chip
end entity acl_top;
architecture rtl of acl_top is
  -- Types
  type spi_cs_t is (IDLE, S0, S1, S2, S3, S4, S5, S6, S7, S8);

  -- Registered signals with initial values
  signal encoded      : array_t(NUM_SEGMENTS-1 downto 0)(3 downto 0) := (others => x"0");
  signal rst          : std_logic_vector(1 downto 0) := (others => '0');
  signal reg_arvalid  : std_logic                    := '0';
  signal reg_araddr   : std_logic_vector(5 downto 0) := (others => '0');
  signal reg_rready   : std_logic                    := '0';
  signal reg_awvalid  : std_logic                    := '0';
  signal reg_awaddr   : std_logic_vector(5 downto 0) := (others => '0');
  signal reg_wvalid   : std_logic                    := '0';
  signal reg_wdata    : std_logic_vector(7 downto 0) := (others => '0');
  signal wait_time    : integer range 0 to 2**16     := 0;
  signal spi_cs       : spi_cs_t                     := IDLE;

  -- Unregistered signals
  signal digit_point  : std_logic_vector(NUM_SEGMENTS-1 downto 0);
  signal reg_awready  : std_logic;
  signal reg_wready   : std_logic;
  signal reg_bready   : std_logic;
  signal reg_bvalid   : std_logic;
  signal reg_bresp    : std_logic_vector(1 downto 0);
  signal reg_arready  : std_logic;
  signal reg_rvalid   : std_logic;
  signal reg_rdata    : std_logic_vector(7 downto 0);
  signal reg_rresp    : std_logic_vector(1 downto 0);

  -- Attributes
  attribute ASYNC_REG : string;
  attribute MARK_DEBUG : string;
  attribute ASYNC_REG of rst : signal is "TRUE";
  attribute MARK_DEBUG of reg_awvalid, reg_awready, reg_awaddr : signal is "TRUE";
  attribute MARK_DEBUG of reg_wvalid, reg_wready, reg_wdata : signal is "TRUE";
  attribute MARK_DEBUG of reg_arvalid, reg_arready, reg_araddr : signal is "TRUE";
  attribute MARK_DEBUG of reg_rvalid, reg_rready, reg_rdata : signal is "TRUE";
  attribute MARK_DEBUG of spi_cs : signal is "TRUE";
begin

  digit_point <= (others => '1');

  u_seven_segment : entity work.seven_segment
    generic map (
     NUM_SEGMENTS => NUM_SEGMENTS,
     CLK_PER      => 20)
    port map    (
     clk          => clk,
     reset        => rst(1),
     encoded      => encoded,
     digit_point  => digit_point,
     anode        => anode,
     cathode      => cathode);

  -- UART
  u_spi : entity work.spi
    port map(
      sys_clk     => clk,
      sys_rst     => rst(1),

      -- CPU interface
      reg_awvalid => reg_awvalid,
      reg_awready => reg_awready,
      reg_awaddr  => reg_awaddr,

      reg_wvalid  => reg_wvalid,
      reg_wready  => reg_wready,
      reg_wdata   => reg_wdata,

      reg_bready  => reg_bready,
      reg_bvalid  => reg_bvalid,
      reg_bresp   => reg_bresp,

      reg_arvalid => reg_arvalid,
      reg_arready => reg_arready,
      reg_araddr  => reg_araddr,

      reg_rready  => reg_rready,
      reg_rvalid  => reg_rvalid,
      reg_rdata   => reg_rdata,
      reg_rresp   => reg_rresp,

      -- External pins
      CSn         => CSn,
      SCLK        => SCLK,
      MOSI        => MOSI,
      MISO        => MISO);

  reg_bready <= '1';
  reg_rready <= '1';

  process (clk)
  begin
    if rising_edge(clk) then
      rst(1) <= rst(0);
      rst(0) <= not CPU_RESETN;
      reg_arvalid <= '0';
      case spi_cs is
        when IDLE =>
          wait_time <= wait_time + 1;
          if wait_time = 2**16 then spi_cs <= S0; end if;
        when S0 =>
          reg_awvalid <= '1';
          reg_awaddr  <= 6x"27";
          reg_wvalid  <= '1';
          reg_wdata   <= x"00";
          spi_cs      <= S1;
        when S1 =>
          if reg_wready then
            reg_awvalid <= '1';
            reg_awaddr  <= 6x"2D";
            reg_wvalid  <= '1';
            reg_wdata   <= x"02";
            spi_cs      <= S2;
          end if;
        when S2 =>
          if reg_wready then
            reg_awvalid <= '0';
            reg_wvalid  <= '0';
            spi_cs      <= S3;
          end if;
        when S3 =>
          reg_arvalid <= '1';
          reg_araddr  <= 6x"08";
          if reg_arready then spi_cs <= S4; end if;
        when S4 =>
          if reg_rready then
            encoded(0) <= reg_rdata(3 downto 0);
            encoded(1) <= reg_rdata(7 downto 4);
            spi_cs <= S5;
          end if;
        when S5 =>
          reg_arvalid <= '1';
          reg_araddr  <= 6x"09";
          if reg_arready then spi_cs <= S6; end if;
        when S6 =>
          if reg_rready then
            encoded(2) <= reg_rdata(3 downto 0);
            encoded(3) <= reg_rdata(7 downto 4);
            spi_cs <= S7;
          end if;
        when S7 =>
          reg_arvalid <= '1';
          reg_araddr  <= 6x"0A";
          if reg_arready then spi_cs <= S8; end if;
        when S8 =>
          if reg_rready then
            encoded(4) <= reg_rdata(3 downto 0);
            encoded(5) <= reg_rdata(7 downto 4);
            spi_cs <= S3;
          end if;
      end case;

      if rst(1) then
        spi_cs      <= IDLE;
        reg_awvalid <= '0';
        reg_wvalid  <= '0';
        reg_arvalid <= '0';
      end if;
    end if;
  end process;
end architecture rtl;
