library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_misc.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity tb_pdm is
end entity tb_pdm;

architecture rtl of tb_pdm is

  component pdm_top is
    generic (RAM_SIZE     : integer := 16384;
             CLK_FREQ     : integer := 100); -- Mhz
    port (clk         : in std_logic;

          -- Microphone interface
          m_clk       : out std_logic;
          m_lr_sel    : out std_logic;
          m_data      : in std_logic;

          -- Tricolor LED
          R, G, B     : out std_logic;

          -- Pushbutton interface
          BTNU        : in std_logic;
          BTNC        : in std_logic;

          -- LED Array
          LED         : out std_logic_vector(15 downto 0) := (others => '0');

          -- PDM output
          AUD_PWM     : out std_logic;
          AUD_SD      : out std_logic);
  end component pdm_top;
  component pdm_output is
    port (clk         : in std_logic; -- 100Mhz
          data_in     : in unsigned(6 downto 0);
          data_out    : out std_logic := '0');
  end component pdm_output;

  constant CLK_FREQ : integer := 100; -- Mhz
  signal clk : std_logic := '0';

  -- Microphone interface
  signal m_clk : std_logic;
  signal m_lr_sel : std_logic;
  signal m_data : std_logic;

  -- Tricolor LED
  signal R, G, B : std_logic;

  -- Pushbutton interface
  signal BTNU : std_logic;
  signal BTNC : std_logic;

  -- LED Array
  signal LED  : std_logic_vector(15 downto 0) := (others => '0');

  -- PDM output
  signal AUD_PWM : std_logic;
  signal AUD_SD  : std_logic;

  signal data_in : unsigned(6 downto 0) := (others => '0');
  type array_2d is array (natural range <>) of unsigned(6 downto 0);
  constant sin_table : array_2d(127 downto 0) :=
    (to_unsigned(16#00#,7), to_unsigned(16#01#,7), to_unsigned(16#03#,7), to_unsigned(16#04#,7),
     to_unsigned(16#06#,7), to_unsigned(16#07#,7), to_unsigned(16#09#,7), to_unsigned(16#0a#,7),
     to_unsigned(16#0c#,7), to_unsigned(16#0d#,7), to_unsigned(16#0f#,7), to_unsigned(16#10#,7),
     to_unsigned(16#12#,7), to_unsigned(16#13#,7), to_unsigned(16#15#,7), to_unsigned(16#16#,7),
     to_unsigned(16#18#,7), to_unsigned(16#19#,7), to_unsigned(16#1a#,7), to_unsigned(16#1c#,7),
     to_unsigned(16#1d#,7), to_unsigned(16#1f#,7), to_unsigned(16#20#,7), to_unsigned(16#21#,7),
     to_unsigned(16#23#,7), to_unsigned(16#24#,7), to_unsigned(16#25#,7), to_unsigned(16#26#,7),
     to_unsigned(16#27#,7), to_unsigned(16#29#,7), to_unsigned(16#2a#,7), to_unsigned(16#2b#,7),
     to_unsigned(16#2c#,7), to_unsigned(16#2d#,7), to_unsigned(16#2e#,7), to_unsigned(16#2f#,7),
     to_unsigned(16#30#,7), to_unsigned(16#31#,7), to_unsigned(16#32#,7), to_unsigned(16#33#,7),
     to_unsigned(16#34#,7), to_unsigned(16#35#,7), to_unsigned(16#36#,7), to_unsigned(16#36#,7),
     to_unsigned(16#37#,7), to_unsigned(16#38#,7), to_unsigned(16#38#,7), to_unsigned(16#39#,7),
     to_unsigned(16#3a#,7), to_unsigned(16#3a#,7), to_unsigned(16#3b#,7), to_unsigned(16#3b#,7),
     to_unsigned(16#3c#,7), to_unsigned(16#3c#,7), to_unsigned(16#3d#,7), to_unsigned(16#3d#,7),
     to_unsigned(16#3d#,7), to_unsigned(16#3e#,7), to_unsigned(16#3e#,7), to_unsigned(16#3e#,7),
     to_unsigned(16#3e#,7), to_unsigned(16#3e#,7), to_unsigned(16#3e#,7), to_unsigned(16#3e#,7),
     to_unsigned(16#3f#,7), to_unsigned(16#3e#,7), to_unsigned(16#3e#,7), to_unsigned(16#3e#,7),
     to_unsigned(16#3e#,7), to_unsigned(16#3e#,7), to_unsigned(16#3e#,7), to_unsigned(16#3e#,7),
     to_unsigned(16#3d#,7), to_unsigned(16#3d#,7), to_unsigned(16#3d#,7), to_unsigned(16#3c#,7),
     to_unsigned(16#3c#,7), to_unsigned(16#3b#,7), to_unsigned(16#3b#,7), to_unsigned(16#3a#,7),
     to_unsigned(16#3a#,7), to_unsigned(16#39#,7), to_unsigned(16#38#,7), to_unsigned(16#38#,7),
     to_unsigned(16#37#,7), to_unsigned(16#36#,7), to_unsigned(16#36#,7), to_unsigned(16#35#,7),
     to_unsigned(16#34#,7), to_unsigned(16#33#,7), to_unsigned(16#32#,7), to_unsigned(16#31#,7),
     to_unsigned(16#30#,7), to_unsigned(16#2f#,7), to_unsigned(16#2e#,7), to_unsigned(16#2d#,7),
     to_unsigned(16#2c#,7), to_unsigned(16#2b#,7), to_unsigned(16#2a#,7), to_unsigned(16#29#,7),
     to_unsigned(16#27#,7), to_unsigned(16#26#,7), to_unsigned(16#25#,7), to_unsigned(16#24#,7),
     to_unsigned(16#23#,7), to_unsigned(16#21#,7), to_unsigned(16#20#,7), to_unsigned(16#1f#,7),
     to_unsigned(16#1d#,7), to_unsigned(16#1c#,7), to_unsigned(16#1a#,7), to_unsigned(16#19#,7),
     to_unsigned(16#18#,7), to_unsigned(16#16#,7), to_unsigned(16#15#,7), to_unsigned(16#13#,7),
     to_unsigned(16#12#,7), to_unsigned(16#10#,7), to_unsigned(16#0f#,7), to_unsigned(16#0d#,7),
     to_unsigned(16#0c#,7), to_unsigned(16#0a#,7), to_unsigned(16#09#,7), to_unsigned(16#07#,7),
     to_unsigned(16#06#,7), to_unsigned(16#04#,7), to_unsigned(16#03#,7), to_unsigned(16#01#,7));
  signal counter : integer range 0 to 255 := 0;
  signal int_count : integer range 0 to 127 := 0;

begin

  process begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
  end process;

  u_pdm_input : pdm_top
    generic map(CLK_FREQ => CLK_FREQ)
    port map(clk => clk,
             m_clk => m_clk,
             m_lr_sel => m_lr_sel,
             m_data => m_data,
             R => R,
             G => G,
             B => B,
             BTNU => BTNU,
             BTNC => BTNC,
             LED => LED,
             AUD_PWM => AUD_PWM,
             AUD_SD => AUD_SD);

  u_pdm_output : pdm_output
    port map (clk      => m_clk,
              data_in  => data_in,
              data_out => m_data);

  -- PDM generator
  process (m_clk) begin
    if rising_edge(m_clk) then
      int_count <= int_count + 1;
      if int_count = 127 then
        if counter = 255 then
          counter <= 0;
        else
          counter <= counter + 1;
        end if;
        int_count <= 0;
      end if;
      if counter > 127 then
        data_in <= 64+sin_table(counter - 128);
      else
       data_in <= 64-sin_table(counter);
      end if;
    end if;
  end process;
end architecture;