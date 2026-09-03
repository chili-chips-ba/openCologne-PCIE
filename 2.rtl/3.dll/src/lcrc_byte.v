// LFSR with polynomial x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + x^10
//                    + x^8 + x^7 + x^5 + x^4 + x^2 + x + 1
// Initial value is 0xFFFFFFFF

module lcrc_byte (
    input  wire  [7:0] data_in,
    input  wire        crc_en,
    input  wire [31:0] crcIn,
    output reg  [31:0] crcOut
);

    always @(*) begin
        if (!crc_en) begin
            crcOut = crcIn;
        end else begin
            crcOut[0]  = crcIn[24] ^ crcIn[30] ^ data_in[0] ^ data_in[6];
            crcOut[1]  = crcIn[24] ^ crcIn[25] ^ crcIn[31] ^ data_in[0] ^ data_in[1] ^ data_in[6] ^ data_in[7];
            crcOut[2]  = crcIn[24] ^ crcIn[25] ^ crcIn[26] ^ data_in[0] ^ data_in[1] ^ data_in[2] ^ data_in[6] ^ data_in[7];
            crcOut[3]  = crcIn[25] ^ crcIn[26] ^ crcIn[27] ^ data_in[1] ^ data_in[2] ^ data_in[3] ^ data_in[7];
            crcOut[4]  = crcIn[24] ^ crcIn[26] ^ crcIn[27] ^ crcIn[28] ^ crcIn[30] ^ data_in[0] ^ data_in[2] ^ data_in[3] ^ data_in[4] ^ data_in[6];
            crcOut[5]  = crcIn[24] ^ crcIn[25] ^ crcIn[27] ^ crcIn[28] ^ crcIn[29] ^ crcIn[30] ^ crcIn[31] ^ data_in[0] ^ data_in[1] ^ data_in[3] ^ data_in[4] ^ data_in[5] ^ data_in[6] ^ data_in[7];
            crcOut[6]  = crcIn[25] ^ crcIn[26] ^ crcIn[28] ^ crcIn[29] ^ crcIn[30] ^ crcIn[31] ^ data_in[1] ^ data_in[2] ^ data_in[4] ^ data_in[5] ^ data_in[6] ^ data_in[7];
            crcOut[7]  = crcIn[24] ^ crcIn[26] ^ crcIn[27] ^ crcIn[29] ^ crcIn[31] ^ data_in[0] ^ data_in[2] ^ data_in[3] ^ data_in[5] ^ data_in[7];
            crcOut[8]  = crcIn[0]  ^ crcIn[24] ^ crcIn[25] ^ crcIn[27] ^ crcIn[28] ^ data_in[0] ^ data_in[1] ^ data_in[3] ^ data_in[4];
            crcOut[9]  = crcIn[1]  ^ crcIn[25] ^ crcIn[26] ^ crcIn[28] ^ crcIn[29] ^ data_in[1] ^ data_in[2] ^ data_in[4] ^ data_in[5];
            crcOut[10] = crcIn[2]  ^ crcIn[24] ^ crcIn[26] ^ crcIn[27] ^ crcIn[29] ^ data_in[0] ^ data_in[2] ^ data_in[3] ^ data_in[5];
            crcOut[11] = crcIn[3]  ^ crcIn[24] ^ crcIn[25] ^ crcIn[27] ^ crcIn[28] ^ data_in[0] ^ data_in[1] ^ data_in[3] ^ data_in[4];
            crcOut[12] = crcIn[4]  ^ crcIn[24] ^ crcIn[25] ^ crcIn[26] ^ crcIn[28] ^ crcIn[29] ^ crcIn[30] ^ data_in[0] ^ data_in[1] ^ data_in[2] ^ data_in[4] ^ data_in[5] ^ data_in[6];
            crcOut[13] = crcIn[5]  ^ crcIn[25] ^ crcIn[26] ^ crcIn[27] ^ crcIn[29] ^ crcIn[30] ^ crcIn[31] ^ data_in[1] ^ data_in[2] ^ data_in[3] ^ data_in[5] ^ data_in[6] ^ data_in[7];
            crcOut[14] = crcIn[6]  ^ crcIn[26] ^ crcIn[27] ^ crcIn[28] ^ crcIn[30] ^ crcIn[31] ^ data_in[2] ^ data_in[3] ^ data_in[4] ^ data_in[6] ^ data_in[7];
            crcOut[15] = crcIn[7]  ^ crcIn[27] ^ crcIn[28] ^ crcIn[29] ^ crcIn[31] ^ data_in[3] ^ data_in[4] ^ data_in[5] ^ data_in[7];
            crcOut[16] = crcIn[8]  ^ crcIn[24] ^ crcIn[28] ^ crcIn[29] ^ data_in[0] ^ data_in[4] ^ data_in[5];
            crcOut[17] = crcIn[9]  ^ crcIn[25] ^ crcIn[29] ^ crcIn[30] ^ data_in[1] ^ data_in[5] ^ data_in[6];
            crcOut[18] = crcIn[10] ^ crcIn[26] ^ crcIn[30] ^ crcIn[31] ^ data_in[2] ^ data_in[6] ^ data_in[7];
            crcOut[19] = crcIn[11] ^ crcIn[27] ^ crcIn[31] ^ data_in[3] ^ data_in[7];
            crcOut[20] = crcIn[12] ^ crcIn[28] ^ data_in[4];
            crcOut[21] = crcIn[13] ^ crcIn[29] ^ data_in[5];
            crcOut[22] = crcIn[14] ^ crcIn[24] ^ data_in[0];
            crcOut[23] = crcIn[15] ^ crcIn[24] ^ crcIn[25] ^ crcIn[30] ^ data_in[0] ^ data_in[1] ^ data_in[6];
            crcOut[24] = crcIn[16] ^ crcIn[25] ^ crcIn[26] ^ crcIn[31] ^ data_in[1] ^ data_in[2] ^ data_in[7];
            crcOut[25] = crcIn[17] ^ crcIn[26] ^ crcIn[27] ^ data_in[2] ^ data_in[3];
            crcOut[26] = crcIn[18] ^ crcIn[24] ^ crcIn[27] ^ crcIn[28] ^ crcIn[30] ^ data_in[0] ^ data_in[3] ^ data_in[4] ^ data_in[6];
            crcOut[27] = crcIn[19] ^ crcIn[25] ^ crcIn[28] ^ crcIn[29] ^ crcIn[31] ^ data_in[1] ^ data_in[4] ^ data_in[5] ^ data_in[7];
            crcOut[28] = crcIn[20] ^ crcIn[26] ^ crcIn[29] ^ crcIn[30] ^ data_in[2] ^ data_in[5] ^ data_in[6];
            crcOut[29] = crcIn[21] ^ crcIn[27] ^ crcIn[30] ^ crcIn[31] ^ data_in[3] ^ data_in[6] ^ data_in[7];
            crcOut[30] = crcIn[22] ^ crcIn[24] ^ crcIn[28] ^ crcIn[31] ^ data_in[0] ^ data_in[4] ^ data_in[7];
            crcOut[31] = crcIn[23] ^ crcIn[25] ^ crcIn[29] ^ data_in[1] ^ data_in[5];
        end
    end

endmodule
