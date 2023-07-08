-- calculator_moore.vhd
-- ------------------------------------
-- Moore version of the Calculator state machine
-- ------------------------------------
-- Author : Frank Bruno
-- A Moore version of the Calculator state machine

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;
use IEEE.math_real.all;
use WORK.calculator_pkg.all;

entity calculator_moore is
  generic(
    BITS : integer := 32
  );
  port(
    clk     : in  std_logic;
    reset   : in  std_logic;
    start   : in  std_logic;
    buttons : in  std_logic_vector(4 downto 0);
    switch  : in  std_logic_vector(15 downto 0);
    accum   : out std_logic_vector(BITS - 1 downto 0)
  );
end entity calculator_moore;

architecture rtl of calculator_moore is

  constant BC : natural := natural(ceil(log2(real(BITS))));

  type state_t is (IDLE, WAIT4BUTTON, ADD, SUB, MULT, RESET_S);

  signal op_store, last_op : std_logic_vector(4 downto 0);
  signal accumulator       : unsigned(BITS - 1 downto 0) := (others => '0');
  signal state             : state_t                     := IDLE;

  attribute MARK_DEBUG : string;
  attribute MARK_DEBUG of op_store : signal is "TRUE";
  attribute MARK_DEBUG of last_op : signal is "TRUE";
  attribute MARK_DEBUG of accumulator : signal is "TRUE";
  attribute MARK_DEBUG of state : signal is "TRUE";

begin

  process(clk)
    variable product : unsigned(BITS + 16 - 1 downto 0);
  begin
    if rising_edge(clk) then
      if reset then
        state       <= IDLE;
        accumulator <= (others => '0');
      else
        case state is
          when IDLE =>
            -- Wait for data to be operated on to be entered. Then the user presses
            -- The operation, add, sub, multiply, clear or equal
            last_op <= buttons;         -- operation to perform
            if start then
              state <= WAIT4BUTTON;
            end if;

          when WAIT4BUTTON =>
            -- Wait for second data to be entered, then user presses next operation.
            -- In this case, if we get an =, we perform the operation and we're
            -- done. The user can also put in another operation to perform with
            -- a new value on the accumulator.
            if last_op(UP) then
              state <= MULT;
            elsif last_op(DOWN) then
              state <= RESET_S;
            elsif last_op(LEFT) then
              state <= ADD;
            elsif last_op(RIGHT) then
              state <= SUB;
            else
              state <= IDLE;
            end if;

          when MULT =>
            product     := accumulator * unsigned(switch);
            -- Note that even though the output is > 32 bits we will overflow
            -- if larger.
            accumulator <= product(accumulator'range);
            state       <= IDLE;

          when ADD =>
            accumulator <= accumulator + unsigned(switch);
            state       <= IDLE;
            
          when SUB =>
            accumulator <= accumulator - unsigned(switch);
            state       <= IDLE;

          when RESET_S =>
            accumulator <= (others => '0');
            state       <= IDLE;
        end case;
      end if;
    end if;
  end process;

  accum <= std_logic_vector(accumulator);
end;
