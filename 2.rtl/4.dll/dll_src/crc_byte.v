module crc_byte(
    input wire  [7:0] data_in,
    input wire        crc_en,
    input wire [15:0] crcIn,
    output reg [15:0] crcOut
    );

    always @(*) begin
        if (!crc_en) begin // no advancement
            crcOut = crcIn;
        end else begin
            crcOut[0] = crcIn[8] ^ crcIn[12] ^ data_in[7] ^ data_in[3];
            crcOut[1] = crcIn[8] ^ crcIn[9] ^ crcIn[12] ^ crcIn[13] ^ data_in[7] ^ data_in[6] ^ data_in[3] ^ data_in[2];
            crcOut[2] = crcIn[9] ^ crcIn[10] ^ crcIn[13] ^ crcIn[14] ^ data_in[6] ^ data_in[5] ^ data_in[2] ^ data_in[1];
            crcOut[3] = crcIn[8] ^ crcIn[10] ^ crcIn[11] ^ crcIn[12] ^ crcIn[14] ^ crcIn[15] ^ data_in[7] ^ data_in[5] ^ data_in[4] ^ data_in[3] ^ data_in[1] ^ data_in[0];
            crcOut[4] = crcIn[9] ^ crcIn[11] ^ crcIn[12] ^ crcIn[13] ^ crcIn[15] ^ data_in[6] ^ data_in[4] ^ data_in[3] ^ data_in[2] ^ data_in[0];
            crcOut[5] = crcIn[10] ^ crcIn[12] ^ crcIn[13] ^ crcIn[14] ^ data_in[5] ^ data_in[3] ^ data_in[2] ^ data_in[1];
            crcOut[6] = crcIn[11] ^ crcIn[13] ^ crcIn[14] ^ crcIn[15] ^ data_in[4] ^ data_in[2] ^ data_in[1] ^ data_in[0];
            crcOut[7] = crcIn[12] ^ crcIn[14] ^ crcIn[15] ^ data_in[3] ^ data_in[1] ^ data_in[0];
            crcOut[8] = crcIn[0] ^ crcIn[13] ^ crcIn[15] ^ data_in[2] ^ data_in[0];
            crcOut[9] = crcIn[1] ^ crcIn[14] ^ data_in[1];
            crcOut[10] = crcIn[2] ^ crcIn[15] ^ data_in[0];
            crcOut[11] = crcIn[3];
            crcOut[12] = crcIn[4] ^ crcIn[8] ^ crcIn[12] ^ data_in[7] ^ data_in[3];
            crcOut[13] = crcIn[5] ^ crcIn[9] ^ crcIn[13] ^ data_in[6] ^ data_in[2];
            crcOut[14] = crcIn[6] ^ crcIn[10] ^ crcIn[14] ^ data_in[5] ^ data_in[1];
            crcOut[15] = crcIn[7] ^ crcIn[11] ^ crcIn[15] ^ data_in[4] ^ data_in[0];
        end
    end

endmodule