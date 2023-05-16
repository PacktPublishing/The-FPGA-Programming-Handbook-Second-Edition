LIBRARY IEEE, XPM;
USE IEEE.std_logic_1164.all;
--USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.std_logic_SIGNED.all;
USE ieee.numeric_std.all;
use IEEE.math_real.all;
use XPM.vcomponents.all;

entity flt_temp is
  generic (SMOOTHING    : integer := 16;
           NUM_SEGMENTS : integer := 8);
  port (clk              : in  std_logic; -- 100Mhz clock

        -- Switch Interface
        SW               : in  std_logic;

        -- LED Interface
        LED              : out std_logic;

        -- data from fix to float
        fix_temp_tvalid  : in  std_logic;
        fix_temp_tdata   : in  std_logic_vector(31 downto 0);

        -- Addsub interface
        addsub_a_tvalid  : out std_logic;
        addsub_a_tdata   : out std_logic_vector(31 downto 0);
        addsub_b_tvalid  : out std_logic;
        addsub_b_tdata   : out std_logic_vector(31 downto 0);
        addsub_op_tvalid : out std_logic;
        addsub_op_tdata  : out std_logic_vector(7 downto 0);
        addsub_tvalid    : in  std_logic;
        addsub_tdata     : in  std_logic_vector(31 downto 0);

        -- Multiplier interface
        mult_a_tvalid    : out std_logic;
        mult_a_tdata     : out std_logic_vector(31 downto 0);
        mult_b_tvalid    : out std_logic;
        mult_b_tdata     : out std_logic_vector(31 downto 0);
        mult_tvalid      : in  std_logic;
        mult_tdata       : in  std_logic_vector(31 downto 0);

        -- Fused Multiplier-Add interface
        fused_a_tvalid   : out std_logic;
        fused_a_tdata    : out std_logic_vector(31 downto 0);
        fused_b_tvalid   : out std_logic;
        fused_b_tdata    : out std_logic_vector(31 downto 0);
        fused_c_tvalid   : out std_logic;
        fused_c_tdata    : out std_logic_vector(31 downto 0);
        fused_tvalid     : in  std_logic;
        fused_tdata      : in  std_logic_vector(31 downto 0);

        -- Float to fixed
        fp_temp_tvalid   : out std_logic;
        fp_temp_tdata    : out std_logic_vector(31 downto 0);
        fx_temp_tvalid   : in  std_logic;
        fx_temp_tdata    : in  std_logic_vector(15 downto 0);

        -- Float to fixed
        seven_segment_tvalid : out std_logic;
        seven_segment_tdata  : out std_logic_vector(NUM_SEGMENTS*4-1 downto 0);
        seven_segment_tuser  : out std_logic_vector(NUM_SEGMENTS-1 downto 0));

end entity flt_temp;

