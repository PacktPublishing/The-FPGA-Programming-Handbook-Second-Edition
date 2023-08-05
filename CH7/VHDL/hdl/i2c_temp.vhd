-- i2c_temp.vhd
-- ------------------------------------
-- I2C temperature sensor interface
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- This module uses the I2C temperature sensor on the board to read and display the temperature.

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;
use IEEE.math_real.all;

library xpm;
use xpm.vcomponents.all;

use work.temp_pkg.all;
use work.counting_buttons_pkg.all;
use work.util_pkg.all;

entity i2c_temp is
  generic(
    SMOOTHING    : integer := 16;       -- must be a power of two
    INTERVAL     : integer := 1000000000; -- ns
    NUM_SEGMENTS : integer := 8;
    CLK_PER      : integer := 10        -- ns
  );
  port(
    clk     : in    std_logic;          -- 100 MHz clock
    -- Temperature Sensor Interface
    TMP_SCL : inout std_logic;
    TMP_SDA : inout std_logic;
    TMP_INT : inout std_logic;
    TMP_CT  : inout std_logic;
    -- Switch Interface
    SW      : in    std_logic;
    -- LED Interface
    LED     : out   std_logic;
    -- 7 segment display
    anode   : out   std_logic_vector(NUM_SEGMENTS - 1 downto 0);
    cathode : out   std_logic_vector(7 downto 0)
  );
end entity i2c_temp;

