-- ps2_pkg.vhd
-- ------------------------------------
-- Package for PS2 Interface
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- Clean up the top level of the ps2_host

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE ieee.numeric_std.all;

package ps2_pkg is

  component debounce is
    generic(CYCLES : integer := 16);
    port(clk     : in  std_logic;
         reset   : in  std_logic;
         sig_in  : in  std_logic;
         sig_out : out std_logic);
  end component debounce;

  type array8_t is array (natural range <>) of std_logic_vector(7 downto 0);

  constant rx_expect : array8_t(0 to 10) :=
    (x"AA", -- Self test
     x"FA", -- Ack
     x"FA", -- Ack
     x"AB", -- Ack + keyboard code
     x"FA", -- Ack
     x"FA", -- Ack
     x"FA", -- Ack
     x"FA", -- Ack
     x"FA", -- Ack
     x"FA", -- Ack
     x"FA"); -- Ack
  constant init_data : array8_t(0 to 9) :=
    (x"ED", x"00", x"F2", x"ED", x"02", x"F3", x"20", x"F4", x"F3", x"00");

  type state_t is (IDLE, CLK_FALL0, CLK_FALL1,
                   CLK_HIGH, XMIT0, XMIT1, XMIT2,
                   XMIT3, XMIT4, XMIT5, XMIT6);

  type start_state_t is (START_IDLE, SEND_CMD, START0,
                         START1, START2, START3, START4,
                         START5, START6);

  type out_state_t is (OUT_IDLE, OUT_WAIT);
end package ps2_pkg;
