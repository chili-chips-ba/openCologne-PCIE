   reg  [9:0] dec_lut [0:1023];
   reg  [1:0] dec_rd  [0:1023];

   integer    lut_d, lut_rd_i;
   reg [10:0] lut_enc;
   reg  [3:0] lut_ones;

   function [7:0] kcode;
      input integer idx;
      begin
         case (idx)
           0 : kcode = 8'h1C;
           1 : kcode = 8'h3C;
           2 : kcode = 8'h5C;
           3 : kcode = 8'h7C;
           4 : kcode = 8'h9C;
           5 : kcode = 8'hBC;
           6 : kcode = 8'hDC;
           7 : kcode = 8'hFC;
           8 : kcode = 8'hF7;
           9 : kcode = 8'hFB;
           10: kcode = 8'hFD;
           default : kcode = 8'hFE;
         endcase
      end
   endfunction

   initial begin : build_dec_lut
      for (lut_d = 0; lut_d < 1024; lut_d = lut_d + 1) begin
         dec_lut[lut_d] = 10'h0;
         lut_ones       = ones10(lut_d[9:0]);
         dec_rd [lut_d] = (lut_ones == 6) ? 2'd1 :
                          (lut_ones == 4) ? 2'd2 : 2'd0;
      end
      for (lut_d = 0; lut_d < 256; lut_d = lut_d + 1)
        for (lut_rd_i = 0; lut_rd_i < 2; lut_rd_i = lut_rd_i + 1) begin
           lut_enc = enc8b10b(lut_d[7:0], 1'b0, lut_rd_i[0]);
           dec_lut[lut_enc[9:0]] = {1'b1, 1'b0, lut_d[7:0]};
        end
      for (lut_d = 0; lut_d < 12; lut_d = lut_d + 1)
        for (lut_rd_i = 0; lut_rd_i < 2; lut_rd_i = lut_rd_i + 1) begin
           lut_enc = enc8b10b(kcode(lut_d), 1'b1, lut_rd_i[0]);
           dec_lut[lut_enc[9:0]] = {1'b1, 1'b1, kcode(lut_d)};
        end
   end
