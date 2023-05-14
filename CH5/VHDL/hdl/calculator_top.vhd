LIBRARY IEEE, WORK;
USE IEEE.std_logic_1164.all;
USE ieee.numeric_std.all;
use IEEE.math_real.all;
use WORK.calculator_pkg.all;
USE WORK.counting_buttons_pkg.all;

entity calculator_top is
  generic (BITS : integer := 32;
           NUM_SEGMENTS : integer := 8;
           SM_TYPE : string := "MEALY"; -- Mealy or Moore
           USE_PLL : string := "TRUE");
  port (clk        : in std_logic;
        CPU_RESETN : in std_logic;
        SW         : in std_logic_vector(15 downto 0);
        buttons    : in std_logic_vector(4 downto 0);

        anode      : out std_logic_vector(NUM_SEGMENTS-1 downto 0);
        cathode    : out std_logic_vector(7 downto 0));
end entity calculator_top;

architecture rtl of calculator_top is
  component sys_pll is
  port(clk_in1 : in std_logic;
       clk_out1 : out std_logic;
       locked   : out std_logic);
  end component;

  attribute MARK_DEBUG : string;
  attribute ASYNC_REG : string;
  signal clk_50 : std_logic;
  signal reset  : std_logic;
  signal accumulator : std_logic_vector(31 downto 0);
  attribute MARK_DEBUG of accumulator : signal is "TRUE";
  signal encoded : array_t(NUM_SEGMENTS-1 downto 0)(3 downto 0);
  attribute MARK_DEBUG of encoded : signal is "TRUE";
  signal digit_point : std_logic_vector(NUM_SEGMENTS-1 downto 0);

  -- Capture button events
  signal button_sync : std_logic_vector(2 downto 0);
  attribute ASYNC_REG of button_sync : signal is "TRUE";
  signal counter_en :std_logic;
  signal counter : integer range 0 to 255;
  signal button_down : std_logic;
  signal button_capt : std_logic_vector(4 downto 0);
  signal sw_capt : std_logic_vector(15 downto 0);
  signal int_reset : std_logic;
  signal reset_sync : std_logic_vector(1 downto 0) := (others => '1');
  attribute ASYNC_REG of reset_sync : signal is "TRUE";
begin

  g_USE_PLL : if USE_PLL = "TRUE" generate
    u_sys_pll : sys_pll
        port map(clk_in1 => clk, clk_out1 => clk_50, locked => int_reset);
    process(clk_50)
    begin
      if rising_edge(clk_50) then
        reset_sync <= reset_sync(0) & not(int_reset and CPU_RESETN);
      end if;
    end process;
    reset <= reset_sync(1);
  else generate
    clk_50 <= clk;
    reset  <= '0'; -- No reset necessary unless using external reset or PLL
  end generate;

  u_seven_segment : entity work.seven_segment
    generic map (NUM_SEGMENTS => NUM_SEGMENTS, CLK_PER => 20)
    port map (clk => clk_50, reset => reset, encoded => encoded, digit_point => digit_point, anode => anode, cathode => cathode);

  process (clk_50)
  begin
    if rising_edge(clk_50) then
      button_down <= '0';
      button_capt <= (others => '0');
      button_sync <= button_sync(1 downto 0) & or(buttons);
      if button_sync(2 downto 1) = "01" then counter_en <= '1';
      elsif  not button_sync(1) then         counter_en <= '0';
      end if;

      if counter_en then
        counter <= counter + 1;
        if  counter = 255 then
          counter_en  <= '0';
          counter     <= 0;
          button_down <= '1';
          button_capt <= buttons;
          sw_capt     <= SW;
        end if;
      end if;
      if reset then
        counter_en  <= '0';
        counter     <= 0;
        button_down <= '0';
      end if;
    end if;
  end process;

  g_MOORE : if SM_TYPE = "MOORE" generate
    u_sm : entity work.calculator_moore
      generic map (BITS => BITS)
      port map (clk => clk_50, reset => reset, start => button_down, buttons => button_capt, switch => sw_capt, accum => accumulator);
  else generate
    u_sm : entity work.calculator_mealy
      port map (clk => clk_50, reset => reset, start => button_down, buttons => button_capt, switch => sw_capt, accum => accumulator);
  end generate;

  process (clk_50)
  begin
    if rising_edge(clk_50) then
      encoded     <= bin_to_bcd(accumulator);
      digit_point <= (others => '1');
    end if;
  end process;
end architecture;
