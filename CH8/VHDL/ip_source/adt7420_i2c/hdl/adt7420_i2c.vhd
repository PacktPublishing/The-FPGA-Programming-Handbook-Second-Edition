-- adt7420_i2c.vhd
-- ------------------------------------
--Interface to the ADT7420 I2C interface
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;

entity adt7420_i2c is
  generic(
    INTERVAL : integer := 1000000000;
    CLK_PER  : integer := 10
  );
  port(
    clk             : in    std_logic;  -- 100 MHz clock
    rst             : in    std_logic;  -- synchronous, high-active
    -- Temperature Sensor Interface
    TMP_SCL         : inout std_logic;
    TMP_SDA         : inout std_logic;
    TMP_INT         : inout std_logic;  -- currently unused
    TMP_CT          : inout std_logic;  -- currently unused

    fix_temp_tvalid : out   std_logic;
    fix_temp_tdata  : out   std_logic_vector(15 downto 0)
  );
end entity adt7420_i2c;

architecture rtl of adt7420_i2c is

  -- Subprograms
  function to_01(value : std_logic) return std_logic is
  begin
    if value = '0' then
      return '0';
    else
      return '1';
    end if;
  end function;

  -- Types  
  type i2c_state_t is (IDLE, START, TLOW, TSU, THIGH, THD, TSTO);

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

  -- Registered signals with initial values
  signal sda_en        : std_logic                     := '0';
  signal scl_en        : std_logic                     := '0';
  signal i2c_data      : std_logic_vector(I2CBITS - 1 downto 0);
  signal i2c_en        : std_logic_vector(I2CBITS - 1 downto 0);
  signal i2c_capt      : std_logic_vector(I2CBITS - 1 downto 0);
  signal counter       : integer range 0 to TIME_1SEC  := 0;
  signal counter_reset : std_logic                     := '0';
  signal bit_count     : integer range 0 to I2CBITS    := 0;
  signal temp_data     : std_logic_vector(15 downto 0) := (others => '0');
  signal convert       : std_logic                     := '0';
  signal i2c_state     : i2c_state_t                   := IDLE;

  -- Unregistered signals
  signal capture_en       : std_logic;
  signal bit_index        : natural range 0 to I2CBITS - 1;
  signal temp_data_s13_q4 : signed(12 downto 0);
  signal temp_data_u13_q4 : unsigned(12 downto 0);

  -- Attributes
  attribute MARK_DEBUG : string;
  attribute MARK_DEBUG of sda_en, scl_en : signal is "TRUE";
  attribute MARK_DEBUG of i2c_data, i2c_en, i2c_capt : signal is "TRUE";
  attribute MARK_DEBUG of counter : signal is "TRUE";
  attribute MARK_DEBUG of bit_count : signal is "TRUE";
  attribute MARK_DEBUG of i2c_state : signal is "TRUE";

begin

  TMP_SCL <= 'Z' when scl_en = '1' else '0';
  TMP_SDA <= 'Z' when sda_en = '1' else '0';

  bit_index  <= 0 when (bit_count = I2CBITS) else I2CBITS - bit_count - 1;
  capture_en <= i2c_capt(bit_index);

  fsm : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        scl_en <= '0';
        sda_en <= '0';
        counter_reset <= '0';
        counter <= 0;
        convert <= '0';
        i2c_data <= (others => '0');
        i2c_en <= (others => '0');
        i2c_capt <= (others => '0');
        bit_count <= 0;
        temp_data <= (others => '0');
        i2c_state <= IDLE;
      else
        scl_en        <= '1';
        sda_en        <= (not i2c_en(bit_index)) or i2c_data(bit_index);
        if counter_reset = '1' then
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
              if capture_en = '1' then
                temp_data <= temp_data(14 downto 0) & to_01(TMP_SDA); -- using to_01 to convert 'H' into '1' in simulation
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
    end if;
  end process;

  -- Strip alarm flags from temperature value (bits 2..0)
  temp_data_s13_q4 <= signed(temp_data(temp_data'high downto 3));

  -- Clip negative temperatures at zero, as we're not supporting negative 
  -- temperatures yet.
  temp_data_u13_q4 <= unsigned(temp_data_s13_q4(12 downto 0)) when temp_data_s13_q4 >= 0 else (others => '0');

  fix_temp_tvalid <= convert;
  fix_temp_tdata  <= std_logic_vector(resize(temp_data_u13_q4, fix_temp_tdata'length));

end architecture;
