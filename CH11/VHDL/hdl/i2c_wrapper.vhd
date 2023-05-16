LIBRARY IEEE, XPM;
USE IEEE.std_logic_1164.all;
USE IEEE.std_logic_UNSIGNED.all;
USE ieee.numeric_std.all;
use IEEE.math_real.all;
use XPM.vcomponents.all;
use WORK.temp_pkg.all;

entity i2c_wrapper is
  generic (CLK_PER     : integer := 10);
  port    (clk         : in    std_logic; -- 100Mhz clock

           -- Temperature Sensor Interface
           TMP_SCL     : inout std_logic;
           TMP_SDA     : inout std_logic;
           TMP_INT     : inout std_logic;
           TMP_CT      : inout std_logic;

           -- Switch interface - Fahrenheit or celsius
           ftemp       : in    std_logic;

           update_temp : out   std_logic;
           capt_temp   : out   array_t (15 downto 0)(7 downto 0));
end entity i2c_wrapper;
architecture rtl of i2c_wrapper is
  component i2c_temp_flt is
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

          -- Data to be displayed
          temp_valid : out    std_logic;
          encoded    : out array_t (NUM_SEGMENTS-1 downto 0)(3 downto 0));
  end component i2c_temp_flt;
  signal encoded    : array_t (7 downto 0)(3 downto 0);
  signal temp_valid : std_logic;
  -- capt_temp               "     F 0000.0000";
  signal capt_temp_r : array_t (15 downto 0)(7 downto 0)
    := (x"20", x"20", x"20", x"20", x"20", x"46", x"20", x"30",
        x"30", x"30", x"30", x"2E", x"30", x"30", x"30", x"30");

begin

  capt_temp <= capt_temp_r;

  -- i2C temperature sensor
  u_i2c_temp_flt : i2c_temp_flt
    generic map (CLK_PER        => CLK_PER)
    port map    (clk            => clk,

                 -- Temperature Sensor Interface
                 TMP_SCL        => TMP_SCL,
                 TMP_SDA        => TMP_SDA,
                 TMP_INT        => TMP_INT,
                 TMP_CT         => TMP_CT,

                 -- Switch interface - Fahrenheit or celsius
                 SW             => ftemp,

                 -- Data to be displayed
                 temp_valid     => temp_valid,
                 encoded        => encoded);

  process (clk)
  begin
    if rising_edge(clk) then
      if temp_valid then
        update_temp             <= not update_temp;
        capt_temp_r(9)          <= x"0C"; -- Degree symbol
        if ftemp then
          capt_temp_r(10) <= x"46"; -- F
        else
          capt_temp_r(10) <= x"43"; -- C
        end if;

        for i in 7 downto 0 loop
          if i > 3 then
            capt_temp_r(7-i) <= x"3" & encoded(i);
          else
            capt_temp_r(8-i) <= x"3" & encoded(i);
          end if;
        end loop;
      end if;
    end if;
  end process;
end architecture rtl;