architecture rtl of i2c_temp is

  -- Types
  type spi_t is (IDLE, START, TLOW, TSU, THIGH, THD, TSTO);
  type slv16_array_t is array (0 to 15) of std_logic_vector(15 downto 0);

  -- Constants
  constant TIME_1SEC   : integer          := INTERVAL / CLK_PER; -- Clock ticks in 1 sec
  constant TIME_THDSTA : integer          := 600 / CLK_PER;
  constant TIME_TSUSTA : integer          := 600 / CLK_PER;
  constant TIME_THIGH  : integer          := 600 / CLK_PER;
  constant TIME_TLOW   : integer          := 1300 / CLK_PER;
  constant TIME_TSUSTO : integer          := 600 / CLK_PER;
  constant TIME_THDDAT : integer          := 30 / CLK_PER;
  constant I2C_ADDR    : std_logic_vector := "1001011"; -- 0x4B
  constant I2CBITS     : integer          := 1 + -- start
                                             7 + -- 7 bits for address
                                             1 + -- 1 bit for read
                                             1 + -- 1 bit for ack back
                                             8 + -- 8 bits upper data
                                             1 + -- 1 bit for ack
                                             8 + -- 8 bits lower data
                                             1 + -- 1 bit for ack
                                             1; -- 1 bit for stop

  -- Celsius to Farenheit conversion factor (9/5), in Q1.16 format
  constant NINE_FIFTHS : std_logic_vector(16 downto 0) := "11100110011001100";

  constant FRACTION_TABLE : slv16_array_t := (
    0  => std_logic_vector(to_unsigned(0 * 625, 16)),
    1  => std_logic_vector(to_unsigned(1 * 625, 16)),
    2  => std_logic_vector(to_unsigned(2 * 625, 16)),
    3  => std_logic_vector(to_unsigned(3 * 625, 16)),
    4  => std_logic_vector(to_unsigned(4 * 625, 16)),
    5  => std_logic_vector(to_unsigned(5 * 625, 16)),
    6  => std_logic_vector(to_unsigned(6 * 625, 16)),
    7  => std_logic_vector(to_unsigned(7 * 625, 16)),
    8  => std_logic_vector(to_unsigned(8 * 625, 16)),
    9  => std_logic_vector(to_unsigned(9 * 625, 16)),
    10 => std_logic_vector(to_unsigned(10 * 625, 16)),
    11 => std_logic_vector(to_unsigned(11 * 625, 16)),
    12 => std_logic_vector(to_unsigned(12 * 625, 16)),
    13 => std_logic_vector(to_unsigned(13 * 625, 16)),
    14 => std_logic_vector(to_unsigned(14 * 625, 16)),
    15 => std_logic_vector(to_unsigned(15 * 625, 16))
  );

  -- Divisor reciprocals, in Q1.16 format
  constant DIVIDE : array_t(16 downto 0)(16 downto 0) := (
    0  => "10000000000000000",          -- 1
    1  => "01000000000000000",          -- 1/2
    2  => "00101010101010101",          -- 1/3
    3  => "00100000000000000",          -- 1/4
    4  => "00011001100110011",          -- 1/5
    5  => "00010101010101010",          -- 1/6
    6  => "00010010010010010",          -- 1/7
    7  => "00010000000000000",          -- 1/8
    8  => "00001110001110001",          -- 1/9
    9  => "00001100110011001",          -- 1/10
    10 => "00001011101000101",          -- 1/11
    11 => "00001010101010101",          -- 1/12
    12 => "00001001110110001",          -- 1/13
    13 => "00001001001001001",          -- 1/14
    14 => "00001000100010001",          -- 1/15
    15 => "00001000000000000",          -- 1/16
    16 => "00001000000000000"           -- 1/16
  );

  -- Registered signals with initial values
  signal encoded        : array_t(NUM_SEGMENTS - 1 downto 0)(3 downto 0) := (others => (others => '0'));
  signal encoded_int    : array_t(NUM_SEGMENTS - 1 downto 0)(3 downto 0) := (others => (others => '0'));
  signal encoded_frac   : array_t(NUM_SEGMENTS - 1 downto 0)(3 downto 0) := (others => (others => '0'));
  signal digit_point    : std_logic_vector(NUM_SEGMENTS - 1 downto 0)    := (others => '0');
  signal sda_en         : std_logic                                      := '0';
  signal scl_en         : std_logic                                      := '0';
  signal i2c_data       : std_logic_vector(I2CBITS - 1 downto 0)         := (others => '0');
  signal i2c_en         : std_logic_vector(I2CBITS - 1 downto 0)         := (others => '0');
  signal i2c_capt       : std_logic_vector(I2CBITS - 1 downto 0)         := (others => '0');
  signal counter        : integer range 0 to TIME_1SEC                   := 0;
  signal counter_reset  : std_logic                                      := '0';
  signal bit_count      : integer range 0 to I2CBITS                     := 0;
  signal temp_data      : std_logic_vector(15 downto 0)                  := (others => '0');
  signal convert        : std_logic                                      := '0';
  signal i2c_state      : spi_t                                          := IDLE;
  signal smooth_data    : unsigned(28 downto 0)                          := (others => '0');
  signal smooth_convert : std_logic                                      := '0';
  signal smooth_count   : integer range 0 to SMOOTHING + 1               := 0;
  signal sample_count   : integer range 0 to 32                          := 0;
  signal rden           : std_logic                                      := '0';
  signal accumulator    : unsigned(17 downto 0)                          := (others => '0');
  signal convert_pipe   : std_logic_vector(4 downto 0)                   := (others => '0');

  -- Unregistered signals
  signal capture_en : std_logic;
  signal dout       : std_logic_vector(12 downto 0);
  signal bit_index  : natural range 0 to I2CBITS - 1;

  attribute MARK_DEBUG : string;
  attribute MARK_DEBUG of sda_en, scl_en : signal is "TRUE";
  attribute MARK_DEBUG of counter : signal is "TRUE";
  attribute MARK_DEBUG of bit_count : signal is "TRUE";
  attribute MARK_DEBUG of temp_data : signal is "TRUE";
  attribute MARK_DEBUG of capture_en : signal is "TRUE";
  attribute MARK_DEBUG of convert : signal is "TRUE";
  attribute MARK_DEBUG of i2c_state : signal is "TRUE";

