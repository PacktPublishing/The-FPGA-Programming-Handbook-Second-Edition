-- traffic_light.vhd
-- ------------------------------------
-- Traffic light controller
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;

entity traffic_light is
  generic(
    CLK_PER : integer := 10             -- ns
  );
  port(
    clk : in  std_logic;
    SW  : in  std_logic_vector(1 downto 0);
    R   : out std_logic_vector(1 downto 0);
    G   : out std_logic_vector(1 downto 0);
    B   : out std_logic_vector(1 downto 0)
  );
end entity traffic_light;

architecture rtl of traffic_light is

  -- Uncomment for faster simulation: 1s -> 100us
  -- constant COUNT_1S    : integer := 100000 / CLK_PER;
  constant COUNT_1S    : integer := 1000000000 / CLK_PER;
  constant COUNT_10S   : integer := 10 * COUNT_1S;
  constant COUNT_500US : integer := COUNT_1S / 2000; -- 500 us x 2 gives a 1 kHz PWM base frequency

  type light_t is (RED, YELLOW, GREEN);
  type state_t is (
    INIT_UD_GREEN, UD_GREEN_LR_RED, UD_YELLOW_LR_RED, INIT_UD_RED_LR_GREEN,
    UD_RED_LR_GREEN, UD_RED_LR_YELLOW
  );

  signal counter      : integer range 0 to COUNT_10S := 0;
  signal up_down      : light_t                      := RED;
  signal left_right   : light_t                      := GREEN;
  signal state        : state_t                      := INIT_UD_GREEN;
  signal lr_reg       : std_logic_vector(2 downto 0) := (others => '0');
  signal ud_reg       : std_logic_vector(2 downto 0) := (others => '0');
  signal enable_count : std_logic                    := '0';
  signal light_count  : std_logic                    := '0';

begin

  process(clk)
  begin
    if rising_edge(clk) then
      lr_reg       <= lr_reg(1 downto 0) & SW(0);
      ud_reg       <= ud_reg(1 downto 0) & SW(1);
      enable_count <= '0';

      if enable_count then
        if counter < COUNT_10S then
          counter <= counter + 1;
        end if;
      else
        counter <= 0;
      end if;

      case state is
        when INIT_UD_GREEN =>
          up_down      <= GREEN;
          left_right   <= RED;
          enable_count <= '1';
          if counter = COUNT_10S then
            state <= UD_GREEN_LR_RED;
          end if;
        when UD_GREEN_LR_RED =>
          up_down    <= GREEN;
          left_right <= RED;
          if lr_reg(2) then
            state <= UD_YELLOW_LR_RED;
          end if;
        when UD_YELLOW_LR_RED =>
          up_down      <= YELLOW;
          left_right   <= RED;
          enable_count <= '1';
          if counter = COUNT_1S then
            state <= INIT_UD_RED_LR_GREEN;
          end if;
        when INIT_UD_RED_LR_GREEN =>
          up_down      <= RED;
          left_right   <= GREEN;
          enable_count <= '1';
          if counter = COUNT_10S then
            state <= UD_RED_LR_GREEN;
          end if;
        when UD_RED_LR_GREEN =>
          up_down    <= RED;
          left_right <= GREEN;
          if ud_reg(2) then
            state <= UD_RED_LR_YELLOW;
          end if;
        when UD_RED_LR_YELLOW =>
          up_down      <= RED;
          left_right   <= YELLOW;
          enable_count <= '1';
          if counter = COUNT_1S then
            state <= INIT_UD_GREEN;
          end if;
      end case;
    end if;
  end process;

  process(clk)
    variable pwm_count : natural range 0 to COUNT_500US - 1 := 0;
  begin
    if rising_edge(clk) then
      if pwm_count = COUNT_500US - 1 then
        pwm_count   := 0;
        light_count <= not light_count;
      else
        pwm_count := pwm_count + 1;
      end if;

      R <= (others => '0');
      G <= (others => '0');
      B <= (others => '0');

      if light_count then
        case left_right is
          when GREEN =>
            G(0) <= '1';
          when YELLOW =>
            R(0) <= '1';
            G(0) <= '1';
          when RED =>
            R(0) <= '1';
        end case;
        case up_down is
          when GREEN =>
            G(1) <= '1';
          when YELLOW =>
            R(1) <= '1';
            G(1) <= '1';
          when RED =>
            R(1) <= '1';
        end case;
      end if;
    end if;
  end process;

end architecture;
