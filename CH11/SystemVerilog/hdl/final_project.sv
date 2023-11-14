// final_project.sv
// ------------------------------------
// Final project top level
// ------------------------------------
// Author : Frank Bruno
// The final project wraps a PS/2 interface, a VGA and also audio
module final_project
  (
   input wire          clk,
   output logic        vga_hsync,
   output logic        vga_vsync,
   output logic [11:0] vga_rgb,

   input [4:0]         SW, // Switches to configure resolution
   input               button_c, // Center button
   input               cpu_resetn, // When pressed, reset

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
   output [0:0]        ddr2_odt,

   inout               ps2_clk,
   inout               ps2_data,

   inout wire          TMP_SCL,
   inout wire          TMP_SDA,
   inout wire          TMP_INT,
   inout wire          TMP_CT,

   // Microphone interface
   output logic        m_clk,
   output logic        m_lr_sel,
   input wire          m_data,

   output logic [0:0]  LED
   );

  import final_project_pkg::*;

  localparam MMCM_REGISTER_COUNT  = 24;
  localparam VGA_REGISTER_COUNT   = 8;
  localparam TOTAL_REGISTER_COUNT = MMCM_REGISTER_COUNT + VGA_REGISTER_COUNT;
  localparam           BYTES_PER_PAGE = 16; // Number of bytes returned by the DDR
  localparam           BITS_PER_PAGE  = BYTES_PER_PAGE*8; // Number of bits per each page
  localparam           MMCM_IDX = 0;
  localparam           VGA_IDX  = 1;
  logic                vga_clk;
  logic                init_calib_complete;
  logic                vga_hblank;
  logic                vga_vblank;
  logic                mc_clk;
  logic                clk200;
  logic                clk200_reset, rst200;
  logic                sys_pll_locked;
  typedef struct packed
                 {
                   logic [7:0] data;
                   logic       error;
                 } ps2_t;

  localparam PS2_DEPTH = 8;
  ps2_t ps2_data_capt;
  logic [PS2_DEPTH*2-1:0][7:0] ps2_data_store;
  logic                        ps2_toggle;
  (* async_reg = "TRUE" *) logic [2:0] ps2_sync;
  logic update_ps2;
  logic clear_ps2;
  logic pix_clk_locked_clk200;
  logic pix_clk_locked_clk200_old = '0;

  debounce
    #
    (
     .CYCLES   (32)
     )
  u_debounce
    (
     .clk      (clk200),
     .reset    (reset),

     .sig_in   (~cpu_resetn),
     .sig_out  (clk200_reset)
     );

  assign LED[0] = clk200_reset | rst200;

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

  (* mark_debug = "TRUE" *) logic [11:0]         s_axi_awaddr;
  (* mark_debug = "TRUE" *) logic [1:0]          s_axi_awvalid;
  (* mark_debug = "TRUE" *) logic [1:0]          s_axi_awready;
  (* mark_debug = "TRUE" *) logic [31:0]         s_axi_wdata;
  (* mark_debug = "TRUE" *) logic [1:0]          s_axi_wvalid;
  (* mark_debug = "TRUE" *) logic [1:0]          s_axi_wready;
  (* mark_debug = "TRUE" *) logic [1:0]          s_axi_bvalid;
  (* mark_debug = "TRUE" *) logic [1:0]          s_axi_bready;
  (* mark_debug = "TRUE" *) logic [1:0]          s_axi_bresp[2];
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

  text_rom u_text_rom
    (
     .clock            (ui_clk),         // Clock
     .index            (char_index),  // Character Index
     .sub_index        (char_y),         // Y position in character

     .bitmap_out       (char_slice)      // 8 bit horizontal slice of character
     );

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
  logic [3:0]          s_ddr_arid    = '0;
  logic [26:0]         s_ddr_araddr;
  logic [7:0]          s_ddr_arlen;
  logic [2:0]          s_ddr_arsize  = 3'b100; // 16 bytes
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
  logic                vga_sync_toggle;
  vga_core u_vga_core
    (
     // Register address
     .reg_clk         (clk200),
     .reg_reset       (ui_clk_sync_rst),

     .reg_awvalid     (s_axi_awvalid[VGA_IDX]),
     .reg_awready     (s_axi_awready[VGA_IDX]),
     .reg_awaddr      (s_axi_awaddr),

     .reg_wvalid      (s_axi_wvalid[VGA_IDX]),
     .reg_wready      (s_axi_wready[VGA_IDX]),
     .reg_wdata       (s_axi_wdata),
     .reg_wstrb       (4'b1111),

     .reg_bready      (s_axi_bready[VGA_IDX]),
     .reg_bvalid      (s_axi_bvalid[VGA_IDX]),
     .reg_bresp       (s_axi_bresp[VGA_IDX]),

     .reg_arvalid     (1'b0),
     .reg_arready     (),
     .reg_araddr      ('0),

     .reg_rready      (1'b1),
     .reg_rvalid      (),
     .reg_rdata       (),
     .reg_rresp       (),

     // Master memory
     .mem_clk         (ui_clk),
     .mem_reset       (),

     .mem_arid        (s_ddr_arid),
     .mem_araddr      (s_ddr_araddr),
     .mem_arlen       (s_ddr_arlen),
     .mem_arsize      (s_ddr_arsize),
     .mem_arburst     (s_ddr_arburst),
     .mem_arlock      (s_ddr_arlock),
     .mem_arvalid     (s_ddr_arvalid),
     .mem_arready     (s_ddr_arready),

     .mem_rready      (s_ddr_rready),
     .mem_rid         (s_ddr_rid),
     .mem_rdata       (s_ddr_rdata),
     .mem_rresp       (s_ddr_rresp),
     .mem_rlast       (s_ddr_rlast),
     .mem_rvalid      (s_ddr_rvalid),

     .vga_clk         (vga_clk),
     .vga_hsync       (vga_hsync),
     .vga_hblank      (vga_hblank),
     .vga_vsync       (vga_vsync),
     .vga_vblank      (vga_vblank),
     .vga_rgb         (int_vga_rgb),
     .vga_sync_toggle (vga_sync_toggle)
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

  (* mark_debug = "TRUE" *) cfg_state_t cfg_state = CFG_IDLE0;

  logic [31:0]         disp_addr;

  logic [2:0]          button_sync = '0;
  logic [4:0]          sw_capt;
  logic [5:0]          wr_count;

  logic       update_text;
  (* async_reg = "TRUE" *) logic [2:0] update_text_sync;
  logic       update_temp;
  (* async_reg = "TRUE" *) logic [2:0] update_temp_sync;
  logic       update_temp_capt;

  typedef struct packed
                 {
                   logic [8:0]       address;
                   logic [15:0][7:0] data;
                 } pdm_data_t;

  (* mark_debug = "TRUE" *) logic             pdm_push;
  logic             pdm_pop;
  (* mark_debug = "TRUE" *) pdm_data_t        pdm_din;
  pdm_data_t        pdm_dout;
  logic             pdm_empty;

  initial begin
    update_text      = '0;
    update_text_sync = '0;
    update_temp      = '0;
    update_temp_sync = '0;
    update_temp_capt = '0;
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
          if (s_axi_awready[0]) begin
            s_axi_awvalid[MMCM_IDX] <= '0;
            s_axi_bready[MMCM_IDX]  <= '1;
            cfg_state     <= CFG_MMCM_WAIT_BRESP;
          end // case: 3'b011
        end // case: CFG_WR1
        CFG_MMCM_WAIT_BRESP: begin
          if (s_axi_bvalid[MMCM_IDX]) begin
            wr_count               <= wr_count + 1;
            s_axi_bready[MMCM_IDX] <= '0;
            if (wr_count == MMCM_REGISTER_COUNT) begin
              cfg_state <= CFG_MMCM_WAIT_LOCKED;
            end else begin
              s_axi_awvalid[MMCM_IDX] <= '1;
              s_axi_wvalid[MMCM_IDX]  <= '1;
              cfg_state               <= CFG_WR0;
              s_axi_awaddr            <= addr_array[wr_count];
              s_axi_wdata             <= resolution_lookup(sw_capt, wr_count);
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
  typedef enum bit [3:0]
               {
                TEXT_IDLE,
                TEXT_CLR[3],
                TEXT_WRITE[6]
                } text_sm_t;

  text_sm_t text_sm;

  initial begin
    text_sm = TEXT_IDLE;

  end

  logic [25:0]      total_page;
  logic [2:0][3:0]  char_x;
  logic [12:0]      real_pitch;
  logic [15:0][7:0] capt_text;
  logic [12:0]      pitch_value;
  assign pitch_value = get_pitch(resolution[sw_capt].horiz_display_width);
  logic [15:0][7:0] capt_temp;
  logic [26:0]      y_offset;

  always @(posedge ui_clk) begin
    update_text_sync <= update_text_sync << 1 | update_text;
    update_temp_sync <= update_temp_sync << 1 | update_temp;
    if (^update_temp_sync[2:1]) update_temp_capt <= '1;
    pdm_pop          <= '0;
    s_ddr_awvalid    <= '0;
    done             <= s_ddr_awaddr >= total_page;
    char_x[1]        <= char_x[0];
    char_x[2]        <= char_x[1];
    real_pitch       <= |pitch_value[3:0] ?
                        {pitch_value[12:4], 4'b0} + 16 :
                        {pitch_value[12:4], 4'b0};
    clear_ps2        <= '0;
    case (text_sm)
      TEXT_IDLE: begin
        char_x        <= '0;
        char_y        <= '0;
        if (^update_text_sync[2:1]) begin
          // Clear the screen
          res_text_capt <= res_text[sw_capt];
          total_page <= resolution[sw_capt].vert_display_width *
                        real_pitch;
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
        end else if (update_ps2) begin // if (^update_text_sync[2:1])
          // We'll start the PS2 output on line 8
          y_offset      <= 8 * real_pitch;
          clear_ps2     <= '1;
          char_index    <= ps2_data_store[0];
          capt_text     <= ps2_data_store;
          s_ddr_awvalid <= '0;
          s_ddr_wvalid  <= '0;
          text_sm       <= TEXT_WRITE0;
        end else if (update_temp_capt) begin
          // We'll start the temperature output on line 16
          y_offset         <= 16 * real_pitch;
          update_temp_capt <= '0;
          char_index       <= capt_temp[0];
          capt_text        <= capt_temp;
          s_ddr_awvalid    <= '0;
          s_ddr_wvalid     <= '0;
          text_sm          <= TEXT_WRITE0;
        end else if (!pdm_empty) begin
          pdm_pop          <= '1;
          char_y           <= '1; // Force only one line to be written
          //update_temp_capt <= '0;
          s_ddr_awvalid    <= '1;
          s_ddr_awaddr     <= pdm_dout.address * real_pitch;
          s_ddr_wvalid     <= '1;
          s_ddr_wdata      <= pdm_dout.data;
          text_sm          <= TEXT_WRITE2;
        end
      end // case: TEXT_IDLE
      TEXT_CLR0: begin
        casez ({done, s_ddr_awready, s_ddr_wready})
          3'b111: begin
            s_ddr_awvalid <= '0;
            s_ddr_wvalid  <= '0;
            text_sm       <= TEXT_WRITE0;
          end
          3'b011: begin
            s_ddr_awaddr  <= s_ddr_awaddr + 16;
            s_ddr_awvalid <= '1;
            s_ddr_wvalid  <= '1;
            text_sm       <= TEXT_CLR0;
          end
          3'b010: begin
            s_ddr_awvalid <= '0;
            s_ddr_wvalid  <= '1;
            text_sm       <= TEXT_CLR1;
          end
          3'b001: begin
            s_ddr_awvalid <= '1;
            s_ddr_wvalid  <= '0;
            text_sm       <= TEXT_CLR2;
          end
        endcase // casez ({done, s_ddr_awready, s_ddr_wready})
      end
      TEXT_CLR1: begin
        casez ({done, s_ddr_wready})
          2'b11: begin
            s_ddr_awvalid <= '0;
            s_ddr_wvalid  <= '0;
            text_sm       <= TEXT_WRITE0;
          end
          2'b01: begin
            s_ddr_awaddr  <= s_ddr_awaddr + 16;
            s_ddr_awvalid <= '1;
            s_ddr_wvalid  <= '1;
            text_sm       <= TEXT_CLR0;
          end
        endcase // casez ({done, s_ddr_awready, s_ddr_wready})
      end
      TEXT_CLR2: begin
        casez ({done, s_ddr_awready})
          2'b11: begin
            s_ddr_awvalid <= '0;
            s_ddr_wvalid  <= '0;
            text_sm       <= TEXT_WRITE0;
          end
          2'b01: begin
            s_ddr_awaddr  <= s_ddr_awaddr + 16;
            s_ddr_awvalid <= '1;
            s_ddr_wvalid  <= '1;
            text_sm       <= TEXT_CLR0;
          end
        endcase // casez ({done, s_ddr_awready, s_ddr_wready})
      end // case: TEXT_CLR2
      TEXT_WRITE0: begin
        char_index               <= capt_text[char_x[0]];
        char_x[0]                <= char_x[0] + 1'b1;
        text_sm                  <= TEXT_WRITE1;
      end
      TEXT_WRITE1: begin
        char_x[0]                   <= char_x[0] + 1'b1;
        char_index                  <= capt_text[char_x[0]];
        s_ddr_wdata[char_x[2]*8+:8] <= char_slice;
        s_ddr_awaddr                <= char_y * real_pitch + y_offset;
        if (&char_x[2]) begin
          s_ddr_awvalid <= '1;
          s_ddr_wvalid  <= '1;
          text_sm       <= TEXT_WRITE2;
        end else begin
          text_sm       <= TEXT_WRITE1;
        end
      end
      TEXT_WRITE2: begin
        casez ({&char_y, s_ddr_awready, s_ddr_wready})
          3'b111: begin
            s_ddr_awvalid <= '0;
            s_ddr_wvalid  <= '0;
            text_sm       <= TEXT_IDLE;
          end
          3'b011: begin
            char_x        <= '0;
            char_y        <= char_y + 1'b1;
            s_ddr_awvalid <= '0;
            s_ddr_wvalid  <= '0;
            text_sm       <= TEXT_WRITE0;
          end
          3'b010: begin
            s_ddr_awvalid <= '0;
            s_ddr_wvalid  <= '1;
            text_sm       <= TEXT_WRITE3;
          end
          3'b001: begin
            s_ddr_awvalid <= '1;
            s_ddr_wvalid  <= '0;
            text_sm       <= TEXT_WRITE4;
          end
        endcase // casez ({done, s_ddr_awready, s_ddr_wready})
      end
      TEXT_WRITE3: begin
        casez ({&char_y, s_ddr_wready})
          2'b11: begin
            s_ddr_awvalid <= '0;
            s_ddr_wvalid  <= '0;
            text_sm       <= TEXT_IDLE;
          end
          2'b01: begin
            char_x        <= '0;
            char_y        <= char_y + 1'b1;
            s_ddr_awvalid <= '0;
            s_ddr_wvalid  <= '0;
            text_sm       <= TEXT_WRITE0;
          end
        endcase // casez ({done, s_ddr_awready, s_ddr_wready})
      end
      TEXT_WRITE4: begin
        casez ({done, s_ddr_awready})
          2'b11: begin
            s_ddr_awvalid <= '0;
            s_ddr_wvalid  <= '0;
            text_sm       <= TEXT_IDLE;
          end
          2'b01: begin
            char_x        <= '0;
            char_y        <= char_y + 1'b1;
            s_ddr_awvalid <= '0;
            s_ddr_wvalid  <= '0;
            text_sm       <= TEXT_WRITE0;
          end
        endcase // casez ({done, s_ddr_awready, s_ddr_wready})
      end // case: TEXT_CLR2
    endcase // case (text_sm)
  end // always @ (posedge ui_clk)

  logic [7:0]  ps2_rx_data;
  logic        ps2_rx_user;
  logic        ps2_rx_valid;
  logic        ps2_rx_err;
  // PS/2 interface
  ps2_host
    #
    (
     .CLK_PER          (5),
     .CYCLES           (32)
     )
  u_ps2_host
    (
     .clk              (clk200),
     .reset            (clk200_reset | rst200),

     .ps2_clk          (ps2_clk),
     .ps2_data         (ps2_data),

     .tx_valid         (1'b0),
     .tx_data          (8'b0),
     .tx_ready         (),

     .rx_data          (ps2_rx_data),
     .rx_user          (ps2_rx_err),
     .rx_valid         (ps2_rx_valid),
     .rx_ready         (1'b1)
     );

  logic ftemp; // 0 = celsius, 1 = Fahrenheit
  // Clock crossing logic
  initial begin
    ftemp          = '0;
    ps2_toggle     = '0;
    ps2_data_store = '{default: " "};
  end

  // toggle sync and capture the data
  always @(posedge clk200) begin
    if (ps2_rx_valid) begin
      ps2_toggle    <= ~ps2_toggle;
      ps2_data_capt <= '{data: ps2_rx_data, error: ps2_rx_err};
      case (ps2_rx_data)
        8'h2B: ftemp <= '1; // F = fahrenheit
        8'h21: ftemp <= '0; // C = celsius
      endcase
    end
  end

  // synchronize data on the UI clock
  always @(posedge ui_clk) begin
    ps2_sync <= ps2_sync << 1 | ps2_toggle;

    if (clear_ps2) begin
      update_ps2 <= '0;
    end
    if (^ps2_sync[2:1]) begin
      update_ps2 <= '1;
      for (int i = PS2_DEPTH-1; i >= 0; i--) begin
        if (i == 0) begin
          for (int j = 1; j >= 0; j--) begin
            case (ps2_data_capt.data[j*4+:4])
              0:  ps2_data_store[i*2+j] <= 8'h30;
              1:  ps2_data_store[i*2+j] <= 8'h31;
              2:  ps2_data_store[i*2+j] <= 8'h32;
              3:  ps2_data_store[i*2+j] <= 8'h33;
              4:  ps2_data_store[i*2+j] <= 8'h34;
              5:  ps2_data_store[i*2+j] <= 8'h35;
              6:  ps2_data_store[i*2+j] <= 8'h36;
              7:  ps2_data_store[i*2+j] <= 8'h37;
              8:  ps2_data_store[i*2+j] <= 8'h38;
              9:  ps2_data_store[i*2+j] <= 8'h39;
              10: ps2_data_store[i*2+j] <= 8'h41;
              11: ps2_data_store[i*2+j] <= 8'h42;
              12: ps2_data_store[i*2+j] <= 8'h43;
              13: ps2_data_store[i*2+j] <= 8'h44;
              14: ps2_data_store[i*2+j] <= 8'h45;
              15: ps2_data_store[i*2+j] <= 8'h46;
            endcase // case (ps2_data_capt[i*4+:4])
          end
        end else begin
          ps2_data_store[i*2+:2] <= ps2_data_store[(i-1)*2+:2];
        end
      end // for (int i = 0; i < PS2_DEPTH; i++)
    end
  end // always @ (posedge ui_clk)

  // Temperature sensor
  i2c_wrapper
    #
    (
     .CLK_PER (5)
     )
  u_i2c_wrapper
    (
     .clk              (clk200),

     .TMP_SCL          (TMP_SCL),
     .TMP_SDA          (TMP_SDA),
     .TMP_INT          (TMP_INT),
     .TMP_CT           (TMP_CT),

     .ftemp            (ftemp),

     .update_temp      (update_temp),
     .capt_temp        (capt_temp)
     );

  // Audio data
  (* mark_debug = "TRUE" *)logic [6:0] amplitude;
  (* mark_debug = "TRUE" *)logic       amplitude_valid;

  pdm_inputs
    #
    (
     .CLK_FREQ         (200)    // Mhz
     )
  u_pdm_inputs
    (
     .clk              (clk200),

     // Microphone interface
     .m_clk            (m_clk),
     .m_clk_en         (m_clk_en),
     .m_data           (m_data),

     // Amplitude outputs
     .amplitude        (amplitude),
     .amplitude_valid  (amplitude_valid)
     );

  // data storage
  // Setup a storage buffer for amplitudes. Make it large enough that we can
  // window into it and it remains stable
  localparam AMP_DEPTH = 1024;

  logic [6:0] amplitude_store[AMP_DEPTH];
  (* mark_debug = "TRUE" *) logic [$clog2(AMP_DEPTH)-1:0] amp_rd, amp_wr;
  (* mark_debug = "TRUE" *) logic [8:0]                   rd_count;

  typedef enum bit [1:0]
               {
                WAVE_IDLE,
                WAVE_READ[2]
                } wave_sm_t;

  (* mark_debug = "TRUE" *) wave_sm_t wave_sm;

  initial begin
    amplitude_store = '{default: '0};
    amp_rd          = '0;
    amp_wr          = '0;
    rd_count        = '0;
    pdm_push        = '0;
    wave_sm         = WAVE_IDLE;
  end

  (* async_reg = "TRUE" *) logic [2:0] vga_sync_toggle_sync;
  (* mark_debug = "TRUE" *) logic [6:0] amp_data;
  always @(posedge clk200) begin
    if (amplitude_valid) begin
      amplitude_store[amp_wr] <= amplitude;
      amp_wr                  <= amp_wr + 1'b1;
    end
    amp_data <= amplitude_store[amp_rd];
  end
  always @(posedge clk200) begin
    vga_sync_toggle_sync <= vga_sync_toggle_sync << 1 | vga_sync_toggle;
    pdm_push <= '0;
    case (wave_sm)
      WAVE_IDLE: begin
        if (^vga_sync_toggle_sync[2:1]) begin
          // get the amplitude data from behind the write pointer
          // by 256 samples
          amp_rd   <= amp_wr - 256;
          rd_count <= '0;
          wave_sm  <= WAVE_READ0;
        end
      end
      WAVE_READ0: begin
        // address to ram valid this cycle
        amp_rd   <= amp_rd + 1'b1;
        rd_count <= rd_count + 1'b1;
        wave_sm  <= WAVE_READ1;
      end
      WAVE_READ1: begin
        // address to ram valid this cycle
        amp_rd           <= amp_rd + 1'b1;
        rd_count         <= rd_count + 1'b1;
        pdm_push         <= '1;
        pdm_din.address  <= 31 + rd_count;
        pdm_din.data     <= 1'b1 << amp_data;
        if (rd_count[8]) wave_sm <= WAVE_IDLE;
      end
    endcase // case (wave_sm)
  end // always @ (posedge clk200)

  xpm_fifo_async
    #
    (
     .FIFO_WRITE_DEPTH       (512),
     .WRITE_DATA_WIDTH       ($bits(pdm_din)),
     .READ_MODE              ("fwft")
     )
  u_xpm_fifo_async
    (
     .sleep                  ('0),
     .rst                    (clk200_reset | rst200),

     .wr_clk                 (clk200),
     .wr_en                  (pdm_push),
     .din                    (pdm_din),
     .full                   (),
     .prog_full              (),
     .wr_data_count          (),
     .overflow               (),
     .wr_rst_busy            (),
     .almost_full            (),
     .wr_ack                 (),

     .rd_clk                 (ui_clk),
     .rd_en                  (pdm_pop),
     .dout                   (pdm_dout),
     .empty                  (pdm_empty),
     .prog_empty             (),
     .rd_data_count          (),
     .underflow              (),
     .rd_rst_busy            (),
     .almost_empty           (),
     .data_valid             (),

     .injectsbiterr          ('0),
     .injectdbiterr          ('0),
     .sbiterr                (),
     .dbiterr                ()
     );

  function [12:0] get_pitch(logic [11:0] horiz_display_width);
    logic [11:0] pitch_whole;
    logic [11:0] pitch_fraction;
    pitch_whole         = horiz_display_width/BITS_PER_PAGE;
    pitch_fraction      = horiz_display_width%BITS_PER_PAGE;

    return (pitch_whole + |pitch_fraction) * 16;
  endfunction // get_pitch

endmodule // vga
