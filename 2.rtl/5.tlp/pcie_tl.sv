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
//   pcie_tl: the Transaction Layer, an empty box with its ports. The TL sits
//   between the DLL (dll_if) and the SOC, and has the same user interface as
//   the AMD PCIE_2_1 hard block in EP mode (UG477): TLPs as two AXI-Stream
//   streams, and the cfg sideband. Its job:
//
//   - flow control: send InitFC and UpdateFC credits to the DLL, and hold a
//     TLP back until the link partner has advertised room for it;
//   - the configuration space: answer Configuration Requests itself (Vendor
//     and Device ID, BAR0, the capability list), and capture the bus, device
//     and function number the host assigns (cfg);
//   - the rest: hand Memory Requests to the SOC on m_axis_rx, and send its
//     Completions from s_axis_tx.
//
//   Until then its outputs are tied off: no TLP is sent, no credit is
//   advertised, so the DLL stays in DL_Init.
//==========================================================================

module pcie_tl (
    input logic clk,   // PCLK
    input logic rst_n, // core_rst_n

    dll_if.tl dll,

    axis_if.slave  s_axis_tx,  // TLPs from the SOC (tuser: pcie_tx_tuser_t)
    axis_if.master m_axis_rx,  // TLPs to the SOC   (tuser: pcie_rx_tuser_t)

    cfg_if.core cfg  // status sideband to the SOC
);

  // to the DLL: nothing to send
  assign dll.tx_data         = '0;
  assign dll.tx_tlp_valid    = 1'b0;
  assign dll.tx_tlp_first    = 1'b0;
  assign dll.tx_tlp_last     = 1'b0;
  assign dll.tx_hdr_credit   = '0;
  assign dll.tx_data_credit  = '0;
  assign dll.tx_update_type  = '0;
  assign dll.tx_packet_type  = '0;
  assign dll.tx_dllp_valid   = 1'b0;

  // to the SOC: no TLP, none taken
  assign s_axis_tx.tready    = 1'b0;
  assign m_axis_rx.tdata     = '0;
  assign m_axis_rx.tkeep     = '0;
  assign m_axis_rx.tuser     = '0;
  assign m_axis_rx.tlast     = 1'b0;
  assign m_axis_rx.tvalid    = 1'b0;

  assign cfg.msg_err_fatal   = 1'b0;
  assign cfg.tx_buf_avail    = '0;
  assign cfg.bus_number      = '0;
  assign cfg.device_number   = '0;
  assign cfg.function_number = '0;

endmodule

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 18, 2026
// -----------------------------------------------------------------------------
