LIBRARY IEEE, XPM;
USE IEEE.std_logic_1164.all;
USE IEEE.std_logic_SIGNED.all;
USE ieee.numeric_std.all;
use IEEE.math_real.all;
use XPM.vcomponents.all;

entity text_rom is
  port (clock      : in  std_logic;
        index      : in  std_logic_vector(7 downto 0);
        sub_index  : in  std_logic_vector(2 downto 0);

        bitmap_out : out std_logic_vector(7 downto 0));
end entity text_rom;

architecture rtl of text_rom is
  signal bitmap      : std_logic_vector(7 downto 0); -- 8 bit horizontal slice of character
  signal bitmap_flip : std_logic_vector(7 downto 0);
begin

  process (all) begin
    for i in 0 to 7 loop
      bitmap_out(i) <= bitmap(7-i);
    end loop;
  end process;

  process (clock) begin
    if rising_edge(clock) then
      case index & sub_index is
        -- Middle Fill Bar - Empty
        when x"00" & "000" => bitmap <= x"00";
        when x"00" & "001" => bitmap <= x"FF";
        when x"00" & "010" => bitmap <= x"00";
        when x"00" & "011" => bitmap <= x"00";
        when x"00" & "100" => bitmap <= x"00";
        when x"00" & "101" => bitmap <= x"00";
        when x"00" & "110" => bitmap <= x"FF";
        when x"00" & "111" => bitmap <= x"00";
        -- Middle Fill Bar - 1/8
        when x"01" & "000" => bitmap <= x"00";
        when x"01" & "001" => bitmap <= x"FF";
        when x"01" & "010" => bitmap <= x"80";
        when x"01" & "011" => bitmap <= x"80";
        when x"01" & "100" => bitmap <= x"80";
        when x"01" & "101" => bitmap <= x"80";
        when x"01" & "110" => bitmap <= x"FF";
        when x"01" & "111" => bitmap <= x"00";
        -- Middle Fill Bar - 2/8
        when x"02" & "000" => bitmap <= x"00";
        when x"02" & "001" => bitmap <= x"FF";
        when x"02" & "010" => bitmap <= x"C0";
        when x"02" & "011" => bitmap <= x"C0";
        when x"02" & "100" => bitmap <= x"C0";
        when x"02" & "101" => bitmap <= x"C0";
        when x"02" & "110" => bitmap <= x"FF";
        when x"02" & "111" => bitmap <= x"00";
        -- Middle Fill Bar - 3/8
        when x"03" & "000" => bitmap <= x"00";
        when x"03" & "001" => bitmap <= x"FF";
        when x"03" & "010" => bitmap <= x"E0";
        when x"03" & "011" => bitmap <= x"E0";
        when x"03" & "100" => bitmap <= x"E0";
        when x"03" & "101" => bitmap <= x"E0";
        when x"03" & "110" => bitmap <= x"FF";
        when x"03" & "111" => bitmap <= x"00";
        -- Middle Fill Bar - 4/8
        when x"04" & "000" => bitmap <= x"00";
        when x"04" & "001" => bitmap <= x"FF";
        when x"04" & "010" => bitmap <= x"F0";
        when x"04" & "011" => bitmap <= x"F0";
        when x"04" & "100" => bitmap <= x"F0";
        when x"04" & "101" => bitmap <= x"F0";
        when x"04" & "110" => bitmap <= x"FF";
        when x"04" & "111" => bitmap <= x"00";
        -- Middle Fill Bar - 5/8
        when x"05" & "000" => bitmap <= x"00";
        when x"05" & "001" => bitmap <= x"FF";
        when x"05" & "010" => bitmap <= x"F8";
        when x"05" & "011" => bitmap <= x"F8";
        when x"05" & "100" => bitmap <= x"F8";
        when x"05" & "101" => bitmap <= x"F8";
        when x"05" & "110" => bitmap <= x"FF";
        when x"05" & "111" => bitmap <= x"00";
        -- Middle Fill Bar - 6/8
        when x"06" & "000" => bitmap <= x"00";
        when x"06" & "001" => bitmap <= x"FF";
        when x"06" & "010" => bitmap <= x"FC";
        when x"06" & "011" => bitmap <= x"FC";
        when x"06" & "100" => bitmap <= x"FC";
        when x"06" & "101" => bitmap <= x"FC";
        when x"06" & "110" => bitmap <= x"FF";
        when x"06" & "111" => bitmap <= x"00";
        -- Middle Fill Bar - 7/8
        when x"07" & "000" => bitmap <= x"00";
        when x"07" & "001" => bitmap <= x"FF";
        when x"07" & "010" => bitmap <= x"FE";
        when x"07" & "011" => bitmap <= x"FE";
        when x"07" & "100" => bitmap <= x"FE";
        when x"07" & "101" => bitmap <= x"FE";
        when x"07" & "110" => bitmap <= x"FF";
        when x"07" & "111" => bitmap <= x"00";
        -- Middle Fill Bar - Full
        when x"08" & "000" => bitmap <= x"00";
        when x"08" & "001" => bitmap <= x"FF";
        when x"08" & "010" => bitmap <= x"FF";
        when x"08" & "011" => bitmap <= x"FF";
        when x"08" & "100" => bitmap <= x"FF";
        when x"08" & "101" => bitmap <= x"FF";
        when x"08" & "110" => bitmap <= x"FF";
        when x"08" & "111" => bitmap <= x"00";
        -- Left edge of fill bar
        when x"09" & "000" => bitmap <= x"00";
        when x"09" & "001" => bitmap <= x"00";
        when x"09" & "010" => bitmap <= x"01";
        when x"09" & "011" => bitmap <= x"01";
        when x"09" & "100" => bitmap <= x"01";
        when x"09" & "101" => bitmap <= x"01";
        when x"09" & "110" => bitmap <= x"00";
        when x"09" & "111" => bitmap <= x"00";
        -- Right edge of fill bar
        when x"0A" & "000" => bitmap <= x"00";
        when x"0A" & "001" => bitmap <= x"00";
        when x"0A" & "010" => bitmap <= x"10";
        when x"0A" & "011" => bitmap <= x"10";
        when x"0A" & "100" => bitmap <= x"10";
        when x"0A" & "101" => bitmap <= x"10";
        when x"0A" & "110" => bitmap <= x"00";
        when x"0A" & "111" => bitmap <= x"00";
        -- Copyright Symbol
        when x"0B" & "000" => bitmap <= x"3C";
        when x"0B" & "001" => bitmap <= x"42";
        when x"0B" & "010" => bitmap <= x"5A";
        when x"0B" & "011" => bitmap <= x"52";
        when x"0B" & "100" => bitmap <= x"5A";
        when x"0B" & "101" => bitmap <= x"42";
        when x"0B" & "110" => bitmap <= x"3C";
        when x"0B" & "111" => bitmap <= x"00";
        -- Space
        when x"20" & "000" => bitmap <= x"00";
        when x"20" & "001" => bitmap <= x"00";
        when x"20" & "010" => bitmap <= x"00";
        when x"20" & "011" => bitmap <= x"00";
        when x"20" & "100" => bitmap <= x"00";
        when x"20" & "101" => bitmap <= x"00";
        when x"20" & "110" => bitmap <= x"00";
        when x"20" & "111" => bitmap <= x"00";
        -- "
        when x"22" & "000" => bitmap <= x"6C";
        when x"22" & "001" => bitmap <= x"6C";
        when x"22" & "010" => bitmap <= x"00";
        when x"22" & "011" => bitmap <= x"00";
        when x"22" & "100" => bitmap <= x"00";
        when x"22" & "101" => bitmap <= x"00";
        when x"22" & "110" => bitmap <= x"00";
        when x"22" & "111" => bitmap <= x"00";
        -- + - 178
        when x"2B" & "000" => bitmap <= x"00";
        when x"2B" & "001" => bitmap <= x"30";
        when x"2B" & "010" => bitmap <= x"30";
        when x"2B" & "011" => bitmap <= x"FC";
        when x"2B" & "100" => bitmap <= x"30";
        when x"2B" & "101" => bitmap <= x"30";
        when x"2B" & "110" => bitmap <= x"00";
        when x"2B" & "111" => bitmap <= x"00";
        -- - - 178
        when x"2D" & "000" => bitmap <= x"00";
        when x"2D" & "001" => bitmap <= x"00";
        when x"2D" & "010" => bitmap <= x"00";
        when x"2D" & "011" => bitmap <= x"FC";
        when x"2D" & "100" => bitmap <= x"00";
        when x"2D" & "101" => bitmap <= x"00";
        when x"2D" & "110" => bitmap <= x"00";
        when x"2D" & "111" => bitmap <= x"00";
        -- .
        when x"2E" & "000" => bitmap <= x"00";
        when x"2E" & "001" => bitmap <= x"00";
        when x"2E" & "010" => bitmap <= x"00";
        when x"2E" & "011" => bitmap <= x"00";
        when x"2E" & "100" => bitmap <= x"00";
        when x"2E" & "101" => bitmap <= x"30";
        when x"2E" & "110" => bitmap <= x"30";
        when x"2E" & "111" => bitmap <= x"00";
        -- 0 - 1a0
        when x"30" & "000" => bitmap <= x"7C";
        when x"30" & "001" => bitmap <= x"C6";
        when x"30" & "010" => bitmap <= x"CE";
        when x"30" & "011" => bitmap <= x"D6";
        when x"30" & "100" => bitmap <= x"E6";
        when x"30" & "101" => bitmap <= x"C6";
        when x"30" & "110" => bitmap <= x"7C";
        when x"30" & "111" => bitmap <= x"00";
        -- 1
        when x"31" & "000" => bitmap <= x"30";
        when x"31" & "001" => bitmap <= x"70";
        when x"31" & "010" => bitmap <= x"30";
        when x"31" & "011" => bitmap <= x"30";
        when x"31" & "100" => bitmap <= x"30";
        when x"31" & "101" => bitmap <= x"30";
        when x"31" & "110" => bitmap <= x"FC";
        when x"31" & "111" => bitmap <= x"00";
        -- 2
        when x"32" & "000" => bitmap <= x"78";
        when x"32" & "001" => bitmap <= x"CC";
        when x"32" & "010" => bitmap <= x"0C";
        when x"32" & "011" => bitmap <= x"38";
        when x"32" & "100" => bitmap <= x"60";
        when x"32" & "101" => bitmap <= x"C0";
        when x"32" & "110" => bitmap <= x"FC";
        when x"32" & "111" => bitmap <= x"00";
        -- 3
        when x"33" & "000" => bitmap <= x"78";
        when x"33" & "001" => bitmap <= x"CC";
        when x"33" & "010" => bitmap <= x"0C";
        when x"33" & "011" => bitmap <= x"38";
        when x"33" & "100" => bitmap <= x"0C";
        when x"33" & "101" => bitmap <= x"CC";
        when x"33" & "110" => bitmap <= x"78";
        when x"33" & "111" => bitmap <= x"00";
        -- 4
        when x"34" & "000" => bitmap <= x"1C";
        when x"34" & "001" => bitmap <= x"34";
        when x"34" & "010" => bitmap <= x"6C";
        when x"34" & "011" => bitmap <= x"CC";
        when x"34" & "100" => bitmap <= x"FE";
        when x"34" & "101" => bitmap <= x"0C";
        when x"34" & "110" => bitmap <= x"0C";
        when x"34" & "111" => bitmap <= x"00";
        -- 5
        when x"35" & "000" => bitmap <= x"FC";
        when x"35" & "001" => bitmap <= x"C0";
        when x"35" & "010" => bitmap <= x"F8";
        when x"35" & "011" => bitmap <= x"0C";
        when x"35" & "100" => bitmap <= x"0C";
        when x"35" & "101" => bitmap <= x"CC";
        when x"35" & "110" => bitmap <= x"78";
        when x"35" & "111" => bitmap <= x"00";
        -- 6
        when x"36" & "000" => bitmap <= x"38";
        when x"36" & "001" => bitmap <= x"60";
        when x"36" & "010" => bitmap <= x"C0";
        when x"36" & "011" => bitmap <= x"F8";
        when x"36" & "100" => bitmap <= x"CC";
        when x"36" & "101" => bitmap <= x"CC";
        when x"36" & "110" => bitmap <= x"78";
        when x"36" & "111" => bitmap <= x"00";
        -- 7
        when x"37" & "000" => bitmap <= x"FC";
        when x"37" & "001" => bitmap <= x"0C";
        when x"37" & "010" => bitmap <= x"0C";
        when x"37" & "011" => bitmap <= x"18";
        when x"37" & "100" => bitmap <= x"30";
        when x"37" & "101" => bitmap <= x"60";
        when x"37" & "110" => bitmap <= x"60";
        when x"37" & "111" => bitmap <= x"00";
        -- 8
        when x"38" & "000" => bitmap <= x"78";
        when x"38" & "001" => bitmap <= x"CC";
        when x"38" & "010" => bitmap <= x"CC";
        when x"38" & "011" => bitmap <= x"78";
        when x"38" & "100" => bitmap <= x"CC";
        when x"38" & "101" => bitmap <= x"CC";
        when x"38" & "110" => bitmap <= x"78";
        when x"38" & "111" => bitmap <= x"00";
        -- 9
        when x"39" & "000" => bitmap <= x"78";
        when x"39" & "001" => bitmap <= x"CC";
        when x"39" & "010" => bitmap <= x"CC";
        when x"39" & "011" => bitmap <= x"7C";
        when x"39" & "100" => bitmap <= x"0C";
        when x"39" & "101" => bitmap <= x"18";
        when x"39" & "110" => bitmap <= x"70";
        when x"39" & "111" => bitmap <= x"00";
        -- :
        when x"3A" & "000" => bitmap <= x"00";
        when x"3A" & "001" => bitmap <= x"00";
        when x"3A" & "010" => bitmap <= x"30";
        when x"3A" & "011" => bitmap <= x"30";
        when x"3A" & "100" => bitmap <= x"00";
        when x"3A" & "101" => bitmap <= x"30";
        when x"3A" & "110" => bitmap <= x"30";
        when x"3A" & "111" => bitmap <= x"00";
        -- @ - 220
        when x"40" & "000" => bitmap <= x"7C";
        when x"40" & "001" => bitmap <= x"82";
        when x"40" & "010" => bitmap <= x"9E";
        when x"40" & "011" => bitmap <= x"86";
        when x"40" & "100" => bitmap <= x"9E";
        when x"40" & "101" => bitmap <= x"80";
        when x"40" & "110" => bitmap <= x"78";
        when x"40" & "111" => bitmap <= x"00";
        -- A
        when x"41" & "000" => bitmap <= x"30";
        when x"41" & "001" => bitmap <= x"78";
        when x"41" & "010" => bitmap <= x"CC";
        when x"41" & "011" => bitmap <= x"CC";
        when x"41" & "100" => bitmap <= x"FC";
        when x"41" & "101" => bitmap <= x"CC";
        when x"41" & "110" => bitmap <= x"CC";
        when x"41" & "111" => bitmap <= x"00";
        -- B
        when x"42" & "000" => bitmap <= x"FC";
        when x"42" & "001" => bitmap <= x"66";
        when x"42" & "010" => bitmap <= x"66";
        when x"42" & "011" => bitmap <= x"7C";
        when x"42" & "100" => bitmap <= x"66";
        when x"42" & "101" => bitmap <= x"66";
        when x"42" & "110" => bitmap <= x"FC";
        when x"42" & "111" => bitmap <= x"00";
        -- C
        when x"43" & "000" => bitmap <= x"3C";
        when x"43" & "001" => bitmap <= x"66";
        when x"43" & "010" => bitmap <= x"C0";
        when x"43" & "011" => bitmap <= x"C0";
        when x"43" & "100" => bitmap <= x"C0";
        when x"43" & "101" => bitmap <= x"66";
        when x"43" & "110" => bitmap <= x"3C";
        when x"43" & "111" => bitmap <= x"00";
        -- D
        when x"44" & "000" => bitmap <= x"F8";
        when x"44" & "001" => bitmap <= x"6C";
        when x"44" & "010" => bitmap <= x"66";
        when x"44" & "011" => bitmap <= x"66";
        when x"44" & "100" => bitmap <= x"66";
        when x"44" & "101" => bitmap <= x"6C";
        when x"44" & "110" => bitmap <= x"F8";
        when x"44" & "111" => bitmap <= x"00";
        -- E
        when x"45" & "000" => bitmap <= x"FE";
        when x"45" & "001" => bitmap <= x"C2";
        when x"45" & "010" => bitmap <= x"C8";
        when x"45" & "011" => bitmap <= x"F8";
        when x"45" & "100" => bitmap <= x"C8";
        when x"45" & "101" => bitmap <= x"C2";
        when x"45" & "110" => bitmap <= x"FE";
        when x"45" & "111" => bitmap <= x"00";
        -- F
        when x"46" & "000" => bitmap <= x"FE";
        when x"46" & "001" => bitmap <= x"C2";
        when x"46" & "010" => bitmap <= x"C8";
        when x"46" & "011" => bitmap <= x"F8";
        when x"46" & "100" => bitmap <= x"C8";
        when x"46" & "101" => bitmap <= x"C0";
        when x"46" & "110" => bitmap <= x"C0";
        when x"46" & "111" => bitmap <= x"00";
        -- G
        when x"47" & "000" => bitmap <= x"3C";
        when x"47" & "001" => bitmap <= x"66";
        when x"47" & "010" => bitmap <= x"C0";
        when x"47" & "011" => bitmap <= x"C0";
        when x"47" & "100" => bitmap <= x"CE";
        when x"47" & "101" => bitmap <= x"66";
        when x"47" & "110" => bitmap <= x"3E";
        when x"47" & "111" => bitmap <= x"00";
        -- H
        when x"48" & "000" => bitmap <= x"C6";
        when x"48" & "001" => bitmap <= x"C6";
        when x"48" & "010" => bitmap <= x"C6";
        when x"48" & "011" => bitmap <= x"FE";
        when x"48" & "100" => bitmap <= x"C6";
        when x"48" & "101" => bitmap <= x"C6";
        when x"48" & "110" => bitmap <= x"C6";
        when x"48" & "111" => bitmap <= x"00";
        -- I
        when x"49" & "000" => bitmap <= x"3C";
        when x"49" & "001" => bitmap <= x"18";
        when x"49" & "010" => bitmap <= x"18";
        when x"49" & "011" => bitmap <= x"18";
        when x"49" & "100" => bitmap <= x"18";
        when x"49" & "101" => bitmap <= x"18";
        when x"49" & "110" => bitmap <= x"3C";
        when x"49" & "111" => bitmap <= x"00";
        -- J
        when x"4A" & "000" => bitmap <= x"0E";
        when x"4A" & "001" => bitmap <= x"06";
        when x"4A" & "010" => bitmap <= x"06";
        when x"4A" & "011" => bitmap <= x"06";
        when x"4A" & "100" => bitmap <= x"66";
        when x"4A" & "101" => bitmap <= x"66";
        when x"4A" & "110" => bitmap <= x"3C";
        when x"4A" & "111" => bitmap <= x"00";
        -- K
        when x"4B" & "000" => bitmap <= x"C6";
        when x"4B" & "001" => bitmap <= x"CC";
        when x"4B" & "010" => bitmap <= x"D8";
        when x"4B" & "011" => bitmap <= x"F0";
        when x"4B" & "100" => bitmap <= x"D8";
        when x"4B" & "101" => bitmap <= x"CC";
        when x"4B" & "110" => bitmap <= x"C6";
        when x"4B" & "111" => bitmap <= x"00";
        -- L - 280
        when x"4C" & "000" => bitmap <= x"F0";
        when x"4C" & "001" => bitmap <= x"60";
        when x"4C" & "010" => bitmap <= x"60";
        when x"4C" & "011" => bitmap <= x"60";
        when x"4C" & "100" => bitmap <= x"60";
        when x"4C" & "101" => bitmap <= x"62";
        when x"4C" & "110" => bitmap <= x"FE";
        when x"4C" & "111" => bitmap <= x"00";
        -- M
        when x"4D" & "000" => bitmap <= x"82";
        when x"4D" & "001" => bitmap <= x"C6";
        when x"4D" & "010" => bitmap <= x"EE";
        when x"4D" & "011" => bitmap <= x"D6";
        when x"4D" & "100" => bitmap <= x"D6";
        when x"4D" & "101" => bitmap <= x"C6";
        when x"4D" & "110" => bitmap <= x"C6";
        when x"4D" & "111" => bitmap <= x"00";
        -- N
        when x"4E" & "000" => bitmap <= x"C6";
        when x"4E" & "001" => bitmap <= x"E6";
        when x"4E" & "010" => bitmap <= x"F6";
        when x"4E" & "011" => bitmap <= x"DE";
        when x"4E" & "100" => bitmap <= x"CE";
        when x"4E" & "101" => bitmap <= x"C6";
        when x"4E" & "110" => bitmap <= x"C6";
        when x"4E" & "111" => bitmap <= x"00";
        -- O
        when x"4F" & "000" => bitmap <= x"38";
        when x"4F" & "001" => bitmap <= x"6C";
        when x"4F" & "010" => bitmap <= x"C6";
        when x"4F" & "011" => bitmap <= x"C6";
        when x"4F" & "100" => bitmap <= x"c6";
        when x"4F" & "101" => bitmap <= x"6C";
        when x"4F" & "110" => bitmap <= x"38";
        when x"4F" & "111" => bitmap <= x"00";
        -- P - 2A0
        when x"50" & "000" => bitmap <= x"FC";
        when x"50" & "001" => bitmap <= x"66";
        when x"50" & "010" => bitmap <= x"66";
        when x"50" & "011" => bitmap <= x"66";
        when x"50" & "100" => bitmap <= x"7C";
        when x"50" & "101" => bitmap <= x"60";
        when x"50" & "110" => bitmap <= x"F0";
        when x"50" & "111" => bitmap <= x"00";
        -- Q
        when x"51" & "000" => bitmap <= x"38";
        when x"51" & "001" => bitmap <= x"6C";
        when x"51" & "010" => bitmap <= x"C6";
        when x"51" & "011" => bitmap <= x"C6";
        when x"51" & "100" => bitmap <= x"D6";
        when x"51" & "101" => bitmap <= x"6C";
        when x"51" & "110" => bitmap <= x"3C";
        when x"51" & "111" => bitmap <= x"06";
        -- R
        when x"52" & "000" => bitmap <= x"F8";
        when x"52" & "001" => bitmap <= x"CC";
        when x"52" & "010" => bitmap <= x"CC";
        when x"52" & "011" => bitmap <= x"F8";
        when x"52" & "100" => bitmap <= x"D8";
        when x"52" & "101" => bitmap <= x"CC";
        when x"52" & "110" => bitmap <= x"C6";
        when x"52" & "111" => bitmap <= x"00";
        -- S
        when x"53" & "000" => bitmap <= x"7C";
        when x"53" & "001" => bitmap <= x"C6";
        when x"53" & "010" => bitmap <= x"E0";
        when x"53" & "011" => bitmap <= x"3C";
        when x"53" & "100" => bitmap <= x"06";
        when x"53" & "101" => bitmap <= x"C6";
        when x"53" & "110" => bitmap <= x"7C";
        when x"53" & "111" => bitmap <= x"00";
        -- T - 2C0
        when x"54" & "000" => bitmap <= x"7E";
        when x"54" & "001" => bitmap <= x"5A";
        when x"54" & "010" => bitmap <= x"18";
        when x"54" & "011" => bitmap <= x"18";
        when x"54" & "100" => bitmap <= x"18";
        when x"54" & "101" => bitmap <= x"18";
        when x"54" & "110" => bitmap <= x"18";
        when x"54" & "111" => bitmap <= x"00";
        -- U
        when x"55" & "000" => bitmap <= x"C6";
        when x"55" & "001" => bitmap <= x"C6";
        when x"55" & "010" => bitmap <= x"C6";
        when x"55" & "011" => bitmap <= x"C6";
        when x"55" & "100" => bitmap <= x"C6";
        when x"55" & "101" => bitmap <= x"C6";
        when x"55" & "110" => bitmap <= x"7C";
        when x"55" & "111" => bitmap <= x"00";
        -- V
        when x"56" & "000" => bitmap <= x"C6";
        when x"56" & "001" => bitmap <= x"C6";
        when x"56" & "010" => bitmap <= x"C6";
        when x"56" & "011" => bitmap <= x"C6";
        when x"56" & "100" => bitmap <= x"6C";
        when x"56" & "101" => bitmap <= x"38";
        when x"56" & "110" => bitmap <= x"10";
        when x"56" & "111" => bitmap <= x"00";
        -- W
        when x"57" & "000" => bitmap <= x"C6";
        when x"57" & "001" => bitmap <= x"C6";
        when x"57" & "010" => bitmap <= x"C6";
        when x"57" & "011" => bitmap <= x"D6";
        when x"57" & "100" => bitmap <= x"D6";
        when x"57" & "101" => bitmap <= x"6C";
        when x"57" & "110" => bitmap <= x"6C";
        when x"57" & "111" => bitmap <= x"00";
        -- X
        when x"58" & "000" => bitmap <= x"C6";
        when x"58" & "001" => bitmap <= x"C6";
        when x"58" & "010" => bitmap <= x"6C";
        when x"58" & "011" => bitmap <= x"38";
        when x"58" & "100" => bitmap <= x"6C";
        when x"58" & "101" => bitmap <= x"C6";
        when x"58" & "110" => bitmap <= x"C6";
        when x"58" & "111" => bitmap <= x"00";
        -- Y
        when x"59" & "000" => bitmap <= x"66";
        when x"59" & "001" => bitmap <= x"66";
        when x"59" & "010" => bitmap <= x"66";
        when x"59" & "011" => bitmap <= x"3C";
        when x"59" & "100" => bitmap <= x"18";
        when x"59" & "101" => bitmap <= x"18";
        when x"59" & "110" => bitmap <= x"18";
        when x"59" & "111" => bitmap <= x"00";
        -- Z - 2F0
        when x"5A" & "000" => bitmap <= x"FE";
        when x"5A" & "001" => bitmap <= x"8C";
        when x"5A" & "010" => bitmap <= x"18";
        when x"5A" & "011" => bitmap <= x"30";
        when x"5A" & "100" => bitmap <= x"60";
        when x"5A" & "101" => bitmap <= x"C2";
        when x"5A" & "110" => bitmap <= x"FE";
        when x"5A" & "111" => bitmap <= x"00";
        -- a
        when x"61" & "000" => bitmap <= x"00";
        when x"61" & "001" => bitmap <= x"00";
        when x"61" & "010" => bitmap <= x"78";
        when x"61" & "011" => bitmap <= x"0C";
        when x"61" & "100" => bitmap <= x"7C";
        when x"61" & "101" => bitmap <= x"CC";
        when x"61" & "110" => bitmap <= x"76";
        when x"61" & "111" => bitmap <= x"00";
        -- b - 330
        when x"62" & "000" => bitmap <= x"E0";
        when x"62" & "001" => bitmap <= x"60";
        when x"62" & "010" => bitmap <= x"7C";
        when x"62" & "011" => bitmap <= x"66";
        when x"62" & "100" => bitmap <= x"66";
        when x"62" & "101" => bitmap <= x"66";
        when x"62" & "110" => bitmap <= x"DC";
        when x"62" & "111" => bitmap <= x"00";
        -- c
        when x"63" & "000" => bitmap <= x"00";
        when x"63" & "001" => bitmap <= x"00";
        when x"63" & "010" => bitmap <= x"7C";
        when x"63" & "011" => bitmap <= x"C6";
        when x"63" & "100" => bitmap <= x"C0";
        when x"63" & "101" => bitmap <= x"C6";
        when x"63" & "110" => bitmap <= x"7C";
        when x"63" & "111" => bitmap <= x"00";
        -- d
        when x"64" & "000" => bitmap <= x"1C";
        when x"64" & "001" => bitmap <= x"0C";
        when x"64" & "010" => bitmap <= x"7C";
        when x"64" & "011" => bitmap <= x"CC";
        when x"64" & "100" => bitmap <= x"CC";
        when x"64" & "101" => bitmap <= x"CC";
        when x"64" & "110" => bitmap <= x"76";
        when x"64" & "111" => bitmap <= x"00";
        -- e
        when x"65" & "000" => bitmap <= x"00";
        when x"65" & "001" => bitmap <= x"00";
        when x"65" & "010" => bitmap <= x"3C";
        when x"65" & "011" => bitmap <= x"66";
        when x"65" & "100" => bitmap <= x"7E";
        when x"65" & "101" => bitmap <= x"60";
        when x"65" & "110" => bitmap <= x"3C";
        when x"65" & "111" => bitmap <= x"00";
        -- f
        when x"66" & "000" => bitmap <= x"1C";
        when x"66" & "001" => bitmap <= x"36";
        when x"66" & "010" => bitmap <= x"30";
        when x"66" & "011" => bitmap <= x"7E";
        when x"66" & "100" => bitmap <= x"30";
        when x"66" & "101" => bitmap <= x"30";
        when x"66" & "110" => bitmap <= x"30";
        when x"66" & "111" => bitmap <= x"00";
        -- g
        when x"67" & "000" => bitmap <= x"00";
        when x"67" & "001" => bitmap <= x"00";
        when x"67" & "010" => bitmap <= x"76";
        when x"67" & "011" => bitmap <= x"CC";
        when x"67" & "100" => bitmap <= x"CC";
        when x"67" & "101" => bitmap <= x"7C";
        when x"67" & "110" => bitmap <= x"0C";
        when x"67" & "111" => bitmap <= x"F8";
        -- h - 360
        when x"68" & "000" => bitmap <= x"60";
        when x"68" & "001" => bitmap <= x"60";
        when x"68" & "010" => bitmap <= x"7C";
        when x"68" & "011" => bitmap <= x"66";
        when x"68" & "100" => bitmap <= x"66";
        when x"68" & "101" => bitmap <= x"66";
        when x"68" & "110" => bitmap <= x"66";
        when x"68" & "111" => bitmap <= x"00";
        -- i
        when x"69" & "000" => bitmap <= x"18";
        when x"69" & "001" => bitmap <= x"00";
        when x"69" & "010" => bitmap <= x"38";
        when x"69" & "011" => bitmap <= x"18";
        when x"69" & "100" => bitmap <= x"18";
        when x"69" & "101" => bitmap <= x"18";
        when x"69" & "110" => bitmap <= x"7e";
        when x"69" & "111" => bitmap <= x"00";
        -- j
        when x"6A" & "000" => bitmap <= x"0C";
        when x"6A" & "001" => bitmap <= x"00";
        when x"6A" & "010" => bitmap <= x"3C";
        when x"6A" & "011" => bitmap <= x"0C";
        when x"6A" & "100" => bitmap <= x"0C";
        when x"6A" & "101" => bitmap <= x"0C";
        when x"6A" & "110" => bitmap <= x"6C";
        when x"6A" & "111" => bitmap <= x"38";
        -- k
        when x"6B" & "000" => bitmap <= x"60";
        when x"6B" & "001" => bitmap <= x"60";
        when x"6B" & "010" => bitmap <= x"66";
        when x"6B" & "011" => bitmap <= x"6C";
        when x"6B" & "100" => bitmap <= x"78";
        when x"6B" & "101" => bitmap <= x"6C";
        when x"6B" & "110" => bitmap <= x"66";
        when x"6B" & "111" => bitmap <= x"00";
        -- l
        when x"6C" & "000" => bitmap <= x"38";
        when x"6C" & "001" => bitmap <= x"18";
        when x"6C" & "010" => bitmap <= x"18";
        when x"6C" & "011" => bitmap <= x"18";
        when x"6C" & "100" => bitmap <= x"18";
        when x"6C" & "101" => bitmap <= x"18";
        when x"6C" & "110" => bitmap <= x"7E";
        when x"6C" & "111" => bitmap <= x"00";
        -- m
        when x"6D" & "000" => bitmap <= x"00";
        when x"6D" & "001" => bitmap <= x"00";
        when x"6D" & "010" => bitmap <= x"CC";
        when x"6D" & "011" => bitmap <= x"FE";
        when x"6D" & "100" => bitmap <= x"D6";
        when x"6D" & "101" => bitmap <= x"D6";
        when x"6D" & "110" => bitmap <= x"C6";
        when x"6D" & "111" => bitmap <= x"00";
        -- n - 390
        when x"6E" & "000" => bitmap <= x"00";
        when x"6E" & "001" => bitmap <= x"00";
        when x"6E" & "010" => bitmap <= x"DC";
        when x"6E" & "011" => bitmap <= x"66";
        when x"6E" & "100" => bitmap <= x"66";
        when x"6E" & "101" => bitmap <= x"66";
        when x"6E" & "110" => bitmap <= x"66";
        when x"6E" & "111" => bitmap <= x"00";
        -- o
        when x"6F" & "000" => bitmap <= x"00";
        when x"6F" & "001" => bitmap <= x"00";
        when x"6F" & "010" => bitmap <= x"7C";
        when x"6F" & "011" => bitmap <= x"C6";
        when x"6F" & "100" => bitmap <= x"C6";
        when x"6F" & "101" => bitmap <= x"C6";
        when x"6F" & "110" => bitmap <= x"7C";
        when x"6F" & "111" => bitmap <= x"00";
        -- p
        when x"70" & "000" => bitmap <= x"00";
        when x"70" & "001" => bitmap <= x"00";
        when x"70" & "010" => bitmap <= x"DC";
        when x"70" & "011" => bitmap <= x"66";
        when x"70" & "100" => bitmap <= x"66";
        when x"70" & "101" => bitmap <= x"7C";
        when x"70" & "110" => bitmap <= x"60";
        when x"70" & "111" => bitmap <= x"E0";
        -- q
        when x"71" & "000" => bitmap <= x"00";
        when x"71" & "001" => bitmap <= x"00";
        when x"71" & "010" => bitmap <= x"76";
        when x"71" & "011" => bitmap <= x"CC";
        when x"71" & "100" => bitmap <= x"CC";
        when x"71" & "101" => bitmap <= x"7C";
        when x"71" & "110" => bitmap <= x"0C";
        when x"71" & "111" => bitmap <= x"0E";
        -- r
        when x"72" & "000" => bitmap <= x"00";
        when x"72" & "001" => bitmap <= x"00";
        when x"72" & "010" => bitmap <= x"DC";
        when x"72" & "011" => bitmap <= x"66";
        when x"72" & "100" => bitmap <= x"60";
        when x"72" & "101" => bitmap <= x"60";
        when x"72" & "110" => bitmap <= x"F0";
        when x"72" & "111" => bitmap <= x"00";
        -- s
        when x"73" & "000" => bitmap <= x"00";
        when x"73" & "001" => bitmap <= x"00";
        when x"73" & "010" => bitmap <= x"3E";
        when x"73" & "011" => bitmap <= x"60";
        when x"73" & "100" => bitmap <= x"3C";
        when x"73" & "101" => bitmap <= x"06";
        when x"73" & "110" => bitmap <= x"7C";
        when x"73" & "111" => bitmap <= x"00";
        -- t
        when x"74" & "000" => bitmap <= x"00";
        when x"74" & "001" => bitmap <= x"30";
        when x"74" & "010" => bitmap <= x"7E";
        when x"74" & "011" => bitmap <= x"30";
        when x"74" & "100" => bitmap <= x"30";
        when x"74" & "101" => bitmap <= x"36";
        when x"74" & "110" => bitmap <= x"1C";
        when x"74" & "111" => bitmap <= x"00";
        -- u
        when x"75" & "000" => bitmap <= x"00";
        when x"75" & "001" => bitmap <= x"00";
        when x"75" & "010" => bitmap <= x"CC";
        when x"75" & "011" => bitmap <= x"CC";
        when x"75" & "100" => bitmap <= x"CC";
        when x"75" & "101" => bitmap <= x"CC";
        when x"75" & "110" => bitmap <= x"76";
        when x"75" & "111" => bitmap <= x"00";
        -- v - 3d0
        when x"76" & "000" => bitmap <= x"00";
        when x"76" & "001" => bitmap <= x"00";
        when x"76" & "010" => bitmap <= x"66";
        when x"76" & "011" => bitmap <= x"66";
        when x"76" & "100" => bitmap <= x"66";
        when x"76" & "101" => bitmap <= x"3C";
        when x"76" & "110" => bitmap <= x"18";
        when x"76" & "111" => bitmap <= x"00";
        -- w
        when x"77" & "000" => bitmap <= x"00";
        when x"77" & "001" => bitmap <= x"00";
        when x"77" & "010" => bitmap <= x"C6";
        when x"77" & "011" => bitmap <= x"D6";
        when x"77" & "100" => bitmap <= x"D6";
        when x"77" & "101" => bitmap <= x"6C";
        when x"77" & "110" => bitmap <= x"6C";
        when x"77" & "111" => bitmap <= x"00";
        -- x
        when x"78" & "000" => bitmap <= x"00";
        when x"78" & "001" => bitmap <= x"00";
        when x"78" & "010" => bitmap <= x"C6";
        when x"78" & "011" => bitmap <= x"6C";
        when x"78" & "100" => bitmap <= x"38";
        when x"78" & "101" => bitmap <= x"6C";
        when x"78" & "110" => bitmap <= x"C6";
        when x"78" & "111" => bitmap <= x"00";
        -- y
        when x"79" & "000" => bitmap <= x"00";
        when x"79" & "001" => bitmap <= x"00";
        when x"79" & "010" => bitmap <= x"66";
        when x"79" & "011" => bitmap <= x"66";
        when x"79" & "100" => bitmap <= x"66";
        when x"79" & "101" => bitmap <= x"3C";
        when x"79" & "110" => bitmap <= x"18";
        when x"79" & "111" => bitmap <= x"70";
        -- z
        when x"7A" & "000" => bitmap <= x"00";
        when x"7A" & "001" => bitmap <= x"00";
        when x"7A" & "010" => bitmap <= x"7E";
        when x"7A" & "011" => bitmap <= x"4C";
        when x"7A" & "100" => bitmap <= x"18";
        when x"7A" & "101" => bitmap <= x"32";
        when x"7A" & "110" => bitmap <= x"7E";
        when x"7A" & "111" => bitmap <= x"00";
        when others        => bitmap <= x"00";
      end case;
    end if;
  end process;

end architecture rtl;
