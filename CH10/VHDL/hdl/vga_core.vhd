LIBRARY IEEE, XPM;
USE IEEE.std_logic_1164.all;
USE IEEE.std_logic_SIGNED.all;
USE ieee.numeric_std.all;
use IEEE.math_real.all;
use XPM.vcomponents.all;

entity vga_core is
  port (-- Register address
        reg_clk        : in  std_logic;
        reg_reset      : in  std_logic;

        reg_awvalid    : in  std_logic;
        reg_awready    : out std_logic;
        reg_awaddr     : in  std_logic_vector(11 downto 0);

        reg_wvalid     : in  std_logic;
        reg_wready     : out std_logic;
        reg_wdata      : in  std_logic_vector(31 downto 0);
        reg_wstrb      : in  std_logic_vector(3 downto 0);

        reg_bready     : in  std_logic;
        reg_bvalid     : out std_logic;
        reg_bresp      : out std_logic_vector(1 downto 0);

        reg_arvalid    : in  std_logic;
        reg_arready    : out std_logic;
        reg_araddr     : in  std_logic_vector(11 downto 0);

        reg_rready     : in  std_logic;
        reg_rvalid     : out std_logic;
        reg_rdata      : out std_logic_vector(31 downto 0);
        reg_rresp      : out std_logic_vector(1 downto 0);

        -- Master memory
        mem_clk        : in  std_logic;
        mem_reset      : in  std_logic;

        mem_arid       : out std_logic_vector(3 downto 0);
        mem_araddr     : out std_logic_vector(26 downto 0);
        mem_arlen      : out std_logic_vector(7 downto 0);
        mem_arsize     : out std_logic_vector(2 downto 0);
        mem_arburst    : out std_logic_vector(1 downto 0);
        mem_arlock     : out std_logic;
        mem_arvalid    : out std_logic;
        mem_arready    : in  std_logic;

        mem_rready     : out std_logic;
        mem_rid        : in  std_logic_vector(3 downto 0);
        mem_rdata      : in  std_logic_vector(127 downto 0);
        mem_rresp      : in  std_logic_vector(1 downto 0);
        mem_rlast      : in  std_logic;
        mem_rvalid     : in  std_logic;

        vga_clk        : in  std_logic;
        vga_hsync      : out std_logic;
        vga_hblank     : out std_logic;
        vga_vsync      : out std_logic;
        vga_vblank     : out std_logic;
        vga_rgb        : out std_logic_vector(23 downto 0));
end entity vga_core;

