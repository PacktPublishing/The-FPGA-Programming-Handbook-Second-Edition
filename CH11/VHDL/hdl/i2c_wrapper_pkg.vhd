-- i2c_wrapper_pkg.vhd
-- ------------------------------------
-- Isolate the components for a cleaner top level
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- Xilinx components must still be declared, putting them here cleans up the
-- architecture

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;

use work.counting_buttons_pkg.all;

package i2c_wrapper_pkg is

  component i2c_temp is
    generic
    (
      SMOOTHING    : integer := 16;
      INTERVAL     : integer := 1000000000;
      NUM_SEGMENTS : integer := 8;
      CLK_PER      : integer := 10
    );
    port
    (
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

      -- Data to be displayed
      temp_valid : out    std_logic;
      encoded    : out array_t (NUM_SEGMENTS-1 downto 0)(3 downto 0)
    );
    end component;
    
end package i2c_wrapper_pkg;
