LIBRARY IEEE, WORK;
USE IEEE.std_logic_1164.all;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.std_logic_SIGNED.all;
USE ieee.numeric_std.all;
use IEEE.math_real.all;
use WORK.calculator_pkg.all;

entity calculator_mealy is
  generic (BITS : integer := 32);
  port (clk     : in std_logic;
        start   : in std_logic;
        buttons : in std_logic_vector(4 downto 0);
        switch  : in std_logic_vector(15 downto 0);
        
        done    : out std_logic;
        accum   : out std_logic_vector(BITS-1 downto 0));
end entity calculator_mealy;
        
architecture rtl of calculator_mealy is

  attribute MARK_DEBUG : string;
  constant BC : natural := natural(log2(real(BITS)));
  signal last_op : std_logic_vector(4 downto 0);
  signal accumulator : std_logic_vector(BITS-1 downto 0);
  attribute MARK_DEBUG of last_op     : signal is "TRUE";
  attribute MARK_DEBUG of accumulator : signal is "TRUE";
  type state_t is (IDLE, WAIT4BUTTON);
  signal state : state_t := IDLE;
  attribute MARK_DEBUG of state       : signal is "TRUE";

begin

  process (clk) 
    variable mult : std_logic_vector(BITS + 16 - 1 downto 0);
  begin
    if rising_edge(clk) then
      done <= '0';
      case state is
        when IDLE =>
          -- Wait for data to be operated on to be entered. Then the user presses
          -- The operation, add, sub, multiply, clear or equal
          accumulator <= (others => '0');
          last_op     <= buttons; -- operation to perform
          accumulator(15 downto 0) <= switch;
          if start then 
            state <= IDLE when buttons(DOWN) else WAIT4BUTTON; 
          end if;
        when WAIT4BUTTON =>
          -- wait for second data to be entered, then user presses next operation.
          -- In this case, if we get an =, we perform the operation and we're
          -- done. The user can also put in another operation to perform with
          -- a new value on the accumulator.
          if start then
            last_op <= buttons; -- Store our last operation
            if last_op(UP) then
              mult := accumulator * switch;
              accumulator <= mult(BITS-1 downto 0);
            elsif last_op(DOWN) then
              state       <= IDLE;
            elsif last_op(LEFT) then
              accumulator <= accumulator + switch;
            elsif last_op(RIGHT) then
              accumulator <= accumulator - switch;
            else
              state <= WAIT4BUTTON;
            end if;
          else
            state <= WAIT4BUTTON;
          end if;
      end case;
    end if;
  end process;

  accum <= accumulator;
end architecture;  