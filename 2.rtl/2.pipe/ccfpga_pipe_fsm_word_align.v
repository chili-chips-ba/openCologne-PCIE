////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Interessengruppe fuer Mikroelektronik und Eingebettete Systeme (IMES)
// Fachhochschule Dortmund
//
// Development in cooperation with Cologne Chip AG
//
// Filename     : ccfpga_pipe_fsm_word_align.v
// Author       : Philipp Leduc
// Tool         :
// Description  : FSM to implement Word Aligment and generate RxValid.
// Commentary   :
// Abreviations : [i_] > input (port)
//                [o_] > output (port)
//                [s_] > signal
//                [_n] > low active
//
//
// Changelog:
// -------------------------------------------------------------------------------------------------
// Version | Author             | Date       | Changes
// -------------------------------------------------------------------------------------------------
// 1.0     | Leduc              | 05.06.2021 | released
// -------------------------------------------------------------------------------------------------
////////////////////////////////////////////////////////////////////////////////////////////////////

module ccfpga_pipe_fsm_word_align (
   input  wire                  i_clk,
   input  wire                  i_reset,
   input  wire                  i_enable,

   output wire            [1:0] o_fsm_state,     // fsm status (CSS)
   output reg                   o_rx_valid,

   output reg                   o_counter_reset, // Reset Clock Counter
   input  wire                  i_count_flag,    // Flag for Count Indication

   output reg                   o_mcomma_align,  // Byte Lock negative disparity
   output reg                   o_pcomma_align,  // Byte Lock positive disparity
   input  wire                  i_byte_locked    // Byte lock established
   );

    localparam [1:0]  WAIT        = 2'b00,
                      ALIGN_START = 2'b01,
                      COUNT_START = 2'b10,
                      RX_VALID    = 2'b11;

    reg [1:0] s_state, s_next_state;

    reg s_set_rx_valid;
    reg s_rx_valid;

    assign o_fsm_state = s_state;

    // State Register
    always@(posedge i_clk, posedge i_reset) begin
        if (i_reset == 1'b1)
            s_state <= WAIT;
        else
            s_state <= s_next_state;
        end

    // Transition Logic
    always@(*) begin
        s_next_state = s_state;
        case(s_state)
            WAIT : begin
                if ( i_enable == 1'b1 && i_byte_locked == 1'b0 )
                s_next_state = ALIGN_START;
                else
                s_next_state = WAIT;
                end
            ALIGN_START : begin
                if ( i_byte_locked == 1'b1 )
                s_next_state = COUNT_START;
                else
                s_next_state = ALIGN_START;
                end
            COUNT_START : begin
                if ( i_count_flag == 1'b1 )
                s_next_state = RX_VALID;
                else
                s_next_state = COUNT_START;
                end
            RX_VALID: begin
                s_next_state = WAIT;
                end
        endcase
    end

    // Output Logic
    always@(s_state)
    begin
        o_counter_reset = 1'b1;
        o_mcomma_align  = 1'b0;
        o_pcomma_align  = 1'b0;
        s_rx_valid      = 1'b0;
        s_set_rx_valid  = 1'b0;
        case(s_state)
            WAIT : begin
            // NONE
                end
            ALIGN_START : begin
                s_set_rx_valid  = 1'b1;
                o_mcomma_align  = 1'b1;
                o_pcomma_align  = 1'b1;
                end
            COUNT_START : begin
                o_counter_reset = 1'b0;
                end
            RX_VALID: begin
                s_rx_valid     = 1'b1;
                s_set_rx_valid = 1'b1;
                end
        endcase
    end

    // DFF Rx Valid
    always@(posedge i_clk, posedge i_reset) begin
        if (i_reset == 1'b1)
             o_rx_valid <= 1'b0;
        else
            if ( s_set_rx_valid == 1'b1 )
             o_rx_valid <= s_rx_valid;
        end

endmodule