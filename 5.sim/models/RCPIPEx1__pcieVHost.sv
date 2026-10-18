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
//   RCPIPEx1__pcieVHost: the host of the test bench, a pcieVHost in root
//   complex mode on an x1 PIPE link. A thin wrapper of upstream's
//   pcieVHostPipex1 with EndPoint fixed to 0, so the role is in the name and
//   cannot be set wrong. Its program is usercode/VUserMain<NodeNum>.cpp.
//
//   The same model and PIPE wrapper ran on openPCIE against the AMD PCIE_2_1
//   hard macro, there as the EP; see 5.sim/README.md.
//==========================================================================

module RCPIPEx1__pcieVHost #(
    parameter int NodeNum   = 1,
    parameter int DataWidth = 64  // 8, 16, 32 or 64
) (
    input  logic                     pcieclk,  // 250 MHz symbol clock, Gen1
    input  logic                     pclk,     // pcieclk / (DataWidth/8)
    input  logic                     nreset,

`ifdef VERILATOR
    // Electrical idle side-band: Verilator has no Z on a wire
    output logic                     ElecIdleOut,
    input  logic                     ElecIdleIn,
`endif

    input  logic [  DataWidth-1:0]   RxData,
    input  logic [DataWidth/8-1:0]   RxDataK,
    output logic [  DataWidth-1:0]   TxData,
    output logic [DataWidth/8-1:0]   TxDataK
);

  pcieVHostPipex1 #(
      .NodeNum  (NodeNum),
      .EndPoint (0),
      .DataWidth(DataWidth)
  ) u_pcievhost (
      .pcieclk   (pcieclk),
      .pclk      (pclk),
      .nreset    (nreset),
      .Gen2ClkSel(  /*LINT:OK*/),  // Gen1 only
      .ClkOut    (  /*LINT:OK*/),  // the test bench makes the clocks
`ifdef VERILATOR
      .ElecIdleOut(ElecIdleOut),
      .ElecIdleIn (ElecIdleIn),
`endif
      .RxData    (RxData),
      .RxDataK   (RxDataK),
      .TxData    (TxData),
      .TxDataK   (TxDataK)
  );

endmodule

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        April 2025
// -----------------------------------------------------------------------------
