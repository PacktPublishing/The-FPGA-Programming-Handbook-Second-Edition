-- vga_core.vhd
-- ------------------------------------
-- Core of the VGA
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
-- Generate VGA timing, store and display data to the DDR memory.

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;
use IEEE.math_real.all;

library xpm;
use XPM.vcomponents.all;

use work.vga_pkg.all;

entity vga_core is
  port(
    -- Register address
    reg_clk     : in  std_logic;
    reg_reset   : in  std_logic;
    reg_awvalid : in  std_logic;
    reg_awready : out std_logic;
    reg_awaddr  : in  std_logic_vector(11 downto 0);
    reg_wvalid  : in  std_logic;
    reg_wready  : out std_logic;
    reg_wdata   : in  std_logic_vector(31 downto 0);
    reg_wstrb   : in  std_logic_vector(3 downto 0);
    reg_bready  : in  std_logic;
    reg_bvalid  : out std_logic;
    reg_bresp   : out std_logic_vector(1 downto 0);
    reg_arvalid : in  std_logic;        -- @suppress "Unused port"
    reg_arready : out std_logic;
    reg_araddr  : in  std_logic_vector(11 downto 0); -- @suppress "Unused port"
    reg_rready  : in  std_logic;        -- @suppress "Unused port"
    reg_rvalid  : out std_logic;
    reg_rdata   : out std_logic_vector(31 downto 0);
    reg_rresp   : out std_logic_vector(1 downto 0);
    -- Master memory
    mem_clk     : in  std_logic;
    mem_reset   : in  std_logic;
    mem_arid    : out std_logic_vector(3 downto 0);
    mem_araddr  : out std_logic_vector(26 downto 0);
    mem_arlen   : out std_logic_vector(7 downto 0);
    mem_arsize  : out std_logic_vector(2 downto 0);
    mem_arburst : out std_logic_vector(1 downto 0);
    mem_arlock  : out std_logic;
    mem_arvalid : out std_logic;
    mem_arready : in  std_logic;
    mem_rready  : out std_logic;
    mem_rid     : in  std_logic_vector(3 downto 0); -- @suppress "Unused port"
    mem_rdata   : in  std_logic_vector(127 downto 0);
    mem_rresp   : in  std_logic_vector(1 downto 0); -- @suppress "Unused port"
    mem_rlast   : in  std_logic;        -- @suppress "Unused port"
    mem_rvalid  : in  std_logic;
    -- VGA interface
    vga_clk     : in  std_logic;
    vga_rst     : in  std_logic;
    vga_hsync   : out std_logic;
    vga_hblank  : out std_logic;
    vga_vsync   : out std_logic;
    vga_vblank  : out std_logic;
    vga_rgb     : out std_logic_vector(23 downto 0)
  );
end entity vga_core;

