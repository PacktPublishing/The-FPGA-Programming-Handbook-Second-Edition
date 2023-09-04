-- flt_temp.vhd
-- ------------------------------------
-- Component to tie together the floating point temperature sensor
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library xpm;
use xpm.vcomponents.all;

use work.util_pkg.all;                  -- clog2, slv4_array_t
use work.temp_pkg.all;                  -- bin_to_bcd

entity flt_temp is
  generic(
    SMOOTHING    : integer := 16;
    NUM_SEGMENTS : natural := 8
  );
  port(
    clk                  : in  std_logic; -- 100 MHz clock
    rst                  : in std_logic; -- synchronous, high-active
    -- Switch Interface
    SW                   : in  std_logic;
    -- LED Interface
    LED                  : out std_logic;
    -- Data from fix to float
    fix_temp_tvalid      : in  std_logic;
    fix_temp_tdata       : in  std_logic_vector(31 downto 0);
    -- Addsub interface
    addsub_a_tvalid      : out std_logic;
    addsub_a_tdata       : out std_logic_vector(31 downto 0);
    addsub_b_tvalid      : out std_logic;
    addsub_b_tdata       : out std_logic_vector(31 downto 0);
    addsub_op_tvalid     : out std_logic;
    addsub_op_tdata      : out std_logic_vector(7 downto 0);
    addsub_tvalid        : in  std_logic;
    addsub_tdata         : in  std_logic_vector(31 downto 0);
    -- Multiplier interface
    mult_a_tvalid        : out std_logic;
    mult_a_tdata         : out std_logic_vector(31 downto 0);
    mult_b_tvalid        : out std_logic;
    mult_b_tdata         : out std_logic_vector(31 downto 0);
    mult_tvalid          : in  std_logic;
    mult_tdata           : in  std_logic_vector(31 downto 0);
    -- Fused Multiplier-Add interface
    fused_a_tvalid       : out std_logic;
    fused_a_tdata        : out std_logic_vector(31 downto 0);
    fused_b_tvalid       : out std_logic;
    fused_b_tdata        : out std_logic_vector(31 downto 0);
    fused_c_tvalid       : out std_logic;
    fused_c_tdata        : out std_logic_vector(31 downto 0);
    fused_tvalid         : in  std_logic;
    fused_tdata          : in  std_logic_vector(31 downto 0);
    -- Float to fixed
    fp_temp_tvalid       : out std_logic;
    fp_temp_tdata        : out std_logic_vector(31 downto 0);
    fx_temp_tvalid       : in  std_logic;
    fx_temp_tdata        : in  std_logic_vector(15 downto 0);
    -- Float to fixed
    seven_segment_tvalid : out std_logic;
    seven_segment_tdata  : out std_logic_vector(NUM_SEGMENTS * 4 - 1 downto 0);
    seven_segment_tuser  : out std_logic_vector(NUM_SEGMENTS - 1 downto 0)
  );
end entity flt_temp;

