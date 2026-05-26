////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Interessengruppe fuer Mikroelektronik und Eingebettete Systeme (IMES)
// Fachhochschule Dortmund
//
// Development in cooperation with Cologne Chip AG
//
// Filename     : ccfpga_pipe_clk_counter.v
// Author       : Philipp Leduc
// Tool         :
// Description  : Simple parametized Clock Counter to implement the wait time between SerDes Byte
//                Lock and RxDataValid on PIPE Interface.
// Commentary   : Always check if CLK_NUMB matches necessary BIT_WIDTH.
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

module ccfpga_pipe_clk_counter #(
    parameter  BIT_WIDTH = 4,        // Width of Count Register
    parameter  CLK_NUMB  = 10        // Target Count Value to set Flag
   )
   (
    input  wire  i_clk,
    input  wire  i_reset,           // Asynchronous Reset
    output reg   o_flag
    );

reg [BIT_WIDTH-1:0] s_count;

always@(posedge i_clk, posedge i_reset) begin
    if (i_reset == 1'b1) begin
        o_flag  <= 1'b0;
        s_count <= {BIT_WIDTH{1'b0}};
        end
    else begin
        if (s_count >= CLK_NUMB-1) begin
             o_flag  <= 1'b1;
            // s_count <= {BIT_WIDTH{1'b0}};
             end
        else begin
             o_flag  <= 1'b0;
             s_count <= s_count + 4'd1;
             end
        end
     end

endmodule