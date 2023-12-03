-- spi.vhd
-- ------------------------------------
-- AXI SPI state machine interface
-- ------------------------------------
-- Author : Frank Bruno
LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;
use IEEE.math_real.all;

entity spi is
  port (
    -- Utility signals
    sys_clk     : in std_logic; -- 100Mhz clock
    sys_rst     : in std_logic; -- 100Mhz clock

    -- CPU interface
    reg_awvalid : in std_logic;
    reg_awready : out std_logic;
    reg_awaddr  : in std_logic_vector(5 downto 0);

    reg_wvalid : in std_logic;
    reg_wready : out std_logic;
    reg_wdata  : in std_logic_vector(7 downto 0);

    reg_bready : in std_logic;
    reg_bvalid : out std_logic := '0';
    reg_bresp  : out std_logic_vector(1 downto 0);

    reg_arvalid : in std_logic;
    reg_arready : out std_logic;
    reg_araddr  : in std_logic_vector(5 downto 0);

    reg_rready  : in std_logic;
    reg_rvalid  : out std_logic;
    reg_rdata   : out std_logic_vector(7 downto 0);
    reg_rresp   : out std_logic_vector(1 downto 0);

    -- External pins
    CSn         : out std_logic := '1';
    SCLK        : out std_logic;
    MOSI        : out std_logic := '0';
    MISO        : in std_logic);

end entity spi;
architecture rtl of spi is
  -- Types
  type reg_cs_t is (REG_IDLE, REG_W4DATA, REG_W4ADDR,
                    REG_INIT, REG_ADDRS,   REG_RVALIDS,
                    REG_BRESPS, REG_W4RDREADY, REG_CSDISABLE);

  -- Registered signals with initial values
  signal reg_cs  : reg_cs_t                       := REG_IDLE;
  signal clk_cnt : integer range 0 to 31          := 0;
  signal bit_cnt : integer range 0 to 31          := 0;
  signal reg_we  : std_logic                      := '0';
  signal reg_din : std_logic_vector(7 downto 0)   := (others => '0');
  signal sclk_en : std_logic                      := '0';
  signal reg_addr : std_logic_vector(15 downto 0) := (others => '0');
  signal wr_data  : std_logic_vector(23 downto 0) := (others => '0');

  -- Attributes
  attribute MARK_DEBUG : string;
  attribute MARK_DEBUG of reg_cs : signal is "TRUE";
  attribute MARK_DEBUG of clk_cnt, bit_cnt, reg_we, reg_din : signal is "TRUE";
begin

  SCLK <= '1' when clk_cnt > 15 and sclk_en = '1' else '0';

  reg_rresp <= "00";

  process (sys_clk)
    variable valids : std_logic_vector(1 downto 0);
  begin
    if rising_edge (sys_clk) then
      valids      := reg_awvalid & reg_wvalid;
      reg_arready <= '0';
      reg_awready <= '0';
      reg_wready  <= '0';
      reg_bvalid  <= '0';
      if clk_cnt = 31 then
        bit_cnt   <= bit_cnt + 1;
        clk_cnt   <= 0;
      else
        clk_cnt   <= clk_cnt + 1;
      end if;

      case reg_cs is
        when REG_IDLE =>
          clk_cnt     <= 0;
          bit_cnt     <= 0;
          CSn         <= '1';
          reg_rvalid  <= '0';

          if reg_arvalid then
            reg_we      <= '0';
            reg_arready <= '1';
            reg_addr    <= x"0B" & "00" & reg_araddr;
            CSn         <= '0';
            reg_cs      <= REG_INIT;
          else
            case valids is
              when "11" =>
                reg_addr    <= x"0A" & "00" & reg_awaddr;
                reg_we      <= '1';
                reg_din     <= reg_wdata;
                CSn         <= '0';
                reg_cs      <= REG_INIT;
              when "10" =>
                -- Address only
                reg_awready <= '0';
                reg_addr    <= x"0A" & "00" & reg_awaddr;
                reg_cs      <= REG_W4DATA;
              when "01" =>
                reg_wready <= '0';
                reg_din    <= reg_wdata;
                reg_cs     <= REG_W4ADDR;
              when others =>
            end case;
          end if;
        when REG_W4DATA =>
          reg_we      <= '1';
          reg_din     <= reg_wdata;
          CSn         <= '0';
          reg_cs      <= REG_INIT;
        when REG_W4ADDR =>
          reg_addr    <= x"0A" & "00" & reg_awaddr;
          reg_we      <= '1';
          CSn         <= '0';
          reg_cs      <= REG_INIT;
        when REG_INIT =>
          -- Write out the address
          if clk_cnt = 31 then
            sclk_en <= '1';
            wr_data <= reg_addr & reg_din when reg_we else reg_addr & x"00";
            reg_cs  <= REG_ADDRS;
          end if;
        when REG_ADDRS =>
          if clk_cnt = 31 then
            wr_data <= wr_data(22 downto 0) & '0';
          end if;
          MOSI <= wr_data(23);
          if bit_cnt = 25 and clk_cnt = 0 then
            reg_cs  <= REG_CSDISABLE;
            sclk_en <= '0';
          end if;
          if (bit_cnt > 15) and (clk_cnt = 1) then
            reg_rdata <= reg_rdata(6 downto 0) & MISO;
          end if;
        when REG_CSDISABLE =>
          CSn <= '1';
          if clk_cnt = 31 then
            if reg_we then
              reg_awready <= '1';
              reg_wready  <= '1';
              reg_cs      <= REG_BRESPS;
            elsif reg_rready then
              reg_rvalid  <= '1';
              reg_cs      <= REG_IDLE;
            else
              reg_cs      <= REG_RVALIDS;
            end if;
          end if;
        when REG_RVALIDS =>
          if reg_rready then
            reg_rvalid  <= '1';
            reg_cs      <= REG_IDLE;
          end if;
        when REG_BRESPS =>
          if reg_bready then
            reg_bvalid  <= '1';
            reg_bresp   <= "00"; --/ Okay
            reg_cs      <= REG_IDLE;
          else
            reg_awready <= '0';
            reg_wready  <= '0';
            reg_cs      <= REG_BRESPS;
          end if;
        when REG_W4RDREADY =>
          if reg_rready then
            reg_arready <= '1';
            reg_cs      <= REG_IDLE;
          end if;
      end case;
      if sys_rst then
        reg_cs     <= REG_IDLE;
        CSn        <= '1';
        reg_we     <= '0';
        reg_din    <= x"00";
        reg_bvalid <= '0';
        clk_cnt    <= 0;
        bit_cnt    <= 0;
        sclk_en    <= '0';
        MOSI       <= '0';
      end if;
    end if;
  end process;
end architecture rtl;
