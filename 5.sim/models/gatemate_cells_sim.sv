// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openCologne-PCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
//                   Copyright (C) 2026 Chili.CHIPS
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// 1. Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
// contributors may be used to endorse or promote products derived
// from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
// IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//              https://opensource.org/license/bsd-3-clause
//--------------------------------------------------------------------------
// Description:
//   Simulation models of the GateMate primitives that clk_rst_gen uses and
//   the Yosys library has only as blackboxes: CC_USR_RSTN, CC_PLL, CC_BUFG.
//   CC_PLL makes CLK0 at OUT_CLK MHz and reports lock 20 reference clocks
//   after start; its other settings are not modelled.
//==========================================================================

`timescale 1ps/1ps

module CC_USR_RSTN (
    output logic USR_RSTN
);
  initial begin
    USR_RSTN = 1'b0;
    #100_000;
    USR_RSTN = 1'b1;
  end
endmodule: CC_USR_RSTN

module CC_BUFG (
    input  logic I,
    output logic O
);
  assign O = I;
endmodule: CC_BUFG

module CC_PLL #(
    parameter string REF_CLK     = "10.0",
    parameter string OUT_CLK     = "100.0",
    parameter string PERF_MD     = "ECONOMY",
    parameter int    LOW_JITTER  = 1,
    parameter int    LOCK_REQ    = 1,
    parameter int    CLK270_DOUB = 0,
    parameter int    CLK180_DOUB = 0
) (
    input  logic CLK_REF,
    input  logic USR_CLK_REF,
    input  logic CLK_FEEDBACK,
    input  logic USR_LOCKED_STDY_RST,
    output logic USR_PLL_LOCKED_STDY,
    output logic USR_PLL_LOCKED,
    output logic CLK0,
    output logic CLK90,
    output logic CLK180,
    output logic CLK270,
    output logic CLK_REF_OUT
);
  real    period_ps;
  integer ref_edges;

  assign CLK_REF_OUT         = CLK_REF;
  assign CLK180              = ~CLK0;
  assign CLK270              = ~CLK90;
  assign USR_PLL_LOCKED_STDY = USR_PLL_LOCKED;

  initial begin
    USR_PLL_LOCKED = 1'b0;
    ref_edges      = 0;
  end

  always @(posedge CLK_REF) begin
    if (ref_edges < 20) begin
      ref_edges = ref_edges + 1;
    end
    else begin
      USR_PLL_LOCKED = 1'b1;
    end
  end

  initial begin
    period_ps = 1.0e6 / OUT_CLK.atoreal();
    CLK0      = 1'b0;
    forever begin
      #(period_ps / 2.0) CLK0 = ~CLK0;
    end
  end

  initial begin
    CLK90 = 1'b0;
    #(period_ps / 4.0);
    forever begin
      #(period_ps / 2.0) CLK90 = ~CLK90;
    end
  end
endmodule: CC_PLL

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 21, 2026
// -----------------------------------------------------------------------------
