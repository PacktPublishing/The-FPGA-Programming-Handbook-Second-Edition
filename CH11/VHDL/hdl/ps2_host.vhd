LIBRARY IEEE, XPM;
USE IEEE.std_logic_1164.all;
USE IEEE.std_logic_UNSIGNED.all;
USE ieee.numeric_std.all;
use IEEE.math_real.all;
use XPM.vcomponents.all;

entity ps2_host is
  generic(CLK_PER : integer := 10;
          CYCLES  : integer := 16);
  port(clk      : in std_logic;
       reset    : in std_logic;

       ps2_clk  : inout std_logic;
       ps2_data : inout std_logic;

       -- Transmit data to the keyboard from the FPGA
       tx_valid : in    std_logic;
       tx_data  : in    std_logic_vector(7 downto 0);
       tx_ready : out   std_logic := '1';

       -- Data from the device to the FPGA
       rx_data  : out   std_logic_vector(7 downto 0);
       rx_user  : out   std_logic;
       rx_valid : out   std_logic;
       rx_ready : in    std_logic);
end entity ps2_host;
architecture rtl of ps2_host is
  component debounce is
    generic(CYCLES : integer := 16);
    port(clk     : in  std_logic;
         reset   : in  std_logic;
         sig_in  : in  std_logic;
         sig_out : out std_logic);
  end component debounce;

  constant COUNT_100us : integer := integer(100000/CLK_PER);
  constant COUNT_20us  : integer := integer(20000/CLK_PER);
  signal counter_100us : integer range 0 to COUNT_100us := 0;
  signal counter_20us  : integer range 0 to COUNT_20us := 0;
  signal rx_data_r  : std_logic_vector(7 downto 0) := x"00";
  signal rx_user_r  : std_logic := '0';
  signal rx_valid_r : std_logic := '0';
  signal ps2_clk_clean : std_logic;
  signal ps2_clk_clean_last : std_logic;
  signal ps2_data_clean : std_logic;
  signal ps2_clk_en : std_logic;
  signal ps2_data_en : std_logic;
  signal data_capture : std_logic_vector(10 downto 0);
  signal data_counter : integer range 0 to 15;
  signal done         : std_logic;
  signal err          : std_logic;
  signal tx_xmit      : std_logic;
  signal tx_data_capt : std_logic_vector(7 downto 0);
  type state_t is (IDLE, CLK_FALL0, CLK_FALL1,
                   CLK_HIGH, XMIT0, XMIT1, XMIT2,
                   XMIT3, XMIT4, XMIT5, XMIT6);
  signal state : state_t := IDLE;
  type start_state_t is (START_IDLE, SEND_CMD, START0,
                         START1, START2, START3, START4,
                         START5, START6);
  signal start_state : start_state_t := START_IDLE;
  signal send_set : std_logic;
  signal clr_set : std_logic;
  signal send_data : std_logic_vector(7 downto 0);
  type array8_t is array (natural range <>) of std_logic_vector(7 downto 0);
  signal init_data : array8_t(0 to 9) :=
    (x"ED", x"00", x"F2", x"ED", x"02", x"F3", x"20", x"F4", x"F3", x"00");
  signal rx_expect : array8_t(0 to 10) :=
    (x"AA", -- Self test
     x"FA", -- Ack
     x"FA", -- Ack
     x"AB", -- Ack + keyboard code
     x"FA", -- Ack
     x"FA", -- Ack
     x"FA", -- Ack
     x"FA", -- Ack
     x"FA", -- Ack
     x"FA", -- Ack
     x"FA"); -- Ack
  signal start_count : integer range 0 to 10 := 0;
  signal tx_data_out : std_logic_vector(10 downto 0);
  signal xmit_ready  : std_logic;
  type out_state_t is (OUT_IDLE, OUT_WAIT);
  signal out_state : out_state_t := OUT_IDLE;

