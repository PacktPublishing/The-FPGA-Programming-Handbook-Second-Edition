library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_misc.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity seven_segment is
  generic (NUM_SEGMENTS : integer := 8;
           CLK_PER      : integer := 10;    -- Clock period in ns
           REFR_RATE    : integer := 1000); -- Refresh rate in Hz
  port (clk         : in std_logic;
        seven_segment_tvalid : in std_logic;
        seven_segment_tdata  : in std_logic_vector(NUM_SEGMENTS*4-1 downto 0);
        seven_segment_tuser  : in std_logic_vector(NUM_SEGMENTS-1 downto 0);
        anode       : out std_logic_vector(NUM_SEGMENTS-1 downto 0);
        cathode     : out std_logic_vector(7 downto 0));
end entity seven_segment;
architecture rtl of seven_segment is
  component cathode_top is
    port (clk         : in std_logic;
          encoded     : in std_logic_vector(3 downto 0);
          digit_point : in std_logic;
          cathode     : out std_logic_vector(7 downto 0));
  end component cathode_top;

  constant CLKS     : integer := CLK_PER * REFR_RATE;
  constant INTERVAL : integer := integer(100000000.0 / real(CLKS));
  signal refresh_count : std_logic_vector(natural(log2(real(INTERVAL)))-1 downto 0) := (others => '0');
  signal anode_count : integer range 0 to NUM_SEGMENTS := 0;
  signal segments    : std_logic_vector(NUM_SEGMENTS*8 + 7 downto 0);
  signal encoded     : std_logic_vector(NUM_SEGMENTS*4 + 3 downto 0);
  signal digit_point : std_logic_vector(NUM_SEGMENTS-1 downto 0);

begin

  process (clk)
  begin
    if rising_edge(clk) then
      if seven_segment_tvalid = '1' then
        for i in 0 to NUM_SEGMENTS-1 loop
          encoded(i*4+3 downto i*4)     <= seven_segment_tdata(i*4+3 downto i*4);
          digit_point(i) <= not seven_segment_tuser(i);
        end loop;
      end if;
    end if;
  end process;

  g_genarray : for i in 0 to NUM_SEGMENTS-1 generate
    ct : cathode_top
      port map (clk         => clk,
                encoded     => encoded(i*4+3 downto i*4),
                digit_point => digit_point(i),
                cathode     => segments(i*8+7 downto i*8));
  end generate;

  process (clk)
  begin
    if rising_edge(clk) then
      if refresh_count = std_logic_vector(to_unsigned(INTERVAL, refresh_count'length)) then
        refresh_count <= (others => '0');
        if anode_count = NUM_SEGMENTS - 1 then
          anode_count <= 0;
        else
          anode_count   <= anode_count + 1;
        end if;
      else
        refresh_count <= refresh_count + 1;
      end if;
      anode              <= (others => '1');
      anode(anode_count) <= '0';
      cathode            <= segments(anode_count*8+7 downto anode_count*8);
    end if;
  end process;
end architecture rtl;
