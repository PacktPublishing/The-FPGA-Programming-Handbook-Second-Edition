LIBRARY IEEE, WORK, XPM;
USE IEEE.std_logic_1164.all;
USE ieee.numeric_std.all;
use IEEE.math_real.all;
use WORK.temp_pkg.all;
USE WORK.counting_buttons_pkg.all;
USE WORK.i2c_temp_flt_components_pkg.all;
use XPM.vcomponents.all;

entity i2c_temp is
  generic (SMOOTHING    : integer := 16;
           INTERVAL     : integer := 1000000000;
           NUM_SEGMENTS : integer := 8;
           CLK_PER      : integer := 10);
  port (clk     : in std_logic; -- 100Mhz clock
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
        anode   : out std_logic_vector(NUM_SEGMENTS-1 downto 0);
        cathode : out std_logic_vector(7 downto 0));
end entity i2c_temp;

architecture rtl of i2c_temp is

  attribute MARK_DEBUG : string;
  constant TIME_1SEC   : integer := integer(INTERVAL/CLK_PER); -- Clock ticks in 1 sec
  constant TIME_THDSTA : integer := integer(600/CLK_PER);
  constant TIME_TSUSTA : integer := integer(600/CLK_PER);
  constant TIME_THIGH  : integer := integer(600/CLK_PER);
  constant TIME_TLOW   : integer := integer(1300/CLK_PER);
  constant TIME_TSUDAT : integer := integer(20/CLK_PER);
  constant TIME_TSUSTO : integer := integer(600/CLK_PER);
  constant TIME_THDDAT : integer := integer(30/CLK_PER);
  constant I2C_ADDR    : std_logic_vector := "1001011"; -- 0x4B
  constant I2CBITS     : integer := 1 + -- start
                                    7 + -- 7 bits for address
                                    1 + -- 1 bit for read
                                    1 + -- 1 bit for ack back
                                    8 + -- 8 bits upper data
                                    1 + -- 1 bit for ack
                                    8 + -- 8 bits lower data
                                    1 + -- 1 bit for ack
                                    1 + 1;  -- 1 bit for stop

  constant NINE_FIFTHS : std_logic_vector(31 downto 0) := x"3fe66666"; -- 9/5 in floating point
  constant thirty_two : std_logic_vector(31 downto 0) := x"42000000"; -- floating point
  signal encoded      : array_t (NUM_SEGMENTS-1 downto 0)(3 downto 0);
  signal encoded_int  : array_t (NUM_SEGMENTS-1 downto 0)(3 downto 0);
  signal encoded_frac : array_t (NUM_SEGMENTS-1 downto 0)(3 downto 0);
  signal digit_point  : std_logic_vector(NUM_SEGMENTS-1 downto 0);
  signal sda_en       : std_logic := '0';
  signal scl_en       : std_logic := '0';
  attribute MARK_DEBUG of sda_en, scl_en : signal is "TRUE";
  signal i2c_data     : std_logic_vector(I2CBITS - 1 downto 0);
  signal i2c_en       : std_logic_vector(I2CBITS - 1 downto 0);
  signal i2c_capt     : std_logic_vector(I2CBITS - 1 downto 0);
  signal counter      : integer range 0 to TIME_1SEC:= 0;
  attribute MARK_DEBUG of counter : signal is "TRUE";
  signal counter_reset : std_logic := '0';
  signal bit_count    : integer range 0 to I2CBITS := 0;
  attribute MARK_DEBUG of bit_count : signal is "TRUE";
  signal temp_data    : std_logic_vector(15 downto 0);
  signal capture_en   : std_logic;
  signal convert      : std_logic;
  attribute MARK_DEBUG of temp_data : signal is "TRUE";
  attribute MARK_DEBUG of capture_en : signal is "TRUE";
  attribute MARK_DEBUG of convert : signal is "TRUE";
  type spi_t is (IDLE, START, TLOW, TSU, THIGH, THD, TSTO);
  signal spi_state : spi_t := IDLE;
  attribute MARK_DEBUG of spi_state : signal is "TRUE";
  signal fraction : array_t(3 downto 0)(3 downto 0);
  type int_array is array (0 to 15) of integer range 0 to 65535;
  signal fraction_table : int_array :=
    (0  => 0*625,
     1  => 1*625,
     2  => 2*625,
     3  => 3*625,
     4  => 4*625,
     5  => 5*625,
     6  => 6*625,
     7  => 7*625,
     8  => 8*625,
     9  => 9*625,
     10 => 10*625,
     11 => 11*625,
     12 => 12*625,
     13 => 13*625,
     14 => 14*625,
     15 => 15*625);
  signal smooth_data : std_logic_vector(15 downto 0);
  signal smooth_convert : std_logic;
  signal smooth_count : integer range 0 to SMOOTHING := 0;
  signal dout : std_logic_vector(31 downto 0);
  signal rden : std_logic := '0';
  attribute MARK_DEBUG of rden : signal is "TRUE";
  signal convert_pipe : std_logic_vector(2 downto 0);
  attribute MARK_DEBUG of convert_pipe : signal is "TRUE";
  signal divide : array_t(16 downto 0)(31 downto 0) :=
    (0    => x"3F800000", -- 1
     1    => x"3F000000", -- 1/2
     2    => x"3eaaaaab", -- 1/3
     3    => x"3e800000", -- 1/4
     4    => x"3e4ccccd", -- 1/5
     5    => x"3e2aaaab", -- 1/6
     6    => x"3e124924", -- 1/7
     7    => x"3e000000", -- 1/8
     8    => x"3de38e39", -- 1/9
     9    => x"3dcccccd", -- 1/10
     10   => x"3dba2e8c", -- 1/11
     11   => x"3daaaaab", -- 1/12
     12   => x"3d9d89d9", -- 1/13
     13   => x"3d924925", -- 1/14
     14   => x"3d888888", -- 1/15
     15   => x"3d800000", -- 1/16
     16   => x"3d800000"  -- 1/16
    );

  type float_t is record
    sign     : std_logic;
    exponent : std_logic_vector(7 downto 0);
    mantissa : std_logic_vector(22 downto 0);
  end record;

  -- VHDL doesn't have unions
  signal accumulator : std_logic_vector(31 downto 0) := x"00000000";
  signal result_data : std_logic_vector(31 downto 0);
  signal result_valid : std_logic;
  signal temperature : std_logic_vector(31 downto 0);
  signal temperature_valid : std_logic;
  signal mult_in : array_t(1 downto 0)(31 downto 0);
  signal mult_in_valid : std_logic;
  signal fused_data : std_logic_vector(31 downto 0);
  signal fused_valid : std_logic;
  signal s_axis_a_tready : std_logic;
  signal temp_float_valid : std_logic;
  signal temp_float : std_logic_vector(31 downto 0);
  signal fp_add_op : std_logic_vector(7 downto 0);
  signal accum_valid : std_logic;
  signal addsub_in : array_t(1 downto 0)(31 downto 0);
  signal addsub_data : std_logic_vector(31 downto 0);
  signal addsub_valid : std_logic;
