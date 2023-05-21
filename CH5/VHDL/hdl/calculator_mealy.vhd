-- calculator_mealy.vhd
-- ------------------------------------
-- Mealy version of the Calculator state machine
-- ------------------------------------
-- Author : Frank Bruno
-- A mealy version of the Calculator state machine
LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;
use IEEE.math_real.all;
use WORK.calculator_pkg.all;

entity calculator_mealy is
  generic (BITS : integer := 32);
  port (clk     : in std_logic;
        reset   : in std_logic;
        start   : in std_logic;
        buttons : in std_logic_vector(4 downto 0);
        switch  : in std_logic_vector(15 downto 0);

        accum   : out std_logic_vector(BITS-1 downto 0));
end entity calculator_mealy;

architecture rtl of calculator_mealy is

  attribute MARK_DEBUG : string;
  constant BC : natural := natural(log2(real(BITS)));
  signal last_op : std_logic_vector(4 downto 0);
  signal accumulator : std_logic_vector(BITS-1 downto 0) := (others => '0');
  attribute MARK_DEBUG of last_op     : signal is "TRUE";
  attribute MARK_DEBUG of accumulator : signal is "TRUE";
  type state_t is (IDLE, WAIT4BUTTON);
  signal state : state_t := IDLE;
  attribute MARK_DEBUG of state       : signal is "TRUE";

begin

  process (clk)
    variable multiply   : unsigned(BITS+16-1 downto 0);
    variable switch_int : unsigned(15 downto 0);
    variable accum_int  : unsigned(31 downto 0);
  begin
    if rising_edge(clk) then
      case state is
        when IDLE =>
          -- Wait for data to be operated on to be entered. Then the user presses
          -- The operation, add, sub, multiply, clear or equal
          last_op     <= buttons; -- operation to perform
          if start then
            state <= WAIT4BUTTON;
          end if;
        when WAIT4BUTTON =>
          -- wait for second data to be entered, then user presses next operation.
          -- In this case, if we get an =, we perform the operation and we're
          -- done. The user can also put in another operation to perform with
          -- a new value on the accumulator.
          state <= IDLE;
          if last_op(UP) then
            switch_int  := unsigned(switch);
            multiply    := unsigned(accumulator) * switch_int;
            -- note that even though the output is > 32 bits we will overflow
            -- if larger.
            accumulator <= std_logic_vector(multiply(31 downto 0));
          elsif last_op(DOWN) then
            state       <= IDLE;
          elsif last_op(LEFT) then
            switch_int  := unsigned(switch);
            accum_int   := unsigned(accumulator) + switch_int;
            accumulator <= std_logic_vector(accum_int(31 downto 0));
          elsif last_op(RIGHT) then
            switch_int  := unsigned(switch);
            accum_int   := unsigned(accumulator) - switch_int;
            accumulator <= std_logic_vector(accum_int(31 downto 0));
          else
            state <= IDLE;
          end if;
      end case;
      if reset then
        state       <= IDLE;
        accumulator <= (others => '0');
      end if;
    end if;
  end process;

  accum <= accumulator;
end architecture;
