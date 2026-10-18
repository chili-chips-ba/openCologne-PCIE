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
//   top: the EP, two blocks joined at the PIPE interface, as in the RTL
//   block diagram (0.doc/2.rtl/block-diagram.drawio):
//
//     SerDes pins <-> phy_top <-- pipe_mac --> pcie_top
//
//   Either block can be replaced in simulation by pcieVHost: the RC model in
//   place of phy_top, or the EP model in place of pcie_top (5.sim).
//
//   On the chip, the SerDes serial pins and its 100 MHz reference clock are
//   dedicated pins that CC_SERDES connects by itself. They are ports of this
//   module only in simulation, where the SerDes model needs them, along with
//   the model's config clock and its regfile clock and reset.
//==========================================================================

module top (
    input logic clk_brd,  // board oscillator
    input logic perst_n,  // PERST# from the connector, active low

`ifndef SYNTHESIS
    input  logic refclk,   // 100 MHz PCIE REFCLK
    input  logic clk_cfg,  // SerDes model config clock
    input  logic ser_rxp,
    input  logic ser_rxn,
    output logic ser_txp,
    output logic ser_txn,
`endif

    output logic link_up,  // for an LED: the data link is up
    output logic fw_pass   // for an LED: the firmware has reported PASS
);

  logic phy_rdy_n;

`ifndef SYNTHESIS
  logic clk_reg;
  logic rst_reg_n;
`endif

  pipe_if pipe_mac ();

  phy_top u_phy_top (
`ifndef SYNTHESIS
      .clk_ref  (refclk),
      .clk_cfg  (clk_cfg),
      .clk_reg  (clk_reg),
      .rst_reg_n(rst_reg_n),
      .ser_rxp  (ser_rxp),
      .ser_rxn  (ser_rxn),
      .ser_txp  (ser_txp),
      .ser_txn  (ser_txn),
`endif
      .pipe     (pipe_mac),
      .phy_rdy_n(phy_rdy_n)
  );

  pcie_top u_pcie_top (
      .clk_brd    (clk_brd),
      .perst_n    (perst_n),
      .pipe_mac   (pipe_mac),
      .phy_rdy_n  (phy_rdy_n),
`ifndef SYNTHESIS
      .clk_reg    (clk_reg),
      .rst_reg_n  (rst_reg_n),
`else
      .clk_reg    (  /*LINT:OK*/),
      .rst_reg_n  (  /*LINT:OK*/),
`endif
      .trn_link_up(link_up),
      .fw_pass    (fw_pass)
  );

endmodule

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 18, 2026
// -----------------------------------------------------------------------------
