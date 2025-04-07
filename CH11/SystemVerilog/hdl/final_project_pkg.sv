`ifndef _FINAL_PKG
`define _FINAL_PKG
package final_project_pkg;

  localparam BYTES_PER_PAGE = 16; // number of bytes returned by the DDR
  localparam BITS_PER_PAGE  = BYTES_PER_PAGE * 8; // number of bits per each page

  typedef struct packed {
    logic [7:0 ]  divide_count;
    logic [15:8]  mult_integer;
    logic [25:16] mult_fraction;
    logic [7:0]   divide_integer;
    logic [17:0]  divide_fraction;
    logic [11:0]  horiz_display_start;
    logic [11:0]  horiz_display_width;
    logic [11:0]  horiz_sync_width;
    logic [11:0]  horiz_total_width;
    logic [11:0]  vert_display_start;
    logic [11:0]  vert_display_width;
    logic [11:0]  vert_sync_width;
    logic [11:0]  vert_total_width;
    logic         hpol;
    logic         vpol;
  } resolution_t;

  resolution_t resolution[18] =
    '{0: // 25.18 Mhz 640x480 @ 60Hz
      '{divide_count:         8'd9,
        mult_integer:         8'd50,
        mult_fraction:        10'd000,
        divide_integer:       8'd44,
        divide_fraction:      10'd125,
        horiz_display_start:  12'd47, // BP -1
        horiz_display_width:  12'd640,
        horiz_sync_width:     12'd96,
        horiz_total_width:    12'd799, // -1
        vert_display_start:   12'd32,  // -1
        vert_display_width:   12'd480,
        vert_sync_width:      12'd2,
        vert_total_width:     12'd524, //-1
        hpol:                 '0,
        vpol:                 '0},
      1: // 31.5Mhz 640x480 @ 72 Hz
      '{divide_count:         8'd8,
        mult_integer:         8'd39,
        mult_fraction:        10'd375,
        divide_integer:       8'd31,
        divide_fraction:      10'd250,
        horiz_display_start:  12'd127,
        horiz_display_width:  12'd640,
        horiz_sync_width:     12'd40,
        horiz_total_width:    12'd831,
        vert_display_start:   12'd27,
        vert_display_width:   12'd480,
        vert_sync_width:      12'd3,
        vert_total_width:     12'd519,
        hpol:                 '0,
        vpol:                 '0},
      2: // 31.5Mhz 640x480 @ 75 Hz
      '{divide_count:         8'd8,
        mult_integer:         8'd39,
        mult_fraction:        10'd375,
        divide_integer:       8'd31,
        divide_fraction:      10'd250,
        horiz_display_start:  12'd47,
        horiz_display_width:  12'd640,
        horiz_sync_width:     12'd96,
        horiz_total_width:    12'd800,
        vert_display_start:   12'd31,
        vert_display_width:   12'd480,
        vert_sync_width:      12'd2,
        vert_total_width:     12'd520,
        hpol:                 '0,
        vpol:                 '0},
      3: // 36 Mhz 640x480 @ 85 Hz
      '{divide_count:         8'd5,
        mult_integer:         8'd24,
        mult_fraction:        10'd750,
        divide_integer:       8'd27,
        divide_fraction:      10'd500,
        horiz_display_start:  12'd111,
        horiz_display_width:  12'd640,
        horiz_sync_width:     12'd48,
        horiz_total_width:    12'd831,
        vert_display_start:   12'd23,
        vert_display_width:   12'd480,
        vert_sync_width:      12'd3,
        vert_total_width:     12'd508,
        hpol:                 '0,
        vpol:                 '0},
      4: // 40 Mhz 800x600 @ 60 Hz
      '{divide_count:         8'd1,
        mult_integer:         8'd5,
        mult_fraction:        10'd000,
        divide_integer:       8'd20,
        divide_fraction:      10'd000,
        horiz_display_start:  12'd87,
        horiz_display_width:  12'd800,
        horiz_sync_width:     12'd128,
        horiz_total_width:    12'd1055,
        vert_display_start:   12'd22,
        vert_display_width:   12'd600,
        vert_sync_width:      12'd4,
        vert_total_width:     12'd627,
        hpol:                 '1,
        vpol:                 '1},
      5: // 49.5 Mhz 800x600 @ 75 Hz
      '{divide_count:         8'd5,
        mult_integer:         8'd24,
        mult_fraction:        10'd750,
        divide_integer:       8'd20,
        divide_fraction:      10'd000,
        horiz_display_start:  12'd159,
        horiz_display_width:  12'd800,
        horiz_sync_width:     12'd80,
        horiz_total_width:    12'd1055,
        vert_display_start:   12'd20,
        vert_display_width:   12'd600,
        vert_sync_width:      12'd2,
        vert_total_width:     12'd624,
        hpol:                 '1,
        vpol:                 '1},
      6: // 50 Mhz 800x600 @ 72 Hz
      '{divide_count:         8'd1,
        mult_integer:         8'd5,
        mult_fraction:        10'd000,
        divide_integer:       8'd20,
        divide_fraction:      10'd000,
        horiz_display_start:  12'd63,
        horiz_display_width:  12'd800,
        horiz_sync_width:     12'd120,
        horiz_total_width:    12'd1039,
        vert_display_start:   12'd22,
        vert_display_width:   12'd600,
        vert_sync_width:      12'd6,
        vert_total_width:     12'd665,
        hpol:                 '1,
        vpol:                 '1},
      7: // 56.25 Mhz 800x600 @ 85 Hz
      '{divide_count:         8'd2,
        mult_integer:         8'd10,
        mult_fraction:        10'd125,
        divide_integer:       8'd18,
        divide_fraction:      10'd000,
        horiz_display_start:  12'd151,
        horiz_display_width:  12'd800,
        horiz_sync_width:     12'd64,
        horiz_total_width:    12'd1047,
        vert_display_start:   12'd26,
        vert_display_width:   12'd600,
        vert_sync_width:      12'd3,
        vert_total_width:     12'd630,
        hpol:                 '1,
        vpol:                 '1},
      8: // 65 Mhz 1024x768 @ 60 Hz
      '{divide_count:         8'd10,
        mult_integer:         8'd50,
        mult_fraction:        10'd375,
        divide_integer:       8'd15,
        divide_fraction:      10'd500,
        horiz_display_start:  12'd159,
        horiz_display_width:  12'd1024,
        horiz_sync_width:     12'd136,
        horiz_total_width:    12'd1339,
        vert_display_start:   12'd28,
        vert_display_width:   12'd768,
        vert_sync_width:      12'd6,
        vert_total_width:     12'd805,
        hpol:                 '0,
        vpol:                 '0},
      9: // 75 Mhz 1024x768 @ 70 Hz
      '{divide_count:         8'd8,
        mult_integer:         8'd40,
        mult_fraction:        10'd125,
        divide_integer:       8'd13,
        divide_fraction:      10'd375,
        horiz_display_start:  12'd143,
        horiz_display_width:  12'd1024,
        horiz_sync_width:     12'd136,
        horiz_total_width:    12'd1327,
        vert_display_start:   12'd28,
        vert_display_width:   12'd768,
        vert_sync_width:      12'd6,
        vert_total_width:     12'd805,
        hpol:                 '0,
        vpol:                 '0},
      10: // 78.75 Mhz 1024x768 @ 75 Hz
      '{divide_count:        8'd8,
        mult_integer:        8'd39,
        mult_fraction:       10'd375,
        divide_integer:      8'd12,
        divide_fraction:     10'd500,
        horiz_display_start: 12'd175,
        horiz_display_width: 12'd1024,
        horiz_sync_width:    12'd96,
        horiz_total_width:   12'd1311,
        vert_display_start:  12'd27,
        vert_display_width:  12'd768,
        vert_sync_width:     12'd3,
        vert_total_width:    12'd799,
        hpol:                '1,
        vpol:                '1},
      11: // 94.5 Mhz 1024x768 @ 85 Hz
      '{divide_count:        8'd5,
        mult_integer:        8'd23,
        mult_fraction:       10'd625,
        divide_integer:      8'd10,
        divide_fraction:     10'd000,
        horiz_display_start: 12'd207,
        horiz_display_width: 12'd1024,
        horiz_sync_width:    12'd96,
        horiz_total_width:   12'd1375,
        vert_display_start:  12'd35,
        vert_display_width:  12'd768,
        vert_sync_width:     12'd3,
        vert_total_width:    12'd807,
        hpol:                '1,
        vpol:                '1},
      12: // 108 Mhz 1280x1024 @ 60 Hz
      '{divide_count:        8'd2,
        mult_integer:        8'd10,
        mult_fraction:       10'd125,
        divide_integer:      8'd9,
        divide_fraction:     10'd375,
        horiz_display_start: 12'd247,
        horiz_display_width: 12'd1280,
        horiz_sync_width:    12'd112,
        horiz_total_width:   12'd1688,
        vert_display_start:  12'd37,
        vert_display_width:  12'd1024,
        vert_sync_width:     12'd3,
        vert_total_width:    12'd1066,
        hpol:                '1,
        vpol:                '1},
      13: // 135 Mhz 1280x1024 @ 75 Hz
      '{divide_count:        8'd2,
        mult_integer:        8'd10,
        mult_fraction:       10'd125,
        divide_integer:      8'd7,
        divide_fraction:     10'd500,
        horiz_display_start: 12'd247,
        horiz_display_width: 12'd1280,
        horiz_sync_width:    12'd144,
        horiz_total_width:   12'd1688,
        vert_display_start:  12'd37,
        vert_display_width:  12'd1024,
        vert_sync_width:     12'd3,
        vert_total_width:    12'd1066,
        hpol:                '1,
        vpol:                '1},
      14: // 157.5 Mhz 1280x1024 @ 85 Hz
      '{divide_count:        8'd8,
        mult_integer:        8'd39,
        mult_fraction:       10'd375,
        divide_integer:      8'd6,
        divide_fraction:     10'd250,
        horiz_display_start: 12'd223,
        horiz_display_width: 12'd1280,
        horiz_sync_width:    12'd160,
        horiz_total_width:   12'd1728,
        vert_display_start:  12'd043,
        vert_display_width:  12'd1024,
        vert_sync_width:     12'd3,
        vert_total_width:    12'd1072,
        hpol:                '1,
        vpol:                '1},
      15: // 162 Mhz 1600x1200 @ 60 Hz
      '{divide_count:        8'd2,
        mult_integer:        8'd10,
        mult_fraction:       10'd125,
        divide_integer:      8'd6,
        divide_fraction:     10'd250,
        horiz_display_start: 12'd303,
        horiz_display_width: 12'd1600,
        horiz_sync_width:    12'd192,
        horiz_total_width:   12'd2160,
        vert_display_start:  12'd45,
        vert_display_width:  12'd1200,
        vert_sync_width:     12'd3,
        vert_total_width:    12'd1250,
        hpol:                '1,
        vpol:                '1},
      16: // 195 Mhz 1920x1200 @ 60 Hz
      '{divide_count:        8'd1,
        mult_integer:        8'd4,
        mult_fraction:       10'd875,
        divide_integer:      8'd5,
        divide_fraction:     10'd000,
        horiz_display_start: 12'd399,
        horiz_display_width: 12'd1920,
        horiz_sync_width:    12'd200,
        horiz_total_width:   12'd2616,
        vert_display_start:  12'd35,
        vert_display_width:  12'd1200,
        vert_sync_width:     12'd3,
        vert_total_width:    12'd1242,
        hpol:                '1,
        vpol:                '1},
      17: // 195 Mhz 1920x1200 @ 60 Hz
      '{divide_count:        8'd8,
        mult_integer:        8'd37,
        mult_fraction:       10'd125,
        divide_integer:      8'd6,
        divide_fraction:     10'd250,
        horiz_display_start: 12'd147,
        horiz_display_width: 12'd1920,
        horiz_sync_width:    12'd44,
        horiz_total_width:   12'd2199,
        vert_display_start:  12'd3,
        vert_display_width:  12'd1080,
        vert_sync_width:     12'd5,
        vert_total_width:    12'd1124,
        hpol:                '1,
        vpol:                '1}};

  logic [17:0][15:0][7:0] res_text =
              '{0:  "  zH06 @ 084x046",
                1:  "  zH27 @ 084x046",
                2:  "  zH57 @ 084x046",
                3:  "  zH58 @ 084x046",
                4:  "  zH06 @ 006x008",
                5:  "  zH57 @ 006x008",
                6:  "  zH27 @ 006x008",
                7:  "  zH58 @ 006x008",
                8:  " zH06 @ 867x4201",
                9:  " zH07 @ 867x4201",
                10: " zH57 @ 867x4201",
                11: " zH58 @ 867x4201",
                12: "zH06 @ 4201x0821",
                13: "zH57 @ 4201x0821",
                14: "zH58 @ 4201x0821",
                15: "zH06 @ 0021x0061",
                16: "zH06 @ 0021x0291",
                17: "zH06 @ 0801x0291"};

  logic [11:0] addr_array[32] =
               '{0:  12'h200,
                 1:  12'h204,
                 2:  12'h208,
                 3:  12'h20C,
                 4:  12'h210,
                 5:  12'h214,
                 6:  12'h218,
                 7:  12'h21C,
                 8:  12'h220,
                 9:  12'h224,
                 10: 12'h228,
                 11: 12'h22C,
                 12: 12'h230,
                 13: 12'h234,
                 14: 12'h238,
                 15: 12'h23C,
                 16: 12'h240,
                 17: 12'h244,
                 18: 12'h248,
                 19: 12'h24C,
                 20: 12'h250,
                 21: 12'h254,
                 22: 12'h258,
                 23: 12'h25C,
                 24: 12'h000,
                 25: 12'h004,
                 26: 12'h008,
                 27: 12'h00C,
                 28: 12'h010,
                 29: 12'h100,
                 30: 12'h104,
                 31: 12'h108};

  function logic [12:0] get_pitch(input [11:0] horiz_display_width);
    logic [11:0] num_pages;
    logic [12:0] num_bytes;
    begin
      // 640 px -> 5 pages -> 80 bytes
      // 641 px -> 6 pages -> 96 bytes
      num_pages = (horiz_display_width + BITS_PER_PAGE - 1) / BITS_PER_PAGE; // max. value is (1920 + 127) / 128 = 15
      num_bytes = num_pages * BYTES_PER_PAGE; // max. value is 15 * 16 = 240
      return num_bytes;
    end
  endfunction // get_pitch

  function logic [31:0] resolution_lookup(input logic [4:0] sw_capt, input logic [4:0] wr_count);
    case (wr_count)
      0: resolution_lookup   = {6'b0, resolution[sw_capt].mult_fraction,
                           resolution[sw_capt].mult_integer,
                           resolution[sw_capt].divide_count};
      1, 3, 6, 9, 12, 15, 18, 21: resolution_lookup = '0;
      5, 8, 11, 14, 17, 20:       resolution_lookup = 32'hA;
      4, 7, 10, 13, 16, 19, 22:   resolution_lookup = 32'hC350;
      2: begin
        resolution_lookup = {15'b0,
                        resolution[sw_capt].divide_fraction,
                        resolution[sw_capt].divide_integer};
      end
      23:  resolution_lookup = 32'b11;
      24: resolution_lookup = {4'b0,
                          resolution[sw_capt].horiz_display_width,
                          4'b0,
                          resolution[sw_capt].horiz_display_start};
      25: resolution_lookup = {4'b0,
                          resolution[sw_capt].horiz_total_width,
                          4'b0,
                          resolution[sw_capt].horiz_sync_width};
      26: resolution_lookup = {4'b0,
                          resolution[sw_capt].vert_display_width,
                          4'b0,
                          resolution[sw_capt].vert_display_start};
      27: resolution_lookup = {4'b0,
                          resolution[sw_capt].vert_total_width,
                          4'b0,
                          resolution[sw_capt].vert_sync_width};
      28: resolution_lookup = {16'b0, 8'd0, 6'b0,
                          resolution[sw_capt].hpol,
                          resolution[sw_capt].vpol};
      29: resolution_lookup = '0;
      30: resolution_lookup = {18'b0, get_pitch(resolution[sw_capt].horiz_display_width)};
      default: resolution_lookup = 32'b1;
    endcase // case (wr_count)

  endfunction // resolution_lookup

endpackage // final_project_pkg
`endif