architecture rtl of flt_temp is

  -- Types
  type array32_t is array (natural range <>) of unsigned(31 downto 0);
  
  -- Constants
  constant NINE_FIFTHS : std_logic_vector(31 downto 0) := x"3fe66666"; -- 9/5 in floating point
  constant THIRTY_TWO  : std_logic_vector(31 downto 0) := x"42000000"; -- floating point

  constant DIVIDE : array32_t(16 downto 0) := (
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

  constant FRACTION_TABLE : slv16_array_t(0 to 15) := (
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

  -- Registered signals with initial values
  signal encoded_int       : slv4_array_t(NUM_SEGMENTS - 1 downto 0) := (others => (others => '0'));
  signal encoded_frac      : slv4_array_t(NUM_SEGMENTS - 1 downto 0) := (others => (others => '0'));
  signal addsub_op         : std_logic_vector(7 downto 0)                   := (others => '0');
  signal digit_point       : std_logic_vector(NUM_SEGMENTS - 1 downto 0)    := (others => '0');
  signal smooth_count      : integer range 0 to SMOOTHING                   := 0;
  signal rden              : std_logic                                      := '0';
  signal accumulator       : std_logic_vector(31 downto 0)                  := (others => '0');
  signal temperature       : std_logic_vector(31 downto 0)                  := (others => '0');
  signal temperature_valid : std_logic                                      := '0';
  signal convert_pipe      : std_logic_vector(2 downto 0)                   := (others => '0');
  signal mult_in           : array32_t(1 downto 0)                          := (others => (others => '0'));
  signal mult_in_valid     : std_logic                                      := '0';
  signal addsub_in         : array32_t(1 downto 0)                          := (others => (others => '0'));

  -- Unregistered signals
  signal encoded        : slv4_array_t(NUM_SEGMENTS - 1 downto 0);
  signal result_data    : std_logic_vector(31 downto 0);
  signal result_valid   : std_logic;
  signal smooth_data    : std_logic_vector(15 downto 0);
  signal smooth_convert : std_logic;
  signal dout           : std_logic_vector(31 downto 0);

begin

  assert SMOOTHING > 0 and SMOOTHING <= 16 report "invalid SMOOTHING factor" severity failure;

  LED <= SW;

  addsub_a_tvalid  <= convert_pipe(0);
  addsub_a_tdata   <= std_logic_vector(addsub_in(0));
  addsub_b_tvalid  <= convert_pipe(0);
  addsub_b_tdata   <= std_logic_vector(addsub_in(1));
  addsub_op_tvalid <= convert_pipe(0);

  mult_a_tvalid <= mult_in_valid;
  mult_a_tdata  <= std_logic_vector(mult_in(0));
  mult_b_tvalid <= mult_in_valid;
  mult_b_tdata  <= std_logic_vector(mult_in(1));
  result_valid  <= mult_tvalid;
  result_data   <= mult_tdata;

  fp_temp_tvalid <= temperature_valid;
  fp_temp_tdata  <= temperature;
  smooth_convert <= fx_temp_tvalid;
  smooth_data    <= fx_temp_tdata;

  fused_a_tvalid  <= result_valid;
  fused_a_tdata   <= result_data;
  fused_b_tvalid  <= result_valid;
  fused_b_tdata   <= NINE_FIFTHS;
  fused_c_tvalid  <= result_valid;
  fused_c_tdata   <= THIRTY_TWO;
  addsub_op_tdata <= addsub_op;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rden              <= '0';
        convert_pipe      <= "000";
        temperature_valid <= '0';
        temperature       <= (others => '0');
        mult_in_valid     <= '0';
        addsub_op         <= x"00";       -- add
        addsub_in         <= (others => (others => '0'));
        accumulator       <= (others => '0');
        smooth_count      <= 0;
        mult_in           <= (others => (others => '0'));
      else      
        rden              <= '0';
        convert_pipe      <= "000";
        temperature_valid <= '0';
        mult_in_valid     <= '0';
        -- Initial stage: add next temperature sample to accumulator
        if fix_temp_tvalid = '1' then
          addsub_op       <= x"00";       -- add
          convert_pipe(0) <= '1';
          addsub_in(0)    <= unsigned(accumulator);
          addsub_in(1)    <= unsigned(fix_temp_tdata);
        end if;
        -- Stage 0: update accumulator with add/sub result 
        if addsub_tvalid = '1' then
          accumulator <= addsub_tdata;
          if addsub_op = x"00" then       -- add
            convert_pipe(1) <= '1';
          else                            -- sub
            convert_pipe(2) <= '1';
          end if;
        end if;
        -- Stage 1: subtract input sample N-16 from accumulator
        if convert_pipe(1) = '1' then
          addsub_op       <= x"01";       -- sub
          convert_pipe(0) <= '1';
          addsub_in(0)    <= unsigned(accumulator);
          if smooth_count = SMOOTHING then
            rden         <= '1';
            addsub_in(1) <= unsigned(dout);
          else
            addsub_in(1) <= x"00000000";
          end if;
        end if;
        -- Stage 2: divide accumulator by number of accumulated samples 
        if convert_pipe(2) = '1' then
          if smooth_count < SMOOTHING then
            smooth_count <= smooth_count + 1;
          end if;
          mult_in(0)    <= unsigned(accumulator);
          mult_in(1)    <= DIVIDE(smooth_count);
          mult_in_valid <= '1';
        end if;
        -- Stage 3: output temperature in degrees C
        if result_valid = '1' then
          temperature       <= result_data;
          temperature_valid <= not SW;
        end if;
        -- Stage 4: output temperature in degrees F
        if SW = '1' and fused_tvalid = '1' then
          temperature       <= fused_tdata;
          temperature_valid <= '1';
        end if;
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
      rst           => rst,
      wr_clk        => clk,
      wr_en         => fix_temp_tvalid,
      din           => fix_temp_tdata,
      rd_en         => rden,
      dout          => dout,
      injectsbiterr => '0',
      injectdbiterr => '0'
    );

  -- Convert temperature from binary to BCD
  process(clk)
    variable frac_int : integer range 0 to 15;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        seven_segment_tvalid <= '0';
        encoded_int          <= (others => (others => '0'));
        encoded_frac         <= (others => (others => '0'));
      else
        seven_segment_tvalid <= '0';
        if smooth_convert = '1' then 
          seven_segment_tvalid <= '1';
          encoded_int          <= bin_to_bcd(std_logic_vector'("0000000000000000000000") & smooth_data(13 downto 4), NUM_SEGMENTS); -- integer part
          frac_int             := to_integer(unsigned(smooth_data(3 downto 0)));
          encoded_frac         <= bin_to_bcd(std_logic_vector'("0000000000000000") & FRACTION_TABLE(frac_int), NUM_SEGMENTS); -- fractional part
        end if;
      end if;
    end if;    
  end process;

  digit_point <= "00010000";
  encoded     <= encoded_int(3 downto 0) & encoded_frac(3 downto 0);

  -- 7 segment display
  gen_sevent_segment_tdata : for i in encoded'range generate
    seven_segment_tdata(i * 4 + 3 downto i * 4) <= encoded(i); -- TODO: check bit mapping
  end generate gen_sevent_segment_tdata;
  seven_segment_tuser <= digit_point;

end architecture;
