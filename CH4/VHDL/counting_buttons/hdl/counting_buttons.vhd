library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_misc.all;
use IEEE.std_logic_signed.all;
use IEEE.numeric_std.all;
library WORK;
USE WORK.counting_buttons_pkg.all;
entity counting_buttons is
  generic (MODE         : string  := "HEX";  -- "HEX"
           NUM_SEGMENTS : integer := 8;
           CLK_PER      : integer := 10;     -- Clock period in ns
           REFR_RATE    : integer := 1000;   -- Refresh rate in Hz
           ASYNC_BUTTON : string  := "safe");-- "CLOCK", "NOCLOCK", "SAFE", "DEBOUNCE"
  port (clk        : in  std_logic;
        BTNC       : in  std_logic;
        CPU_RESETN : in  std_logic;
        anode      : out std_logic_vector(NUM_SEGMENTS-1 downto 0);
        cathode    : out std_logic_vector(7 downto 0));
end entity counting_buttons;
architecture rtl of counting_buttons is


  -- Decimal increment function
  function dec_inc (din : in array_t(NUM_SEGMENTS-1 downto 0)(3 downto 0))
    return array_t is

    variable int_val : array_t(NUM_SEGMENTS-1 downto 0)(3 downto 0);
    variable next_val : std_logic_vector(3 downto 0);
    variable carry_in : std_logic;
    begin
    carry_in := '1';
    for i in 0 to NUM_SEGMENTS-1 loop
      next_val := din(i) + carry_in;
      if next_val = 10 then
        int_val(i) := (others => '0');
        carry_in   := '1';
      else
        int_val(i) := next_val;
        carry_in   := '0';
      end if;
    end loop;
    return int_val;
  end function;

  function hex_inc (din : in array_t(NUM_SEGMENTS-1 downto 0)(3 downto 0))
    return array_t is

    variable int_val : array_t(NUM_SEGMENTS-1 downto 0)(3 downto 0);
    variable next_val : std_logic_vector(3 downto 0);
    variable carry_in : std_logic;
    begin
    carry_in := '1';
    for i in 0 to NUM_SEGMENTS-1 loop
      next_val := din(i) + carry_in;
      if next_val = 15 then
        int_val(i) := (others => '0');
        carry_in   := '1';
      else
        int_val(i) := next_val;
        carry_in   := '0';
      end if;
    end loop;
    return int_val;
  end function;

  component seven_segment is
    generic (NUM_SEGMENTS : integer := 8;
             CLK_PER      : integer := 10;    -- Clock period in ns
             REFR_RATE    : integer := 1000); -- Refresh rate in Hz
    port (clk : in std_logic;
          encoded : in array_t(NUM_SEGMENTS-1 downto 0)(3 downto 0);
          digit_point : in std_logic_vector(NUM_SEGMENTS-1 downto 0);
          anode : out std_logic_vector(NUM_SEGMENTS-1 downto 0);
          cathode : out std_logic_vector(7 downto 0));
  end component seven_segment;

  attribute MARK_DEBUG : string;
  attribute ASYNC_REG : string;
  signal encoded : array_t(NUM_SEGMENTS-1 downto 0)(3 downto 0);
  signal digit_point : std_logic_vector(NUM_SEGMENTS-1 downto 0) := (others => '1');
  signal last_button : std_logic := '0';
  signal button : std_logic := '0';
  signal button_down : std_logic := '0';
  attribute MARK_DEBUG of button_down : signal is "TRUE";
  signal button_sync : std_logic_vector(2 downto 0);
  attribute ASYNC_REG of button_sync : signal is "TRUE";
  attribute MARK_DEBUG of button_sync : signal is "TRUE";
  signal counter_en : std_logic := '0';
  attribute MARK_DEBUG of counter_en : signal is "TRUE";
  signal counter : std_logic_vector(7 downto 0) := (others => '0');
  attribute MARK_DEBUG of counter : signal is "TRUE";
begin

  u_7seg : seven_segment
    generic map(NUM_SEGMENTS => NUM_SEGMENTS,
                CLK_PER      => CLK_PER,      -- Clock period in ns
                REFR_RATE    => REFR_RATE)    -- Refresh rate in Hz
    port map(clk          => clk,
             encoded      => encoded,
             digit_point  => digit_point,
             anode        => anode,
             cathode      => cathode);

  -- Capture the rising edge of button press
  process (clk)
  begin
    if rising_edge(clk) then
      if ASYNC_BUTTON = "SAFE" then
        button_down <= '0';
        button_sync <= button_sync(1 downto 0) & BTNC;
        if button_sync(2 downto 1) = "01" then
          button_down <= '1';
        else
          button_down <= '0';
        end if;  

      elsif ASYNC_BUTTON = "DEBOUNCE" then
        button_down <= '0';
        button_sync <= button_sync(1 downto 0) & BTNC;
        if button_sync(2 downto 1) = "01" then
          counter_en <= '1';
        elsif not button_sync(1) then
          counter_en <= '0';
        end if;
        if counter_en then
          counter <= counter + 1;
          if and(counter) then
            counter_en  <= '0';
            counter     <= (others => '0');
            button_down <= '1';
          end if;
        end if;
      else
        last_button                             <= button;
        button                                  <= BTNC;
        if BTNC and not button then
          button_down <= '1';
        else
          button_down <= '0';
        end if;
      end if;
    end if;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      if button_down then
        if MODE = "HEX" then
          encoded <= hex_inc(encoded);
        else
          encoded <= dec_inc(encoded);
        end if;
      end if;
      if not CPU_RESETN then
        for i in 0 to NUM_SEGMENTS-1 loop
          encoded(i) <= (others => '0');
        end loop;
        --encoded     <= ((others => '0')(others => '0'));
        digit_point <= (others => '1');
      end if;
    end if;
  end process;
end architecture;
