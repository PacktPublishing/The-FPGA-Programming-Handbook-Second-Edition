-- uart_cpu.vhd
-- ------------------------------------
-- UART CPU interface
-- ------------------------------------
-- Author : Frank Bruno
LIBRARY IEEE, XPM;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;
use IEEE.math_real.all;
use XPM.vcomponents.all;

entity uart_cpu is
  port (
    -- Utility signals
    sys_clk             : in std_logic; -- 100 Mhz for this example
    sys_rstn            : in std_logic; -- Active low reset
    baud_en             : in std_logic; -- Enable for the baud clock

    -- CPU interface
    cpu_int             : out std_logic; -- interrupt
    reg_awvalid         : in  std_logic;
    reg_awready         : out std_logic;
    reg_awaddr          : in  std_logic_vector(2 downto 0);

    reg_wvalid          : in  std_logic;
    reg_wready          : out std_logic;
    reg_wdata           : in  std_logic_vector(7 downto 0);

    reg_bready          : in  std_logic;
    reg_bvalid          : out std_logic;
    reg_bresp           : out std_logic_vector(1 downto 0);

    reg_arvalid         : in  std_logic;
    reg_arready         : out std_logic;
    reg_araddr          : in  std_logic_vector(2 downto 0);

    reg_rready          : in  std_logic;
    reg_rvalid          : out std_logic;
    reg_rdata           : out std_logic_vector(7 downto 0);
    reg_rresp           : out std_logic_vector(1 downto 0);

    -- Registers to design
    baud_terminal_count : out std_logic_vector(15 downto 0); -- Terminal count for baud en
    parity              : out std_logic_vector(2 downto 0); -- Parity setting
    force_rts           : out std_logic; -- Force RTS value for testing
    autoflow            : out std_logic; -- Generate RTS/ CTS automatically
    loopback            : out std_logic; -- Loopback for test
    baud_reset          : out std_logic; -- Reset baud rate counter

    -- RX interface
    rx_fifo_push        : in  std_logic; -- Push data from RX interface
    rx_fifo_din         : in  std_logic_vector(7 downto 0); -- Data from RX interface
    rx_break_det        : in  std_logic; -- Detect break (not implemented)
    rx_parity_err       : in  std_logic; -- Parity error flag on RX
    rx_frame_err        : in  std_logic; -- Stop bit not valid
    rx_fifo_full        : out std_logic; -- FIFO Full

    -- TX interface
    tx_fifo_pop         : in  std_logic; -- Pop TX data for sending
    tx_shift_empty      : in  std_logic; -- TX shift register is empty
    tx_data_avail       : out std_logic; -- ~tx_fifo_empty
    tx_fifo_dout        : out std_logic_vector(7 downto 0); -- Fifo data for TX

    -- External pins
    uart_cts            : in  std_logic); -- Clear to send
end entity uart_cpu;

