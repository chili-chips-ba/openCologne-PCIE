//----------------------------------------------------------------------------------------
// Description: Top module for the parallel crc
// - LFSR with polynomial x^16 + x^12 + x^3 + x + 1
//========================================================================================

module crc_gen #(
    parameter DLLP_WIDTH   = 32,
    parameter LFSR_WIDTH   = 16
)
(
    input wire clk,
    input wire reset,
    input wire crc_en,
    input wire  [DLLP_WIDTH - 1 : 0] data_in,

    output wire [LFSR_WIDTH - 1 : 0] calc_crc
);

    localparam  BYTE = 8;

    wire                     [LFSR_WIDTH-1:0] first_lfsr = {LFSR_WIDTH{1'b1}};
    wire [LFSR_WIDTH*DLLP_WIDTH/BYTE - 1 : 0] lfsr_vector;
    wire [LFSR_WIDTH*DLLP_WIDTH/BYTE - 1 : 0] lfsr_out;
    wire [LFSR_WIDTH*DLLP_WIDTH/BYTE - 1 : 0] lfsr_out_inv;
    wire               [LFSR_WIDTH/2 - 1 : 0] crc_hi;
    wire               [LFSR_WIDTH/2 - 1 : 0] crc_lo;
    assign lfsr_vector = {lfsr_out[LFSR_WIDTH*(DLLP_WIDTH/BYTE-1) - 1 : 0], first_lfsr};
    assign lfsr_out_inv = ~lfsr_out;

    // Generate crc coefficients for each byte
    genvar i;
    generate
        for (i = 0; i < DLLP_WIDTH/BYTE; i = i + 1) begin
            crc_byte crc_byte_inst (
                .data_in               (data_in[i*8 +: 8]),
                .crc_en                (crc_en),
                .crcIn                 (lfsr_vector[i*LFSR_WIDTH +: LFSR_WIDTH]),
                .crcOut                (lfsr_out[i*LFSR_WIDTH +: LFSR_WIDTH])
            );
        end
    endgenerate

    genvar l;
    for (l=0; l < LFSR_WIDTH/2; l=l+1) begin
        assign crc_hi[l] = lfsr_out_inv[LFSR_WIDTH*DLLP_WIDTH/BYTE - l - 1];
    end

    genvar m;
    for (m=0; m < LFSR_WIDTH/2; m=m+1) begin
        assign crc_lo[m] = lfsr_out_inv[LFSR_WIDTH*DLLP_WIDTH/BYTE - LFSR_WIDTH/2 - m - 1];
    end

    assign calc_crc = {crc_lo, crc_hi};

endmodule