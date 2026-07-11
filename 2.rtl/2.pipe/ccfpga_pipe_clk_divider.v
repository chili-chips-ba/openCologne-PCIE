// Clock divider module for CCFPGA
module ccfpga_pipe_clk_divider #(
    parameter DIVIDER = 2
)
(
    input wire clk_in,         // Input clock
    input wire s_reset,        // Active high reset
    output reg clk_out         // Divided output clock
);
    generate
        if (DIVIDER == 2) begin
            always @(posedge clk_in or posedge s_reset) begin
                if (s_reset) begin
                    clk_out <= 1'b0;   // Reset output clock to 0
                end else begin
                    clk_out <= ~clk_out; // Toggle output clock every cycle
                end
            end
        end else begin
            localparam COUNTER_WIDTH = $clog2(DIVIDER) - 1;
            reg [COUNTER_WIDTH-1:0] counter;         // Counter for division

            // Always block triggered on the rising edge of clk_in or reset
            always @(posedge clk_in or posedge s_reset) begin
                if (s_reset) begin
                    counter <= {COUNTER_WIDTH{1'b0}};   // Reset counter to 0
                    clk_out <= 1'b0;   // Reset output clock to 0
                end else begin
                    if (counter == {COUNTER_WIDTH{1'b1}}) begin
                        clk_out <= ~clk_out; // Toggle output clock every 2 cycles
                    end
                    counter <= counter + 1; // Increment counter
                end
            end
        end
    endgenerate

endmodule