begin

  LED <= SW;
  u_seven_segment : entity work.seven_segment
    generic map(
      NUM_SEGMENTS => NUM_SEGMENTS,
      CLK_PER      => CLK_PER,
      REFR_RATE    => 1000
    )
    port map(
      clk         => clk,
      reset       => '0',
      encoded     => encoded,
      digit_point => not digit_point,
      anode       => anode,
      cathode     => cathode
    );

  TMP_SCL <= 'Z' when scl_en else '0';
  TMP_SDA <= 'Z' when sda_en else '0';

  bit_index  <= 0 when (bit_count = I2CBITS) else I2CBITS - bit_count - 1;
  capture_en <= i2c_capt(bit_index);

  fsm : process(clk)
  begin
    if rising_edge(clk) then
      scl_en        <= '1';
      sda_en        <= (not i2c_en(bit_index)) or i2c_data(bit_index);
      if counter_reset then
        counter <= 0;
      else
        counter <= counter + 1;
      end if;
      counter_reset <= '0';
      convert       <= '0';

      case i2c_state is
        when IDLE =>
          i2c_data  <= '0' & I2C_ADDR & '1' & '0' & "00000000" & '0' & "00000000" & '1' & '0';
          i2c_en    <= '1' & "1111111" & '1' & '0' & "00000000" & '1' & "00000000" & '1' & '1';
          i2c_capt  <= '0' & "0000000" & '0' & '0' & "11111111" & '0' & "11111111" & '0' & '0';
          bit_count <= 0;
          sda_en    <= '1';             -- Force to 1 in the beginning.

          if counter = TIME_1SEC - 1 then
            temp_data     <= (others => '0');
            i2c_state     <= START;
            counter_reset <= '1';
            sda_en        <= '0';       -- Drop the data
          end if;

        when START =>
          sda_en <= '0';                -- Drop the data
          -- Hold clock low for thd:sta
          if counter = TIME_THDSTA then
            counter_reset <= '1';
            scl_en        <= '0';       -- Drop the clock
            i2c_state     <= TLOW;
          end if;

        when TLOW =>
          scl_en <= '0';                -- Drop the clock
          if counter = TIME_TLOW then
            bit_count     <= bit_count + 1;
            counter_reset <= '1';
            i2c_state     <= TSU;
          end if;

        when TSU =>
          scl_en <= '0';                -- Drop the clock
          if counter = TIME_TSUSTA then
            counter_reset <= '1';
            i2c_state     <= THIGH;
          end if;

        when THIGH =>
          scl_en <= '1';                -- Raise the clock
          if counter = TIME_THIGH then
            if capture_en then
              temp_data <= temp_data(14 downto 0) & to_01(TMP_SDA);
            end if;
            counter_reset <= '1';
            i2c_state     <= THD;
          end if;

        when THD =>
          if bit_count = I2CBITS - 1 then
            scl_en <= '1';              -- Keep the clock high
          else
            scl_en <= '0';              -- Drop the clock
          end if;
          if counter = TIME_THDDAT then
            counter_reset <= '1';
            if bit_count = I2CBITS - 1 then
              i2c_state <= TSTO;
            else
              i2c_state <= TLOW;
            end if;
          end if;

        when TSTO =>
          if counter = TIME_TSUSTO then
            convert       <= '1';
            counter_reset <= '1';
            i2c_state     <= IDLE;
          end if;
      end case;
    end if;
  end process;

  g_SMOOTHING : if SMOOTHING = 0 generate

    smooth_data    <= resize(unsigned(temp_data(temp_data'high downto 3)) & 3d"0", smooth_data'length);
    smooth_convert <= convert;

  else generate
    /*
    process(clk)
    begin
      if rising_edge(clk) then
        rden           <= '0';
        smooth_convert <= '0';
        convert_pipe   <= convert_pipe sll 1;
        if convert then
          convert_pipe(0) <= '1';
          smooth_count    <= smooth_count + 1;
          accumulator     <= accumulator + (unsigned(temp_data(temp_data'high downto 3)) & 3d"0");
        elsif smooth_count = SMOOTHING + 1 then
          rden         <= '1';
          smooth_count <= smooth_count - 1;
          accumulator  <= accumulator - unsigned(dout);
        elsif convert_pipe(2) then
          if sample_count < SMOOTHING then
            sample_count <= sample_count + 1;
          end if;
          smooth_data <= resize(accumulator * unsigned(DIVIDE(sample_count)), smooth_data'length);
        elsif convert_pipe(3) then
          smooth_convert <= '1';
          smooth_data    <= shift_right(smooth_data, 16);
        end if;
      end if;
    end process;
    */

    smooth : process(clk)
      variable data_mult_u46_q20 : unsigned(45 downto 0);
      variable data_shift_u30_q4 : unsigned(29 downto 0);
      variable data_add_u30_q4   : unsigned(29 downto 0);
    begin
      if rising_edge(clk) then
        rden           <= '0';
        smooth_convert <= '0';
        convert_pipe   <= convert_pipe(3 downto 0) & '0';
        if convert then
          convert_pipe(0) <= '1';
          smooth_count    <= smooth_count + 1;
          accumulator     <= accumulator + unsigned(temp_data(temp_data'high downto 3));
        elsif smooth_count = SMOOTHING + 1 then
          rden         <= '1';
          smooth_count <= smooth_count - 1;
          accumulator  <= accumulator - unsigned(dout);
        elsif convert_pipe(2) then
          if sample_count < SMOOTHING then
            sample_count <= sample_count + 1;
          end if;
          smooth_data <= resize(accumulator * unsigned(DIVIDE(sample_count)), smooth_data'length);
        elsif convert_pipe(3) then
          -- If SW is not set, output the temperature in degrees Celsius
          smooth_convert <= not SW;
          smooth_data    <= shift_right(smooth_data, 16)(smooth_data'range);
        elsif convert_pipe(4) then
          -- If SW is set, output the temperature in degrees Farenheit
          -- °F = (°C * 9/5) + 32
          smooth_convert    <= SW;
          data_mult_u46_q20 := smooth_data * unsigned(NINE_FIFTHS);
          data_shift_u30_q4 := resize(shift_right(unsigned(data_mult_u46_q20), 16), data_mult_u46_q20'length - 16);
          data_add_u30_q4   := data_shift_u30_q4 + 32 * 16;
          smooth_data       <= resize(data_add_u30_q4, smooth_data'length);
        end if;
      end if;
    end process;

    u_xpm_fifo_sync : xpm_fifo_sync
      generic map(
        FIFO_WRITE_DEPTH => 2 ** clog2(SMOOTHING + 1), -- must be a power of two
        WRITE_DATA_WIDTH => 13,
        READ_DATA_WIDTH  => 13,
        READ_MODE        => "FWFT"
      )
      port map(
        sleep         => '0',
        rst           => '0',
        wr_clk        => clk,
        wr_en         => convert,
        din           => temp_data(temp_data'high downto 3),
        rd_en         => rden,
        dout          => dout,
        injectsbiterr => '0',
        injectdbiterr => '0'
      );
  end generate;

  -- Convert temperature from binary to BCD
  process(clk)
    variable sd_int : integer range 0 to 15;
  begin
    if rising_edge(clk) then
      if smooth_convert then
        encoded_int  <= bin_to_bcd(std_logic_vector(23d"0" & smooth_data(15 downto 7)), NUM_SEGMENTS); -- integer portion
        sd_int       := to_integer(smooth_data(6 downto 3));
        encoded_frac <= bin_to_bcd(16d"0" & FRACTION_TABLE(sd_int), NUM_SEGMENTS); -- fractional portion
        digit_point  <= "00010000";
      end if;
    end if;
  end process;

  encoded <= encoded_int(3 downto 0) & encoded_frac(3 downto 0);

end architecture;
