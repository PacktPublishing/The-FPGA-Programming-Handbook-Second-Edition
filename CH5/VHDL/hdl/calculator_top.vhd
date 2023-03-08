LIBRARY IEEE, WORK;
USE IEEE.std_logic_1164.all;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.std_logic_SIGNED.all;
USE ieee.numeric_std.all;
use IEEE.math_real.all;
use WORK.calculator_pkg.all;

entity calculator_top is
  generic (BITS : integer := 32;
           NUM_SEGMENTS : integer := 8;
           SM_TYPE : string := "MEALY"; -- Mealy or Moore
           USE_PLL : string := "TRUE");
  port (clk     : in std_logic;
        SW      : in std_logic_vector(15 downto 0);
        buttons : in std_logic_vector(4 downto 0);
         
        anode   : out std_logic_vector(NUM_SEGMENTS-1 downto 0);
        cathode : out std_logic_vector(7 downto 0));
end entity calculator_top;
        
architecture rtl of calculator_top is
  component sys_pll is
    port(clk_in1 : in std_logic;
         clk_out1 : out std_logic);
  end component;
  component seven_segment is
    generic (NUM_SEGMENTS : integer := 8;
             CLK_PER      : integer := 10;    -- Clock period in ns
             REFR_RATE    : integer := 1000); -- Refresh rate in Hz
    port (clk         : in std_logic;
          encoded     : in array_t(NUM_SEGMENTS-1 downto 0)(3 downto 0);
          digit_point : in std_logic_vector(NUM_SEGMENTS-1 downto 0);
          anode       : out std_logic_vector(NUM_SEGMENTS-1 downto 0);
          cathode     : out std_logic_vector(7 downto 0));
  end component seven_segment;
  component calculator_moore is
    generic (BITS : integer := 32);
    port (clk     : in std_logic;
          start   : in std_logic;
          buttons : in std_logic_vector(4 downto 0);
          switch  : in std_logic_vector(15 downto 0);
        
          done    : out std_logic;
          accum   : out std_logic_vector(BITS-1 downto 0));
  end component calculator_moore;
  component calculator_mealy is
    generic (BITS : integer := 32);
    port (clk     : in std_logic;
          start   : in std_logic;
          buttons : in std_logic_vector(4 downto 0);
          switch  : in std_logic_vector(15 downto 0);
        
          done    : out std_logic;
          accum   : out std_logic_vector(BITS-1 downto 0));
  end component calculator_mealy;
 
  attribute MARK_DEBUG : string;
  attribute ASYNC_REG : string;
  signal clk_50 : std_logic;
  signal accumulator : std_logic_vector(31 downto 0);
  attribute MARK_DEBUG of accumulator : signal is "TRUE";
  signal encoded : array_t(NUM_SEGMENTS-1 downto 0)(3 downto 0);
  attribute MARK_DEBUG of encoded : signal is "TRUE";
  signal digit_point : std_logic_vector(NUM_SEGMENTS-1 downto 0);

  -- Capture button events
  signal button_sync : std_logic_vector(2 downto 0);
  attribute ASYNC_REG of button_sync : signal is "TRUE";
  signal counter_en :std_logic;
  signal counter : std_logic_vector(7 downto 0);
  signal button_down : std_logic;
  signal button_capt : std_logic_vector(4 downto 0);
  signal sw_capt : std_logic_vector(15 downto 0);
begin
         
  g_USE_PLL : if USE_PLL = "TRUE" generate
    u_sys_pll : sys_pll
        port map(clk_in1 => clk, clk_out1 => clk_50);
  else generate
    clk_50 <= clk;
  end generate;
  
  u_seven_segment : seven_segment
    generic map (NUM_SEGMENTS => NUM_SEGMENTS, CLK_PER => 20)
    port map (clk => clk_50, encoded => encoded, digit_point => digit_point, anode => anode, cathode => cathode);

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
        if  and(counter) then
          counter_en  <= '0';
          counter     <= (others =>'0');
          button_down <= '1';
          button_capt <= buttons;
          sw_capt     <= SW;
        end if;
      end if;
    end if;
  end process;

  g_MOORE : if SM_TYPE = "MOORE" generate
    u_sm : calculator_moore
      generic map (BITS => BITS)
      port map (clk => clk_50, start => button_down, buttons => button_capt, switch => sw_capt, accum => accumulator);
    else generate
    u_sm : calculator_mealy
      port map (clk => clk_50, start => button_down, buttons => button_capt, switch => sw_capt, accum => accumulator);
  end generate;

  process (clk_50)
  begin
    if rising_edge(clk_50) then
      encoded     <= bin_to_bcd(accumulator);
      digit_point <= (others => '1');
    end if;
  end process;
end architecture;