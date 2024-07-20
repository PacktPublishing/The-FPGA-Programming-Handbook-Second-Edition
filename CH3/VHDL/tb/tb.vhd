-- tb.vhd
-- ------------------------------------
-- Testbench for Project 2
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- Exhaustively test project_2

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity tb is
  generic(
  SELECTOR    : string;
  UNIQUE_CASE : string;
  TEST_CASE   : string
);
end entity tb;

architecture tb of tb is

  --constant SELECTOR : string  := "UP_FOR"; -- or "DOWN_FOR"
  constant BITS     : integer := 16;
  constant NUM_TEST : integer := 1000;

  -- Count number of bits set in the SW vector
  function no_func(SW : std_logic_vector) return natural is
    variable no : natural;
  begin
    no := 0;
    for i in SW'range loop
      if SW(i) then
        no := no + 1;
      end if;
    end loop;
    return no;
  end function no_func;

  -- Return one-based index of the leading one in the SW vector
  function lo_func(SW : std_logic_vector) return natural is
    variable lo : natural;
  begin
    lo := 0;
    for i in SW'high downto SW'low loop
      if SW(i) then
        lo := i + 1;
        exit;
      end if;
    end loop;
    return lo;
  end function lo_func;

  signal SW   : std_logic_vector(BITS - 1 downto 0);
  signal LED  : std_logic_vector(BITS - 1 downto 0);
  signal BTNC : std_logic;
  signal BTNU : std_logic;
  signal BTNL : std_logic;
  signal BTNR : std_logic;
  signal BTND : std_logic;
begin

  -- Unit under test
  u_alu : entity work.project_2
    generic map(
      SELECTOR => SELECTOR,
      BITS     => BITS
    )
    port map(
      SW   => SW,
      BTNC => BTNC,
      BTNU => BTNU,
      BTNL => BTNL,
      BTNR => BTNR,
      BTND => BTND,
      LED  => LED
    );

  -- Stimulus
  stimulus : process
    variable seed1, seed2 : positive;   -- seed values for random number generator
    variable rand_val     : real;       -- random real value 0 to 1.0
    variable button       : integer range 0 to 4;
  begin
    seed1 := 1;
    seed2 := 1;
    for i in 0 to NUM_TEST - 1 loop
      uniform(seed1, seed2, rand_val);  -- generate random number in range (0.0, 1.0)
      button := integer(trunc(rand_val * 5.0));
      BTNC   <= '0';
      BTNU   <= '0';
      BTNL   <= '0';
      BTNR   <= '0';
      BTND   <= '0';

      case button is
        when 0 => BTNC <= '1';
        when 1 => BTNU <= '1';
        when 2 => BTND <= '1';
        when 3 => BTNL <= '1';
        when 4 => BTNR <= '1';
      end case;

      uniform(seed1, seed2, rand_val);  -- generate random number
      SW <= std_logic_vector(to_unsigned(integer(trunc(rand_val * 65636.0)), SW'length));
      wait for 0 ps;                    -- wait for SW assignment to take effect
      report "setting SW to " & to_string(SW);
      wait for 100 ns;
    end loop;
    SW <= (others => '0');
    report "PASS: project_2 PASSED!";
    std.env.stop;
  end process stimulus;

  checker : process
    variable sw_add : signed(BITS - 1 downto 0);
    variable sw_sub : signed(BITS - 1 downto 0);
    variable sw_mul : signed(BITS - 1 downto 0);
  begin
    wait on SW;
    wait for 1 ps;
    if BTNU then
      if lo_func(SW) /= unsigned(LED) then
        report "FAIL: LED != leading 1's position" severity failure;
      end if;
    end if;
    if BTND then
      if no_func(SW) /= unsigned(LED) then
        report "FAIL: LED != number of ones represented by SW" severity failure;
      end if;
    end if;
    if BTNL then
      sw_add := resize(signed(SW(15 downto 8)), sw_add'length) + resize(signed(SW(7 downto 0)), sw_add'length);
      if sw_add /= signed(LED) then
        report "FAIL: LED != sum of SW[15:8] + SW[7:0] " & to_string(sw_add) & " != " & to_string(signed(LED)) severity failure;
      end if;
    end if;
    if BTNR then
      sw_sub := resize(signed(SW(15 downto 8)), sw_sub'length) - resize(signed(SW(7 downto 0)), sw_sub'length);
      if sw_sub /= signed(LED) then
        report "FAIL: LED != diff of SW[15:8] - SW[7:0] " & to_string(sw_sub) & " != " & to_string(signed(LED)) severity failure;
      end if;
    end if;
    if BTNC then
      sw_mul := signed(SW(15 downto 8)) * signed(SW(7 downto 0));
      if sw_mul /= signed(LED) then
        report "FAIL: LED != prod of SW[15:8] * SW[7:0]" severity failure;
      end if;
    end if;
  end process checker;
end architecture tb;