architecture rtl of flt_temp is
  type array32_t is array (natural range <>) of unsigned(31 downto 0);
  type array4_t is array (natural range <>) of unsigned(3 downto 0);
  attribute MARK_DEBUG : string;
  signal addsub_op    : std_logic_vector(7 downto 0);
  signal encoded      : std_logic_vector(NUM_SEGMENTS*4-1 downto 0);
  signal encoded_int  : std_logic_vector(NUM_SEGMENTS*4-1 downto 0);
  signal encoded_intc : std_logic_vector(NUM_SEGMENTS*4-1 downto 0);
  signal encoded_frac : std_logic_vector(NUM_SEGMENTS*4-1 downto 0);
  signal encoded_fracc: std_logic_vector(NUM_SEGMENTS*4-1 downto 0);
  signal digit_point  : std_logic_vector(NUM_SEGMENTS-1 downto 0);
  signal temp_data    : std_logic_vector(15 downto 0);
  signal capture_en   : std_logic;
  signal convert      : std_logic;
  signal smooth_data : std_logic_vector(15 downto 0);
  signal smooth_convert : std_logic;
  signal sample_count : integer range 0 to 32 := 0;
  attribute MARK_DEBUG of temp_data : signal is "TRUE";
  attribute MARK_DEBUG of capture_en : signal is "TRUE";
  attribute MARK_DEBUG of convert : signal is "TRUE";
  signal smooth_count : integer range 0 to SMOOTHING := 0;
  signal dout : std_logic_vector(31 downto 0);
  signal rden : std_logic := '0';
  signal accumulator : std_logic_vector(31 downto 0) := x"00000000";
  signal result_data : std_logic_vector(31 downto 0);
  signal result_valid : std_logic;
  signal temperature : std_logic_vector(31 downto 0);
  signal temperature_valid : std_logic;
  signal convert_pipe : std_logic_vector(2 downto 0);
  signal divide : array32_t(16 downto 0) :=
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
  constant NINE_FIFTHS : std_logic_vector(31 downto 0) := x"3fe66666"; -- 9/5 in floating point
  constant thirty_two : std_logic_vector(31 downto 0) := x"42000000"; -- floating point
  signal mult_in : array32_t(1 downto 0);
  signal mult_in_valid : std_logic;
  signal s_axis_a_tready : std_logic;
  signal accum_valid : std_logic;
  signal addsub_in : array32_t(1 downto 0);
  signal fraction : array4_t(3 downto 0);
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
begin

  LED <= SW;

      addsub_a_tvalid  <= convert_pipe(0);
      addsub_a_tdata   <= std_logic_vector(addsub_in(0));
      addsub_b_tvalid  <= convert_pipe(0);
      addsub_b_tdata   <= std_logic_vector(addsub_in(1));
      addsub_op_tvalid <= convert_pipe(0);

      mult_a_tvalid    <= mult_in_valid;
      mult_a_tdata     <= std_logic_vector(mult_in(0));
      mult_b_tvalid    <= mult_in_valid;
      mult_b_tdata     <= std_logic_vector(mult_in(1));
      result_valid     <= mult_tvalid;
      result_data      <= mult_tdata;

      fp_temp_tvalid   <= temperature_valid;
      fp_temp_tdata    <= temperature;
      smooth_convert   <= fx_temp_tvalid;
      smooth_data      <= fx_temp_tdata;

      fused_a_tvalid   <= result_valid;
      fused_a_tdata    <= result_data;
      fused_b_tvalid   <= result_valid;
      fused_b_tdata    <= nine_fifths;
      fused_c_tvalid   <= result_valid;
      fused_c_tdata    <= thirty_two;
      addsub_op_tdata  <= addsub_op;

      process (clk)
        variable data_mult : std_logic_vector(51 downto 0);
        variable data_shift : std_logic_vector(51 downto 0);
        variable addsub : array32_t(1 downto 0);
      begin
        if rising_edge(clk) then
          rden           <= '0';
          convert_pipe   <= "000";
          temperature_valid <= '0';
          mult_in_valid <= '0';
          if fix_temp_tvalid = '1' then
            -- First stage, temperature data converted to float, add to accumulator
            addsub_op        <= x"00"; -- add
            convert_pipe(0)  <= '1';
            addsub(0)        := unsigned(accumulator);
            addsub(1)        := unsigned(fix_temp_tdata);
            addsub_in(0)     <= addsub(0);
            addsub_in(1)     <= addsub(1);
          end if;
          if addsub_tvalid = '1' then
            accumulator <= addsub_tdata;
            if addsub_op = x"00" then
              convert_pipe(1) <= '1';
              rden            <= '1';
            else
              convert_pipe(2) <= '1';
            end if;
          end if;
          if convert_pipe(1) = '1' then
            -- We just performed an add, so now perform a subtract
            addsub_op        <= x"01"; -- subtract
            convert_pipe(0)  <= '1';
            addsub(0)        := unsigned(accumulator);
            addsub(1)        := unsigned(dout);
            addsub_in(0)     <= addsub(0);
            if smooth_count = 16 then
              addsub_in(1)     <= addsub(1);
            else
              addsub_in(1)     <= x"00000000";
            end if;
          end if;
          if convert_pipe(2) = '1' then
            -- Drive data into multiplier
            if sample_count < 16 then sample_count <= sample_count + 1; end if;
            if smooth_count < 16 then smooth_count <= smooth_count + 1; end if;
            addsub(0)        := unsigned(accumulator);
            mult_in(0)    <= addsub(0);
            mult_in(1)    <= divide(sample_count);
            mult_in_valid <= '1';
          end if;
          if result_valid = '1' then
            temperature          <= result_data;
            temperature_valid    <= not SW;
          end if;
          -- Fahrenheit conversion
          if SW = '1' and fused_tvalid = '1' then
            temperature          <= fused_tdata;
            temperature_valid    <= '1';
          end if;
        end if;
      end process;

      u_xpm_fifo_sync : xpm_fifo_sync
        generic map(FIFO_WRITE_DEPTH => SMOOTHING*2, WRITE_DATA_WIDTH => 32, READ_DATA_WIDTH => 32)
        port map(sleep => '0',
                 rst => '0',
                 wr_clk => clk,
                 wr_en => fix_temp_tvalid,
                 din => fix_temp_tdata,
                 rd_en => rden,
                 dout => dout,
                 injectsbiterr => '0',
                 injectdbiterr => '0');

  -- convert temperature from
  process (clk)
    variable sd_int : integer range 0 to 15;
  begin
    sd_int := to_integer(unsigned(smooth_data(3 downto 0)));
    if rising_edge(clk) then
      seven_segment_tvalid <= '0';
      if smooth_convert = '1' then
        seven_segment_tvalid <= '1';
        encoded_int  <= encoded_intc; -- Decimal portion
        encoded_frac <= encoded_fracc;
        digit_point  <= "00010000";
      end if;
    end if;
  end process;

  process (smooth_data)
    variable bin_in  : std_logic_vector(31 downto 0);
    variable shifted : std_logic_vector(NUM_SEGMENTS*4-1 downto 0);
    variable bin2bcd : std_logic_vector(NUM_SEGMENTS*4-1 downto 0);
  begin
    bin_in := "00000000000000000000000" & smooth_data(12 downto 4);
    shifted := (others => '0');
    shifted(1 downto 0) := bin_in(31 downto 30);
    for i in 29 downto 1 loop
      shifted := shifted(30 downto 0) & bin_in(i);
      for j in 0 to NUM_SEGMENTS-1 loop
        if shifted(j*4+3 downto j*4) > 4 then
          shifted(j*4+3 downto j*4) := shifted(j*4+3 downto j*4) + 3;
        end if;
      end loop;
    end loop;
    shifted := shifted(30 downto 0) & bin_in(0);
    encoded_intc <= shifted;
  end process;

  process (smooth_data)
    variable bin_in  : std_logic_vector(31 downto 0);
    variable shifted : std_logic_vector(NUM_SEGMENTS*4-1 downto 0);
    variable bin2bcd : std_logic_vector(NUM_SEGMENTS*4-1 downto 0);
  begin
    bin_in := std_logic_vector(to_unsigned(fraction_table(to_integer(unsigned(smooth_data(3 downto 0)))), 32));
    shifted := (others => '0');
    shifted(1 downto 0) := bin_in(31 downto 30);
    for i in 29 downto 1 loop
      shifted := shifted(30 downto 0) & bin_in(i);
      for j in 0 to NUM_SEGMENTS-1 loop
        if shifted(j*4+3 downto j*4) > 4 then
          shifted(j*4+3 downto j*4) := shifted(j*4+3 downto j*4) + 3;
        end if;
      end loop;
    end loop;
    shifted := shifted(30 downto 0) & bin_in(0);
    encoded_fracc <= shifted;
  end process;

  encoded <= encoded_intc(15 downto 0) & encoded_fracc(15 downto 0);

  -- 7 segment display
  process (encoded) begin
    for i in 0 to NUM_SEGMENTS-1 loop
      seven_segment_tdata(4*i+3 downto 4*i) <= encoded(4*i+3 downto 4*i);
    end loop;
  end process;
  seven_segment_tuser <= digit_point;
end architecture;
