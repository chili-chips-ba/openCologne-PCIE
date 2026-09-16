//----------------------------------------------------------------------------------
// Description: This is a generic clock counter module
// - Count up at each clock cycle until reaching a target count value
// - Reset enabled zeros out the count
// - Flag output is set when the target count value is reached and hold until reset
//==================================================================================

module ccfpga_clk_counter #(
    parameter  BIT_WIDTH = 21        // Width of Count Register
   )
   (
    input  wire                 i_clk,
    input  wire                 i_reset,              // Asynchronous Reset
    input  wire [BIT_WIDTH-1:0] max_count,            // Max Count
    output reg                  o_flag                // Output Flag when Count reaches max count
    );

reg [BIT_WIDTH-1:0] s_count;

always@(posedge i_clk, posedge i_reset) begin
    if (i_reset == 1'b1) begin
        o_flag  <= 1'b0;
        s_count <= {BIT_WIDTH{1'b0}};
    end
    else begin
        if (s_count >= max_count-1) begin
             o_flag  <= 1'b1;
             s_count <= {BIT_WIDTH{1'b0}};
        end
        else begin
             o_flag  <= 1'b0;
             s_count <= s_count + 1'b1;
        end
    end
end

endmodule