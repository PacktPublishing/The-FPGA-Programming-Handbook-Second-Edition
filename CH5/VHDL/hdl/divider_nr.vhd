LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE ieee.numeric_std.all;
use IEEE.math_real.all;
use WORK.calculator_pkg.all;

entity divider_nr is
    generic(BITS : integer := 16);
    port(clk       : in  std_logic;
         reset     : in  std_logic;
         start     : in  std_logic;
         dividend  : in  unsigned(BITS - 1 downto 0);
         divisor   : in  unsigned(BITS - 1 downto 0);
         done      : out std_logic;
         quotient  : out unsigned(BITS - 1 downto 0);
         remainder : out unsigned(BITS - 1 downto 0));
end entity divider_nr;
architecture rtl of divider_nr is
    constant BC : natural := natural(log2(real(BITS)));

    signal num_bits_w    : std_logic_vector(BC downto 0);
    signal num_bits      : integer range 0 to BITS;
    signal int_remainder : signed(BITS downto 0); -- Sized with additional sign
    type state_t is (IDLE, INIT, LEFT_SHIFT, TEST_REMAINDER0, TEST_REMAINDER1,
                     ADJ_REMAINDER0, ADJ_REMAINDER1, ADJ_REMAINDER2, UPDATE_QUOTIENT,
                     TEST_N, DIV_DONE);
    signal state         : state_t := IDLE;
begin

    fsm : process(clk)
    begin
        if rising_edge(clk) then
            done <= '0';
            case state is
                when IDLE =>
                    if start then
                        state <= INIT;
                    end if;
                when INIT =>
                    state         <= LEFT_SHIFT;
                    quotient      <= dividend sll (BITS - to_integer(unsigned(num_bits_w)));
                    int_remainder <= (others => '0');
                    num_bits      <= to_integer(unsigned(num_bits_w));
                when LEFT_SHIFT =>
                    int_remainder <= int_remainder(BITS - 1 downto 0) & quotient(BITS - 1);
                    quotient      <= quotient(BITS - 2 downto 0) & '0';
                    if int_remainder(BITS) then
                        state <= ADJ_REMAINDER0;
                    else
                        state <= ADJ_REMAINDER1;
                    end if;
                when ADJ_REMAINDER0 =>
                    state         <= UPDATE_QUOTIENT;
                    int_remainder <= int_remainder + signed('0' & divisor);
                when ADJ_REMAINDER1 =>
                    state         <= UPDATE_QUOTIENT;
                    int_remainder <= int_remainder - signed('0' & divisor);
                when UPDATE_QUOTIENT =>
                    state       <= TEST_N;
                    quotient(0) <= not int_remainder(BITS);
                    num_bits    <= num_bits - 1;
                when TEST_N =>
                    if num_bits > 0 then
                        state <= LEFT_SHIFT;
                    else
                        state <= TEST_REMAINDER1;
                    end if;
                when TEST_REMAINDER1 =>
                    if int_remainder(BITS) then
                        state <= ADJ_REMAINDER2;
                    else
                        state <= DIV_DONE;
                    end if;
                when ADJ_REMAINDER2 =>
                    state         <= DIV_DONE;
                    int_remainder <= int_remainder + signed('0' & divisor);
                when DIV_DONE =>
                    done  <= '1';
                    state <= IDLE;
                when others =>
                    state <= IDLE;
            end case;
            if reset then
                state <= IDLE;
            end if;
        end if;
    end process;

    remainder <= unsigned(int_remainder(BITS - 1 downto 0));

    u_leading_ones : entity work.leading_ones
        generic map(SELECTOR => "DOWN_FOR", BITS => BITS)
        port map(SW => std_logic_vector(dividend), LED => num_bits_w);

end architecture;