begin

  LED <= SW;

  u_seven_segment : entity work.seven_segment
    generic map(NUM_SEGMENTS => NUM_SEGMENTS, CLK_PER => CLK_PER)
    port map(clk => clk, reset => '0', encoded => encoded, digit_point => not digit_point,
             anode => anode, cathode => cathode);

  TMP_SCL <= 'Z' when scl_en else '0';
  TMP_SDA <= 'Z' when sda_en else '0';

  capture_en <= i2c_capt(I2CBITS - bit_count - 1);

  process (clk) begin
    if rising_edge(clk) then
      scl_en                     <= '1';
      sda_en                     <= not i2c_en(I2CBITS - bit_count - 1) or
                                    i2c_data(I2CBITS - bit_count - 1);
      if counter_reset then
        counter <= 0;
      else
        counter <= counter + 1;
      end if;
      counter_reset <= '0';
      convert       <= '0';

      case spi_state is
        when IDLE =>
          i2c_data  <= '0' & I2C_ADDR  & '1' & '0' & "00000000" & '0' & "00000000" & '1' & '0' & '1';
          i2c_en    <= '1' & "1111111" & '1' & '0' & "00000000" & '1' & "00000000" & '1' & '1' & '1';
          i2c_capt  <= '0' & "0000000" & '0' & '0' & "11111111" & '0' & "11111111" & '0' & '0' & '0';
          bit_count <= 0;
          sda_en    <= '1'; -- Force to 1 in the beginning.

          if counter = TIME_1SEC then
            temp_data     <= (others =>'0');
            spi_state     <= START;
            counter_reset <= '1';
            sda_en        <= '0'; -- Drop the data
          end if;
        when START =>
          sda_en <= '0'; -- Drop the data
          -- Hold clock low for thd:sta
          if counter = TIME_THDSTA then
            counter_reset   <= '1';
            scl_en          <= '0'; -- Drop the clock
            spi_state       <= TLOW;
          end if;
        when TLOW =>
          scl_en            <= '0'; -- Drop the clock
          if counter = TIME_TLOW then
            bit_count     <= bit_count + 1;
            counter_reset <= '1';
            spi_state     <= TSU;
        end if;
        when TSU =>
          scl_en            <= '0'; -- Drop the clock
          if counter = TIME_TSUSTA then
            counter_reset <= '1';
            spi_state     <= THIGH;
          end if;
        when THIGH =>
          scl_en          <= '1'; -- Raise the clock
          if counter = TIME_THIGH then
            if capture_en then
              temp_data <= temp_data(14 downto 0) & TMP_SDA;
            end if;
            counter_reset <= '1';
            spi_state     <= THD;
          end if;
        when THD =>
          scl_en            <= '0'; -- Drop the clock
          if counter = TIME_THDDAT then
            counter_reset <= '1';
            if bit_count = I2CBITS then
              spi_state <= TSTO;
            else
              spi_state <= TLOW;
            end if;
          end if;
        when TSTO =>
          if counter = TIME_TSUSTO then
            convert       <= '1';
            counter_reset <= '1';
            spi_state     <= IDLE;
          end if;
        when others => spi_state     <= IDLE;
      end case;
    end if;
  end process;

  g_NO_SMOOTH : if SMOOTHING = 0 generate
      smooth_data <= "0000000000000000000000" & temp_data(15 downto 3);
      smooth_convert <= convert;
    else generate

      -- Stage 1
      u_fx_flt : fix_to_float
      port map
        (
         aclk                   => clk,
         s_axis_a_tvalid        => convert,
         s_axis_a_tdata         => "000" & temp_data(15 downto 3),
         m_axis_result_tvalid   => temp_float_valid,
         m_axis_result_tdata    => temp_float);

      u_fp_addsub : fp_addsub
      port map
        (
         aclk                   => clk,
         s_axis_a_tvalid        => convert_pipe(0),
         s_axis_a_tdata         => addsub_in(0),
         s_axis_b_tvalid        => convert_pipe(0),
         s_axis_b_tdata         => addsub_in(1),
         s_axis_operation_tvalid=> convert_pipe(0),
         s_axis_operation_tdata => fp_add_op,
         m_axis_result_tvalid   => addsub_valid,
         m_axis_result_tdata    => addsub_data);

      u_fp_mult : fp_mult
      port map (
         aclk                   => clk,
         s_axis_a_tvalid        => mult_in_valid,
         s_axis_a_tdata         => mult_in(0),
         s_axis_b_tvalid        => mult_in_valid,
         s_axis_b_tdata         => mult_in(1),
         m_axis_result_tvalid   => result_valid,
         m_axis_result_tdata    => result_data);

      u_flt_to_fix : flt_to_fix
        port map (
         aclk                   => clk,
         s_axis_a_tvalid        => temperature_valid,
         s_axis_a_tdata         => temperature,
         m_axis_result_tvalid   => smooth_convert,
         m_axis_result_tdata    => smooth_data);

      u_fp_fused_mult_add : fp_fused_mult_add
        port map (
         aclk                   => clk,
         s_axis_a_tvalid        => result_valid,
         s_axis_a_tdata         => result_data,
         s_axis_b_tvalid        => result_valid,
         s_axis_b_tdata         => nine_fifths,
         s_axis_c_tvalid        => result_valid,
         s_axis_c_tdata         => thirty_two,
         m_axis_result_tvalid   => fused_valid,
         m_axis_result_tdata    => fused_data);

      process (clk)
      begin
        if rising_edge(clk) then
          rden           <= '0';
          convert_pipe   <= "000";
          temperature_valid <= '0';
          mult_in_valid <= '0';
          if temp_float_valid then
            fp_add_op <= x"00";
            convert_pipe(0) <= '1';
            addsub_in(0) <= accumulator;
            addsub_in(1) <= temp_float;
          end if;
          if addsub_valid then
            accumulator <= addsub_data;
            if fp_add_op = x"00" then
              convert_pipe(1) <= '1';
              rden            <= '1';
            else
              convert_pipe(2) <= '1';
            end if;
          end if;
          if convert_pipe(1) then
            -- We just performed an add, so now perform a subtract
            fp_add_op       <= x"01"; -- subtract
            convert_pipe(0) <= '1';
            addsub_in(0)    <= accumulator;
            if smooth_count = SMOOTHING then
              addsub_in(1)  <= dout;
            else
              addsub_in(1)  <= x"00000000";
            end if;
          end if;
          if convert_pipe(2) then
            -- Drive data into multiplier
            if smooth_count < SMOOTHING then smooth_count <= smooth_count + 1; end if;
            mult_in(0)    <= accumulator;
            mult_in(1)    <= divide(smooth_count);
            mult_in_valid <= '1';
          end if;
          if result_valid then
            temperature          <= result_data;
            temperature_valid    <= not SW;
          end if;
          -- Fahrenheit conversion
          if SW and fused_valid then
            temperature          <= fused_data;
            temperature_valid    <= '1';
          end if;
        end if;
      end process;

      u_xpm_fifo_sync : xpm_fifo_sync
        generic map(FIFO_WRITE_DEPTH => SMOOTHING*2, WRITE_DATA_WIDTH => 32, READ_DATA_WIDTH => 32)
        port map(sleep => '0',
                 rst => '0',
                 wr_clk => clk,
                 wr_en => temp_float_valid,
                 din => temp_float,
                 rd_en => rden,
                 dout => dout,
                 injectsbiterr => '0',
                 injectdbiterr => '0');
  end generate;

  -- convert temperature from
  process (clk)
    variable sd_int : integer range 0 to 15;
  begin
    sd_int := to_integer(unsigned(smooth_data(3 downto 0)));
    if rising_edge(clk) then
      if smooth_convert then
        encoded_int  <= bin_to_bcd("00000000000000000000000" & smooth_data(12 downto 4)); -- Decimal portion
        encoded_frac <= bin_to_bcd(std_logic_vector(to_unsigned(fraction_table(sd_int), 32)));
        digit_point  <= "00010000";
      end if;
    end if;
  end process;

  encoded <= encoded_int(3 downto 0) & encoded_frac(3 downto 0);
end architecture;
