-- uart_top.vhd
-- ------------------------------------
-- UART top level
-- ------------------------------------
-- Author : Frank Bruno
LIBRARY IEEE, XPM;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_misc.all;
use IEEE.numeric_std.all;
USE WORK.counting_buttons_pkg.all;
entity uart_top is
  generic (NUM_SEGMENTS : integer := 8;
           USE_PLL      : string  := "FALSE");
  port (clk : in std_logic;
        anode : out std_logic_vector(NUM_SEGMENTS-1 downto 0);
        cathode : out std_logic_vector(7 downto 0);

        -- UART
        uart_ctsn : in std_logic;  -- Clear to send
        uart_rx : in std_logic;   -- RX pin
        uart_rtsn : out std_logic; -- Request to send
        uart_tx : out std_logic);    -- TX pin
end entity uart_top;

architecture rtl of uart_top is
  component sys_pll is
    Port (
      clk_out1 : out STD_LOGIC;
      clk_in1 : in STD_LOGIC
      );
  end component sys_pll;

  signal encoded : array_t(NUM_SEGMENTS-1 downto 0)(3 downto 0);
  signal digit_point : std_logic_vector(NUM_SEGMENTS-1 downto 0) := (others => '1');
  signal clk_50 : std_logic;
  signal cpu_int : std_logic; -- interrupt
  signal reg_awvalid : std_logic;
  signal reg_awready : std_logic;
  signal reg_awaddr : std_logic_vector(2 downto 0);

  signal reg_wvalid : std_logic;
  signal reg_wready : std_logic;
  signal reg_wdata : std_logic_vector(7 downto 0);

  signal reg_bready : std_logic;
  signal reg_bvalid : std_logic;
  signal reg_bresp : std_logic_vector(1 downto 0);

  signal reg_arvalid : std_logic;
  signal reg_arready : std_logic;
  signal reg_araddr : std_logic_vector(2 downto 0);

  signal reg_rready : std_logic;
  signal reg_rvalid : std_logic;
  signal reg_rdata : std_logic_vector(7 downto 0);
  signal reg_rresp : std_logic_vector(1 downto 0);
  type uart_cs_t is (IDLE, W4DATA, RDDATA);
  signal uart_cs : uart_cs_t := IDLE;

begin

  u_sys_pll : sys_pll
    port map (clk_out1     => clk_50,
              clk_in1      => clk);

  digit_point <= (others => '1');

  u_seven_segment : entity work.seven_segment
    generic map(NUM_SEGMENTS => NUM_SEGMENTS,
                CLK_PER      => 20)
    port map   (clk          => clk_50,
                reset        => '0',
                encoded      => encoded,
                digit_point  => digit_point,
                anode        => anode,
                cathode      => cathode);

  -- UART
  u_uart : entity work.uart
    port map (-- Utility signals
              sys_clk      => clk_50,
              sys_rstn     => '1',

              -- CPU interface
              cpu_int      => cpu_int,
              reg_awvalid  => reg_awvalid,
              reg_awready  => reg_awready,
              reg_awaddr   => reg_awaddr,

              reg_wvalid   => reg_wvalid,
              reg_wready   => reg_wready,
              reg_wdata    => reg_wdata,

              reg_bready   => reg_bready,
              reg_bvalid   => reg_bvalid,
              reg_bresp    => reg_bresp,

              reg_arvalid  => reg_arvalid,
              reg_arready  => reg_arready,
              reg_araddr   => reg_araddr,

              reg_rready   => reg_rready,
              reg_rvalid   => reg_rvalid,
              reg_rdata    => reg_rdata,
              reg_rresp    => reg_rresp,

              -- External pins
              uart_ctsn    => uart_ctsn,
              uart_rx      => uart_rx,
              uart_rtsn    => uart_rtsn,
              uart_tx      => uart_tx);

  reg_bready <= '1';
  reg_rready <= '1';

  -- The UART is setup to be 5600bps 8-n-1, so we won't configure it here.
  -- We'll just poll data when the RX is ready and display on the 7 segment
  -- display.
  process (clk_50)
  begin
    if rising_edge(clk_50) then
      reg_arvalid <= '0';
      case uart_cs is
        when IDLE =>
          reg_arvalid <= '1';
          reg_araddr  <= "101"; -- Check if RX data is available
          uart_cs     <= W4DATA;
        when W4DATA =>
          if reg_rvalid and reg_rdata(0) then
            -- Read RX Register
            reg_arvalid <= '1';
            reg_araddr  <= "000"; -- Check if RX data is available
            uart_cs     <= RDDATA;
          elsif reg_rvalid then
            uart_cs     <= IDLE;
          end if;
        when RDDATA =>
          if reg_rvalid then
            encoded(0) <= reg_rdata(3 downto 0);
            encoded(1) <= reg_rdata(7 downto 4);
            for i in 2 to 7 loop
              encoded(i) <= encoded(i-2);
            end loop;
            uart_cs  <= IDLE;
          end if;
      end case;
    end if;
  end process;
end architecture rtl;
