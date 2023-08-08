-- i2c_temp_flt.vhd
-- ------------------------------------
-- Floating point temperature sensor module
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- Floating point version of the temperature sensor project

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library xpm;
use xpm.vcomponents.all;

use work.temp_pkg.all;
use work.counting_buttons_pkg.all;
use work.i2c_temp_flt_components_pkg.all;
use work.util_pkg.all;

entity i2c_temp is
  generic(
    SMOOTHING    : integer := 16;
    INTERVAL     : integer := 1000000000;
    NUM_SEGMENTS : integer := 8;
    CLK_PER      : integer := 10
  );
  port(
    clk     : in    std_logic;          -- 100Mhz clock
    -- Temperature Sensor Interface
    TMP_SCL : inout std_logic;
    TMP_SDA : inout std_logic;
    TMP_INT : inout std_logic;          -- Currently unused
    TMP_CT  : inout std_logic;          -- currently unused

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
  type i2c_state_t is (IDLE, START, TLOW, TSU, THIGH, THD, TSTO);
  type slv16_array_t is array (0 to 15) of std_logic_vector(15 downto 0);

  -- Constants
  constant TIME_1SEC   : integer          := integer(INTERVAL / CLK_PER); -- Clock ticks in 1 sec
  constant TIME_THDSTA : integer          := integer(600 / CLK_PER);
  constant TIME_TSUSTA : integer          := integer(600 / CLK_PER);
  constant TIME_THIGH  : integer          := integer(600 / CLK_PER);
  constant TIME_TLOW   : integer          := integer(1300 / CLK_PER);
  constant TIME_TSUSTO : integer          := integer(600 / CLK_PER);
  constant TIME_THDDAT : integer          := integer(30 / CLK_PER);
  constant I2C_ADDR    : std_logic_vector := "1001011"; -- 0x4B

  constant I2CBITS : integer := 1 +     -- start
                                7 +     -- 7 bits for address
                                1 +     -- 1 bit for read
                                1 +     -- 1 bit for ack back
                                8 +     -- 8 bits upper data
                                1 +     -- 1 bit for ack
                                8 +     -- 8 bits lower data
                                1 +     -- 1 bit for ack
                                1;      -- 1 bit for stop

  constant NINE_FIFTHS : std_logic_vector(31 downto 0) := x"3fe66666"; -- 9/5 in floating point
  constant THIRTY_TWO  : std_logic_vector(31 downto 0) := x"42000000"; -- floating point

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

  -- Divisor reciprocals, in 32-bit floating point format
  constant DIVIDE : array_t(0 to 16)(31 downto 0) := (
    0  => x"3F800000",                  -- 1
    1  => x"3F000000",                  -- 1/2
    2  => x"3eaaaaab",                  -- 1/3
    3  => x"3e800000",                  -- 1/4
    4  => x"3e4ccccd",                  -- 1/5
    5  => x"3e2aaaab",                  -- 1/6
    6  => x"3e124924",                  -- 1/7
    7  => x"3e000000",                  -- 1/8
    8  => x"3de38e39",                  -- 1/9
    9  => x"3dcccccd",                  -- 1/10
    10 => x"3dba2e8c",                  -- 1/11
    11 => x"3daaaaab",                  -- 1/12
    12 => x"3d9d89d9",                  -- 1/13
    13 => x"3d924925",                  -- 1/14
    14 => x"3d888888",                  -- 1/15
    15 => x"3d800000",                  -- 1/16
    16 => x"3d800000"                   -- 1/16
  );

  -- Registered signals with initial values
  signal encoded_int       : array_t(NUM_SEGMENTS - 1 downto 0)(3 downto 0) := (others => (others => '0'));
  signal encoded_frac      : array_t(NUM_SEGMENTS - 1 downto 0)(3 downto 0) := (others => (others => '0'));
  signal digit_point       : std_logic_vector(NUM_SEGMENTS - 1 downto 0)    := (others => '0');
  signal sda_en            : std_logic                                      := '0';
  signal scl_en            : std_logic                                      := '0';
  signal i2c_data          : std_logic_vector(I2CBITS - 1 downto 0)         := (others => '0');
  signal i2c_en            : std_logic_vector(I2CBITS - 1 downto 0)         := (others => '0');
  signal i2c_capt          : std_logic_vector(I2CBITS - 1 downto 0)         := (others => '0');
  signal counter           : integer range 0 to TIME_1SEC                   := 0;
  signal counter_reset     : std_logic                                      := '0';
  signal bit_count         : integer range 0 to I2CBITS                     := 0;
  signal temp_data         : std_logic_vector(15 downto 0)                  := (others => '0');
  signal convert           : std_logic                                      := '0';
  signal i2c_state         : i2c_state_t                                    := IDLE;
  signal smooth_data       : std_logic_vector(15 downto 0)                  := (others => '0');
  signal rden              : std_logic                                      := '0';
  signal convert_pipe      : std_logic_vector(2 downto 0)                   := (others => '0');
  signal accumulator       : std_logic_vector(31 downto 0)                  := x"00000000";
  signal temperature       : std_logic_vector(31 downto 0)                  := (others => '0');
  signal temperature_valid : std_logic                                      := '0';
  signal mult_in           : array_t(1 downto 0)(31 downto 0)               := (others => (others => '0'));
  signal mult_in_valid     : std_logic                                      := '0';
  signal fp_add_op         : std_logic_vector(7 downto 0)                   := (others => '0');
  signal addsub_in         : array_t(1 downto 0)(31 downto 0)               := (others => (others => '0'));

  -- Unregistered signals
  signal encoded          : array_t(NUM_SEGMENTS - 1 downto 0)(3 downto 0);
  signal capture_en       : std_logic;
  signal dout             : std_logic_vector(31 downto 0);
  signal bit_index        : natural range 0 to I2CBITS - 1;
  signal temp_data_s13_q4 : signed(12 downto 0);
  signal temp_data_u13_q4 : unsigned(12 downto 0);
  signal temp_float_valid : std_logic;
  signal temp_float       : std_logic_vector(31 downto 0);
  signal addsub_data      : std_logic_vector(31 downto 0);
  signal addsub_valid     : std_logic;
  signal result_data      : std_logic_vector(31 downto 0);
  signal result_valid     : std_logic;
  signal smooth_convert   : std_logic;
  signal smooth_count     : integer range 0 to SMOOTHING + 1;
  signal fused_data       : std_logic_vector(31 downto 0);
  signal fused_valid      : std_logic;

  -- Attributes
  attribute MARK_DEBUG : string;
  attribute MARK_DEBUG of sda_en, scl_en : signal is "TRUE";
  attribute MARK_DEBUG of counter : signal is "TRUE";
  attribute MARK_DEBUG of bit_count : signal is "TRUE";
  attribute MARK_DEBUG of temp_data : signal is "TRUE";
  attribute MARK_DEBUG of capture_en : signal is "TRUE";
  attribute MARK_DEBUG of convert : signal is "TRUE";
  attribute MARK_DEBUG of i2c_state : signal is "TRUE";
  attribute MARK_DEBUG of rden : signal is "TRUE";
  attribute MARK_DEBUG of convert_pipe : signal is "TRUE";

begin

  assert SMOOTHING <= 16 report "SMOOTHING factor must be <= 16" severity failure;

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

  -- Strip alarm flags from temperature value (bits 2..0)
  temp_data_s13_q4 <= signed(temp_data(temp_data'high downto 3));

  -- Clip negative temperatures at zero, as we're not supporting negative 
  -- temperatures yet.
  temp_data_u13_q4 <= unsigned(temp_data_s13_q4(12 downto 0)) when temp_data_s13_q4 >= 0 else 13d"0";

  g_NO_SMOOTH : if SMOOTHING = 0 generate

    smooth_data    <= std_logic_vector(resize(temp_data_u13_q4, smooth_data'length));
    smooth_convert <= convert;

  else generate

    u_fx_flt : fix_to_float
      port map(
        aclk                 => clk,
        s_axis_a_tvalid      => convert,
        s_axis_a_tdata       => std_logic_vector(resize(temp_data_u13_q4, 16)),
        m_axis_result_tvalid => temp_float_valid,
        m_axis_result_tdata  => temp_float
      );

    u_fp_addsub : fp_addsub
      port map(
        aclk                    => clk,
        s_axis_a_tvalid         => convert_pipe(0),
        s_axis_a_tdata          => addsub_in(0),
        s_axis_b_tvalid         => convert_pipe(0),
        s_axis_b_tdata          => addsub_in(1),
        s_axis_operation_tvalid => convert_pipe(0),
        s_axis_operation_tdata  => fp_add_op,
        m_axis_result_tvalid    => addsub_valid,
        m_axis_result_tdata     => addsub_data
      );

    u_fp_mult : fp_mult
      port map(
        aclk                 => clk,
        s_axis_a_tvalid      => mult_in_valid,
        s_axis_a_tdata       => mult_in(0),
        s_axis_b_tvalid      => mult_in_valid,
        s_axis_b_tdata       => mult_in(1),
        m_axis_result_tvalid => result_valid,
        m_axis_result_tdata  => result_data
      );

    u_flt_to_fix : flt_to_fix
      port map(
        aclk                 => clk,
        s_axis_a_tvalid      => temperature_valid,
        s_axis_a_tdata       => temperature,
        m_axis_result_tvalid => smooth_convert,
        m_axis_result_tdata  => smooth_data
      );

    u_fp_fused_mult_add : fp_fused_mult_add
      port map(
        aclk                 => clk,
        s_axis_a_tvalid      => result_valid,
        s_axis_a_tdata       => result_data,
        s_axis_b_tvalid      => result_valid,
        s_axis_b_tdata       => NINE_FIFTHS,
        s_axis_c_tvalid      => result_valid,
        s_axis_c_tdata       => THIRTY_TWO,
        m_axis_result_tvalid => fused_valid,
        m_axis_result_tdata  => fused_data
      );

    process(clk)
    begin
      if rising_edge(clk) then
        rden              <= '0';
        convert_pipe      <= "000";
        temperature_valid <= '0';
        mult_in_valid     <= '0';
        -- Initial stage: add next temperature sample to accumulator
        if temp_float_valid then
          fp_add_op       <= x"00";     -- ADD
          convert_pipe(0) <= '1';       -- enable fp_addsub
          addsub_in(0)    <= accumulator;
          addsub_in(1)    <= temp_float;
        end if;
        -- Stage 0: update accumulator with add/sub result 
        if addsub_valid then
          accumulator <= addsub_data;
          if fp_add_op = x"00" then     -- last addsub operation was an ADD
            convert_pipe(1) <= '1';
          else                          -- last addsub operation was a SUB
            convert_pipe(2) <= '1';
          end if;
        end if;
        -- Stage 1: subtract input sample N-16 from accumulator
        if convert_pipe(1) then
          fp_add_op       <= x"01";     -- SUB
          convert_pipe(0) <= '1';       -- enable fp_addsub
          addsub_in(0)    <= accumulator;
          if smooth_count = SMOOTHING then
            rden         <= '1';
            addsub_in(1) <= dout;
          else
            addsub_in(1) <= x"00000000";
          end if;
        end if;
        -- Stage 2: divide accumulator by number of accumulated samples 
        if convert_pipe(2) then
          if smooth_count < SMOOTHING then
            smooth_count <= smooth_count + 1;
          end if;
          mult_in(0)    <= accumulator;
          mult_in(1)    <= DIVIDE(smooth_count);
          mult_in_valid <= '1';
        end if;
        -- Stage 3: output temperature in degrees C
        if result_valid then
          temperature       <= result_data;
          temperature_valid <= not SW;
        end if;
        -- Stage 4: output temperature in degrees F
        if SW and fused_valid then
          temperature       <= fused_data;
          temperature_valid <= '1';
        end if;
      end if;
    end process;

    u_xpm_fifo_sync : xpm_fifo_sync
      generic map(
        FIFO_WRITE_DEPTH => 2 ** clog2(SMOOTHING + 1), -- must be a power of two
        WRITE_DATA_WIDTH => 32,
        READ_DATA_WIDTH  => 32,
        READ_MODE        => "FWFT"
      )
      port map(
        sleep         => '0',
        rst           => '0',
        wr_clk        => clk,
        wr_en         => temp_float_valid,
        din           => temp_float,
        rd_en         => rden,
        dout          => dout,
        injectsbiterr => '0',
        injectdbiterr => '0'
      );
  end generate;

  -- Convert temperature from binary to BCD
  process(clk)
    variable frac_int : integer range 0 to 15;
  begin
    if rising_edge(clk) then
      if smooth_convert then
        encoded_int  <= bin_to_bcd(22d"0" & smooth_data(13 downto 4), NUM_SEGMENTS); -- integer part
        frac_int       := to_integer(unsigned(smooth_data(3 downto 0)));
        encoded_frac <= bin_to_bcd(16d"0" & FRACTION_TABLE(frac_int), NUM_SEGMENTS); -- fractional part
      end if;
    end if;
  end process;

  digit_point <= "00010000";
  encoded     <= encoded_int(3 downto 0) & encoded_frac(3 downto 0);

end architecture;
