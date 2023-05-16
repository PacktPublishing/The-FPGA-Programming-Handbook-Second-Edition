LIBRARY IEEE, XPM;
USE IEEE.std_logic_1164.all;
--USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.std_logic_SIGNED.all;
USE ieee.numeric_std.all;
use IEEE.math_real.all;
use XPM.vcomponents.all;

entity adt7420_i2c is
  generic (INTERVAL     : integer := 1000000000;
           CLK_PER      : integer := 10);
  port (clk     : in std_logic; -- 100Mhz clock
        -- Temperature Sensor Interface
        TMP_SCL : inout std_logic;
        TMP_SDA : inout std_logic;
        TMP_INT : inout std_logic;
        TMP_CT  : inout std_logic;

        fix_temp_tvalid : out std_logic;
        fix_temp_tdata  : out std_logic_vector(15 downto 0));
end entity adt7420_i2c;

architecture rtl of adt7420_i2c is
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
  type spi_t is (IDLE, START, TLOW, TSU, THIGH, THD, TSTO);
  signal spi_state : spi_t := IDLE;
  attribute MARK_DEBUG of spi_state : signal is "TRUE";
begin

  TMP_SCL <= 'Z' when scl_en = '1' else '0';
  TMP_SDA <= 'Z' when sda_en = '1' else '0';

  capture_en <= i2c_capt(I2CBITS - bit_count - 1);

  process (clk) begin
    if rising_edge(clk) then
      scl_en                     <= '1';
      sda_en                     <= not i2c_en(I2CBITS - bit_count - 1) or
                                    i2c_data(I2CBITS - bit_count - 1);
      if counter_reset = '1' then
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
            if capture_en = '1' then
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

  fix_temp_tvalid <= convert;
  fix_temp_tdata  <= "000" & temp_data(15 downto 3); -- lop off lower three unused bits

end architecture;
