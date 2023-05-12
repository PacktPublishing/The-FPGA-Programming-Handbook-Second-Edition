LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE ieee.numeric_std.all;
use IEEE.math_real.all;
use WORK.temp_pkg.all;
use WORK.counting_buttons_pkg.all;

entity parallel is
  port (clk : in std_logic;
        in_data : array_t (255 downto 0)(31 downto 0);
        in_valid : in std_logic;

        out_data : out std_logic_vector(63 downto 0);
        out_valid : out std_logic);
end entity parallel;
architecture rtl of parallel is
  signal int_data0 : array_t (127 downto 0)(63 downto 0);
  signal int_data1 : array_t (63 downto 0)(63 downto 0);
  signal int_data2 : array_t (31 downto 0)(63 downto 0);
  signal int_data3 : array_t (15 downto 0)(63 downto 0);
  signal int_data4 : array_t (7 downto 0)(63 downto 0);
  signal int_data5 : array_t (3 downto 0)(63 downto 0);
  signal int_data6 : array_t (1 downto 0)(63 downto 0);
  signal int_valid : std_logic_vector(6 downto 0);
begin
  process (clk)
  begin
    if rising_edge(clk) then
      for i in 0 to 127 loop
        int_data0(i) <= std_logic_vector(signed(in_data(i*2+0)) + signed(in_data(i*2+1)));
      end loop;
      for i in 0 to 63 loop
        int_data1(i) <= std_logic_vector(signed(int_data0(i*2+0)) + signed(int_data0(i*2+1)));
      end loop;
      for i in 0 to 31 loop
        int_data2(i) <= std_logic_vector(signed(int_data1(i*2+0)) + signed(int_data1(i*2+1)));
      end loop;
      for i in 0 to 15 loop
        int_data3(i) <= std_logic_vector(signed(int_data2(i*2+0)) + signed(int_data2(i*2+1)));
      end loop;
      for i in 0 to 7 loop
        int_data4(i) <= std_logic_vector(signed(int_data3(i*2+0)) + signed(int_data3(i*2+1)));
      end loop;
      for i in 0 to 3 loop
        int_data5(i) <= std_logic_vector(signed(int_data4(i*2+0)) + signed(int_data4(i*2+1)));
      end loop;
      for i in 0 to 1 loop
        int_data6(i) <= std_logic_vector(signed(int_data5(i*2+0)) + signed(int_data5(i*2+1)));
      end loop;
      out_data  <= std_logic_vector(signed(int_data6(0)) + signed(int_data6(1)));
      int_valid <= int_valid(5 downto 0) & in_valid;
      out_valid <= int_valid(6);
    end if;      
  end process;
end architecture rtl;