architecture rtl of uart_cpu is
  attribute MARK_DEBUG : string;
  type reg_cs_t is (REG_IDLE, REG_W4ADDR, REG_W4DATA,
                    SM_BRESP, REG_W4RDREADY);
  signal reg_cs : reg_cs_t := REG_IDLE;
  attribute MARK_DEBUG of reg_cs : signal is "TRUE";
  -- mapped to 16550a registers
  constant RBR_THR  : std_logic_vector(3 downto 0) := x"0"; -- RX Register, TX Register - DLL LSB
  constant IER_IER  : std_logic_vector(3 downto 0) := x"1"; -- Interrupt Enable Register
  constant IIR_FCR0 : std_logic_vector(3 downto 0) := x"2"; -- interrupt ID register, FIFO control register
  constant LCR0     : std_logic_vector(3 downto 0) := x"3"; -- Line Control Register
  constant MCR0     : std_logic_vector(3 downto 0) := x"4"; -- Line Control Register
  constant LSR0     : std_logic_vector(3 downto 0) := x"5"; -- Line Status Register
  constant MSR0     : std_logic_vector(3 downto 0) := x"6"; -- Modem Status Register
  constant SCR0     : std_logic_vector(3 downto 0) := x"7"; -- Scratch register
  constant DLL      : std_logic_vector(3 downto 0) := x"8"; -- Divisor LSB
  constant DLM      : std_logic_vector(3 downto 0) := x"9"; -- Divisor MSB
  -- These registers set the baud rate:
  -- Baud    BAUDCNT_HI BAUDCNT_LO   %ERR
  -- 300     8'hB9      8'hFF      -0.006382%
  -- 1200    8'h2E      8'h7F      -0.006325%
  -- 2400    8'h17      8'h3F      -0.00625%
  -- 4800    8'h0B      8'h9F      -0.0061%
  -- 9600    8'h05      8'hCF      -0.0058%
  -- 14400   8'h03      8'hDF      -0.0055%
  -- 19200   8'h02      8'hE7      -0.0052%
  -- 28800   8'h01      8'hEF      -0.0046%
  -- 38400   8'h01      8'h73      -0.004%
  -- 57600   8'h00      8'hF7      -0.0028%
  constant IIR_FCR1 : std_logic_vector(3 downto 0) := x"A"; -- interrupt ID register, FIFO control register
  constant LCR1     : std_logic_vector(3 downto 0) := x"B"; -- Line Control Register
  constant MCR1     : std_logic_vector(3 downto 0) := x"C"; -- Modem Control Register
  constant LSR1     : std_logic_vector(3 downto 0) := x"D"; -- Line Status Register
  constant MSR1     : std_logic_vector(3 downto 0) := x"E"; -- Modem Status Register
  constant SCR1     : std_logic_vector(3 downto 0) := x"F"; -- Scratch register

  signal reg_addr   : std_logic_vector(2 downto 0);
  signal reg_we     : std_logic;
  signal reg_din    : std_logic_vector(7 downto 0);

  signal dlab          : std_logic := '0';                      -- register selector
  signal break_en      : std_logic := '0';                      -- Enable break
  signal fifo_enable   : std_logic := '1';                      -- Enable the FIFOs
  signal reset_rx_fifo : std_logic := '0';                      -- Reset RX FIFO
  signal reset_tx_fifo : std_logic := '0';                      -- Reset TX FIFO
  signal scratch_reg   : std_logic_vector(7 downto 0) := x"00"; -- For backward compatibility
  signal cts_change    : std_logic;                    -- CTS has changed
  signal cts_last      : std_logic;                    -- last CTS value

  signal rx_fifo_out   : std_logic_vector(7 downto 0);        -- Data from the FIFO
  signal rx_fifo_pop   : std_logic;        -- Pop data from the RX fifo
  signal rx_fifo_empty : std_logic;      -- FIFO empty
  signal rx_data_avail : std_logic;      -- ~fifo empty
  attribute MARK_DEBUG of rx_fifo_out   : signal is "TRUE";
  attribute MARK_DEBUG of rx_fifo_pop   : signal is "TRUE";
  attribute MARK_DEBUG of rx_fifo_empty : signal is "TRUE";
  attribute MARK_DEBUG of rx_data_avail : signal is "TRUE";
  signal rx_fifo_count : std_logic_vector(3 downto 0);      -- {full, count[2:0]}
  signal rx_thresh     : std_logic_vector(3 downto 0) := x"0"; -- Low watermark

  -- Interrupt enables
  signal en_rx_data_avail    : std_logic := '0';   -- ~fifo empty
  signal en_tx_fifo_empty    : std_logic := '0';   --
  signal en_rx_status_change : std_logic := '0';
  signal en_msr_change       : std_logic := '0';

  signal tx_fifo_empty       : std_logic;
  signal rx_status_change    : std_logic;
  signal msr_change          : std_logic;
  signal thr_empty           : std_logic := '0';
  signal tx_shift_empty_d    : std_logic;
  signal int_status          : std_logic_vector(2 downto 0);    -- For interrupt readback
  --Bits 1 and 2	Bit 2	Bit 1
  --0	0	Modem Status Interrupt (lowest)
  --0	1	Transmitter Holding Register Empty Interrupt
  --1	0	Received Data Available Interrupt
  --1	1	Receiver Line Status Interrupt (higest)
  signal char_timeout        : std_logic := '0'; -- fixme!!!
  signal frame_err           : std_logic;     -- Capture the framing error

  signal tx_fifo_push        : std_logic := '0';  -- Push data into TX FIFO
  signal tx_fifo_din         : std_logic_vector(7 downto 0);   -- Registered data into FIFO
  --

  signal break_det           : std_logic;     -- Break Interrupt
  signal overrun_error       : std_logic := '0'; -- write to full RX fifo
  signal parity_err          : std_logic;
  signal rx_fifo_error       : std_logic;
  signal parity_reg          : std_logic_vector(2 downto 0) := "000"; -- Parity setting
  signal autoflow_reg        : std_logic := '0'; -- Generate RTS/ CTS automatically
  signal loopback_reg        : std_logic := '0'; -- Loopback for test
  signal force_rts_reg       : std_logic := '0'; -- Force RTS value for testing
  signal baud_terminal_cnt   : std_logic_vector(15 downto 0) := x"00F7"; -- Terminal count for baud en
  signal rx_din              : std_logic_vector(10 downto 0);
  signal rx_dout             : std_logic_vector(10 downto 0);
  signal tx_din              : std_logic_vector(7 downto 0);
  signal tx_dout             : std_logic_vector(7 downto 0);
  signal wr_data_count       : std_logic_vector(4 downto 0);
  signal tx_fifo_full        : std_logic;
