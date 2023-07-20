library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tb_pdm is
end entity tb_pdm;

architecture rtl of tb_pdm is

  type u6_array_t is array (natural range <>) of unsigned(6 downto 0);

  constant CLK_FREQ   : integer := 100; -- MHz
  constant CLK_PERIOD : time    := 1 sec / (CLK_FREQ * 1000000);

  constant SIN_TABLE : u6_array_t(0 to 127) := (
    7x"00", 7x"01", 7x"03", 7x"04",
    7x"06", 7x"07", 7x"09", 7x"0a",
    7x"0c", 7x"0d", 7x"0f", 7x"10",
    7x"12", 7x"13", 7x"15", 7x"16",
    7x"18", 7x"19", 7x"1a", 7x"1c",
    7x"1d", 7x"1f", 7x"20", 7x"21",
    7x"23", 7x"24", 7x"25", 7x"26",
    7x"27", 7x"29", 7x"2a", 7x"2b",
    7x"2c", 7x"2d", 7x"2e", 7x"2f",
    7x"30", 7x"31", 7x"32", 7x"33",
    7x"34", 7x"35", 7x"36", 7x"36",
    7x"37", 7x"38", 7x"38", 7x"39",
    7x"3a", 7x"3a", 7x"3b", 7x"3b",
    7x"3c", 7x"3c", 7x"3d", 7x"3d",
    7x"3d", 7x"3e", 7x"3e", 7x"3e",
    7x"3e", 7x"3e", 7x"3e", 7x"3e",
    7x"3f", 7x"3e", 7x"3e", 7x"3e",
    7x"3e", 7x"3e", 7x"3e", 7x"3e",
    7x"3d", 7x"3d", 7x"3d", 7x"3c",
    7x"3c", 7x"3b", 7x"3b", 7x"3a",
    7x"3a", 7x"39", 7x"38", 7x"38",
    7x"37", 7x"36", 7x"36", 7x"35",
    7x"34", 7x"33", 7x"32", 7x"31",
    7x"30", 7x"2f", 7x"2e", 7x"2d",
    7x"2c", 7x"2b", 7x"2a", 7x"29",
    7x"27", 7x"26", 7x"25", 7x"24",
    7x"23", 7x"21", 7x"20", 7x"1f",
    7x"1d", 7x"1c", 7x"1a", 7x"19",
    7x"18", 7x"16", 7x"15", 7x"13",
    7x"12", 7x"10", 7x"0f", 7x"0d",
    7x"0c", 7x"0a", 7x"09", 7x"07",
    7x"06", 7x"04", 7x"03", 7x"01");

  signal clk : std_logic := '0';

  -- Microphone interface
  signal m_clk    : std_logic;
  signal m_lr_sel : std_logic;
  signal m_data   : std_logic;

  -- Tricolor LED
  signal R, G, B : std_logic;

  -- Pushbutton interface
  signal BTNU : std_logic;
  signal BTNC : std_logic;

  -- LED Array
  signal LED : std_logic_vector(15 downto 0) := (others => '0');

  -- PDM output
  signal AUD_PWM : std_logic;
  signal AUD_SD  : std_logic;

  signal data_in : unsigned(6 downto 0) := (others => '0');

begin

  clk <= not clk after CLK_PERIOD / 2;

  u_pdm_input : entity work.pdm_top
    generic map(
      CLK_FREQ => CLK_FREQ
    )
    port map(
      clk      => clk,
      m_clk    => m_clk,
      m_lr_sel => m_lr_sel,
      m_data   => m_data,
      R        => R,
      G        => G,
      B        => B,
      BTNU     => BTNU,
      BTNC     => BTNC,
      LED      => LED,
      AUD_PWM  => AUD_PWM,
      AUD_SD   => AUD_SD);

  u_pdm_output : entity work.pdm_output
    port map(
      clk      => m_clk,
      data_in  => data_in,
      data_out => m_data
    );

  -- PDM generator
  process(m_clk)
    variable counter   : integer range 0 to 255 := 0;
    variable int_count : integer range 0 to 127 := 0;
  begin
    if rising_edge(m_clk) then
      if int_count = 127 then
        if counter = 255 then
          counter := 0;
        else
          counter := counter + 1;
        end if;
        int_count := 0;                 -- Note: in VHDL, integers do not wrap so we need to make sure to handle this
      else
        int_count := int_count + 1;
      end if;
      if counter > 127 then
        data_in <= 64 + SIN_TABLE(counter - 128);
      else
        data_in <= 64 - SIN_TABLE(counter);
      end if;
    end if;
  end process;
end architecture;