begin
  rx_data <= rx_data_r;
  rx_user <= rx_user_r;
  rx_valid <= rx_valid_r;

  -- Clean up the signals coming in
  u_debounce0 : debounce
    generic map(CYCLES   => CYCLES)
    port map   (clk      => clk,
                reset    => reset,
                sig_in   => to_x01(ps2_clk),
                sig_out  => ps2_clk_clean);

  u_debounce1 : debounce
    generic map(CYCLES   => CYCLES)
    port map   (clk      => clk,
                reset    => reset,
                sig_in   => to_x01(ps2_data),
                sig_out  => ps2_data_clean);

  -- Enable drives a 0 out on the clock or data lines
  ps2_clk  <= '0' when ps2_clk_en else  'Z';
  ps2_data <= '0' when ps2_data_en else 'Z';

  process (clk)
  begin
    if rising_edge(clk) then
      if tx_valid and tx_ready then
        tx_data_capt <= tx_data;
        tx_ready     <= '0';
      elsif tx_xmit then
        tx_ready <= '1';
      end if;
    end if;
  end process;

  process (clk)
    variable rx_compare : boolean;
  begin
    rx_compare := rx_data_r = rx_expect(start_count);
    if rising_edge(clk) then
      case start_state is
        when START_IDLE =>
          if rx_valid_r = '1' and rx_compare then
            start_state <= SEND_CMD;
          end if;
        when SEND_CMD =>
          send_set    <= '1';
          send_data   <= init_data(start_count);
          start_count <= start_count + 1;
          start_state <= START0;
        when START0 =>
          if clr_set then
            send_set    <= '0';
            start_state <= START1;
          end if;
        when START1 =>
          if rx_valid_r = '1' and rx_compare then
            if start_count = 10 then
              start_state <= START2;
            else
              start_state <= SEND_CMD;
            end if;
          end if;
        when others =>
      end case;
      if reset then start_state <= START_IDLE; end if;
    end if;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      ps2_clk_en         <= '0';
      ps2_data_en        <= '0';
      done               <= '0';
      err                <= '0';
      tx_xmit            <= '0';
      clr_set            <= '0';
      ps2_clk_clean_last <= ps2_clk_clean;

      case state is
        when IDLE =>
          -- Wait for a falling edge of the clock or we received
          -- a xmit request
          if counter_100us /= COUNT_100us then
            counter_100us <= counter_100us + 1;
            xmit_ready    <= '0';
          else
            xmit_ready    <= '1';
          end if;
          data_counter  <= 0;
          if not ps2_clk_clean and ps2_clk_clean_last then
            counter_100us <= 0;
            state         <= CLK_FALL0;
          elsif not tx_ready and xmit_ready then
            counter_100us <= 0;
            tx_data_out   <= '1' & xnor(tx_data) & tx_data & '0';
            state         <= XMIT0;
          elsif send_set and xmit_ready then
            clr_set       <= '1';
            counter_100us <= 0;
            tx_data_out   <= '1' & xnor(send_data) & send_data & '0';
            state         <= XMIT0;
          end if;
        when CLK_FALL0 =>
          -- capture data
          data_capture <= ps2_data_clean & data_capture(10 downto 1);
          data_counter <= data_counter + 1;
          state        <= CLK_FALL1;
        when  CLK_FALL1 =>
          -- Clock has gone low, wait for it to go high
          if ps2_clk_clean then
            state <= CLK_HIGH;
          end if;
        when CLK_HIGH =>
          if data_counter = 11 then
            counter_100us <= 0;
            done          <= '1';
            err           <= xnor(data_capture(9 downto 1));
            state         <= IDLE;
          elsif not ps2_clk_clean then
            state <= CLK_FALL0;
          end if;
        when XMIT0 =>
          clr_set           <= '1';
          ps2_clk_en        <= '1'; -- Drop the clock
          counter_100us     <= counter_100us + 1;
          if counter_100us = COUNT_100us then
            counter_100us   <= 0;
            state           <= XMIT1;
          end if;
        when XMIT1 =>
          ps2_data_en       <= not tx_data_out(data_counter);
          ps2_clk_en        <= '1'; -- Drop the clock
          counter_100us     <= counter_100us + 1;
          if counter_100us = COUNT_20us then
            counter_100us   <= 0;
            state           <= XMIT2;
          end if;
        when XMIT2 =>
          ps2_clk_en        <= '0'; -- Drop the clock
          ps2_data_en       <= not(tx_data_out(data_counter));
          if not ps2_clk_clean and ps2_clk_clean_last then
            data_counter <= data_counter + 1;
            if data_counter = 9 then
              state <= XMIT3;
            end if;
          end if;
        when XMIT3 =>
          if not ps2_clk_clean and ps2_clk_clean_last then
            state <= XMIT4;
          end if;
        when XMIT4 =>
          if not ps2_data_clean then
            state <= XMIT5;
          end if;
        when XMIT5 =>
          if not ps2_clk_clean then
            state <= XMIT6;
          end if;
        when XMIT6 =>
          if ps2_data_clean and ps2_clk_clean then
            state <= IDLE;
          end if;
        when others =>
      end case;
      if reset then
        state <= IDLE;
      end if;
    end if;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      rx_valid_r <= '0';
      case out_state is
        when OUT_IDLE =>
          if done and rx_ready then
            rx_data_r                <= data_capture(8 downto 1);
            rx_user_r                <= err; -- Error indicator
            rx_valid_r               <= '1';
            if not rx_ready then
              out_state <= OUT_WAIT;
            end if;
          end if;
        when OUT_WAIT =>
          if rx_ready then out_state <= OUT_IDLE; end if;
        when others =>
      end case;
      if reset then out_state <= OUT_IDLE; end if;
    end if;
  end process;
end architecture rtl;
