// calculator_moore.sv
// ------------------------------------
// Moore version of the Calculator state machine
// ------------------------------------
// Author : Frank Bruno
// A Moore version of the Calculator state machine
`timescale 1ns/10ps
module calculator_moore
  #
  (
   parameter BITS = 32
   )
  (
   input wire               clk,
   input wire               reset,
   input wire               start,
   input wire [4:0]         buttons,
   input wire signed [15:0] switch,

   output logic [BITS-1:0]  accum
   );

  import calculator_pkg::*;

  localparam BC     = $clog2(BITS);

  (* mark_debug = "true" *) logic [4:0]       op_store;
  (* mark_debug = "true" *) logic [4:0]       last_op;
  (* mark_debug = "true" *) logic [BITS-1:0]  accumulator;

  typedef enum bit [2:0]
               {
                IDLE,
                WAIT4BUTTON,
                ADD,
                SUB,
                MULT
                } state_t;

  (* mark_debug = "true" *) state_t state;
  initial begin
    accumulator = '0;
    state = IDLE;
  end

  always @(posedge clk) begin
    case (state)
      IDLE: begin
        // Wait for data to be operated on to be entered. Then the user presses
        // The operation, add, sub, multiply, clear or equal
        last_op     <= buttons; // operation to perform
        if (start) state <= WAIT4BUTTON;
      end
      WAIT4BUTTON: begin
        // wait for second data to be entered, then user presses next operation.
        // In this case, if we get an =, we perform the operation and we're
        // done. The user can also put in another operation to perform with
        // a new value on the accumulator.
        case (1'b1)
          last_op[UP]:     state <= MULT;
          last_op[DOWN]:   state <= IDLE;
          last_op[LEFT]:   state <= ADD;
          last_op[RIGHT]:  state <= SUB;
          default:         state <= IDLE;
        endcase // case (1'b1)
      end
      MULT: begin
        accumulator <= accumulator * switch;
        state       <= IDLE;
      end
      ADD: begin
        accumulator <= accumulator + switch;
        state       <= IDLE;
      end
      SUB: begin
        accumulator <= accumulator - switch;
        state       <= IDLE;
      end
    endcase // case (state)
    if (reset) begin
      state       <= IDLE;
      accumulator <= '0;
    end
  end

  assign accum = accumulator;

endmodule
