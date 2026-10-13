   function [5:0] rev6;
      input [5:0] v;
      begin
         rev6 = {v[0], v[1], v[2], v[3], v[4], v[5]};
      end
   endfunction

   function [3:0] rev4;
      input [3:0] v;
      begin
         rev4 = {v[0], v[1], v[2], v[3]};
      end
   endfunction

   function [5:0] enc6_rdm;
      input [4:0] x;
      begin
         case (x)
           5'd0  : enc6_rdm = 6'b100111;   5'd1  : enc6_rdm = 6'b011101;
           5'd2  : enc6_rdm = 6'b101101;   5'd3  : enc6_rdm = 6'b110001;
           5'd4  : enc6_rdm = 6'b110101;   5'd5  : enc6_rdm = 6'b101001;
           5'd6  : enc6_rdm = 6'b011001;   5'd7  : enc6_rdm = 6'b111000;
           5'd8  : enc6_rdm = 6'b111001;   5'd9  : enc6_rdm = 6'b100101;
           5'd10 : enc6_rdm = 6'b010101;   5'd11 : enc6_rdm = 6'b110100;
           5'd12 : enc6_rdm = 6'b001101;   5'd13 : enc6_rdm = 6'b101100;
           5'd14 : enc6_rdm = 6'b011100;   5'd15 : enc6_rdm = 6'b010111;
           5'd16 : enc6_rdm = 6'b011011;   5'd17 : enc6_rdm = 6'b100011;
           5'd18 : enc6_rdm = 6'b010011;   5'd19 : enc6_rdm = 6'b110010;
           5'd20 : enc6_rdm = 6'b001011;   5'd21 : enc6_rdm = 6'b101010;
           5'd22 : enc6_rdm = 6'b011010;   5'd23 : enc6_rdm = 6'b111010;
           5'd24 : enc6_rdm = 6'b110011;   5'd25 : enc6_rdm = 6'b100110;
           5'd26 : enc6_rdm = 6'b010110;   5'd27 : enc6_rdm = 6'b110110;
           5'd28 : enc6_rdm = 6'b001110;   5'd29 : enc6_rdm = 6'b101110;
           5'd30 : enc6_rdm = 6'b011110;   5'd31 : enc6_rdm = 6'b101011;
           default: enc6_rdm = 6'b000000;
         endcase
      end
   endfunction

   function enc6_unbal;
      input [4:0] x;
      reg [5:0] c;
      reg [2:0] ones;
      integer   i;
      begin
         c    = enc6_rdm(x);
         ones = 0;
         for (i = 0; i < 6; i = i + 1)
           ones = ones + c[i];
         enc6_unbal = (ones != 3);
      end
   endfunction

   function enc6_flip;
      input [4:0] x;
      begin
         enc6_flip = enc6_unbal(x) || (x == 5'd7);
      end
   endfunction

   function [3:0] enc4_rdm;
      input [2:0] y;
      input       k;
      input       alt7;
      begin
         if (k)
           case (y)
             3'd0 : enc4_rdm = 4'b1011;   3'd1 : enc4_rdm = 4'b0110;
             3'd2 : enc4_rdm = 4'b1010;   3'd3 : enc4_rdm = 4'b1100;
             3'd4 : enc4_rdm = 4'b1101;   3'd5 : enc4_rdm = 4'b0101;
             3'd6 : enc4_rdm = 4'b1001;   3'd7 : enc4_rdm = 4'b0111;
             default: enc4_rdm = 4'b0000;
           endcase
         else
           case (y)
             3'd0 : enc4_rdm = 4'b1011;   3'd1 : enc4_rdm = 4'b1001;
             3'd2 : enc4_rdm = 4'b0101;   3'd3 : enc4_rdm = 4'b1100;
             3'd4 : enc4_rdm = 4'b1101;   3'd5 : enc4_rdm = 4'b1010;
             3'd6 : enc4_rdm = 4'b0110;
             3'd7 : enc4_rdm = alt7 ? 4'b0111 : 4'b1110;
             default: enc4_rdm = 4'b0000;
           endcase
      end
   endfunction

   function enc4_unbal;
      input [2:0] y;
      input       k;
      input       alt7;
      reg [3:0] c;
      reg [2:0] ones;
      integer   i;
      begin
         c    = enc4_rdm(y, k, alt7);
         ones = 0;
         for (i = 0; i < 4; i = i + 1)
           ones = ones + c[i];
         enc4_unbal = (ones != 2);
      end
   endfunction

   function enc4_flip;
      input [2:0] y;
      input       k;
      input       alt7;
      begin
         enc4_flip = k ? 1'b1
                       : (enc4_unbal(y, k, alt7) || (y == 3'd3));
      end
   endfunction

   function [10:0] enc8b10b;
      input [7:0] din;
      input       k;
      input       rd_in;
      reg [4:0]   x;
      reg [2:0]   y;
      reg [5:0]   c6;
      reg [3:0]   c4;
      reg         rd_mid, rd_out, alt7;
      begin
         x = din[4:0];
         y = din[7:5];

         if (k && (x == 5'd28)) begin
            c6     = rd_in ? 6'b110000 : 6'b001111;
            rd_mid = ~rd_in;
         end
         else begin
            c6     = (rd_in && enc6_flip(x)) ? ~enc6_rdm(x) : enc6_rdm(x);
            rd_mid = rd_in ^ enc6_unbal(x);
         end

         alt7 = 1'b0;
         if (!k && (y == 3'd7)) begin
            if (!rd_mid && ((x == 5'd17) || (x == 5'd18) || (x == 5'd20)))
              alt7 = 1'b1;
            if ( rd_mid && ((x == 5'd11) || (x == 5'd13) || (x == 5'd14)))
              alt7 = 1'b1;
         end

         c4     = (rd_mid && enc4_flip(y, k, alt7)) ? ~enc4_rdm(y, k, alt7)
                                                    :  enc4_rdm(y, k, alt7);
         rd_out = rd_mid ^ enc4_unbal(y, k, alt7);

         enc8b10b = {rd_out, rev4(c4), rev6(c6)};
      end
   endfunction

   function [3:0] ones10;
      input [9:0] v;
      integer i;
      begin
         ones10 = 0;
         for (i = 0; i < 10; i = i + 1)
           ones10 = ones10 + v[i];
      end
   endfunction
