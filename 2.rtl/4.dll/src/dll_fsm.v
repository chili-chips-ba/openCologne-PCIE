module dll_fsm #(
   parameter DATA_BYTES = 8,
   parameter DATA_WIDTH = DATA_BYTES*8
   )
   (
   input wire                   reset,                      // Asynchronous Reset
   input wire                   i_clk,                      // Parallel Interface Clock
   input wire                   i_LinkUp,                   // Link Up Status
   input wire                   i_initfc1_rx_done,          // Receive InitFC1 for all 3 types
   input wire                   i_initfc1_tx_done,          // Transmit InitFC1 for all 3 types
   input wire                   i_initfc2_rx_done,          // Receive InitFC2 for all 3 types
   input wire                   i_initfc2_tx_done,          // Transmit InitFC2 for all 3 types

   output reg                   o_initfc1_en,               // Enable InitFC1 Transmission
   output reg                   o_initfc2_en,               // Enable InitFC2 Transmission
   output wire            [2:0] o_fsm_state                 // Current FSM State
   );

   reg [2:0] s_state, s_next_state;
   assign o_fsm_state         = s_state;

   // FSM States
   localparam [2:0]  DL_INACTIVE      = 3'b000,
                     DL_INITFC1       = 3'b001,
                     DL_INITFC2       = 3'b010,
                     DL_ACTIVE        = 3'b011;

   //State Register
   always @(posedge i_clk, posedge reset) begin
      if ( reset )
         s_state <= DL_INACTIVE;
      else 
         s_state <= s_next_state;
   end

   //Transition logic
   always @(*) begin
      s_next_state = s_state;
      case ( s_state )
         DL_INACTIVE : begin
            if ( i_LinkUp == 1'b1 )
               s_next_state = DL_INITFC1;
            else
               s_next_state = DL_INACTIVE;
         end
         DL_INITFC1 : begin
            if ( i_initfc1_rx_done == 1'b1 && i_initfc1_tx_done == 1'b1 )
               s_next_state = DL_INITFC2;
            else if (i_LinkUp == 1'b0)
               s_next_state = DL_INACTIVE;
            else
               s_next_state = DL_INITFC1;
         end
         DL_INITFC2 : begin
            if ( i_initfc2_rx_done == 1'b1 && i_initfc2_tx_done == 1'b1 )
               s_next_state = DL_ACTIVE;
            else if (i_LinkUp == 1'b0)
               s_next_state = DL_INACTIVE;
            else
               s_next_state = DL_INITFC2;
         end
         DL_ACTIVE : begin
            if ( i_LinkUp == 1'b0 )
               s_next_state = DL_INACTIVE;
            else
               s_next_state = DL_ACTIVE;
         end
      endcase
   end

   // Output logic
   always @(s_state) begin
      o_initfc1_en = 1'b0;
      o_initfc2_en = 1'b0;
      case (s_state)
         DL_INACTIVE : begin
            o_initfc1_en = 1'b0;
            o_initfc2_en = 1'b0;
         end
         DL_INITFC1 : begin
            o_initfc1_en = 1'b1;
            o_initfc2_en = 1'b0;
         end
         DL_INITFC2 : begin
            o_initfc1_en = 1'b0;
            o_initfc2_en = 1'b1;
         end
         DL_ACTIVE : begin
            o_initfc1_en = 1'b0;
            o_initfc2_en = 1'b0;
         end
      endcase
   end

endmodule
