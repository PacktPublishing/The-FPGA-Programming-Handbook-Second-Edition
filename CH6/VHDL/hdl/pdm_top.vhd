library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

entity pdm_top is
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
end entity pdm_top;

architecture rtl of pdm_top is
  attribute MARK_DEBUG : string;
  signal amplitude : unsigned(6 downto 0);
  signal amplitude_valid : std_logic;
  attribute MARK_DEBUG of amplitude, amplitude_valid : signal is "TRUE";
  signal button_usync : std_logic_vector(2 downto 0);
  signal button_csync : std_logic_vector(2 downto 0);
  signal start_capture : std_logic := '0';
  signal m_clk_en : std_logic;
  signal m_clk_en_del : std_logic;
  signal light_count : integer range 0 to 127 := 0;
  -- Capture RAM
  type array_2d is array (natural range <>) of integer range 0 to 127;
  signal amplitude_store : array_2d(0 to RAM_SIZE-1);
  signal start_playback : std_logic := '0';
  signal ram_wraddr : integer range 0 to RAM_SIZE-1 := 0;
  signal ram_rdaddr : integer range 0 to RAM_SIZE-1 := 0;
  signal ram_we     : std_logic := '0';
  signal ram_dout   : integer range 0 to 127;
  signal clr_led    : std_logic_vector(15 downto 0) := (others => '0');
  constant RSL2     : integer := natural(log2(real(RAM_SIZE)));
  signal amp_capture : integer range 0 to 127;
  signal AUD_PWM_en : std_logic;
  signal amp_counter : integer range 0 to 127;
  signal clr_addr    : integer range 0 to 15;
  signal ram_rdaddr_sl : std_logic_vector(RSL2-1 downto 0);
begin
  AUD_SD <= '1';
  m_lr_sel <= '0';

  u_pdm_inputs : entity work.pdm_inputs
    port map (clk => clk,
              m_clk => m_clk,
              m_clk_en => m_clk_en,
              m_data => m_data,
              amplitude => amplitude,
              amplitude_valid => amplitude_valid);

  process (clk)
  begin
    -- Display using tricolor LED
    if rising_edge(clk) then
      if m_clk_en then
        light_count <= light_count + 1;
      end if;
      B <= '1' when (40 - amplitude) < light_count else '0';
      R <= '0';
      G <= '0';
    end if;
  end process;

  -- Capture the Audio data
  process (clk)
    variable ram_wraddr_sl : std_logic_vector(RSL2-1 downto 0);
    variable led_index : integer range 0 to 15;
  begin
    if rising_edge(clk) then
      button_csync <= button_csync(1 downto 0) & BTNC;
      ram_we       <= '0';
      for i in 0 to 15 loop
        if clr_led(i) then LED(i) <= '0'; end if;
      end loop;
      if button_csync(2 downto 1) = "01" then
        start_capture <= '1';
        LED           <= (others => '0');
      elsif start_capture and amplitude_valid then
        ram_wraddr_sl := std_logic_vector(to_unsigned(ram_wraddr, RSL2));
        led_index := to_integer(unsigned(ram_wraddr_sl(RSL2-1 downto RSL2-4)));
        LED(led_index) <= '1';
        ram_we                      <= '1';
        ram_wraddr                  <= ram_wraddr + 1;
        if and(ram_wraddr_sl) then
          start_capture <= '0';
          LED(15)       <= '1';
        end if;
      end if;
    end if;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      if ram_we then
        amplitude_store(ram_wraddr) <= to_integer(unsigned(amplitude));
        ram_dout <= amplitude_store(ram_rdaddr);
      end if;
    end if;
  end process;

  ram_rdaddr_sl <= std_logic_vector(to_unsigned(ram_rdaddr, RSL2));
  clr_addr <= TO_INTEGER(unsigned(ram_rdaddr_sl(RSL2-1 downto RSL2-4)));

  -- Playback the audio
  process (clk)
  begin
    if rising_edge(clk) then
      button_usync <= button_usync(1 downto 0) & BTNU;
      m_clk_en_del <= m_clk_en;
      clr_led      <= (others => '0');

      if button_usync(2 downto 1) = "01" then
        start_playback <= '1';
        ram_rdaddr     <= 0;
      elsif start_playback and m_clk_en_del then
        clr_led(clr_addr) <= '1';
        AUD_PWM_en <= '1';
        if amplitude_valid then
          ram_rdaddr <= ram_rdaddr + 1;
          amp_counter <= 1;
          amp_capture <= ram_dout;
          if ram_dout /= 0 then
            AUD_PWM_en <= '0'; -- Activate pull up
          end if;
        else
          amp_counter <= amp_counter + 1;
          if amp_capture < amp_counter then
            AUD_PWM_en <= '0'; -- Activate pull up
          end if;
        end if;
        if and ram_rdaddr_sl then
          start_playback <= '0';
        end if;
      end if;
    end if;
  end process;

  AUD_PWM <= '0' when AUD_PWM_en else 'Z';
end architecture rtl;
