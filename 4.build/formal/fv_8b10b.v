`timescale 1ns/1ps

module fv_enc_disparity (
   input  wire [7:0] d,
   input  wire       k,
   input  wire       rd_in,
   output wire       ok
   );

`include "ccfpga_serdes_8b10b.vh"

   wire [10:0] e    = enc8b10b(d, k, rd_in);
   wire  [3:0] ones = ones10(e[9:0]);

   assign ok = (ones >= 4) && (ones <= 6);
endmodule

module fv_enc_rd_tracking (
   input  wire [7:0] d,
   input  wire       k,
   input  wire       rd_in,
   output wire       ok
   );

`include "ccfpga_serdes_8b10b.vh"

   wire [10:0] e      = enc8b10b(d, k, rd_in);
   wire  [3:0] ones   = ones10(e[9:0]);
   wire        rd_out = e[10];

   wire        expect = (ones == 6) ? 1'b1 :
                        (ones == 4) ? 1'b0 : rd_in;

   assign ok = (rd_out == expect);
endmodule

module fv_roundtrip (
   input  wire [7:0] d,
   input  wire       k,
   input  wire       rd_in,
   output wire       ok
   );

`include "ccfpga_serdes_8b10b.vh"

   wire k_legal = (d == 8'h1C) || (d == 8'h3C) || (d == 8'h5C) || (d == 8'h7C) ||
                  (d == 8'h9C) || (d == 8'hBC) || (d == 8'hDC) || (d == 8'hFC) ||
                  (d == 8'hF7) || (d == 8'hFB) || (d == 8'hFD) || (d == 8'hFE);

   wire        applicable = (!k) || k_legal;

   wire [10:0] e   = enc8b10b(d, k, rd_in);
   wire  [9:0] ent = dec_lut[e[9:0]];

   assign ok = !applicable ||
               (ent[9] && (ent[8] == k) && (ent[7:0] == d));
endmodule

module fv_comma_format (
   output wire ok
   );

`include "ccfpga_serdes_8b10b.vh"

   localparam [9:0] ALIGN_PCOMMA_VALUE = 10'b0101111100;
   localparam [9:0] ALIGN_MCOMMA_VALUE = 10'b1010000011;

   wire [10:0] k285_rdm = enc8b10b(8'hBC, 1'b1, 1'b0);
   wire [10:0] k285_rdp = enc8b10b(8'hBC, 1'b1, 1'b1);

   assign ok = (k285_rdm[9:0] == ALIGN_PCOMMA_VALUE) &&
               (k285_rdp[9:0] == ALIGN_MCOMMA_VALUE);
endmodule

module fv_run_length (
   input  wire [7:0] d0,
   input  wire       k0,
   input  wire [7:0] d1,
   input  wire       k1,
   input  wire       rd_in,
   output wire       ok
   );

`include "ccfpga_serdes_8b10b.vh"

   function legal;
      input [7:0] d;
      input       k;
      begin
         legal = (!k) || (d == 8'h1C) || (d == 8'h3C) || (d == 8'h5C) ||
                 (d == 8'h7C) || (d == 8'h9C) || (d == 8'hBC) ||
                 (d == 8'hDC) || (d == 8'hFC) || (d == 8'hF7) ||
                 (d == 8'hFB) || (d == 8'hFD) || (d == 8'hFE);
      end
   endfunction

   wire [10:0] e0 = enc8b10b(d0, k0, rd_in);
   wire [10:0] e1 = enc8b10b(d1, k1, e0[10]);

   wire [19:0] stream = {e1[9:0], e0[9:0]};

   reg  [14:0] bad;
   integer     i;
   always @(*)
     for (i = 0; i < 15; i = i + 1)
       bad[i] = (stream[i +: 6] == 6'b000000) || (stream[i +: 6] == 6'b111111);

   wire applicable = legal(d0, k0) && legal(d1, k1);

   assign ok = !applicable || (bad == 15'h0);
endmodule

module fv_injective (
   input  wire [7:0] d0,
   input  wire       k0,
   input  wire [7:0] d1,
   input  wire       k1,
   input  wire       rd_in,
   output wire       ok
   );

`include "ccfpga_serdes_8b10b.vh"

   function legal;
      input [7:0] d;
      input       k;
      begin
         legal = (!k) || (d == 8'h1C) || (d == 8'h3C) || (d == 8'h5C) ||
                 (d == 8'h7C) || (d == 8'h9C) || (d == 8'hBC) ||
                 (d == 8'hDC) || (d == 8'hFC) || (d == 8'hF7) ||
                 (d == 8'hFB) || (d == 8'hFD) || (d == 8'hFE);
      end
   endfunction

   wire [10:0] e0 = enc8b10b(d0, k0, rd_in);
   wire [10:0] e1 = enc8b10b(d1, k1, rd_in);

   wire        different  = (d0 != d1) || (k0 != k1);
   wire        applicable = legal(d0, k0) && legal(d1, k1) && different;

   assign ok = !applicable || (e0[9:0] != e1[9:0]);
endmodule
