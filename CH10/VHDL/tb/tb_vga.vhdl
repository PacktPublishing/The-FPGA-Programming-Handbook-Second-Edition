-- tb_vga.vhd
-- ------------------------------------
-- VGA display controller testbench
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.vga_pkg.all;
use work.bmp_pkg.all;

entity tb_vga is
  generic(
    VGA_RESOLUTION : natural range 0 to 17 := 0 -- VGA resolution setting
  );
end entity tb_vga;

architecture RTL of tb_vga is

  signal clk        : std_logic := '0';
  signal vga_hsync  : std_logic;
  signal vga_vsync  : std_logic;
  signal vga_rgb    : std_logic_vector(11 downto 0);
  signal SW         : std_logic_vector(4 downto 0);
  signal button_c   : std_logic;
  signal ddr2_addr  : std_logic_vector(12 downto 0);
  signal ddr2_ba    : std_logic_vector(2 downto 0);
  signal ddr2_cas_n : std_logic;
  signal ddr2_ck_n  : std_logic_vector(0 downto 0);
  signal ddr2_ck_p  : std_logic_vector(0 downto 0);
  signal ddr2_cke   : std_logic_vector(0 downto 0);
  signal ddr2_ras_n : std_logic;
  signal ddr2_we_n  : std_logic;
  signal ddr2_dq    : std_logic_vector(15 downto 0);
  signal ddr2_dqs_n : std_logic_vector(1 downto 0);
  signal ddr2_dqs_p : std_logic_vector(1 downto 0);
  signal ddr2_cs_n  : std_logic_vector(0 downto 0);
  signal ddr2_dm    : std_logic_vector(1 downto 0);
  signal ddr2_odt   : std_logic_vector(0 downto 0);

begin

  --------------------------------------------------------------------------------------------------
  -- 100 MHz board block generation
  --------------------------------------------------------------------------------------------------

  clk <= not clk after 5 ns;

  --------------------------------------------------------------------------------------------------
  -- Test process
  --------------------------------------------------------------------------------------------------

  test : process is
    alias init_calib_complete is << signal .tb_vga.u_vga.init_calib_complete : std_logic >>;
    alias locked is << signal .tb_vga.u_vga.locked : std_logic >>;
  begin
    SW       <= std_logic_vector(to_unsigned(VGA_RESOLUTION, SW'length));
    button_c <= '0';
    wait until rising_edge(init_calib_complete);
    report "DDR calibration complete";
    wait on clk until locked;
    report "pix_clk MMCM locked";
    button_c <= '1';
    wait for 1 us;
    button_c <= '0';
    wait;
  end process test;

  --------------------------------------------------------------------------------------------------
  -- Unit under test
  --------------------------------------------------------------------------------------------------

  u_vga : entity work.vga
    port map(
      clk        => clk,
      vga_hsync  => vga_hsync,
      vga_vsync  => vga_vsync,
      vga_rgb    => vga_rgb,
      SW         => SW,
      button_c   => button_c,
      ddr2_addr  => ddr2_addr,
      ddr2_ba    => ddr2_ba,
      ddr2_cas_n => ddr2_cas_n,
      ddr2_ck_n  => ddr2_ck_n,
      ddr2_ck_p  => ddr2_ck_p,
      ddr2_cke   => ddr2_cke,
      ddr2_ras_n => ddr2_ras_n,
      ddr2_we_n  => ddr2_we_n,
      ddr2_dq    => ddr2_dq,
      ddr2_dqs_n => ddr2_dqs_n,
      ddr2_dqs_p => ddr2_dqs_p,
      ddr2_cs_n  => ddr2_cs_n,
      ddr2_dm    => ddr2_dm,
      ddr2_odt   => ddr2_odt
    );

  --------------------------------------------------------------------------------------------------
  -- Save VGA output frames to *.bmp files
  --------------------------------------------------------------------------------------------------

  save_bmp : process is
    constant WIDTH     : natural := to_integer(RESOLUTION(VGA_RESOLUTION).horiz_display_width); -- e.g. 640
    constant HEIGHT    : natural := to_integer(RESOLUTION(VGA_RESOLUTION).vert_display_width); -- e.g. 480
    variable frame_idx : natural;
    variable bmp_data  : integer_vector(0 to WIDTH * HEIGHT * 3 - 1);
    alias vga_clk is << signal .tb_vga.u_vga.vga_clk : std_logic >>;
    alias vga_hblank is << signal .tb_vga.u_vga.u_vga_core.vga_hblank : std_logic >>;
    alias vga_vblank is << signal .tb_vga.u_vga.u_vga_core.vga_vblank : std_logic >>;
  begin
    frame_idx := 0;
    loop
      wait until falling_edge(vga_vblank);
      for y in 0 to HEIGHT - 1 loop
        for x in 0 to WIDTH - 1 loop
          wait on vga_clk until rising_edge(vga_clk) and vga_hblank = '0';
          -- Scale RGB values to range 0..255
          bmp_data(y * WIDTH * 3 + x * 3 + 0) := to_integer(unsigned(vga_rgb(3 downto 0))) * 17; -- R 
          bmp_data(y * WIDTH * 3 + x * 3 + 1) := to_integer(unsigned(vga_rgb(7 downto 4))) * 17; -- G
          bmp_data(y * WIDTH * 3 + x * 3 + 2) := to_integer(unsigned(vga_rgb(11 downto 8))) * 17; -- B
        end loop;
      end loop;
      write_bmp("img_" & to_string(frame_idx) & ".bmp", WIDTH, HEIGHT, bmp_data);
      report "wrote img_" & to_string(frame_idx) & ".bmp";
      frame_idx := frame_idx + 1;
    end loop;
    wait;
  end process save_bmp;

end architecture RTL;
