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
//   EPPIPEx1__pcieVHost_DUT: the stand-in for the EP DUT, a pcieVHost in
//   EP mode at VProc node 2, with the PIPE ports the real EP has. An option
//   next to the EP RTL + firmware, kept on purpose: it proves the test bench
//   and the host on their own (make DUT=mock, the default for now).
//==========================================================================

`timescale 1ps/1ps

module EPPIPEx1__pcieVHost_DUT
#(parameter int DataWidth = 64  // 8, 16, 32 or 64 only
)
(
   // Clocks and reset
   input                     rst_n,
   input                     pclk,
   input                     pcieclk,

`ifdef VERILATOR
   // Electrical idle as a side-band: Verilator has no X/Z on a wire, so
   // the pcieVHost models tell each other when the line is idle
   output                    elec_idle_out,
   input                     elec_idle_in,
`endif

   // PCIE PIPE data
   output [DataWidth-1:0]    txdata,
   output [DataWidth/8-1:0]  txdatak,
   input  [DataWidth-1:0]    rxdata,
   input  [DataWidth/8-1:0]  rxdatak
);

//--------------------------------------------------------------
// The stand-in EP: a pcieVHost in EP mode at VProc node 2
//--------------------------------------------------------------

  pcieVHostPipex1 #(
    .NodeNum                           (2),
    .EndPoint                          (1),
    .DataWidth                         (DataWidth)
  ) bfm_pcie
  (
    .pclk                              (pclk),
    .pcieclk                           (pcieclk),
    .nreset                            (rst_n),

    .Gen2ClkSel                        (),
    .ClkOut                            (),

`ifdef VERILATOR
    .ElecIdleOut                       (elec_idle_out),
    .ElecIdleIn                        (elec_idle_in),
`endif

    .TxData                            (txdata),
    .TxDataK                           (txdatak),

    .RxData                            (rxdata),
    .RxDataK                           (rxdatak)
   );

endmodule

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        April 2025
// -----------------------------------------------------------------------------