begin
  parity              <= parity_reg;
  autoflow            <= autoflow_reg;
  loopback            <= loopback_reg;
  force_rts           <= force_rts_reg;
  baud_terminal_count <= baud_terminal_cnt;
  reg_rresp           <= "00";

  process (sys_clk)
    variable rd_addr : std_logic_vector(3 downto 0);
    variable wr_valids : std_logic_vector(1 downto 0);
  begin

    if rising_edge(sys_clk) then
      rd_addr   := dlab & reg_araddr;
      wr_valids := reg_awvalid & reg_wvalid;
      -- defaults
      rx_fifo_pop   <= '0';
      reg_we        <= '0';
      reg_bvalid    <= '0';
      baud_reset    <= '0';

      -- Detect a change in CTS status
      cts_last      <= uart_cts;
      if baud_en and (cts_last xor uart_cts) then
        cts_change <= '1';
      end if;

      case reg_cs is
        when REG_IDLE =>
          reg_arready <= '1';
          reg_awready <= '1';
          reg_wready  <= '1';
          reg_rvalid  <= '0';
          if reg_arvalid then
            reg_rvalid  <= '1';
            if not reg_rready then
              reg_arready <= '0';
              reg_cs      <= REG_W4RDREADY;
            end if;

            -- Read bus
            case rd_addr is
              -- RX Buffer Register, TX Holding Register
              when RBR_THR =>
                reg_rdata     <= rx_fifo_out(7 downto 0);
                rx_fifo_pop   <= not rx_fifo_empty;
                if not reg_rready then
                  reg_arready <= '0';
                  reg_cs      <= REG_W4RDREADY;
                end if;
              when IER_IER =>
                reg_rdata <= x"0" & -- Don't support lp modes or sleep
                             en_rx_data_avail &
                             en_tx_fifo_empty &
                             en_rx_status_change &
                             en_msr_change;
              when IIR_FCR0 | IIR_FCR1 =>
                thr_empty      <= '0'; -- reset status bit
                reg_rdata(7 downto 6) <= fifo_enable & fifo_enable;
                reg_rdata(5 downto 4) <= "00";
                reg_rdata(3 downto 0) <= int_status & cpu_int;
              when LCR0 | LCR1 =>
                reg_rdata <= dlab &     -- 1 = select config registers, 0 = normal
                             break_en & -- Enable break signal (not currently used)
                             parity_reg &   /* Parity setting
                                             * [5:3]    Setting
                                             *  xx0     No Parity
                                             *  001     Odd Parity
                                             *  011     Even Parity
                                             *  101     High Parity (stick)
                                             *  111     Low Parity (stick)
                                             */
                            '0' &     -- Unused (not requested)
                            "00";    -- Unused since we are forcing 8 bit data
              when MCR0 | MCR1 =>
                reg_rdata <= "00" &           -- Reserved
                             autoflow_reg &   -- Generate RTS automatically
                             loopback_reg &   -- Loopback mode
                             "00" &           -- AUX unused
                             force_rts_reg &  -- RTS
                             '0';             -- DTR unused
              when LSR0 | LSR1 =>
                reg_rdata <= (rx_fifo_error and not rx_fifo_empty) & -- Error in Received FIFO (br, par, fr)
                             tx_shift_empty &                   -- Empty Data Holding Registers
                             tx_fifo_empty &                    -- Empty Transmitter Holding Register
                             (break_det  and not rx_fifo_empty) & -- Break Interrupt
                             (frame_err  and not rx_fifo_empty) & -- Framing Error
                             (parity_err and not rx_fifo_empty) & -- Parity Error
                             overrun_error &      -- Overrun Error
                             not rx_fifo_empty;   -- Data Ready
              when MSR0 | MSR1 =>
                cts_change <= '0';
                reg_rdata <= "000" &        -- Unused
                             uart_cts &     -- current Clear to send
                             "000" &
                             cts_change;    -- Change in CTS detected
              when SCR0 | SCR1 =>
                reg_rdata <= scratch_reg; -- Readback scratch
              when DLL =>
                reg_rdata  <= baud_terminal_cnt(7 downto 0);
                baud_reset <= '1';
              when DLM =>
                reg_rdata  <= baud_terminal_cnt(15 downto 8);
                baud_reset <= '1';
              when others => reg_rdata <= x"00"; -- Not necessary
            end case;

          else -- if (reg_arvalid)
            case wr_valids is
              when "11" =>
                reg_addr    <= reg_awaddr;
                reg_we      <= '1';
                reg_din     <= reg_wdata;
                -- Addr and data are available
                if reg_bready then
                  reg_awready <= '1';
                  reg_wready  <= '1';
                  reg_bvalid  <= '1';
                  reg_bresp   <= "00"; -- Okay
                else
                  reg_awready <= '0';
                  reg_wready  <= '0';
                  reg_cs      <= SM_BRESP;
                end if;
              when "10" =>
                -- Address only
                reg_awready <= '0';
                reg_addr    <= reg_awaddr;
                reg_cs      <= REG_W4DATA;
              when "01" =>
                reg_wready <= '0';
                reg_din    <= reg_wdata;
                reg_cs     <= REG_W4ADDR;
              when others =>
            end case;
          end if;
        when REG_W4DATA =>
          reg_we      <= '1';
          reg_din     <= reg_wdata;
          if reg_bready then
            reg_awready <= '1';
            reg_wready  <= '1';
            reg_bvalid  <= '1';
            reg_bresp   <= "00"; -- Okay
            reg_cs      <= REG_IDLE;
          else
            reg_awready <= '0';
            reg_wready  <= '0';
            reg_cs      <= SM_BRESP;
          end if;
        when REG_W4ADDR =>
          reg_addr    <= reg_awaddr;
          reg_we      <= '1';
          if reg_bready then
            reg_awready <= '1';
            reg_wready  <= '1';
            reg_bvalid  <= '1';
            reg_bresp   <= "00"; -- Okay
            reg_cs      <= REG_IDLE;
          else
            reg_awready <= '0';
            reg_wready  <= '0';
            reg_cs      <= SM_BRESP;
          end if;
        when SM_BRESP =>
          if reg_bready then
            reg_awready <= '1';
            reg_wready  <= '1';
            reg_bvalid  <= '1';
            reg_bresp   <= "00"; -- Okay
            reg_cs      <= REG_IDLE;
          else
            reg_awready <= '0';
            reg_wready  <= '0';
            reg_cs      <= SM_BRESP;
          end if;
        when REG_W4RDREADY =>
          if reg_rready then
            reg_arready <= '1';
            reg_cs      <= REG_IDLE;
          end if;
      end case;

      -- Reset clause
      if not sys_rstn then
        rx_fifo_pop         <= '0';
      end if;
    end if;
  end process;

  process (sys_clk)
    variable addr : std_logic_vector(3 downto 0);
  begin

    if rising_edge (sys_clk) then
      addr          := dlab & reg_addr;
      tx_fifo_push  <= '0';
      reset_rx_fifo <= '0';
      reset_tx_fifo <= '0';

      -- Detect overrun
      if rx_fifo_push and not rx_fifo_pop and rx_fifo_full then
        overrun_error <= '1';
      elsif not rx_fifo_full then
        overrun_error <= '0';
      end if;

      -- set int_status and cpu_int
      if en_rx_status_change and (overrun_error or
                                  (parity_err and not rx_fifo_empty) or
                                  (break_det and not rx_fifo_empty) or
                                  (frame_err and not rx_fifo_empty)) then
        int_status <= "011";
        cpu_int    <= '0';
      elsif en_rx_data_avail and rx_data_avail then
        -- This might be a cheat, but I didn't see the purpose of setting
        -- a threshold and going off even if 1 piece of data was in the FIFO
        -- I might have read the spec wrong. This is better anyways.
        int_status <= "010";
        cpu_int    <= '0';
      elsif char_timeout then
        -- fixme!!!!
        int_status <= "110";
        cpu_int    <= '0';
      elsif en_tx_fifo_empty and thr_empty then
        -- fixme, set a flag when go empty and clear when
        -- reading this
        int_status <= "001";
        cpu_int    <= '0';
      elsif en_msr_change and cts_change then
        int_status <= "000";
        cpu_int    <= '0';
      else
        cpu_int <= '1';
      end if;

      -- detect shift register going empty and set thr_empty
      tx_shift_empty_d <= tx_shift_empty;
      if tx_shift_empty and not tx_shift_empty_d and tx_fifo_empty then
        thr_empty <= '1';
      end if;

      if reg_we then
        case addr is
          when RBR_THR =>
            thr_empty <= '0';
            -- RX Buffer Register, TX Holding Register
            tx_fifo_push      <= '1';
            tx_fifo_din(7 downto 0)  <= reg_din;
          when IER_IER =>
            en_rx_data_avail    <= reg_din(3);
            en_tx_fifo_empty    <= reg_din(2);
            en_rx_status_change <= reg_din(1);
            en_msr_change       <= reg_din(0);
          when IIR_FCR0 | IIR_FCR1 =>
            -- FIFO control register
            fifo_enable   <= reg_din(0);
            if reg_din(1) then
              reset_rx_fifo <= '1';
            end if;
            if reg_din(2) then
              reset_tx_fifo <= '1';
            end if;
            -- reg_din[3] DMA mode, not supported currently
            -- reg_din[4] Reserved
            -- reg_din[5] Reserved
            -- Threshold set for RX. 1/2 the 16 FIFO of 16550
            case reg_din(7 downto 6) is
              when "00" => rx_thresh <= x"1";
              when "01" => rx_thresh <= x"2";
              when "10" => rx_thresh <= x"4";
              when "11" => rx_thresh <= x"7";
            end case; -- case (reg_din[7:6])
          when LCR0 | LCR1 =>
            dlab         <= reg_din(7); -- 1 = select config registers
            break_en     <= reg_din(6); -- (not currently used)
            parity_reg   <= reg_din(5 downto 3);   /* Parity setting
            * [5:3]    Setting
            *  xx0     No Parity
            *  001     Odd Parity
            *  010     Even Parity
            *  101     High Parity (stick)
            *  111     Low Parity (stick)
            */
          when MCR0 | MCR1 =>
            autoflow_reg  <= reg_din(5); -- Generate RTS automatically
            loopback_reg  <= reg_din(4); -- Loopback mode
            force_rts_reg <= reg_din(1); -- RTS
          when SCR0 | SCR1 =>
            scratch_reg <= reg_din; -- scratch register
          when DLL =>
            baud_terminal_cnt(7 downto 0)  <= reg_din;
          when DLM =>
            baud_terminal_cnt(15 downto 8) <= reg_din;
          when others =>
        end case;
      end if;

      -- Reset clause
      if not sys_rstn then
        thr_empty           <= '0';
        dlab                <= '0';
        break_en            <= '0';
        parity_reg          <= "000";
        autoflow_reg        <= '0';
        loopback_reg        <= '0';
        force_rts_reg       <= '0';
        fifo_enable         <= '1';
        reset_rx_fifo       <= '0';
        reset_tx_fifo       <= '0';
        rx_thresh           <= x"0"; --2'h1; -- Default to depth of 1 to signal data ready
        en_rx_data_avail    <= '0';
        en_tx_fifo_empty    <= '0';
        en_rx_status_change <= '0';
        en_msr_change       <= '0';
        tx_fifo_push        <= '0';
        overrun_error       <= '0';
        baud_terminal_cnt   <= x"00F7"; -- 57600
      end if;
    end if;
  end process;

  -- FIFO blocks
  -- These are synchronous due to the nature of the clocks. The presentation
  -- will go over asynchronous FIFOs
  -- Need to store:
  -- framing error
  -- parity error
  rx_din <= rx_break_det & rx_parity_err & rx_frame_err & rx_fifo_din;
  break_det <= rx_dout(10);
  parity_err <= rx_dout(9);
  frame_err <= rx_dout(8);
  rx_fifo_out <= rx_dout(7 downto 0);
  u_rx : xpm_fifo_sync
    generic map (
        FIFO_WRITE_DEPTH => 16,
        WRITE_DATA_WIDTH => 11,
        READ_DATA_WIDTH  => 11,
        WR_DATA_COUNT_WIDTH => 5,
        READ_MODE        => "fwft")
    port map    (
        -- Common module ports
        sleep            => '0',
        rst              => reset_rx_fifo,

        -- Write Domain ports
        wr_clk           => sys_clk,
        wr_en            => rx_fifo_push,
        din              => rx_break_det & rx_parity_err & rx_frame_err & rx_fifo_din,
        full             => rx_fifo_full,
        wr_data_count    => wr_data_count,

        -- Read Domain ports
        rd_en            => rx_fifo_pop,
        dout             => rx_dout,
        empty            => rx_fifo_empty,

        injectsbiterr    => '0',
        injectdbiterr    => '0');

  process (all) begin
    if wr_data_count > '0' & rx_thresh then
      rx_data_avail <= '1';
    else
      rx_data_avail <= '0';
    end if;
  end process;

  rx_fifo_error <= break_det or  parity_err or frame_err;

  u_tx : xpm_fifo_sync
    generic map (
      FIFO_WRITE_DEPTH => 16,
      WRITE_DATA_WIDTH => 8,
      READ_DATA_WIDTH  => 8,
      READ_MODE        => "fwft")
    port map    (
      -- Common module ports
      sleep            => '0',
      rst              => reset_tx_fifo,

     -- Write Domain ports
      wr_clk           => sys_clk,
      wr_en            => tx_fifo_push,
      din              => tx_fifo_din,
      full             => tx_fifo_full,

      -- Read Domain ports
      rd_en            => tx_fifo_pop,
      dout             => tx_fifo_dout,
      empty            => tx_fifo_empty,
      injectsbiterr    => '0',
      injectdbiterr    => '0');

  tx_data_avail <= not tx_fifo_empty;

end architecture rtl;