architecture rtl of vga_core is

  -- Constants
  constant AXI4_PAGE_SIZE : natural                      := 4096; -- bytes
  constant AXI4_OKAY      : std_logic_vector(1 downto 0) := "00";

  -- Register address offsets
  constant H_DISP_START_WIDTH     : unsigned(11 downto 0) := x"000";
  constant H_DISP_FPEND_TOTAL     : unsigned(11 downto 0) := x"004";
  constant V_DISP_START_WIDTH     : unsigned(11 downto 0) := x"008";
  constant V_DISP_FPEND_TOTAL     : unsigned(11 downto 0) := x"00C";
  constant V_DISP_POLARITY_FORMAT : unsigned(11 downto 0) := x"010";
  constant DISPLAY_ADDR           : unsigned(11 downto 0) := x"100";
  constant DISPLAY_PITCH          : unsigned(11 downto 0) := x"104";
  constant VGA_LOAD_MODE          : unsigned(11 downto 0) := x"108";

  -- Types
  type reg_cs_t is (SM_IDLE, SM_W4ADDR, SM_W4DATA, SM_BRESP);
  type scan_cs_t is (SCAN_IDLE, SCAN_OUT);
  type mem_cs_t is (MEM_IDLE, MEM_W4RSTH, MEM_W4RSTL, MEM_W4RDY0, MEM_W4RDY1, MEM_REQ, MEM_W4RDY2);

  -- Registered signals with initial values
  signal reg_cs                  : reg_cs_t                      := SM_IDLE; -- [reg_clk domain]
  signal reg_addr                : std_logic_vector(11 downto 0) := (others => '0'); -- [reg_clk domain]
  signal reg_we                  : std_logic                     := '0'; -- [reg_clk domain]
  signal reg_din                 : std_logic_vector(31 downto 0) := (others => '0'); -- [reg_clk domain]
  signal reg_be                  : std_logic_vector(3 downto 0)  := (others => '0'); -- [reg_clk domain]
  signal horiz_display_start_reg : unsigned(11 downto 0)         := (others => '0'); -- [reg_clk domain]
  signal horiz_display_width_reg : unsigned(11 downto 0)         := (others => '0'); -- [reg_clk domain]
  signal horiz_sync_width_reg    : unsigned(11 downto 0)         := (others => '0'); -- [reg_clk domain]
  signal horiz_total_width_reg   : unsigned(11 downto 0)         := (others => '0'); -- [reg_clk domain]
  signal vert_display_start_reg  : unsigned(11 downto 0)         := (others => '0'); -- [reg_clk domain]
  signal vert_display_width_reg  : unsigned(11 downto 0)         := (others => '0'); -- [reg_clk domain]
  signal vert_sync_width_reg     : unsigned(11 downto 0)         := (others => '0'); -- [reg_clk domain]
  signal vert_total_width_reg    : unsigned(11 downto 0)         := (others => '0'); -- [reg_clk domain]
  signal polarity_reg            : unsigned(1 downto 0)          := (others => '0'); -- [reg_clk domain]
  signal pitch_reg               : unsigned(12 downto 0)         := (others => '0'); -- [reg_clk domain]
  signal horiz_display_start     : unsigned(11 downto 0)         := (others => '0'); -- [vga_clk domain]
  signal horiz_display_width     : unsigned(11 downto 0)         := (others => '0'); -- [vga_clk domain]
  signal horiz_sync_width        : unsigned(11 downto 0)         := (others => '0'); -- [vga_clk domain]
  signal horiz_total_width       : unsigned(11 downto 0)         := (others => '0'); -- [vga_clk domain]
  signal vert_display_start      : unsigned(11 downto 0)         := (others => '0'); -- [vga_clk domain]
  signal vert_display_width      : unsigned(11 downto 0)         := (others => '0'); -- [vga_clk domain]
  signal vert_sync_width         : unsigned(11 downto 0)         := (others => '0'); -- [vga_clk domain]
  signal vert_total_width        : unsigned(11 downto 0)         := (others => '0'); -- [vga_clk domain]
  signal polarity                : unsigned(1 downto 0)          := (others => '0'); -- [vga_clk domain]
  signal pitch                   : unsigned(12 downto 0)         := (others => '0'); -- [vga_clk domain]
  signal vga_pop                 : std_logic                     := '0'; -- [vga_clk domain]
  signal load_mode               : std_logic                     := '0'; -- [reg_clk domain]
  signal load_mode_sync          : std_logic_vector(2 downto 0)  := "000"; -- [vga_clk domain]
  signal mc_req_sync             : std_logic_vector(2 downto 0)  := "000"; -- [mem_clk domain]
  signal horiz_count             : unsigned(11 downto 0)         := (others => '0'); -- [vga_clk domain]
  signal mc_req                  : std_logic                     := '0'; -- [vga_clk domain]
  signal mc_words                : unsigned(8 downto 0)          := (others => '0'); -- [vga_clk domain]
  signal mc_addr                 : unsigned(mem_araddr'range)    := (others => '0'); -- [vga_clk domain]
  signal fifo_rst                : std_logic                     := '0'; -- [mem_clk domain]
  signal scan_cs                 : scan_cs_t                     := SCAN_IDLE; -- [vga_clk domain]
  signal mem_cs                  : mem_cs_t                      := MEM_IDLE; -- [mem_clk domain]

  -- Unregistered signals
  signal vga_data        : std_logic_vector(127 downto 0); -- [vga_clk domain]
  signal vga_empty       : std_logic;   -- [vga_clk domain]
  signal rd_rst_busy     : std_logic;   -- [vga_clk domain]
  signal wr_rst_busy     : std_logic;   -- [mem_clk domain]
  signal pixel_fifo_full : std_logic;   -- [mem_clk domain]

  -- Attributes
  attribute ASYNC_REG : string;
  attribute ASYNC_REG of load_mode_sync : signal is "TRUE";
  attribute ASYNC_REG of mc_req_sync : signal is "TRUE";
begin

  reg_arready <= '1';
  reg_rvalid  <= '0';
  reg_rdata   <= (others => '0');
  reg_rresp   <= (others => '0');

  ------------------------------------------------------------------------------------------------
  -- AXI4-lite write FSM
  ------------------------------------------------------------------------------------------------

  axi4lite_wr : process(reg_clk)
  begin
    if rising_edge(reg_clk) then
      if reg_reset = '1' then
        reg_we      <= '0';
        reg_addr    <= (others => '0');
        reg_din     <= (others => '0');
        reg_be      <= (others => '0');
        reg_awready <= '0';
        reg_wready  <= '0';
        reg_bvalid  <= '0';
        reg_bresp   <= (others => '0');
        reg_cs      <= SM_IDLE;

      else
        -- Defaults:
        reg_we      <= '0';
        reg_awready <= '0';
        reg_wready  <= '0';

        case reg_cs is
          when SM_IDLE =>
            if reg_awvalid and reg_wvalid then
              -- Address and data are available
              reg_we      <= '1';
              reg_addr    <= reg_awaddr; -- TODO: check address hit, otherwise return SLVERR
              reg_awready <= '1';
              reg_din     <= reg_wdata;
              reg_be      <= reg_wstrb;
              reg_wready  <= '1';
              reg_bvalid  <= '1';
              reg_bresp   <= AXI4_OKAY;
              reg_cs      <= SM_BRESP;
            elsif reg_awvalid then
              -- Address first
              reg_awready <= '1';
              reg_addr    <= reg_awaddr;
              reg_cs      <= SM_W4DATA;
            elsif reg_wvalid then
              -- Data first
              reg_wready <= '1';
              reg_din    <= reg_wdata;
              reg_be     <= reg_wstrb;
              reg_cs     <= SM_W4ADDR;
            end if;

          -- Address received, wait for data
          when SM_W4DATA =>
            if reg_wvalid then
              reg_we     <= '1';
              reg_din    <= reg_wdata;
              reg_be     <= reg_wstrb;
              reg_wready <= '1';
              reg_bvalid <= '1';
              reg_bresp  <= AXI4_OKAY;
              reg_cs     <= SM_BRESP;
            end if;

          -- Data received, wait for address
          when SM_W4ADDR =>
            if reg_awvalid then
              reg_we     <= '1';
              reg_addr   <= reg_awaddr;
              reg_bvalid <= '1';
              reg_bresp  <= AXI4_OKAY;
              reg_cs     <= SM_BRESP;
            end if;

          -- Send write response
          when SM_BRESP =>
            if reg_bready then
              reg_bvalid <= '0';
              reg_cs     <= SM_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------------------------
  -- Register write logic
  ------------------------------------------------------------------------------------------------

  reg_write : process(reg_clk)
  begin
    if rising_edge(reg_clk) then
      if reg_reset = '1' then
        horiz_display_start_reg <= (others => '0');
        horiz_display_width_reg <= (others => '0');
        horiz_sync_width_reg    <= (others => '0');
        horiz_total_width_reg   <= (others => '0');
        vert_display_start_reg  <= (others => '0');
        vert_display_width_reg  <= (others => '0');
        vert_sync_width_reg     <= (others => '0');
        vert_total_width_reg    <= (others => '0');
        polarity_reg            <= (others => '0');
        pitch_reg               <= (others => '0');
        load_mode               <= '0';
      else
        if reg_we then
          case unsigned(reg_addr) is
            when H_DISP_START_WIDTH =>
              if reg_be(0) then
                horiz_display_start_reg(7 downto 0) <= unsigned(reg_din(7 downto 0));
              end if;
              if reg_be(1) then
                horiz_display_start_reg(11 downto 8) <= unsigned(reg_din(11 downto 8));
              end if;
              if reg_be(2) then
                horiz_display_width_reg(7 downto 0) <= unsigned(reg_din(23 downto 16));
              end if;
              if reg_be(3) then
                horiz_display_width_reg(11 downto 8) <= unsigned(reg_din(27 downto 24));
              end if;
            when H_DISP_FPEND_TOTAL =>
              if reg_be(0) then
                horiz_sync_width_reg(7 downto 0) <= unsigned(reg_din(7 downto 0));
              end if;
              if reg_be(1) then
                horiz_sync_width_reg(11 downto 08) <= unsigned(reg_din(11 downto 8));
              end if;
              if reg_be(2) then
                horiz_total_width_reg(7 downto 00) <= unsigned(reg_din(23 downto 16));
              end if;
              if reg_be(3) then
                horiz_total_width_reg(11 downto 08) <= unsigned(reg_din(27 downto 24));
              end if;
            when V_DISP_START_WIDTH =>
              if reg_be(0) then
                vert_display_start_reg(7 downto 00) <= unsigned(reg_din(7 downto 0));
              end if;
              if reg_be(1) then
                vert_display_start_reg(11 downto 08) <= unsigned(reg_din(11 downto 8));
              end if;
              if reg_be(2) then
                vert_display_width_reg(7 downto 00) <= unsigned(reg_din(23 downto 16));
              end if;
              if reg_be(3) then
                vert_display_width_reg(11 downto 08) <= unsigned(reg_din(27 downto 24));
              end if;
            when V_DISP_FPEND_TOTAL =>
              if reg_be(0) then
                vert_sync_width_reg(7 downto 00) <= unsigned(reg_din(7 downto 0));
              end if;
              if reg_be(1) then
                vert_sync_width_reg(11 downto 08) <= unsigned(reg_din(11 downto 8));
              end if;
              if reg_be(2) then
                vert_total_width_reg(7 downto 00) <= unsigned(reg_din(23 downto 16));
              end if;
              if reg_be(3) then
                vert_total_width_reg(11 downto 08) <= unsigned(reg_din(27 downto 24));
              end if;
            when V_DISP_POLARITY_FORMAT =>
              if reg_be(0) then
                polarity_reg(1 downto 00) <= unsigned(reg_din(1 downto 0));
              end if;
            when DISPLAY_ADDR =>
              null;                     -- not used
            when DISPLAY_PITCH =>
              if reg_be(0) then
                pitch_reg(7 downto 00) <= unsigned(reg_din(7 downto 0));
              end if;
              if reg_be(1) then
                pitch_reg(12 downto 08) <= unsigned(reg_din(12 downto 8));
              end if;
            when VGA_LOAD_MODE =>
              if reg_be(0) then
                load_mode <= not load_mode;
              end if;
            when others =>
              report "unsupported register address: " & to_hstring(unsigned(reg_addr)) severity failure;
          end case;
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------------------------
  -- VGA timing generator
  ------------------------------------------------------------------------------------------------

  vga_timing : process(vga_clk)
    variable hsync_en, vsync_en : std_logic;
    variable vga_hblank_v       : std_logic;
    variable vga_vblank_v       : std_logic;

    -- Registered variables
    variable horiz_count_v : unsigned(11 downto 0) := (others => '1');
    variable vert_count_v  : unsigned(11 downto 0) := (others => '1');
    variable scanline      : unsigned(11 downto 0) := (others => '0');
    variable is_init       : boolean               := false;
  begin
    if rising_edge(vga_clk) then
      if vga_rst then
        is_init             := false;
        horiz_count_v       := (others => '1');
        vert_count_v        := (others => '1');
        scanline            := (others => '0');
        horiz_count         <= (others => '0');
        horiz_display_start <= (others => '0');
        horiz_display_width <= (others => '0');
        horiz_sync_width    <= (others => '0');
        horiz_total_width   <= (others => '0');
        vert_display_start  <= (others => '0');
        vert_display_width  <= (others => '0');
        vert_sync_width     <= (others => '0');
        vert_total_width    <= (others => '0');
        polarity            <= (others => '0');
        pitch               <= (others => '0');
        mc_req              <= '0';
        mc_addr             <= (others => '0');
        mc_words            <= (others => '0');
        vga_hblank          <= '0';
        vga_hsync           <= '0';
        vga_vblank          <= '0';
        vga_vsync           <= '0';

      else

        -- Synchronize load_mode
        load_mode_sync <= load_mode_sync(1 downto 0) & load_mode;

        -- Latch new settings in vga_clk domain
        if xor(load_mode_sync(2 downto 1)) then
          horiz_display_start <= horiz_display_start_reg;
          horiz_display_width <= horiz_display_width_reg;
          horiz_sync_width    <= horiz_sync_width_reg;
          horiz_total_width   <= horiz_total_width_reg;
          vert_display_start  <= vert_display_start_reg;
          vert_display_width  <= vert_display_width_reg;
          vert_sync_width     <= vert_sync_width_reg;
          vert_total_width    <= vert_total_width_reg;
          polarity            <= polarity_reg;
          pitch               <= pitch_reg;
          is_init             := true;
        end if;

        if is_init then
          -- Horizontal and vertical pixel counters
          if horiz_count_v >= horiz_total_width then
            horiz_count_v := 12d"0";
            if vert_count_v >= vert_total_width then
              vert_count_v := 12d"0";
            else
              vert_count_v := vert_count_v + 1;
            end if;
            report "vert_count = " & to_string(to_integer(vert_count_v));
          else
            horiz_count_v := horiz_count_v + 1;
          end if;

          -- Generate VGA signals
          vga_hblank_v := '0' when horiz_count_v > horiz_display_start and horiz_count_v <= horiz_display_start + horiz_display_width else '1';
          vga_vblank_v := '0' when vert_count_v > vert_display_start and vert_count_v <= vert_display_start + vert_display_width else '1';
          hsync_en     := '1' when horiz_count_v > horiz_total_width - horiz_sync_width else '0';
          vsync_en     := '1' when vert_count_v > vert_total_width - vert_sync_width else '0';
          horiz_count  <= horiz_count_v;
          vga_hblank   <= vga_hblank_v;
          vga_hsync    <= polarity(1) xor not (hsync_en);
          vga_vblank   <= vga_vblank_v;
          vga_vsync    <= polarity(0) xor not (vsync_en); -- REVIEW: vblank comes but vsync does not

          -- Issue a new memory controller request at the start of every active line
          scanline := vert_count_v - vert_display_start;
          if horiz_count_v = horiz_display_start + horiz_display_width + 1 and vert_count_v >= vert_display_start and vert_count_v < vert_display_start + vert_display_width then
            mc_req   <= not mc_req;
            mc_addr  <= resize(scanline * pitch, mc_addr'length);
            mc_words <= pitch(pitch'high downto 4); -- in units of 16-byte words
          end if;
        end if;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------------------------
  -- Memory controller state machine
  ------------------------------------------------------------------------------------------------

  mem_ctrl : process(mem_clk)
    -- Registered variables 
    variable mc_addr_reg  : unsigned(mc_addr'range)  := (others => '0');
    variable mc_words_reg : unsigned(mc_words'range) := (others => '0');
    variable mc_addr_high : unsigned(mc_addr'range)  := (others => '0'); -- address of the last byte in burst
    variable next_addr    : unsigned(mc_addr'range)  := (others => '0');
    variable len_diff     : unsigned(12 downto 0)    := (others => '0'); -- number of bytes until the next 4 KiB address boundary

  begin
    if rising_edge(mem_clk) then
      if mem_reset then
        mc_addr_reg  := (others => '0');
        mc_words_reg := (others => '0');
        mc_addr_high := (others => '0');
        len_diff     := (others => '0');
        next_addr    := (others => '0');
        mc_req_sync  <= (others => '0');
        mem_cs       <= MEM_IDLE;
        fifo_rst     <= '0';
        mem_arid     <= (others => '0');
        mem_araddr   <= (others => '0');
        mem_arsize   <= (others => '0');
        mem_arburst  <= (others => '0');
        mem_arlock   <= '0';
        mem_arvalid  <= '0';
        mem_arlen    <= (others => '0');

      else
        -- Synchronize memory controller request flag to mem_clk domain
        mc_req_sync <= mc_req_sync(1 downto 0) & mc_req;

        case mem_cs is

          when MEM_IDLE =>
            if xor(mc_req_sync(2 downto 1)) then
              mc_addr_reg  := mc_addr;  -- assuming mc_addr is stable an can be safely registered into mem_clk domain here
              mc_words_reg := mc_words; -- assuming mc_words is stable an can be safely registered into mem_clk domain here
              fifo_rst     <= '1';
              mem_cs       <= MEM_W4RSTH;
            end if;

          when MEM_W4RSTH =>
            mc_addr_high := mc_addr_reg + mc_words_reg * BYTES_PER_PAGE - 1;
            len_diff     := resize(AXI4_PAGE_SIZE - (mc_addr_reg mod AXI4_PAGE_SIZE), 13); -- max. value : 4096
            --
            if wr_rst_busy then
              fifo_rst <= '0';
              mem_cs   <= MEM_W4RSTL;
            end if;

          when MEM_W4RSTL =>
            if not wr_rst_busy then
              mem_arid    <= (others => '0');
              mem_araddr  <= std_logic_vector(mc_addr_reg);
              mem_arsize  <= "100";     -- 16 bytes
              mem_arburst <= "01";      -- incrementing
              mem_arlock  <= '0';
              mem_arvalid <= '1';
              --
              if mc_addr_high(mc_addr_high'high downto 12) /= mc_addr_reg(mc_addr_reg'high downto 12) then
                -- Burst is crossing a 4 KiB address boundary.
                assert len_diff mod BYTES_PER_PAGE = 0 severity failure;
                assert len_diff < 256 * BYTES_PER_PAGE report "burst length out of range" severity failure;
                mem_arlen <= std_logic_vector(resize((len_diff / BYTES_PER_PAGE) - 1, 8));
                next_addr := mc_addr_reg + resize(len_diff * BYTES_PER_PAGE, mc_addr_reg'length);
                len_diff  := resize(mc_words_reg * BYTES_PER_PAGE - len_diff, len_diff'length);
                mem_cs    <= MEM_W4RDY1;
              else
                -- Burst is not crossing a 4 KiB address boundary.
                assert mc_words_reg <= 256 report "burst length out of range" severity failure;
                mem_arlen <= std_logic_vector(resize(mc_words_reg - 1, 8));
                mem_cs    <= MEM_W4RDY0;
              end if;
            end if;

          -- Set mem_arvalid, wait for mem_arready (burst not crossing a 4 KiB address boundary)
          when MEM_W4RDY0 =>
            assert mem_arvalid severity failure;
            if mem_arready then
              mem_arvalid <= '0';
              mem_cs      <= MEM_IDLE;
            end if;

          -- Set mem_arvalid, wait for mem_arready (burst *is* crossing a 4 KiB address boundary)
          when MEM_W4RDY1 =>
            assert mem_arvalid severity failure;
            if mem_arready then
              mem_arvalid <= '0';
              mem_cs      <= MEM_REQ;
            end if;

          -- Issue remaing part of a burst crossing a 4 KiB address boundary 
          when MEM_REQ =>
            mem_arid    <= (others => '0');
            mem_araddr  <= std_logic_vector(next_addr);
            mem_arsize  <= "100";       -- 16 bytes
            mem_arburst <= "01";        -- incrementing
            mem_arlock  <= '0';
            mem_arvalid <= '1';
            mem_arlen   <= std_logic_vector(len_diff(7 downto 0));
            mem_cs      <= MEM_W4RDY2;

          -- Set mem_arvalid, wait for mem_arready
          when MEM_W4RDY2 =>
            assert mem_arvalid severity failure;
            if mem_arready then
              mem_arvalid <= '0';
              mem_cs      <= MEM_IDLE;
            end if;

        end case;
      end if;
    end if;
  end process mem_ctrl;

  -- Pixel FIFO
  -- Sized large enough to hold one scanline at 1920x32bpp (480 bytes)
  pixel_fifo : xpm_fifo_async
    generic map(
      FIFO_WRITE_DEPTH => 512,
      WRITE_DATA_WIDTH => 128,
      READ_DATA_WIDTH  => 128,
      READ_MODE        => "fwft"
    )
    port map(
      sleep         => '0',
      rst           => fifo_rst,
      --
      wr_clk        => mem_clk,
      wr_en         => mem_rvalid,
      din           => mem_rdata,
      wr_rst_busy   => wr_rst_busy,
      full          => pixel_fifo_full,
      --
      rd_clk        => vga_clk,
      rd_en         => vga_pop,
      dout          => vga_data,
      empty         => vga_empty,
      rd_rst_busy   => rd_rst_busy,
      --
      injectsbiterr => '0',
      injectdbiterr => '0'
    );

  mem_rready <= not pixel_fifo_full;

  -- Read pixel data from pixel FIFO and convert values to RGB
  -- REVIEW: adds one-cycle delay to vga_rgb vs. sync signals
  read_fifo : process(vga_clk)
    variable pix_count : natural range 0 to 127;
  begin
    if rising_edge(vga_clk) then
      if vga_rst or rd_rst_busy then
        scan_cs   <= SCAN_IDLE;
        vga_pop   <= '0';
        vga_rgb   <= (others => '0');
        pix_count := 0;
      else
        vga_pop <= '0';
        case scan_cs is
          when SCAN_IDLE =>
            if horiz_count = horiz_display_start then
              pix_count := 0;
              if vga_data(pix_count) and not vga_empty then
                vga_rgb <= (others => '1');
              else
                vga_rgb <= (others => '0');
              end if;
              scan_cs   <= SCAN_OUT;
              pix_count := pix_count + 1;
            end if;

          when SCAN_OUT =>
            if vga_data(pix_count) then
              vga_rgb <= (others => '1');
            else
              vga_rgb <= (others => '0');
            end if;
            if pix_count = 126 then
              vga_pop <= not vga_empty;
            end if;
            pix_count := pix_count + 1 when pix_count < 127 else 0;
        end case;
      end if;
    end if;
  end process;

end architecture rtl;
