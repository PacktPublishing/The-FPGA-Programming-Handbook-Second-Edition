// spi.vhd
// ------------------------------------
// AXI SPI state machine interface
// ------------------------------------
// Author : Frank Bruno
`timescale 1ns / 10ps

module spi
  (
   // Utility signals
   input              sys_clk, // 100 Mhz for this example
   input              sys_rst, // 100 Mhz for this example

   // CPU interface
   input wire         reg_awvalid,
   output logic       reg_awready,
   input wire [5:0]   reg_awaddr,

   input wire         reg_wvalid,
   output logic       reg_wready,
   input wire [7:0]   reg_wdata,

   input wire         reg_bready,
   output logic       reg_bvalid,
   output logic [1:0] reg_bresp,

   input wire         reg_arvalid,
   output logic       reg_arready,
   input wire [5:0]   reg_araddr,

   input wire         reg_rready,
   output logic       reg_rvalid,
   output logic [7:0] reg_rdata,
   output logic [1:0] reg_rresp,

   // External pins
   output logic       CSn, // Chip select to ACL
   output logic       SCLK, // Clock to ACL chip
   output logic       MOSI, // Data to ACL chip
   input wire         MISO  // Data from ACL chip
   );

  typedef enum bit [3:0]
               {
                REG_IDLE,
                REG_W4DATA,
                REG_W4ADDR,
                REG_INIT,
                REG_ADDR,
                REG_RVALID,
                REG_BRESP,
                REG_W4RDREADY,
                REG_CSDISABLE
                } reg_cs_t;

  (* mark_debug = "true" *) reg_cs_t reg_cs;

  (* mark_debug = "true" *) logic [4:0]          clk_cnt;
  (* mark_debug = "true" *) logic [4:0]          bit_cnt;
  (* mark_debug = "true" *) logic                reg_we;
  (* mark_debug = "true" *) logic [7:0]          reg_din;
  logic                sclk_en;
  logic [15:0]         reg_addr;
  logic [23:0]         wr_data;

  assign SCLK = sclk_en ? clk_cnt[4] : '0;

  initial begin
    reg_cs     = REG_IDLE;
    CSn        = '1;
    reg_we     = '0;
    reg_din    = '0;
    reg_bvalid = '0;
    clk_cnt    = '0;
    bit_cnt    = '0;
    sclk_en    = '0;
    MOSI       = '0;
  end

  assign reg_rresp = '0;

  always @(posedge sys_clk) begin

    reg_arready <= '0;
    reg_awready <= '0;
    reg_wready  <= '0;
    reg_bvalid  <= '0;
    bit_cnt     <= bit_cnt + &clk_cnt;
    clk_cnt     <= clk_cnt + 1'b1;

    case (reg_cs)
      REG_IDLE: begin
        clk_cnt     <= '0;
        bit_cnt     <= '0;
        CSn         <= '1;
        reg_rvalid  <= '0;

        if (reg_arvalid) begin
          reg_we      <= '0;
          reg_arready <= '1;
          reg_addr    <= {8'h0B, 2'b00, reg_araddr};
          CSn         <= '0;
          reg_cs      <= REG_INIT;
        end else begin
          case ({reg_awvalid, reg_wvalid})
            2'b11: begin
              reg_addr    <= {8'h0A, 2'b0, reg_awaddr};
              reg_we      <= '1;
              reg_din     <= reg_wdata;
              CSn         <= '0;
              reg_cs      <= REG_INIT;
            end
            2'b10: begin
              // Address only
              reg_awready <= '0;
              reg_addr    <= {8'h0A, 2'b0, reg_awaddr};
              reg_cs      <= REG_W4DATA;
            end
            2'b01: begin
              reg_wready <= '0;
              reg_din    <= reg_wdata;
              reg_cs     <= REG_W4ADDR;
            end
          endcase // case ({reg_awvalid, reg_awvalid})
        end // else: !if(reg_arvalid)
      end // case: REG_IDLE
      REG_W4DATA: begin
        reg_we      <= '1;
        reg_din     <= reg_wdata;
        CSn         <= '0;
        reg_cs      <= REG_INIT;
      end
      REG_W4ADDR: begin
        reg_addr    <= {8'h0A, 2'b0, reg_awaddr};
        reg_we      <= '1;
        CSn         <= '0;
        reg_cs      <= REG_INIT;
      end
      REG_INIT: begin
        // Write out the address
        if (&clk_cnt) begin
          sclk_en <= '1;
          wr_data <= reg_we ? {reg_addr, reg_din} : {reg_addr, 8'h0};
          reg_cs  <= REG_ADDR;
        end
      end
      REG_ADDR: begin
        if (&clk_cnt) wr_data <= wr_data << 1;
        MOSI <= wr_data[23];
        //if (bit_cnt == 24 && clk_cnt[4:0] == 6'h0F) begin
        if (bit_cnt == 25 && clk_cnt[4:0] == 6'h00) begin
          reg_cs  <= REG_CSDISABLE;
          sclk_en <= '0;
        end
        //if ((bit_cnt > 15) && (clk_cnt[4:0] == 6'h1)) reg_rdata <= reg_rdata << 1 | MISO;
        if ((bit_cnt > 15) && (clk_cnt[4:0] == 6'h1)) reg_rdata <= reg_rdata << 1 | MISO;
      end // case: REG_ADDR
      REG_CSDISABLE: begin
        CSn <= '1;
        if (&clk_cnt) begin
          if (reg_we) begin
            reg_awready <= '1;
            reg_wready  <= '1;
            reg_cs      <= REG_BRESP;
          end else if (reg_rready) begin
            reg_rvalid  <= '1;
            reg_cs      <= REG_IDLE;
          end else begin
            reg_cs      <= REG_RVALID;
          end
        end // if (bit_cnt == 17)
      end
      REG_RVALID: begin
        if (reg_rready) begin
          reg_rvalid  <= '1;
          reg_cs      <= REG_IDLE;
        end
      end
      REG_BRESP: begin
        if (reg_bready) begin
          reg_bvalid  <= '1;
          reg_bresp   <= '0; // Okay
          reg_cs      <= REG_IDLE;
        end else begin
          reg_awready <= '0;
          reg_wready  <= '0;
          reg_cs      <= REG_BRESP;
        end
      end
      REG_W4RDREADY: begin
        if (reg_rready) begin
          reg_arready <= '1;
          reg_cs      <= REG_IDLE;
        end
      end
    endcase // case (reg_cs)
    if (sys_rst) begin
      reg_cs     <= REG_IDLE;
      CSn        <= '1;
      reg_we     <= '0;
      reg_din    <= '0;
      reg_bvalid <= '0;
      clk_cnt    <= '0;
      bit_cnt    <= '0;
      sclk_en    <= '0;
      MOSI       <= '0;
    end
  end // always @ (posedge reg_clk)
endmodule // uart
