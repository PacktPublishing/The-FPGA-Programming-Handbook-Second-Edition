library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity project_2 is
  generic(SELECTOR : string;
          BITS : integer := 16);
  port(SW: in std_logic_vector(BITS-1 downto 0);
       BTNC : in std_logic;
       BTNU : in std_logic;
       BTNL : in std_logic;
       BTNR : in std_logic;
       BTND : in std_logic;

       LED: out std_logic_vector(BITS-1 downto 0));
end entity project_2;

architecture rtl of project_2 is
  signal LO_LED : std_logic_vector(natural(log2(real(BITS))) downto 0);
  signal NO_LED : std_logic_vector(natural(log2(real(BITS))) downto 0);
  signal AD_LED : std_logic_vector(BITS-1 downto 0);
  signal SB_LED : std_logic_vector(BITS-1 downto 0);
  signal MULT_LED : std_logic_vector(BITS-1 downto 0);
begin

  u_lo : entity work.leading_ones
    generic map(SELECTOR => SELECTOR, BITS => BITS)
    port map(SW => SW, LED => LO_LED);
  u_ad : entity work.add_sub
    generic map(SELECTOR => "ADD", BITS => BITS)
    port map(SW => SW, LED => AD_LED);
  u_sb : entity work.add_sub
    generic map(SELECTOR => "SUB", BITS => BITS)
    port map(SW => SW, LED => SB_LED);
  u_no : entity work.num_ones
    generic map(BITS => BITS)
    port map(SW => SW, LED => NO_LED);
  u_mt : entity work.mult
    generic map(BITS => BITS)
    port map(SW => SW, LED => MULT_LED);

  btn_sel : process (all)
    variable sel : std_logic_vector(4 downto 0);
  begin
    sel := BTNC & BTNU & BTND & BTNL & BTNR;
    LED <= (others => '0');
    case? sel is
      when "1----" => LED <= MULT_LED;
      when "01---" => LED(natural(log2(real(BITS))) downto 0) <= LO_LED;
      when "001--" => LED(natural(log2(real(BITS))) downto 0) <= NO_LED;
      when "0001-" => LED <= AD_LED;
      when "00001" => LED <= SB_LED;
      when others  => LED <= (others => '0');
    end case?;
  end process btn_sel;
end architecture rtl;