architecture rtl of vga_core is
  attribute ASYNC_REG : string;
  constant H_DISP_START_WIDTH     : unsigned := x"000";
  constant H_DISP_FPEND_TOTAL     : unsigned := x"004";
  constant V_DISP_START_WIDTH     : unsigned := x"008";
  constant V_DISP_FPEND_TOTAL     : unsigned := x"00C";
  constant V_DISP_POLARITY_FORMAT : unsigned := x"010";
  constant DISPLAY_ADDR           : unsigned := x"100";
  constant DISPLAY_PITCH          : unsigned := x"104";
  constant VGA_LOAD_MODE          : unsigned := x"108";

  type reg_cs_t is (SM_IDLE, SM_W4ADDR, SM_W4DATA, SM_BRESP);

  signal reg_cs : reg_cs_t := SM_IDLE;
  signal reg_addr : std_logic_vector(11 downto 0);
  signal reg_we : std_logic;
  signal reg_din : std_logic_vector(31 downto 0);
  signal reg_be  : std_logic_vector(3 downto 0);
  signal horiz_display_start_reg : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(47, 12));
  signal horiz_display_width_reg : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(640, 12));
  signal horiz_sync_width_reg    : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(96, 12));
  signal horiz_total_width_reg   : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(799, 12));
  signal vert_display_start_reg  : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(31, 12));
  signal vert_display_width_reg  : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(480, 12));
  signal vert_sync_width_reg     : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(2, 12));
  signal vert_total_width_reg    : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(524, 12));
  signal disp_addr_reg           : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(0, 32));
  signal pixel_depth_reg         : std_logic_vector(7 downto 0);
  signal polarity_reg            : std_logic_vector(1 downto 0)  := std_logic_vector(to_unsigned(0, 2));
  signal pitch_reg               : std_logic_vector(12 downto 0) := std_logic_vector(to_unsigned(5*16, 13));
  signal horiz_display_start     : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(47, 12));
  signal horiz_display_width     : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(640, 12));
  signal horiz_sync_width        : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(96, 12));
  signal horiz_total_width       : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(799, 12));
  signal vert_display_start      : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(31, 12));
  signal vert_display_width      : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(480, 12));
  signal vert_sync_width         : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(2, 12));
  signal vert_total_width        : std_logic_vector(11 downto 0) := std_logic_vector(to_unsigned(524, 12));
  signal disp_addr               : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(0, 32));
  signal pixel_depth             : std_logic_vector(7 downto 0);
  signal polarity                : std_logic_vector(1 downto 0)  := std_logic_vector(to_unsigned(0, 2));
  signal pitch                   : std_logic_vector(12 downto 0) := std_logic_vector(to_unsigned(5*16, 13));
  signal vga_pop                 : std_logic;
  signal vga_data                : std_logic_vector(127 downto 0);
  signal vga_empty               : std_logic;
  signal load_mode               : std_logic := '0';
  signal load_mode_sync          : std_logic_vector(2 downto 0) := "000";
  signal mc_req_sync             : std_logic_vector(2 downto 0) := "000";
  attribute ASYNC_REG of load_mode_sync : signal is "TRUE";
  attribute ASYNC_REG of mc_req_sync : signal is "TRUE";
  signal horiz_count             : std_logic_vector(11 downto 0) := (others => '0');
  signal vert_count              : std_logic_vector(11 downto 0) := (others => '0');
  signal mc_req                  : std_logic := '0';
  signal mc_words                : std_logic_vector(8 downto 0);
  signal mc_addr                 : std_logic_vector(24 downto 0);
  signal fifo_rst                : std_logic := '0';
  signal scanline                : std_logic_vector(11 downto 0);
  signal last_hblank             : std_logic;
  signal pix_count               : std_logic_vector(6 downto 0);
  signal rd_rst_busy             : std_logic;
  type scan_cs_t is (SCAN_IDLE, SCAN_OUT);
  signal scan_cs : scan_cs_t := SCAN_IDLE;
  signal wr_rst_busy             : std_logic;
  signal mem_wait                : std_logic := '0';
  type mem_cs_t is (MEM_IDLE, MEM_W4RSTH, MEM_W4RSTL,
                    MEM_W4RDY0, MEM_W4RDY1, MEM_REQ);
  signal mem_cs : mem_cs_t := MEM_IDLE;
  signal next_addr               : std_logic_vector(28 downto 0);
  signal len_diff                : std_logic_vector(10 downto 0);

  signal mem_arid_r              : std_logic_vector(3 downto 0) := x"0";
  signal mem_araddr_r            : std_logic_vector(26 downto 0) := (others => '0');
  signal mem_arlen_r             : std_logic_vector(7 downto 0) := (others => '0');
  signal mem_arsize_r            : std_logic_vector(2 downto 0) := "100"; -- 16bytes
  signal mem_arburst_r           : std_logic_vector(1 downto 0) := "01";  -- incrementing
  signal mem_arlock_r            : std_logic := '0';
  signal mem_arvalid_r           : std_logic := '0';
  signal mem_rready_r            : std_logic := '1';
  signal reg_awready_r           : std_logic;
  signal reg_wready_r            : std_logic;
  signal reg_bvalid_r            : std_logic;
  signal reg_bresp_r             : std_logic_vector(1 downto 0);
  signal reg_arready_r           : std_logic;
  signal reg_rvalid_r            : std_logic;
  signal reg_rdata_r             : std_logic_vector(31 downto 0);
  signal reg_rresp_r             : std_logic_vector(1 downto 0);
  signal vga_hsync_r             : std_logic;
  signal vga_hblank_r            : std_logic;
  signal vga_vsync_r             : std_logic;
  signal vga_vblank_r            : std_logic;
  signal vga_rgb_r               : std_logic_vector(23 downto 0);


