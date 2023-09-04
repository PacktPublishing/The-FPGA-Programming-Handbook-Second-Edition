-- bmp_pkg.vhd
-- ------------------------------------
-- BMP utility package
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package bmp_pkg is

  --------------------------------------------------------------------------------------------------
  -- Types
  --------------------------------------------------------------------------------------------------

  subtype byte_t is std_logic_vector(7 downto 0);
  type byte_array_t is array (natural range <>) of byte_t;

  type binary_file_t is protected
    procedure fopen(filename : string);
    procedure write_byte(data : byte_t);
    procedure write_array(data : byte_array_t);
    procedure write_int_array(data : integer_vector);
    procedure fclose;
  end protected binary_file_t;

  --------------------------------------------------------------------------------------------------
  -- Subprograms
  --------------------------------------------------------------------------------------------------

  procedure write_bmp(filename : string; width : natural; height : natural; data : integer_vector);

end package bmp_pkg;

package body bmp_pkg is

  procedure write_bmp(filename : string; width : natural; height : natural; data : integer_vector) is
    variable width_u32  : unsigned(31 downto 0);
    variable height_u32 : unsigned(31 downto 0);
    variable f          : binary_file_t;
    variable r, g, b    : natural;
  begin
    width_u32  := to_unsigned(width, 32);
    height_u32 := to_unsigned(height, 32);

    f.fopen(filename);

    -- Bitmap file header
    f.write_array((8x"42", 8x"4D"));    -- offset 0
    f.write_array((8x"00", 8x"00", 8x"00", 8x"00")); -- offset 2: the size of the BMP file in bytes
    f.write_array((8x"00", 8x"00"));    -- offset 6: reserved
    f.write_array((8x"00", 8x"00"));    -- offset 8: reserved
    f.write_array((8x"36", 8x"00", 8x"00", 8x"00")); -- offset 10: the offset of the byte where the bitmap image data can be found

    -- DIB header
    f.write_array((8x"28", 8x"00", 8x"00", 8x"00")); -- 40 bytes  Number of bytes in the DIB header ((from this point));
    for i in 0 to 3 loop
      f.write_byte(std_logic_vector(width_u32(i * 8 + 7 downto i * 8)));
    end loop;
    for i in 0 to 3 loop
      f.write_byte(std_logic_vector(height_u32(i * 8 + 7 downto i * 8)));
    end loop;
    f.write_array((8x"03", 8x"00"));    -- 3 planes  Number of color planes being used
    f.write_array((8x"18", 8x"00"));    -- 24 bits Number of bits per pixel
    f.write_array((8x"00", 8x"00", 8x"00", 8x"00")); -- 0 BI_RGB, no pixel array compression used
    f.write_array((8x"10", 8x"00", 8x"00", 8x"00")); -- 16 bytes  Size of the raw bitmap data ((including padding));
    f.write_array((8x"13", 8x"0B", 8x"00", 8x"00")); -- 2835 pixels/metre horizontal  Print resolution of the image,
    f.write_array((8x"13", 8x"0B", 8x"00", 8x"00")); -- 2835 pixels/metre vertical
    f.write_array((8x"00", 8x"00", 8x"00", 8x"00")); -- 0 colors  Number of colors in the palette
    f.write_array((8x"00", 8x"00", 8x"00", 8x"00")); -- 0 important colors  0 means all colors are important

    -- Bitmap data
    --  * packed in rows
    --  * size of each row is rounded up to a multiple of 4 bytes by padding
    --  * order is BGR
    for y in 0 to height - 1 loop
      for x in 0 to width - 1 loop
        r := data((height - 1 - y) * width * 3 + x * 3 + 0);
        g := data((height - 1 - y) * width * 3 + x * 3 + 1);
        b := data((height - 1 - y) * width * 3 + x * 3 + 2);
        f.write_int_array((b, g, r));
      end loop;
    end loop;

    f.fclose;

  end procedure;

  type binary_file_t is protected body
    type binary_file is file of character;

    file my_file : binary_file;         -- open write_mode is filename;

    procedure fopen(filename : string) is
    begin
      file_open(my_file, filename, write_mode);
    end procedure;

    procedure write_byte(data : byte_t) is
    begin
      write(my_file, character'val(to_integer(unsigned(data))));
    end procedure;

    procedure write_array(data : byte_array_t) is
    begin
      for i in data'range loop
        write_byte(data(i));
      end loop;
    end procedure;

    procedure write_int_array(data : integer_vector) is
    begin
      for i in data'range loop
        write_byte(std_logic_vector(to_unsigned(data(i), 8)));
      end loop;
    end procedure;

    procedure fclose is
    begin
      file_close(my_file);
    end procedure;

  end protected body binary_file_t;

end package body bmp_pkg;
