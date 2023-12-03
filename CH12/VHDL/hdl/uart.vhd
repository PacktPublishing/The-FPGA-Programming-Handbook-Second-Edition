-- uart.vhd
-- ------------------------------------
-- Top level of the UART
-- ------------------------------------
-- Author : Frank Bruno
LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;
use IEEE.math_real.all;

LIBRARY XPM;
use XPM.vcomponents.all;

entity uart is
  port (
    -- Utility signals
   sys_clk : in std_logic; -- 100 Mhz for this example
   sys_rstn : in std_logic; -- Active low reset

   -- CPU interface
   cpu_int : out std_logic; -- interrupt
   reg_awvalid : in std_logic;
   reg_awready : out std_logic;
   reg_awaddr : in std_logic_vector(2 downto 0);

   reg_wvalid : in std_logic;
   reg_wready : out std_logic;
   reg_wdata : in std_logic_vector(7 downto 0);

   reg_bready : in std_logic;
   reg_bvalid : out std_logic;
   reg_bresp : out std_logic_vector(1 downto 0);

   reg_arvalid : in std_logic;
   reg_arready : out std_logic;
   reg_araddr : in std_logic_vector(2 downto 0);

   reg_rready : in std_logic;
   reg_rvalid : out std_logic;
   reg_rdata : out std_logic_vector(7 downto 0);
   reg_rresp : out std_logic_vector(1 downto 0);

   -- External pins
   uart_ctsn : in std_logic; -- Clear to send
   uart_rx : in std_logic; -- RX pin
   uart_rtsn : out std_logic; -- Request to send
   uart_tx : out std_logic);   -- TX pin
end entity uart;

architecture rtl of uart is
  -- Types
  type tx_t is (TX_IDLE, TX_START, TX_WAIT, TX_TX);
  type rx_t is (RX_IDLE, RX_START, RX_SHIFT, RX_PUSH);

  -- Registered signals with initial values
  signal rx_sm          : rx_t                     := RX_IDLE;
  signal tx_sm          : tx_t                     := TX_IDLE;
  signal tx_clken_count : integer range 0 to 2**16 := 0;   -- Counter to generate the clock enables
  signal rx_clken_count : integer range 0 to 2**16 := 0;   -- Counter to generate the clock enables
  signal tx_baudclk_en  : std_logic                := '0'; -- Enable to simulate the baud clock
  signal rx_baudclk_en  : std_logic                := '0'; -- Enable to simulate the baud clock
  signal tx_clk_cnt     : integer range 0 to 7     := 0;   -- Track # of sub baud clocks
  signal tx_data_cnt    : integer range 0 to 15    := 0;   -- Data Counter
  signal rx_clk_cnt     : integer range 0 to 7     := 0;   -- Track # of sub baud clocks
  signal rx_data_cnt    : integer range 0 to 15    := 0;   -- Data Counter
  signal rx_data_shift  : std_logic_vector(6 downto 0)  := (others => '0'); -- Shift 7 pieces of data for voting
  signal tx_fifo_pop    : std_logic                     := '0'; -- Pop TX data
  signal tx_shift       : std_logic_vector(10 downto 0) := (others => '0');  -- TX shift register
  signal rx_shifter     : std_logic_vector(10 downto 0) := (others => '0');  -- TX shift register
  signal rx_parity_err  : std_logic                     := '0'; -- Parity Errror on Receive
  signal tx_rtsn        : std_logic                     := '0'; -- Generate the RTSn for tx
  signal uart_rxd       : std_logic_vector(6 downto 0)  := (others => '0');      -- delayed RX data
  signal rx_frame_err   : std_logic                     := '0'; -- Framing error (missing stop bit)
  signal rx_fifo_push   : std_logic                     := '0'; -- Piush receive data into FIFO
  signal rx_fifo_din    : std_logic_vector(7 downto 0)  := (others => '0');   -- RX data into receive FIFO
  signal vote_bit       : std_logic                     := '0'; -- Vote on the current bit
  signal voted          : std_logic                     := '0'; -- for testing to see if we have mismatch
  signal tx_shift_empty : std_logic                     := '0'; -- TX shift register empty for status
  signal enable_tx      : std_logic                     := '0'; -- Force a '1' or break when not enabled
  signal int_rx         : std_logic                     := '0';
  signal rx_baud_reset  : std_logic                     := '0'; -- Reset RX baud clock to resync
  signal tx_ctsn        : std_logic                     := '0';

  -- Unregistered signals
  signal tx_data_avail  : std_logic; -- Transmit data is available
  signal tx_fifo_dout   : std_logic_vector(7 downto 0);  -- Data for TX
  signal parity         : std_logic_vector(2 downto 0);        -- Parity selection
  signal force_rts      : std_logic;     --
  signal autoflow       : std_logic;      -- Automatically generate flow control
  signal loopback       : std_logic;      -- Loopback mode
  signal rx_fifo_full   : std_logic;  -- We can't accept RX
  signal baud_terminal_count : std_logic_vector(15 downto 0);
  signal baud_reset : std_logic;    -- When terminal count values change, reset count

  -- Attributes
  attribute MARK_DEBUG : string;
  attribute MARK_DEBUG of rx_sm : signal is "TRUE";
  attribute MARK_DEBUG of rx_clken_count : signal is "TRUE";
  attribute MARK_DEBUG of rx_baudclk_en : signal is "TRUE";
  attribute MARK_DEBUG of rx_clk_cnt : signal is "TRUE";
  attribute MARK_DEBUG of rx_data_cnt : signal is "TRUE";
  attribute MARK_DEBUG of rx_data_shift : signal is "TRUE";
  attribute MARK_DEBUG of uart_rxd : signal is "TRUE";
  attribute MARK_DEBUG of rx_shifter : signal is "TRUE";
  attribute MARK_DEBUG of rx_fifo_push : signal is "TRUE";
  attribute MARK_DEBUG of rx_fifo_din : signal is "TRUE";
  attribute MARK_DEBUG of baud_terminal_count : signal is "TRUE";
  attribute MARK_DEBUG of rx_baud_reset : signal is "TRUE";