begin

  mem_arid    <= mem_arid_r;
  mem_araddr  <= mem_araddr_r;
  mem_arlen   <= mem_arlen_r;
  mem_arsize  <= mem_arsize_r;
  mem_arburst <= mem_arburst_r;
  mem_arlock  <= mem_arlock_r;
  mem_arvalid <= mem_arvalid_r;

  mem_rready  <= mem_rready_r;
  reg_awready <= reg_awready_r;
  reg_wready  <= reg_wready_r;
  reg_bvalid  <= reg_bvalid_r;
  reg_bresp   <= reg_bresp_r;
  reg_arready <= '1';
  reg_rvalid  <= '0';
  reg_rdata   <= (others => '0');
  reg_rresp   <= (others => '0');
  vga_hsync   <= vga_hsync_r;
  vga_hblank  <= vga_hblank_r;
  vga_vsync   <= vga_vsync_r;
  vga_vblank  <= vga_vblank_r;
  vga_rgb     <= vga_rgb_r;

  process (reg_clk)
    variable valid : std_logic_vector(1 downto 0);
  begin
    valid := reg_awvalid & reg_awvalid;
    if rising_edge(reg_clk) then
      reg_we     <= '0';
      reg_bvalid_r <= '0';

      case reg_cs is
        when SM_IDLE =>
          reg_awready   <= '1';
          reg_wready_r  <= '1';
          case valid is
            when "11" =>
              -- Addr and data are available
              reg_addr    <= reg_awaddr;
              reg_we      <= '1';
              reg_din     <= reg_wdata;
              reg_be      <= reg_wstrb;
              if reg_bready then
                reg_awready   <= '1';
                reg_wready_r  <= '1';
                reg_bvalid_r  <= '1';
                reg_bresp_r   <= (others => '0'); -- Okay
              else
                reg_awready   <= '0';
                reg_wready_r  <= '0';
                reg_cs        <= SM_BRESP;
              end if;
            when "10" =>
              -- Address only
              reg_awready <= '0';
              reg_addr    <= reg_awaddr;
              reg_cs      <= SM_W4DATA;
            when "01" =>
              reg_wready_r <= '0';
              reg_din      <= reg_wdata;
              reg_be       <= reg_wstrb;
              reg_cs       <= SM_W4ADDR;
            when others =>
          end case;
        when SM_W4DATA =>
          reg_we      <= '1';
          reg_din     <= reg_wdata;
          reg_be      <= reg_wstrb;
          if reg_bready then
            reg_awready   <= '1';
            reg_wready_r  <= '1';
            reg_bvalid_r  <= '1';
            reg_bresp_r   <= (others => '0'); -- Okay
            reg_cs        <= SM_IDLE;
          else
            reg_awready   <= '0';
            reg_wready_r  <= '0';
            reg_cs        <= SM_BRESP;
          end if;
        when SM_W4ADDR =>
          reg_addr    <= reg_awaddr;
          reg_we      <= '1';
          if reg_bready then
            reg_awready   <= '1';
            reg_wready_r  <= '1';
            reg_bvalid_r  <= '1';
            reg_bresp_r   <= (others => '0'); -- Okay
            reg_cs        <= SM_IDLE;
          else
            reg_awready   <= '0';
            reg_wready_r  <= '0';
            reg_cs        <= SM_BRESP;
          end if;
        when SM_BRESP =>
          if reg_bready then
            reg_awready   <= '1';
            reg_wready_r  <= '1';
            reg_bvalid_r  <= '1';
            reg_bresp_r   <= (others => '0'); -- Okay
            reg_cs        <= SM_IDLE;
          else
            reg_awready   <= '0';
            reg_wready_r  <= '0';
            reg_cs        <= SM_BRESP;
          end if;
      end case;
    end if;
  end process;

  process (reg_clk) begin
    if rising_edge(reg_clk) then
      if reg_we then
        case reg_addr is
          when std_logic_vector(H_DISP_START_WIDTH) =>
            if reg_be(0) then horiz_display_start_reg(7 downto 0)  <= reg_din(7 downto 0); end if;
            if reg_be(1) then horiz_display_start_reg(11 downto 8) <= reg_din(11 downto 8); end if;
            if reg_be(2) then horiz_display_width_reg(7 downto 0)  <= reg_din(23 downto 16); end if;
            if reg_be(3) then horiz_display_width_reg(11 downto 8) <= reg_din(27 downto 24); end if;
          when std_logic_vector(H_DISP_FPEND_TOTAL) =>
            if reg_be(0) then horiz_sync_width_reg(7 downto 0)   <= reg_din(7 downto 0); end if;
            if reg_be(1) then horiz_sync_width_reg(11 downto 08)  <= reg_din(11 downto 8); end if;
            if reg_be(2) then horiz_total_width_reg(7 downto 00)  <= reg_din(23 downto 16); end if;
            if reg_be(3) then horiz_total_width_reg(11 downto 08) <= reg_din(27 downto 24); end if;
          when std_logic_vector(V_DISP_START_WIDTH) =>
            if reg_be(0) then vert_display_start_reg(7 downto 00)  <= reg_din(7 downto 0); end if;
            if reg_be(1) then vert_display_start_reg(11 downto 08) <= reg_din(11 downto 8); end if;
            if reg_be(2) then vert_display_width_reg(7 downto 00)  <= reg_din(23 downto 16); end if;
            if reg_be(3) then vert_display_width_reg(11 downto 08) <= reg_din(27 downto 24); end if;
          when std_logic_vector(V_DISP_FPEND_TOTAL) =>
            if reg_be(0) then vert_sync_width_reg(7 downto 00)   <= reg_din(7 downto 0); end if;
            if reg_be(1) then vert_sync_width_reg(11 downto 08)  <= reg_din(11 downto 8); end if;
            if reg_be(2) then vert_total_width_reg(7 downto 00)  <= reg_din(23 downto 16); end if;
            if reg_be(3) then vert_total_width_reg(11 downto 08) <= reg_din(27 downto 24); end if;
          when std_logic_vector(V_DISP_POLARITY_FORMAT) =>
            if reg_be(0) then polarity_reg(1 downto 00)     <= reg_din(1 downto 0); end if;
            if reg_be(1) then pixel_depth_reg(7 downto 00)  <= reg_din(15 downto 8); end if;
          when std_logic_vector(DISPLAY_ADDR) =>
            if reg_be(0) then disp_addr_reg(7 downto 00)    <= reg_din(7 downto 0); end if;
            if reg_be(1) then disp_addr_reg(15 downto 08)   <= reg_din(15 downto 8); end if;
            if reg_be(2) then disp_addr_reg(23 downto 016)  <= reg_din(23 downto 16); end if;
            if reg_be(3) then disp_addr_reg(31 downto 024)  <= reg_din(31 downto 24); end if;
          when std_logic_vector(DISPLAY_PITCH) =>
            if reg_be(0) then pitch_reg(7 downto 00)        <= reg_din(7 downto 0); end if;
            if reg_be(1) then pitch_reg(12 downto 08)       <= reg_din(12 downto 8); end if;
          when std_logic_vector(VGA_LOAD_MODE) => if reg_be(0) then load_mode <= not load_mode; end if;
          when others =>
        end case;
      end if;
    end if;
  end process;

  process (vga_clk)
    variable gt_start, lt_end, hsync_en, gt_vbstart, lt_vbend, vsync_en : std_logic;
    variable right_side, hsync_val, vb_right, vsync_start : std_logic_vector(11 downto 0);
  begin
    if horiz_count > horiz_display_start then
      gt_start := '1';
    else
      gt_start := '0';
    end if;
    right_side := horiz_display_start + horiz_display_width;
    if horiz_count <= right_side then
      lt_end := '1';
    else
      lt_end := '0';
    end if;
    hsync_val := horiz_total_width - horiz_sync_width;
    if horiz_count > hsync_val then
      hsync_en := '1';
    else
      hsync_en := '0';
    end if;
    if vert_count > vert_display_start then
      gt_vbstart := '1';
    else
      gt_vbstart := '0';
    end if;
    vb_right := vert_display_start + vert_display_width;
    if vert_count <= vb_right then
      lt_vbend := '1';
    else
      lt_vbend := '0';
    end if;
    vsync_start := vert_total_width - vert_sync_width;
    if vert_count > vsync_start then
      vsync_en := '1';
    else
      vsync_en := '0';
    end if;
    if rising_edge(vga_clk) then
      load_mode_sync <= load_mode_sync(1 downto 0) & load_mode;
      if xor(load_mode_sync(2 downto 1)) then
        horiz_display_start <= horiz_display_start_reg;
        horiz_display_width <= horiz_display_width_reg;
        horiz_sync_width    <= horiz_sync_width_reg;
        horiz_total_width   <= horiz_total_width_reg;
        vert_display_start  <= vert_display_start_reg;
        vert_display_width  <= vert_display_width_reg;
        vert_sync_width     <= vert_sync_width_reg;
        vert_total_width    <= vert_total_width_reg;
        disp_addr           <= disp_addr_reg;
        polarity            <= polarity_reg;
        pixel_depth         <= pixel_depth_reg;
        pitch               <= pitch_reg;
      end if;
      if horiz_count >= horiz_total_width then
        horiz_count <= (others => '0');
        if vert_count >= vert_total_width then vert_count <= (others =>'0');
        else vert_count <= vert_count + 1; end if;
        scanline <= vert_count - vert_display_start + 2;
        mc_addr  <= scanline * pitch;
        mc_words <= pitch(12 downto 4) + or(pitch(3 downto 0));
      else
        horiz_count <= horiz_count + 1;
      end if;
      if vga_hblank_r and not last_hblank and not vga_vblank_r then mc_req   <= not mc_req; end if;
      last_hblank   <= vga_hblank_r;

      vga_hblank_r    <= not(gt_start and lt_end);
      vga_hsync_r     <= polarity(1) xor not(hsync_en);

      vga_vblank_r    <= not(gt_vbstart and lt_vbend);
      vga_vsync_r     <= polarity(0) xor not(vsync_en);
    end if;
  end process;

  process (vga_clk) begin
    if rising_edge(vga_clk) then
      vga_pop <= '0';
      case scan_cs is
        when SCAN_IDLE =>
          if horiz_count = horiz_display_start then
            if vga_data(0) and not vga_empty then
              vga_rgb_r <= (others => '1');
            else
              vga_rgb_r <= (others => '0');
            end if;
            scan_cs   <= SCAN_OUT;
            pix_count <= (others => '0');
          end if;
        when SCAN_OUT =>
          pix_count <= pix_count + 1;
          -- Right now just do single bit per pixel
          if pix_count = 126 then
            vga_pop <= not vga_empty;
          end if;
          if vga_data(to_integer(unsigned(pix_count))) then
            vga_rgb_r <= (others => '1');
          else
            vga_rgb_r <= (others => '0');
          end if;
          if rd_rst_busy then scan_cs <= SCAN_IDLE; end if;
      end case;
    end if;
  end process;


  -- Pixel FIFO
  -- Sized large enough to hold one scanline at 1920x32bpp (480 bytes)
  u_xpm_fifo_async : xpm_fifo_async
    generic map(
     FIFO_WRITE_DEPTH       => 512,
     WRITE_DATA_WIDTH       => 128,
     READ_DATA_WIDTH        => 128,
     READ_MODE              => "fwft")
    port map(
     sleep                  => '0',
     rst                    => fifo_rst,

     wr_clk                 => mem_clk,
     wr_en                  => mem_rvalid,
     din                    => mem_rdata,
     wr_rst_busy            => wr_rst_busy,

     rd_clk                 => vga_clk,
     rd_en                  => vga_pop,
     dout                   => vga_data,
     empty                  => vga_empty,
     rd_rst_busy            => rd_rst_busy,

     injectsbiterr          => '0',
     injectdbiterr          => '0');


  -- memory controller state machine
  process (mem_clk) begin
    if rising_edge(mem_clk) then
      mc_req_sync <= mc_req_sync(1 downto 0) & mc_req;
      case mem_cs is
        when MEM_IDLE =>
          mem_arvalid_r <= '0';
          if xor(mc_req_sync(2 downto 1)) then
            fifo_rst <= '1';
            mem_cs   <= MEM_W4RSTH;
          end if;
        when MEM_W4RSTH =>
          next_addr <= "0000" & (mc_addr + (mc_words(7 downto 0) & x"0")); -- Look to see if we need to break req
          len_diff  <= 2047 - mc_addr(10 downto 0);
          if wr_rst_busy then
            fifo_rst <= '0';
            mem_cs   <= MEM_W4RSTL;
          end if;

        when MEM_W4RSTL =>
          if not wr_rst_busy then
            mem_arid_r    <= (others => '0');
            mem_araddr_r  <= "000000" & mc_addr(20 downto 0);
            mem_arsize_r  <= "100"; -- 16 bytes
            mem_arburst_r <= "01"; -- incrementing
            mem_arlock_r  <= '0';
            mem_arvalid_r <= '1';
            next_addr   <= "0000" & (mc_addr  + len_diff(7 downto 0) + 1);
            len_diff    <= "000" & (mc_words(7 downto 0) - len_diff(7 downto 0));
            if next_addr(24 downto 11) /= mc_addr(24 downto 11) then
              -- look if we are going to cross 2K boundary
              mem_arlen_r <= len_diff(7 downto 0);
              if mem_arready then
                mem_cs <= MEM_REQ;
              else
                mem_cs <= MEM_W4RDY1;
              end if;
            else
              mem_arlen_r   <= mc_words(7 downto 0) - 1;
              if mem_arready then
                mem_cs <= MEM_IDLE;
              else
                mem_cs <= MEM_W4RDY0;
              end if;
            end if;
          end if;
        when MEM_W4RDY0 =>
          if mem_arready then
            mem_cs        <= MEM_IDLE;
            mem_arvalid_r <= '0';
          else
            mem_cs <= MEM_W4RDY0;
          end if;
        when MEM_W4RDY1 =>
          if mem_arready then
            mem_cs        <= MEM_REQ;
            mem_arvalid_r <= '0';
          else
            mem_cs <= MEM_W4RDY1;
          end if;
        when MEM_REQ =>
          if not wr_rst_busy then
            mem_arid_r    <= (others => '0');
            mem_araddr_r  <= next_addr(26 downto 0);
            mem_arsize_r  <= "100"; -- 16 bytes
            mem_arburst_r <= "01"; -- incrementing
            mem_arlock_r  <= '0';
            mem_arvalid_r <= '1';
            mem_arlen_r   <= len_diff(7 downto 0);
            if mem_arready then
              mem_cs <= MEM_IDLE;
            else
              mem_cs <= MEM_W4RDY0;
            end if;
          end if;
      end case;
    end if;
  end process;
end architecture rtl;
