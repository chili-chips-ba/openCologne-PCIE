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
//   dll_if: between the Data Link Layer (dll_logic, Cologne Chip) and the
//   Transaction Layer, on PCLK. Two kinds of traffic cross it:
//
//   - TLPs, in DATA_BYTES-wide beats with first/last flags, and a flag for a
//     last beat that holds only one DW (tx_tlp_last_half). The DLL adds the
//     sequence number and LCRC on the way out and keeps each TLP in its
//     retry buffer until the link partner acknowledges it (tx_tlp_ready low
//     while the buffer is full); on the way in it checks and strips them.
//   - Flow-control credits, as DLLP fields: the TL tells the DLL which
//     InitFC/UpdateFC to send, and the DLL hands over the ones it receives.
//     A TLP may only be sent when the receiver has advertised room for it.
//
//   dl_state is the DLL's state for VC0: DL_Inactive, DL_Init (FC1, FC2),
//   DL_Active. TLPs flow only in DL_Active.
//==========================================================================

interface dll_if #(
    parameter int DATA_BYTES = 8
);
  localparam int DATA_W = DATA_BYTES * 8;

  // TL -> DLL: TLPs
  logic [DATA_W-1:0] tx_data;
  logic              tx_tlp_valid;
  logic              tx_tlp_first;
  logic              tx_tlp_last;
  logic              tx_tlp_last_half;
  logic              tx_tlp_ready;  // DLL -> TL: the retry buffer has room

  // TL -> DLL: the flow-control DLLP to send
  logic [       7:0] tx_hdr_credit;
  logic [      11:0] tx_data_credit;
  logic [       1:0] tx_update_type;  // DLLP Type[5:4]: 00 P, 01 NP, 10 Cpl
  logic [       1:0] tx_packet_type;  // DLLP Type[7:6]: 01 InitFC1, 11 InitFC2, 10 UpdateFC
  logic              tx_dllp_valid;

  // DLL -> TL: TLPs
  logic [DATA_W-1:0] rx_data;
  logic              rx_tlp_valid;
  logic              rx_tlp_first;
  logic              rx_tlp_last;

  // DLL -> TL: a flow-control DLLP received
  logic [       7:0] rx_hdr_credit;
  logic [      11:0] rx_data_credit;
  logic [       1:0] rx_update_type;  // as tx_update_type
  logic [       1:0] rx_packet_type;  // as tx_packet_type
  logic              rx_dllp_valid;

  logic [       2:0] dl_state;  // DLL -> TL

  modport dll(
      input tx_data, tx_tlp_valid, tx_tlp_first, tx_tlp_last, tx_tlp_last_half,
      input tx_hdr_credit, tx_data_credit, tx_update_type, tx_packet_type, tx_dllp_valid,
      output tx_tlp_ready, rx_data, rx_tlp_valid, rx_tlp_first, rx_tlp_last,
      output rx_hdr_credit, rx_data_credit, rx_update_type, rx_packet_type, rx_dllp_valid,
      output dl_state
  );
  modport tl(
      output tx_data, tx_tlp_valid, tx_tlp_first, tx_tlp_last, tx_tlp_last_half,
      output tx_hdr_credit, tx_data_credit, tx_update_type, tx_packet_type, tx_dllp_valid,
      input tx_tlp_ready, rx_data, rx_tlp_valid, rx_tlp_first, rx_tlp_last,
      input rx_hdr_credit, rx_data_credit, rx_update_type, rx_packet_type, rx_dllp_valid,
      input dl_state
  );
endinterface

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 18, 2026
// -----------------------------------------------------------------------------
