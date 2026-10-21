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
//   complex mode on an x1 PIPE link, at VProc node NodeNum. Its program is
//   usercode/VUserMain<NodeNum>.cpp. The same model and PIPE wrapper ran on
//   openPCIE against the AMD PCIE_2_1 hard macro, there as the EP.
//
//   A shell of PIPEx1__pcieVHost with EndPoint fixed to 0, so the role is in
//   the name and cannot be set wrong. Its ports, the same as there, are the
//   link at the PIPE, Data Link and Transaction layers: tb.u_rc is the
//   decoder page of a dump. See PIPEx1__pcieVHost.sv.
//==========================================================================

module RCPIPEx1__pcieVHost #(
    parameter int NodeNum   = 1,
    parameter int DataWidth = 64,  // 8, 16, 32 or 64
    parameter int DllBytes  = 8    // dll_rx_data width, in bytes
) (
    input  logic                     pcieclk,
    input  logic                     pclk,
    input  logic                     nreset,
`ifdef VERILATOR
    output logic                     ElecIdleOut,
    input  logic                     ElecIdleIn,
`endif
    input  logic [  DataWidth-1:0]   RxData,
    input  logic [DataWidth/8-1:0]   RxDataK,
    output logic [  DataWidth-1:0]   TxData,
    output logic [DataWidth/8-1:0]   TxDataK,
    output logic                     pipe_dn_pclk,
    output logic [  DataWidth-1:0]   pipe_dn_data,
    output logic [DataWidth/8-1:0]   pipe_dn_datak,
    output logic                     pipe_up_pclk,
    output logic [  DataWidth-1:0]   pipe_up_data,
    output logic [DataWidth/8-1:0]   pipe_up_datak,
    input  logic                     dll_clk,
    output logic [ DllBytes*8-1:0]   dll_rx_data,
    output logic                     dll_rx_tlp_valid,
    output logic                     dll_rx_tlp_first,
    output logic                     dll_rx_tlp_last,
    output logic [             7:0]  dll_rx_hdr_credit,
    output logic [            11:0]  dll_rx_data_credit,
    output logic [             1:0]  dll_rx_update_type,
    output logic [             1:0]  dll_rx_packet_type,
    output logic                     dll_rx_dllp_valid,
    output logic                     dllp_clk,
    output logic [            31:0]  dllp_dn_data,
    output logic                     dllp_dn_valid,
    output logic [            31:0]  dllp_up_data,
    output logic                     dllp_up_valid,
    output logic                     tx_clk,
    output logic [            31:0]  tx_tlp_data,
    output logic                     tx_tlp_sop,
    output logic                     tx_tlp_eop,
    output logic                     tx_tlp_valid,
    output logic [            31:0]  tx_peer_data,
    output logic                     tx_peer_sop,
    output logic                     tx_peer_eop,
    output logic                     tx_peer_valid,
    output logic                     rx_clk,
    output logic [            31:0]  rx_tlp_data,
    output logic                     rx_tlp_sop,
    output logic                     rx_tlp_eop,
    output logic                     rx_tlp_valid,
    output logic [            31:0]  rx_peer_data,
    output logic                     rx_peer_sop,
    output logic                     rx_peer_eop,
    output logic                     rx_peer_valid
);

  PIPEx1__pcieVHost #(
      .NodeNum  (NodeNum),
      .EndPoint (1'b0),
      .DataWidth(DataWidth),
      .DllBytes (DllBytes)
  ) u_vhost (.*);

endmodule: RCPIPEx1__pcieVHost

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        April 2025
// -----------------------------------------------------------------------------