begin

  process (sys_clk)
  begin
    if rising_edge(sys_clk) then
      tx_baudclk_en <= '0';
      rx_baudclk_en <= '0';

      if tx_clken_count = to_integer(unsigned('0' & baud_terminal_count(15 downto 1))) then
        tx_baudclk_en  <= '1';
        tx_clken_count <= 0;
      else
        tx_clken_count <= tx_clken_count + 1;
      end if;

      if rx_clken_count = to_integer(unsigned('0' & baud_terminal_count(15 downto 2))) then
        rx_baudclk_en  <= '1';
        rx_clken_count <= rx_clken_count + 1;
      elsif rx_clken_count = to_integer(unsigned('0' & baud_terminal_count(15 downto 1))) then
        rx_clken_count <= 0;
      else
        rx_clken_count <= rx_clken_count + 1;
      end if;

      -- Synchronous reset
      -- Asynchronous resets with large fanouts can cause the use of clock
      -- trees in FPGAs.
      -- Putting the reset clause at the top for a synchronous reset can
      -- Cause hold logic to be implemented during reset for signals not in
      -- the clause. Puttinf the clause below means we only need to reset
      -- essential signals.
      if not sys_rstn or baud_reset then
        tx_clken_count <= 0;
        tx_baudclk_en  <= '0';
      end if;
      if not sys_rstn or baud_reset or rx_baud_reset then
        rx_clken_count <= 0;
        rx_baudclk_en  <= '0';
      end if;
    end if;
  end process;

  u_cpu : entity work.uart_cpu
  port map
    (
     -- Utility signals
     sys_clk             => sys_clk,
     sys_rstn            => sys_rstn,
     baud_en             => tx_baudclk_en,

     -- CPU interface
     cpu_int             => cpu_int,
     reg_awvalid         => reg_awvalid,
     reg_awready         => reg_awready,
     reg_awaddr          => reg_awaddr,

     reg_wvalid          => reg_wvalid,
     reg_wready          => reg_wready,
     reg_wdata           => reg_wdata,

     reg_bready          => reg_bready,
     reg_bvalid          => reg_bvalid,
     reg_bresp           => reg_bresp,

     reg_arvalid         => reg_arvalid,
     reg_arready         => reg_arready,
     reg_araddr          => reg_araddr,

     reg_rready          => reg_rready,
     reg_rvalid          => reg_rvalid,
     reg_rdata           => reg_rdata,
     reg_rresp           => reg_rresp,

     -- Registers to design
     baud_terminal_count => baud_terminal_count,
     baud_reset          => baud_reset,
     rx_break_det        => '0', -- fixme!
     parity              => parity,
     force_rts           => force_rts,
     autoflow            => autoflow,
     loopback            => loopback,

     -- RX interface
     rx_fifo_push        => rx_fifo_push,
     rx_fifo_din         => rx_fifo_din,
     rx_parity_err       => rx_parity_err,
     rx_frame_err        => rx_frame_err,
     rx_fifo_full        => rx_fifo_full,

     -- TX interface
     tx_fifo_pop         => tx_fifo_pop,
     tx_shift_empty      => tx_shift_empty,
     tx_data_avail       => tx_data_avail,
     tx_fifo_dout        => tx_fifo_dout,

     -- External pins
     uart_cts            => uart_ctsn); -- polarity doesn't matter. for change

  -- Request to send
  process (all)
  begin
    -- From what I found, it seems the original RTS/CTS only protected the
    -- TX direction.
    --if autoflow then
    --  uart_rtsn <= tx_rtsn;
    --else
    --  uart_rtsn <= !force_rts;
    --end if;
    -- I found information on using RTS to mean "do not send to me"
    if autoflow then
      uart_rtsn <= rx_fifo_full;
    else
      uart_rtsn <= not force_rts;
    end if;
  end process;

  -- Fixme!!!! do we need to handle this differently for each RTS type?
  process (all)
  begin
    if loopback then
      tx_ctsn <= uart_rtsn; -- pass in the ctsn
      int_rx  <= uart_tx;
    else
      tx_ctsn <= uart_ctsn; -- pass in the ctsn
      int_rx  <= uart_rx;
    end if;
  end process;

  -- Fixme!!!! Do we add break?
  process (all)
  begin
    if enable_tx then
      uart_tx <= tx_shift(0);
    else
      uart_tx <= '1';
    end if;
  end process;

  process (all)
  begin
    case rx_data_shift(4 downto 2) is
      when "000" => vote_bit <= '0';
      when "001" => vote_bit <= '0';
      when "010" => vote_bit <= '0';
      when "011" => vote_bit <= '1';
      when "100" => vote_bit <= '0';
      when "101" => vote_bit <= '1';
      when "110" => vote_bit <= '1';
      when "111" => vote_bit <= '1';
    end case; -- case (rx_data_shift[4:2])
  end process;

      -- UART Data State Machines
  process (sys_clk)
  begin
    if rising_edge (sys_clk) then
      enable_tx   <= '0';
      tx_fifo_pop <= '0';
      case tx_sm is
        when TX_IDLE =>
          tx_shift_empty <= '1';
          tx_rtsn        <= '1'; -- default to no TX
          if tx_data_avail then
            tx_sm       <= TX_START;
            tx_fifo_pop <= '1';
          end if;
        when TX_START =>
          tx_shift_empty <= '0';
          if not parity(0) then
            tx_shift <= "11" & tx_fifo_dout & '0'; -- No parity
          else
            case parity(2 downto 1) is
              when "00" => tx_shift <= '1' & xnor(tx_fifo_dout) & tx_fifo_dout & '0'; -- Odd parity
              when "01" => tx_shift <= '1' & xor(tx_fifo_dout) & tx_fifo_dout & '0'; -- Even parity
              when "10" => tx_shift <= "11" & tx_fifo_dout & '0'; -- Force 1 parity
              when "11" => tx_shift <= "10" & tx_fifo_dout & '0'; -- Force 0 parity
            end case; -- casex (parity)
          end if;
          tx_clk_cnt  <= 0;
          tx_data_cnt <= 0;
          tx_rtsn     <= '0';
          tx_sm       <= TX_WAIT;
        when TX_WAIT =>
          if tx_baudclk_en and not tx_ctsn then
            enable_tx <= '1';
            tx_sm     <= TX_TX;
          end if;
        when TX_TX =>
          enable_tx <= '1';
          if tx_baudclk_en then
            tx_clk_cnt <= tx_clk_cnt + 1; -- count to 7
            if tx_clk_cnt = 6 then
              tx_clk_cnt  <= 0;
              if (parity(0) = '1' and (tx_data_cnt /= 10)) or
                 (parity(0) = '0' and (tx_data_cnt /= 9)) then
                tx_data_cnt <= tx_data_cnt + 1;
                tx_shift    <= tx_shift srl 1;
              else
                tx_data_cnt <= 0;
                tx_sm       <= TX_IDLE;
              end if;
            end if;
          end if;
      end case;

      -- Provide some noise rejection and
      uart_rxd <= uart_rxd(5 downto 0) & int_rx; -- Delay to look for start bit
      rx_fifo_push <= '0';
      rx_baud_reset <= '0';

      case rx_sm is
        when RX_IDLE =>
          rx_clk_cnt  <= 0;
          rx_data_cnt <= 0;
          -- Constantly watch for Start transition
          if uart_rxd = "1000000" then
            rx_baud_reset <= '1';
            rx_data_shift <= rx_data_shift(5 downto 0) & '0';
            rx_sm         <= RX_START;
          end if;
        when RX_START =>
          -- Verify we really detected a start bit
          if rx_baudclk_en then
            -- Take shifted data since clock is offset by this amount
            rx_data_shift <= rx_data_shift(5 downto 0) & uart_rxd(6);
            rx_clk_cnt    <= rx_clk_cnt + 1;
            if rx_clk_cnt = 4 then
              voted <= not(and(rx_data_shift(4 downto 2)) or nor(rx_data_shift(4 downto 2)));
              rx_shifter(rx_data_cnt) <= vote_bit;
              if not vote_bit then
                -- We did get a stop bit
                rx_data_cnt <= rx_data_cnt + 1;
                rx_sm <= RX_SHIFT;
              else
                -- We had a false detect, go back to idle
                rx_sm <= RX_IDLE;
              end if;
            end if;
          end if;
        when RX_SHIFT =>
          -- Bail out after the stop bit captured
          if (parity(0) = '1' and (rx_data_cnt = 11)) or (parity(0) = '0' and (rx_data_cnt = 10)) then
            -- Vote and push into storage register
            rx_data_shift <= rx_data_shift(5 downto 0) & uart_rxd(6);
            rx_clk_cnt    <= rx_clk_cnt + 1;
            rx_data_cnt   <= 0;
            rx_sm         <= RX_PUSH;
          end if;
          if rx_baudclk_en then
            -- Take shifted data since clock is offset by this amount
            rx_data_shift <= rx_data_shift(5 downto 0) & uart_rxd(6);
            rx_clk_cnt    <= rx_clk_cnt + 1;
            if rx_clk_cnt = 4 then
              voted <= not(and(rx_data_shift(4 downto 2) or nor(rx_data_shift(4 downto 2))));
              rx_shifter(rx_data_cnt) <= vote_bit;
              -- Bail out after the stop bit captured
              if (parity(0) = '1' and (rx_data_cnt /= 11)) or (parity(0) = '0' and (rx_data_cnt /= 10)) then
                rx_data_cnt <= rx_data_cnt + 1;
              else
                -- Vote and push into storage register
                rx_data_cnt <= 0;
                rx_sm       <= RX_PUSH;
              end if;
            elsif rx_clk_cnt = 6 then
              rx_clk_cnt  <= 0;
            end if;
          end if;
        when RX_PUSH =>
          -- Done w/ receive, push data into the RX fifo, detect error
          -- conditions
          rx_fifo_din <= rx_shifter(8 downto 1);
          if not parity(0) then
            rx_frame_err <= not rx_shifter(9);
          else
            rx_frame_err <= not rx_shifter(10);
          end if;

          if not parity(0) then
            rx_parity_err <= '0'; -- No parity, no error
          else
            case parity(2 downto 1) is
              when "00" => rx_parity_err <= xnor(rx_shifter(9 downto 1)); -- Odd Parity
              when "01" => rx_parity_err <= xor(rx_shifter(9 downto 1)); -- Even Parity
              when "10" => rx_parity_err <= xnor(rx_shifter(9 downto 1)); -- Force 1 Parity
              when "11" => rx_parity_err <= xnor(rx_shifter(9 downto 1)); -- Force 0 Parity
            end case; -- casex (parity)
          end if;
          rx_fifo_push <= '1';
          rx_sm        <= RX_IDLE;
      end case;

      if not sys_rstn then
        tx_sm        <= TX_IDLE;
        rx_sm        <= RX_IDLE;
        tx_fifo_pop  <= '0';
        enable_tx    <= '0';
        rx_fifo_push <= '0';
        rx_baud_reset<= '0';
      end if;
    end if;
  end process;
end architecture rtl;
