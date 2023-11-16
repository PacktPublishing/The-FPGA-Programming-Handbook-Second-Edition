// vga.sv
// ------------------------------------
// Top level of the VGA Display controller
// ------------------------------------
// Author : Frank Bruno
// Simple VGA controller capable of multiple resolutions and corresponding
// character generator to display the current mode.
module vga
  (
   input wire          clk,
   output logic        vga_hsync,
   output logic        vga_vsync,
   output logic [11:0] vga_rgb,

   input [4:0]         SW, // Switches to configure resolution
   input               button_c, // Center button

   output [12:0]       ddr2_addr,
   output [2:0]        ddr2_ba,
   output              ddr2_cas_n,
   output [0:0]        ddr2_ck_n,
   output [0:0]        ddr2_ck_p,
   output [0:0]        ddr2_cke,
   output              ddr2_ras_n,
   output              ddr2_we_n,
   inout [15:0]        ddr2_dq,
   inout [1:0]         ddr2_dqs_n,
   inout [1:0]         ddr2_dqs_p,

   output [0:0]        ddr2_cs_n,
   output [1:0]        ddr2_dm,
   output [0:0]        ddr2_odt
   );

  import vga_pkg::*;

  localparam           MMCM_REGISTER_COUNT  = 24;
  localparam           VGA_REGISTER_COUNT   = 8;
  localparam           TOTAL_REGISTER_COUNT = MMCM_REGISTER_COUNT + VGA_REGISTER_COUNT;
  localparam           BYTES_PER_PAGE       = 16; // Number of bytes returned by the DDR
  localparam           BITS_PER_PAGE        = 16*8; // Number of bits per each page
  localparam           MMCM_IDX             = 0;
  localparam           VGA_IDX              = 1;
  localparam           CHAR_ROWS            = 8; // number of rows in character bitmap
  localparam           RES_TEXT_LENGTH      = 16;
  localparam           AXI4_OKAY            = '0;

  logic                init_calib_complete;
  logic                vga_hblank;
  logic                vga_vblank;
  logic                mc_clk;
  logic                clk200, rst200;
  logic                sys_pll_locked;
  logic                pix_clk_locked_clk200;
  logic                pix_clk_locked_clk200_old = '0;

  sys_pll u_sys_pll
    (
     .clk_out1         (clk200),
     .clk_out2         (mc_clk),
     .clk_in1          (clk),
     .locked           (sys_pll_locked)
     );

  // 200 MHz reset synchronizer
  xpm_cdc_async_rst
    #
    (
     .DEST_SYNC_FF    (4), // 2-10
     .INIT_SYNC_FF    (0), // 0=disable simulation init values, 1=enable simulation init values
     .RST_ACTIVE_HIGH (1)  // 0=active low reset, 1=active high reset
    )
  u_rst200_sync
    (
     .src_arst        (~sys_pll_locked),  // Source asynchronous reset signal.
     .dest_clk        (clk200),           // Destination clock.
     .dest_arst       (rst200)            // src_arst asynchronous reset signal synchronized to destination clock domain
     );

  logic [11:0]         s_axi_awaddr;
  logic [1:0]          s_axi_awvalid;
  logic [1:0]          s_axi_awready;
  logic [31:0]         s_axi_wdata;
  logic [1:0]          s_axi_wvalid;
  logic [1:0]          s_axi_wready;
  logic [1:0]          s_axi_bvalid;
  logic [1:0]          s_axi_bready;
  logic [1:0]          s_axi_bresp[2];
  logic                locked;
  logic                pll_rst;

  pix_clk u_clk
    (
     .s_axi_aclk       (clk200),
     .s_axi_aresetn    (1'b1),
     .s_axi_awaddr     (s_axi_awaddr),
     .s_axi_awvalid    (s_axi_awvalid[MMCM_IDX]),
     .s_axi_awready    (s_axi_awready[MMCM_IDX]),
     .s_axi_wdata      (s_axi_wdata),
     .s_axi_wstrb      (4'hF),
     .s_axi_wvalid     (s_axi_wvalid[MMCM_IDX]),
     .s_axi_wready     (s_axi_wready[MMCM_IDX]),
     .s_axi_bresp      (s_axi_bresp[MMCM_IDX]),
     .s_axi_bvalid     (s_axi_bvalid[MMCM_IDX]),
     .s_axi_bready     (s_axi_bready[MMCM_IDX]),
     .s_axi_araddr     (11'b0),
     .s_axi_arvalid    (1'b0),
     .s_axi_arready    (),
     .s_axi_rdata      (),
     .s_axi_rresp      (),
     .s_axi_rvalid     (),
     .s_axi_rready     (1'b1),

     // Clock out ports
     .clk_out1         (vga_clk),
     // Status and control signals
     .locked           (locked),
     // Clock in ports
     .clk_in1          (clk200)
     );

  // Generate vga_rst
  xpm_cdc_async_rst
    #
    (
     .DEST_SYNC_FF    (2), // 2-10
     .INIT_SYNC_FF    (0), // 0=disable simulation init values, 1=enable simulation init values
     .RST_ACTIVE_HIGH (1)  // 0=active low reset, 1=active high reset
     )
  u_vga_rst_sync
    (
     .src_arst        (~locked), // Source asynchronous reset signal.
     .dest_clk        (vga_clk), // Destination clock.
     .dest_arst       (vga_rst)  // src_arst asynchronous reset signal synchronized to destination clock domain
    );

  xpm_cdc_single
    #
    (
     .DEST_SYNC_FF   (4), // 2-10
     .INIT_SYNC_FF   (0), // 0=disable simulation init values, 1=enable simulation init values
     .SIM_ASSERT_CHK (0), // 0=disable simulation messages, 1=enable simulation messages
     .SRC_INPUT_REG  (0)  // 0=do not register input, 1=register input
    )
  u_pix_clk_locked_sync
    (
     .src_clk        ('0),                   // 1-bit input: optional; required when SRC_INPUT_REG = 1
     .src_in         (locked),               // 1-bit input: Input signal to be synchronized to dest_clk domain.
     .dest_clk       (clk200),               // 1-bit input: Clock signal for the destination clock domain.
     .dest_out       (pix_clk_locked_clk200) // 1-bit output: src_in synchronized to the destination clock domain. This output is registered.
    );

  logic [7:0]          char_index;
  logic [2:0]          char_y;
  logic [7:0]          char_slice;

  logic                ui_clk;
  logic                ui_clk_sync_rst;
  logic                mmcm_locked;
  logic                aresetn = '1;
  logic                app_sr_req = '0;;
  logic                app_ref_req = '0;
  logic                app_zq_req = '0;
  logic                app_sr_active;
  logic                app_ref_ack;
  logic                app_zq_ack;
  logic [3:0]          s_ddr_awid    = '0;
  logic [26:0]         s_ddr_awaddr;
  logic [7:0]          s_ddr_awlen   = '0;
  logic [2:0]          s_ddr_awsize  = 3'b100;
  logic [1:0]          s_ddr_awburst = 2'b01;
  logic [0:0]          s_ddr_awlock  = '0;
  logic [3:0]          s_ddr_awcache = '0;
  logic [2:0]          s_ddr_awprot  = '0;
  logic [3:0]          s_ddr_awqos   = '0;
  logic                s_ddr_awvalid = '0;
  logic                s_ddr_awready;
  logic [127:0]        s_ddr_wdata;
  logic [15:0]         s_ddr_wstrb = '0;
  logic                s_ddr_wlast = '0;
  logic                s_ddr_wvalid = '0;
  logic                s_ddr_wready;
  logic [3:0]          s_ddr_bid;
  logic [1:0]          s_ddr_bresp;
  logic                s_ddr_bvalid;
  logic                s_ddr_bready = '1;
  logic [3:0]          s_ddr_arid = '0;
  logic [26:0]         s_ddr_araddr;
  logic [7:0]          s_ddr_arlen;
  logic [2:0]          s_ddr_arsize = 3'b100; // 16 bytes
  logic [1:0]          s_ddr_arburst = 2'b01;  // incrementing
  logic [0:0]          s_ddr_arlock;
  logic [3:0]          s_ddr_arcache = '0;;
  logic [2:0]          s_ddr_arprot  = '0;
  logic [3:0]          s_ddr_arqos   = '0;
  logic                s_ddr_arvalid;
  logic                s_ddr_arready;
  logic [3:0]          s_ddr_rid;
  logic [127:0]        s_ddr_rdata;
  logic [1:0]          s_ddr_rresp;
  logic                s_ddr_rlast;
  logic                s_ddr_rvalid;
  logic                s_ddr_rready;

  text_rom u_text_rom
    (
     .clock            (ui_clk),         // Clock
     .index            (char_index),  // Character Index
     .sub_index        (char_y),         // Y position in character

     .bitmap_out       (char_slice)      // 8 bit horizontal slice of character
     );

  ddr2_vga u_ddr2_vga
    (
     // Memory interface ports
     .ddr2_addr                      (ddr2_addr),
     .ddr2_ba                        (ddr2_ba),
     .ddr2_cas_n                     (ddr2_cas_n),
     .ddr2_ck_n                      (ddr2_ck_n),
     .ddr2_ck_p                      (ddr2_ck_p),
     .ddr2_cke                       (ddr2_cke),
     .ddr2_ras_n                     (ddr2_ras_n),
     .ddr2_we_n                      (ddr2_we_n),
     .ddr2_dq                        (ddr2_dq),
     .ddr2_dqs_n                     (ddr2_dqs_n),
     .ddr2_dqs_p                     (ddr2_dqs_p),
     .init_calib_complete            (init_calib_complete),

     .ddr2_cs_n                      (ddr2_cs_n),
     .ddr2_dm                        (ddr2_dm),
     .ddr2_odt                       (ddr2_odt),
     // Application interface ports
     .ui_clk                         (ui_clk),
     .ui_clk_sync_rst                (ui_clk_sync_rst),
     .mmcm_locked                    (mmcm_locked),
     .aresetn                        (aresetn),
     .app_sr_req                     (app_sr_req),
     .app_ref_req                    (app_ref_req),
     .app_zq_req                     (app_zq_req),
     .app_sr_active                  (app_sr_active),
     .app_ref_ack                    (app_ref_ack),
     .app_zq_ack                     (app_zq_ack),
     // Slave Interface Write Address Ports
     .s_axi_awid                     (s_ddr_awid),
     .s_axi_awaddr                   (s_ddr_awaddr),
     .s_axi_awlen                    (s_ddr_awlen),
     .s_axi_awsize                   (s_ddr_awsize),
     .s_axi_awburst                  (s_ddr_awburst),
     .s_axi_awlock                   (s_ddr_awlock),
     .s_axi_awcache                  (s_ddr_awcache),
     .s_axi_awprot                   (s_ddr_awprot),
     .s_axi_awqos                    (s_ddr_awqos),
     .s_axi_awvalid                  (s_ddr_awvalid),
     .s_axi_awready                  (s_ddr_awready),
     // Slave Interface Write Data Ports
     .s_axi_wdata                    (s_ddr_wdata),
     .s_axi_wstrb                    (s_ddr_wstrb),
     .s_axi_wlast                    (s_ddr_wlast),
     .s_axi_wvalid                   (s_ddr_wvalid),
     .s_axi_wready                   (s_ddr_wready),
     // Slave Interface Write Response Ports
     .s_axi_bid                      (s_ddr_bid),
     .s_axi_bresp                    (s_ddr_bresp),
     .s_axi_bvalid                   (s_ddr_bvalid),
     .s_axi_bready                   (s_ddr_bready),
     // Slave Interface Read Address Ports
     .s_axi_arid                     (s_ddr_arid),
     .s_axi_araddr                   (s_ddr_araddr),
     .s_axi_arlen                    (s_ddr_arlen),
     .s_axi_arsize                   (s_ddr_arsize),
     .s_axi_arburst                  (s_ddr_arburst),
     .s_axi_arlock                   (s_ddr_arlock),
     .s_axi_arcache                  (s_ddr_arcache),
     .s_axi_arprot                   (s_ddr_arprot),
     .s_axi_arqos                    (s_ddr_arqos),
     .s_axi_arvalid                  (s_ddr_arvalid),
     .s_axi_arready                  (s_ddr_arready),
     // Slave Interface Read Data Ports
     .s_axi_rid                      (s_ddr_rid),
     .s_axi_rdata                    (s_ddr_rdata),
     .s_axi_rresp                    (s_ddr_rresp),
     .s_axi_rlast                    (s_ddr_rlast),
     .s_axi_rvalid                   (s_ddr_rvalid),
     .s_axi_rready                   (s_ddr_rready),
     // System Clock Ports
     .sys_clk_i                      (mc_clk),
     // Reference Clock Ports
     .clk_ref_i                      (clk200),
     .sys_rst                        (1'b1)
     );

  wire [23:0]          int_vga_rgb;

  vga_core u_vga_core
    (
     // Register address
     .reg_clk      (clk200),
     .reg_reset    (rst200),

     .reg_awvalid  (s_axi_awvalid[VGA_IDX]),
     .reg_awready  (s_axi_awready[VGA_IDX]),
     .reg_awaddr   (s_axi_awaddr),

     .reg_wvalid   (s_axi_wvalid[VGA_IDX]),
     .reg_wready   (s_axi_wready[VGA_IDX]),
     .reg_wdata    (s_axi_wdata),
     .reg_wstrb    (4'b1111),

     .reg_bready   (s_axi_bready[VGA_IDX]),
     .reg_bvalid   (s_axi_bvalid[VGA_IDX]),
     .reg_bresp    (s_axi_bresp[VGA_IDX]),

     .reg_arvalid  (1'b0),
     .reg_arready  (),
     .reg_araddr   ('0),

     .reg_rready   (1'b1),
     .reg_rvalid   (),
     .reg_rdata    (),
     .reg_rresp    (),

     // Master memory
     .mem_clk      (ui_clk),
     .mem_reset    (ui_clk_sync_rst),

     .mem_arid     (s_ddr_arid),
     .mem_araddr   (s_ddr_araddr),
     .mem_arlen    (s_ddr_arlen),
     .mem_arsize   (s_ddr_arsize),
     .mem_arburst  (s_ddr_arburst),
     .mem_arlock   (s_ddr_arlock),
     .mem_arvalid  (s_ddr_arvalid),
     .mem_arready  (s_ddr_arready),

     .mem_rready   (s_ddr_rready),
     .mem_rid      (s_ddr_rid),
     .mem_rdata    (s_ddr_rdata),
     .mem_rresp    (s_ddr_rresp),
     .mem_rlast    (s_ddr_rlast),
     .mem_rvalid   (s_ddr_rvalid),

     .vga_clk      (vga_clk),
     .vga_hsync    (vga_hsync),
     .vga_hblank   (vga_hblank),
     .vga_vsync    (vga_vsync),
     .vga_vblank   (vga_vblank),
     .vga_rgb      (int_vga_rgb)
     );

  assign vga_rgb = {int_vga_rgb[23:20],int_vga_rgb[15:12], int_vga_rgb[7:4]};

  logic [15:0][7:0]       res_text_capt;

  typedef enum bit [3:0]
               {
                CFG_IDLE[2],
                CFG_WR[6],
                CFG_WR31,
                CFG_MMCM_WAIT_BRESP,
                CFG_MMCM_WAIT_LOCKED,
                CFG_VGA_WAIT_BRESP
                } cfg_state_t;

  (* mark_debug = "TRUE" *) cfg_state_t cfg_state;

  (* async_reg = "TRUE" *) logic [2:0]          button_sync;
  logic [4:0]          sw_capt = '0;
  logic [5:0]          wr_count;

  initial begin
    button_sync = '0;
    cfg_state   = CFG_IDLE0;
  end

  logic [1:0] last_write;
  logic       update_text;
  logic [2:0] update_text_sync;

  initial begin
    update_text      = '0;
    update_text_sync = '0;
  end

  // Clock reconfiguration
  always @(posedge clk200) begin
    if (rst200) begin
      button_sync               <= '0;
      wr_count                  <= '0;
      cfg_state                 <= CFG_IDLE0;
      update_text               <= '0;
      sw_capt                   <= '0;
      s_axi_awvalid             <= '0;
      s_axi_awaddr              <= '0;
      s_axi_wvalid              <= '0;
      s_axi_wdata               <= '0;
      s_axi_bready              <= '0;
      pix_clk_locked_clk200_old <= '0;
    end else begin
      pix_clk_locked_clk200_old <= pix_clk_locked_clk200;

      // Synchronize the center button signal
      button_sync <= button_sync << 1 | button_c;

      case (cfg_state)
        CFG_IDLE0: begin
          update_text <= ~update_text;
          wr_count    <= '0;
          cfg_state   <= CFG_IDLE1;
        end
        CFG_IDLE1: begin
          s_axi_awvalid[MMCM_IDX] <= '0;
          s_axi_wvalid[MMCM_IDX]  <= '0;
          if (button_sync[2:1] == 2'b10) begin
            // We can start writing the text as we are updating
            update_text             <= ~update_text;
            s_axi_awvalid[MMCM_IDX] <= '1;
            s_axi_wvalid[MMCM_IDX]  <= '1;
            sw_capt                 <= SW;
            wr_count                <= 1;
            s_axi_awaddr            <= addr_array[wr_count];
            s_axi_wdata             <= resolution_lookup(SW, wr_count);
            cfg_state               <= CFG_WR0;
          end
        end
        CFG_WR0: begin
          casez ({s_axi_awready[0], s_axi_wready[0]})
            2'b11: begin
              s_axi_awvalid[MMCM_IDX] <= '0;
              s_axi_wvalid[MMCM_IDX]  <= '0;
              s_axi_bready[MMCM_IDX]  <= '1;
              cfg_state     <= CFG_MMCM_WAIT_BRESP;
            end // case: 3'b011
            2'b10: begin
              s_axi_awvalid[MMCM_IDX] <= '0;
              cfg_state     <= CFG_WR1;
            end
            2'b01: begin
              s_axi_wvalid[MMCM_IDX]  <= '0;
              cfg_state     <= CFG_WR2;
            end
          endcase // casez ({last_write, s_axi_awready, s_axi_wready})
        end // case: CFG_WR0
        CFG_WR1: begin
          if (s_axi_wready[0]) begin
            s_axi_wvalid[MMCM_IDX]  <= '0;
            s_axi_bready[MMCM_IDX]  <= '1;
            cfg_state     <= CFG_MMCM_WAIT_BRESP;
          end // case: 3'b011
        end // case: CFG_WR1
        CFG_WR2: begin
          if (s_axi_awready[MMCM_IDX]) begin
            s_axi_awvalid[MMCM_IDX] <= '0;
            s_axi_bready[MMCM_IDX]  <= '1;
            cfg_state     <= CFG_MMCM_WAIT_BRESP;
          end // case: 3'b011
        end // case: CFG_WR1
        CFG_MMCM_WAIT_BRESP: begin
          if (s_axi_bvalid[MMCM_IDX]) begin
            s_axi_bready[MMCM_IDX] <= '0;
            if (wr_count == MMCM_REGISTER_COUNT) begin
              cfg_state <= CFG_MMCM_WAIT_LOCKED;
            end else begin
              s_axi_awvalid[MMCM_IDX] <= '1;
              s_axi_wvalid[MMCM_IDX]  <= '1;
              cfg_state               <= CFG_WR0;
              s_axi_awaddr            <= addr_array[wr_count];
              s_axi_wdata             <= resolution_lookup(sw_capt, wr_count);
              wr_count                <= wr_count + 1;
            end
          end
        end // case: CFG_MMCM_WAIT_BRESP
        CFG_MMCM_WAIT_LOCKED: begin
          if (pix_clk_locked_clk200 && ~pix_clk_locked_clk200_old) begin
            cfg_state <= CFG_WR3;
          end
        end
        CFG_WR3: begin
          s_axi_awvalid[VGA_IDX] <= '1;
          s_axi_wvalid[VGA_IDX]  <= '1;
          cfg_state              <= CFG_WR31;
          s_axi_awaddr           <= addr_array[wr_count];
          s_axi_wdata            <= resolution_lookup(sw_capt, wr_count);
          wr_count               <= wr_count + 1;
        end
        CFG_WR31: begin
          // Note that we are not handling bresp error conditions
          case ({s_axi_awready[VGA_IDX], s_axi_wready[VGA_IDX]})
            2'b11: begin
              s_axi_awvalid[VGA_IDX] <= '0;
              s_axi_wvalid[VGA_IDX]  <= '0;
              s_axi_bready[VGA_IDX]  <= '1;
              cfg_state              <= CFG_VGA_WAIT_BRESP;
            end
            2'b10: begin
              s_axi_awvalid[VGA_IDX] <= '0;
              cfg_state              <= CFG_WR4;
            end
            2'b01: begin
              s_axi_wvalid[VGA_IDX] <= '0;
              cfg_state             <= CFG_WR5;
            end
          endcase // case ({last_write[0], s_axi_bvalid})
        end
        // Load VGA registers: got awready, wait for wready
        CFG_WR4: begin
          if (s_axi_wready[VGA_IDX]) begin
            s_axi_wvalid[VGA_IDX] <= '0;
            s_axi_bready[VGA_IDX] <= '1;
            cfg_state             <= CFG_VGA_WAIT_BRESP;
          end
        end
        // Load VGA registers: got wready, wait for awready
        CFG_WR5: begin
          if (s_axi_awready[VGA_IDX]) begin
            s_axi_awvalid[VGA_IDX] <= '0;
            s_axi_bready[VGA_IDX]  <= '1;
            cfg_state              <= CFG_VGA_WAIT_BRESP;
          end
        end
        // Load VGA registers, wait for write response
        CFG_VGA_WAIT_BRESP: begin
          if (s_axi_bvalid[VGA_IDX])  begin
            s_axi_bready[VGA_IDX] <= '0;
            if (wr_count == TOTAL_REGISTER_COUNT) begin
              wr_count  <= '0;
              cfg_state <= CFG_IDLE1;
            end else begin
              cfg_state <= CFG_WR3;
            end
          end
        end
      endcase // case (cfg_state)
    end // else: !if(rst200)
  end // always @ (posedge mc_clk)

  // State machine to load initial text
  // 1. Clear screen
  // 2. Draw the text on the first 8 scanlines
  logic done;
  typedef enum  bit [3:0]
       {
        TEXT_IDLE,
        TEXT_CLR[3],
        TEXT_CLR_WAIT_BRESP,
        TEXT_WRITE_WAIT_BRESP,
        TEXT_WRITE[5]
        } text_sm_t;

  text_sm_t text_sm = TEXT_IDLE;

  logic [3:0]       button_count = '0;
  logic [25:0]      total_page;
  logic [2:0][3:0]  char_x;
  logic [12:0]      pitch;
  logic [15:0][7:0] capt_text;
  logic [26:0]      y_offset;

  always @(posedge ui_clk) begin
    if (ui_clk_sync_rst) begin
      update_text_sync <= '0;
      s_ddr_awvalid    <= '0;
      s_ddr_awlen      <= '0;
      s_ddr_awsize     <= 3'b100;      // 16 bytes in transfer
      s_ddr_awburst    <= 2'b01;       // INCR burst type
      s_ddr_awlock     <= '0;        // normal access
      s_ddr_awcache    <= '0;
      s_ddr_awprot     <= '0;
      s_ddr_awqos      <= '0;
      s_ddr_awaddr     <= '0;
      s_ddr_wvalid     <= '0;
      s_ddr_wdata      <= '0;
      s_ddr_wstrb      <= '0;
      s_ddr_wlast      <= '0;
      s_ddr_bready     <= '0;

      char_x           <= '0;
      char_y           <= '0;
      text_sm          <= TEXT_IDLE;
      char_index       <= '0;
      total_page       <= '0;

    end else begin
      // Defaults:
      s_ddr_awlen   <= '0;
      s_ddr_awsize  <= 3'b100;         // 16 bytes in transfer
      s_ddr_awburst <= 2'b01;          // INCR burst type
      s_ddr_awlock  <= '0;             // normal access
      s_ddr_awcache <= '0;
      s_ddr_awprot  <= '0;
      s_ddr_awqos   <= '0;

      // Synchronize update_text toggle into ui_clk domain
      update_text_sync <= update_text_sync << 1 | update_text;

      // Resolution character index delay line
      char_x[1]        <= char_x[0];
      char_x[2]        <= char_x[1];

      case (text_sm)
        TEXT_IDLE: begin
          char_x        <= '0;
          char_y        <= '0;
          if (^update_text_sync[2:1]) begin
            // Clear the screen
            pitch         <= get_pitch(resolution[sw_capt].horiz_display_width);
            total_page    <= resolution[sw_capt].vert_display_width *
                             get_pitch(resolution[sw_capt].horiz_display_width);
            y_offset      <= '0;
            s_ddr_awaddr  <= '0;
            s_ddr_awvalid <= '1;
            s_ddr_wdata   <= '0;
            s_ddr_wstrb   <= '1;
            s_ddr_wlast   <= '1;
            s_ddr_wvalid  <= '1;
            char_index    <= res_text[sw_capt][0];
            capt_text     <= res_text[sw_capt];
            text_sm       <= TEXT_CLR0;
          end
        end // case: TEXT_IDLE
        TEXT_CLR0: begin
          casez ({s_ddr_awready, s_ddr_wready})
            2'b11: begin
              s_ddr_awvalid <= '0;
              s_ddr_wvalid  <= '0;
              s_ddr_bready  <= '1;
              text_sm       <= TEXT_CLR_WAIT_BRESP;
            end
            2'b10: begin
              s_ddr_awvalid <= '0;
              text_sm       <= TEXT_CLR1;
            end
            2'b01: begin
              s_ddr_wvalid  <= '0;
              text_sm       <= TEXT_CLR2;
            end
          endcase // casez ({s_ddr_awready, s_ddr_wready})
        end
        TEXT_CLR1: begin
          if (s_ddr_wready) begin
            s_ddr_wvalid  <= '0;
            s_ddr_bready  <= '1;
            text_sm       <= TEXT_CLR_WAIT_BRESP;
          end
        end
        TEXT_CLR2: begin
          if (s_ddr_awready) begin
            s_ddr_awvalid <= '0;
            s_ddr_bready  <= '1;
            text_sm       <= TEXT_CLR_WAIT_BRESP;
          end
        end // case: TEXT_CLR2
        // Clear screen: wait for write response
        TEXT_CLR_WAIT_BRESP: begin
          if (s_ddr_bvalid) begin
            s_ddr_bready <= '0;
            if (s_ddr_awaddr == (total_page - BYTES_PER_PAGE)) begin
              text_sm <= TEXT_WRITE0;
            end else begin
              s_ddr_bready  <= '0;
              s_ddr_awaddr  <= s_ddr_awaddr + BYTES_PER_PAGE;
              s_ddr_awvalid <= '1;
              s_ddr_wvalid  <= '1;
              text_sm       <= TEXT_CLR0;
            end
          end
        end
        TEXT_WRITE0: begin
          char_index               <= capt_text[char_x[0]];
          char_x[0]                <= char_x[0] + 1'b1;
          text_sm                  <= TEXT_WRITE1;
        end
        TEXT_WRITE1: begin
          char_index                  <= capt_text[char_x[0]];
          if (char_x[0] < RES_TEXT_LENGTH - 1) begin
            char_x[0]                   <= char_x[0] + 1'b1;
          end
          s_ddr_wdata[char_x[2]*8+:8] <= char_slice;
          if (char_x[2] == (RES_TEXT_LENGTH - 1)) begin
            s_ddr_awvalid <= '1;
            s_ddr_awaddr  <= char_y * pitch + y_offset;
            s_ddr_wvalid  <= '1;
            s_ddr_wstrb   <= '1;
            s_ddr_wlast   <= '1;
            text_sm       <= TEXT_WRITE2;
          end
        end
        TEXT_WRITE2: begin
          casez ({s_ddr_awready, s_ddr_wready})
            2'b11: begin
              s_ddr_awvalid <= '0;
              s_ddr_wvalid  <= '0;
              s_ddr_bready  <= '1;
              text_sm       <= TEXT_WRITE_WAIT_BRESP;
            end
            2'b10: begin
              s_ddr_awvalid <= '0;
              text_sm       <= TEXT_WRITE3;
            end
            2'b01: begin
              s_ddr_wvalid  <= '0;
              text_sm       <= TEXT_WRITE4;
            end
          endcase // casez ({s_ddr_awready, s_ddr_wready})
        end
        TEXT_WRITE3: begin
          if (s_ddr_wready) begin
            s_ddr_wvalid  <= '0;
            s_ddr_bready  <= '1;
            text_sm       <= TEXT_WRITE_WAIT_BRESP;
          end
        end
        TEXT_WRITE4: begin
          if (s_ddr_awready) begin
            s_ddr_awvalid <= '0;
            s_ddr_bready  <= '1;
            text_sm       <= TEXT_WRITE_WAIT_BRESP;
          end
        end // case: TEXT_CLR2
        // Write resolution text: wait for write response
        TEXT_WRITE_WAIT_BRESP: begin
          if (s_ddr_bvalid) begin
            s_ddr_bready <= '0;
            if (char_y == (CHAR_ROWS - 1)) begin
              text_sm <= TEXT_IDLE;
            end else begin
              char_x  <= '0;
              char_y  <= char_y + 1'b1;  // proceed with next character row
              text_sm <= TEXT_WRITE0;
            end
          end
        end
      endcase // case (text_sm)
    end
  end // always @ (posedge ui_clk)

  function [12:0] get_pitch(input logic [11:0] horiz_display_width);
    logic [11:0] pitch_whole;
    logic [11:0] pitch_fraction;
    pitch_whole         = horiz_display_width/BITS_PER_PAGE;
    pitch_fraction      = horiz_display_width%BITS_PER_PAGE;

    return (pitch_whole + |pitch_fraction) * 16;
  endfunction // get_pitch

endmodule // vga
