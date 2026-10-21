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
//   EPPIPEx1__pcieVHost_DUT: the mock of the EP DUT, a pcieVHost in
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
// The mock EP: a pcieVHost in EP mode at VProc node 2. Its other ports,
// left open here, are the link at the PIPE, Data Link and Transaction
// layers as the EP sees it: tb.dut.bfm_pcie is the EP's decoder page of a
// dump (see models/PIPEx1__pcieVHost.sv)
//--------------------------------------------------------------

  PIPEx1__pcieVHost #(
    .NodeNum                           (2),
    .EndPoint                          (1'b1),
    .DataWidth                         (DataWidth),
    .DllBytes                          (DataWidth/8)
  ) bfm_pcie
  (
    .pclk                              (pclk),
    .pcieclk                           (pcieclk),
    .nreset                            (rst_n),

`ifdef VERILATOR
    .ElecIdleOut                       (elec_idle_out),
    .ElecIdleIn                        (elec_idle_in),
`endif

    .TxData                            (txdata),
    .TxDataK                           (txdatak),
    .RxData                            (rxdata),
    .RxDataK                           (rxdatak),

    .pipe_dn_pclk                      (),
    .pipe_dn_data                      (),
    .pipe_dn_datak                     (),
    .pipe_up_pclk                      (),
    .pipe_up_data                      (),
    .pipe_up_datak                     (),

    .dll_clk                           (pclk),
    .dll_rx_data                       (),
    .dll_rx_tlp_valid                  (),
    .dll_rx_tlp_first                  (),
    .dll_rx_tlp_last                   (),
    .dll_rx_hdr_credit                 (),
    .dll_rx_data_credit                (),
    .dll_rx_update_type                (),
    .dll_rx_packet_type                (),
    .dll_rx_dllp_valid                 (),
    .dllp_clk                          (),
    .dllp_dn_data                      (),
    .dllp_dn_valid                     (),
    .dllp_up_data                      (),
    .dllp_up_valid                     (),

    .tx_clk                            (),
    .tx_tlp_data                       (),
    .tx_tlp_sop                        (),
    .tx_tlp_eop                        (),
    .tx_tlp_valid                      (),
    .tx_peer_data                      (),
    .tx_peer_sop                       (),
    .tx_peer_eop                       (),
    .tx_peer_valid                     (),
    .rx_clk                            (),
    .rx_tlp_data                       (),
    .rx_tlp_sop                        (),
    .rx_tlp_eop                        (),
    .rx_tlp_valid                      (),
    .rx_peer_data                      (),
    .rx_peer_sop                       (),
    .rx_peer_eop                       (),
    .rx_peer_valid                     ()
   );

endmodule

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        April 2025
// -----------------------------------------------------------------------------
