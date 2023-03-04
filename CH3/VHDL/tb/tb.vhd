library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_misc.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;
use std.env.finish;

entity tb is
end entity tb;

architecture tb of tb is
  constant SELECTOR  : string := "UP_FOR";
  constant TEST_CASE : string := "ALL";
  constant BITS      : integer := 16;
  constant NUM_TEST  : integer := 1000;

  component project_1 is
    generic(SELECTOR : string := "";
            BITS : integer := 16);
    port(SW: in std_logic_vector(BITS-1 downto 0);
         BTNC : in std_logic;
         BTNU : in std_logic;
         BTNL : in std_logic;
         BTNR : in std_logic;
         BTND : in std_logic;

         LED: out std_logic_vector(BITS-1 downto 0));
  end component project_1;
  
  function no_func (signal SW : std_logic_vector(BITS-1 downto 0)) return unsigned is
    variable count : unsigned(natural(log2(real(BITS))) downto 0);
  begin   
    count := (others => '0');
    for i in SW'range loop
      count := resize(count + "0" & SW(i), 5);
    end loop;
    return count;
  end function no_func;  
  
  function lo_func (signal SW : std_logic_vector(BITS-1 downto 0)) return unsigned is
    variable count : unsigned(natural(log2(real(BITS))) downto 0);
  begin   
    count := (others => '0');
    for i in SW'range loop
      if SW(i) = '1' then
        count  := resize(TO_UNSIGNED(i, natural(log2(real(BITS)))) + 1, 5);
      end if;
    end loop;
    return count;
  end function lo_func;  
  
  signal SW   : std_logic_vector(BITS-1 downto 0);
  signal LED  : std_logic_vector(BITS-1 downto 0);
  signal BTNC : std_logic;
  signal BTNU : std_logic;
  signal BTNL : std_logic;
  signal BTNR : std_logic;
  signal BTND : std_logic;
  signal LO_LED : std_logic_vector(natural(log2(real(BITS))) downto 0);
  signal NO_LED : std_logic_vector(natural(log2(real(BITS))) downto 0);
  signal AD_LED : std_logic_vector(BITS/2-1 downto 0);
  signal SB_LED : std_logic_vector(BITS/2-1 downto 0);
  signal MULT_LED : std_logic_vector(BITS-1 downto 0);
  signal passed   : boolean := true;
begin
  u_alu : project_1
    generic map(SELECTOR => SELECTOR, BITS => BITS)
    port map(SW => SW, BTNC => BTNC, BTNU => BTNU, BTNL => BTNL, 
             BTNR => BTNR, BTND => BTND, LED => LED);

  -- Stimulus
  stimulus : process 
    variable seed1, seed2: positive;  -- seed values for random number generator
    variable rand_val: real;              -- random real value 0 to 1.0
    variable button : integer range 0 to 4;
  begin
  
    for i in 0 to NUM_TEST loop
      uniform(seed1, seed2, rand_val);              -- generate random number
      button := integer(trunc(rand_val*5.0));
      BTNC <= '0';
      BTNU <= '0';
      BTNL <= '0';
      BTNR <= '0';
      BTND <= '0';

      case button is
        when 0 => BTNC   <= '1';
        when 1 => BTNU   <= '1';
        when 2 => BTND   <= '1';
        when 3 => BTNL   <= '1';
        when 4 => BTNR   <= '1';
      end case;

      uniform(seed1, seed2, rand_val);              -- generate random number
      SW        <= std_logic_vector(to_unsigned(integer(trunc(rand_val*65636.0)), LED'length));
      report "setting SW to " & to_string(SW);
      wait for 100 ns;
    end loop;
    SW <= (others => '0');
    if passed then
      report "PASS: project_2 PASSED!";
    else
      report "FAIL: project_2 Failed";
    end if;  
    finish;
  end process stimulus;
  
  checker : process (all)
    variable sw_add : signed(7 downto 0);
    variable sw_sub : signed(7 downto 0);
    variable sw_mul : signed(15 downto 0);
  begin
    if BTNU then
      if lo_func(SW) /= unsigned(LED(natural(log2(real(BITS))) downto 0)) then
        report "FAIL: LED != leading 1's position";
      end if;
    end if;
    if BTND then
      if no_func(SW) /= unsigned(LED(natural(log2(real(BITS))) downto 0)) then
        report "FAIL: LED != number of ones represented by SW";
      end if;
    end if;
    if BTNL then
      sw_add := signed(SW(15 downto 8)) + signed(SW(7 downto 0));
      if sw_add /= signed(LED(BITS/2-1 downto 0)) then
        report "FAIL: LED != sum of SW[15:8] + SW[7:0] " & to_string(sw_add) & " != " & to_string(signed(LED(BITS/2-1 downto 0)));
      end if;
    end if;
    if BTNR then
      sw_sub := signed(SW(15 downto 8)) - signed(SW(7 downto 0));
      if sw_sub /= signed(LED(BITS/2-1 downto 0)) then
        report "FAIL: LED != dif of SW[15:8] - SW[7:0] " & to_string(sw_sub) & " != " & to_string(signed(LED(BITS/2-1 downto 0)));
      end if;
    end if;
    if BTNC then
      sw_mul := signed(SW(15 downto 8)) * signed(SW(7 downto 0));
      if sw_mul /= signed(LED(BITS-1 downto 0)) then
        report "FAIL: LED != sum of SW[15:8] + SW[7:0]";
      end if;
    end if;
  end process checker;
end architecture tb;