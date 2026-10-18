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
//   pcie_core: the soft PCIE stack, everything between the PIPE interface and
//   the SOC, as in the RTL block diagram (0.doc/2.rtl/block-diagram.drawio):
//
//     pipe <-> MAC <-> DLL <-- dll --> TL <-> s_axis_tx / m_axis_rx, cfg
//
//   - MAC (ccfpga_LTSSM_logic, Cologne Chip): the LTSSM trains the link,
//     then sends and receives the ordered sets and scrambled data on PIPE.
//   - DLL (dll_logic, Cologne Chip): sequence numbers and LCRC, Ack/Nak and
//     replay, flow-control DLLPs; it starts once the LTSSM is in L0.
//   - TL (pcie_tl): an empty box for now.
//
//   The data link is up (trn_link_up, UG477 trn_lnk_up) when the DLL is in
//   DL_Active.
//==========================================================================

module pcie_core #(
    parameter int DATA_BYTES = 8
) (
    input logic pipe_rst_n,  // PIPE Reset#
    input logic mac_rst_n,   // PCLK: MAC and DLL
    input logic core_rst_n,  // PCLK: TL

    pipe_if.mac pipe,

    output logic trn_link_up,  // data link up, PCLK

    axis_if.slave  s_axis_tx,  // TLPs from the SOC (tuser: pcie_tx_tuser_t)
    axis_if.master m_axis_rx,  // TLPs to the SOC   (tuser: pcie_rx_tuser_t)

    cfg_if.core cfg  // status sideband to the SOC
);

  localparam logic [4:0] LTSSM_L0  = 5'b01010;        // ccfpga_LTSSM_fsm
  localparam logic [2:0] DL_ACTIVE = 3'b011;          // dll_fsm

  localparam int         DATA_W    = DATA_BYTES * 8;

  logic                  mac_link_up;
  logic [           4:0] ltssm_state;
  logic [    DATA_W-1:0] mac_rx_data;
  logic [    DATA_W-1:0] dll_tx_data;
  logic [DATA_BYTES-1:0] dll_tx_datak;

  dll_if #(.DATA_BYTES(DATA_BYTES)) dll ();

  // The MAC drives PIPE Reset#
  assign pipe.reset_n = pipe_rst_n;

  ccfpga_LTSSM_logic #(
      .DATA_BYTES   (DATA_BYTES),
      .PATTERN_WIDTH(128)
  ) u_mac (
      .i_Reset_n     (mac_rst_n),
      .i_PCLK        (pipe.pclk),
      .i_RxValid     (pipe.rx_valid),
      .i_PhyStatus   (pipe.phy_status),
      .i_RxStatus    (pipe.rx_status),
      .i_RxElecIdle  (pipe.rx_elec_idle),
      .i_RxData      (pipe.rx_data),
      .i_RxDataK     (pipe.rx_datak),
      .i_TxData      (dll_tx_data),
      .i_TxDataK     (dll_tx_datak),
      .o_PowerDown   (pipe.power_down),
      .o_TxDetectRx  (pipe.tx_detect_rx),
      .o_TxElecIdle  (pipe.tx_elec_idle),
      .o_TxCompliance(pipe.tx_compliance),
      .o_RxPolarity  (pipe.rx_polarity),
      .o_TxData      (pipe.tx_data),
      .o_TxDataK     (pipe.tx_datak),
      .o_RxData      (mac_rx_data),
      .o_RxDataK     (  /*LINT:OK*/),       // dll_logic has no K input
      .o_LinkUp      (mac_link_up),
      .o_LTSSM_State (ltssm_state)
  );

  dll_logic #(
      .DATA_BYTES                (DATA_BYTES),
      .NUMBER_OF_VIRTUAL_CHANNELS(1),
      .PATTERN_WIDTH             (64)
  ) u_dll (
      .phy_clk          (pipe.pclk),
      .phy_reset        (~mac_rst_n),
      .phy_linkup       (mac_link_up && (ltssm_state == LTSSM_L0)),
      .phy_rx_data      (mac_rx_data),
      .tl_tx_data       (dll.tx_data),
      .tl_tx_tlp_valid  (dll.tx_tlp_valid),
      .tl_tx_tlp_first  (dll.tx_tlp_first),
      .tl_tx_tlp_last   (dll.tx_tlp_last),
      .tl_tx_tlp_ready  (dll.tx_tlp_ready),
      .tl_tx_hdr_credit (dll.tx_hdr_credit),
      .tl_tx_data_credit(dll.tx_data_credit),
      .tl_tx_update_type(dll.tx_update_type),
      .tl_tx_packet_type(dll.tx_packet_type),
      .tl_tx_dllp_valid (dll.tx_dllp_valid),
      .phy_tx_data      (dll_tx_data),
      .phy_tx_data_k    (dll_tx_datak),
      .tl_rx_data       (dll.rx_data),
      .tl_rx_tlp_valid  (dll.rx_tlp_valid),
      .tl_rx_tlp_first  (dll.rx_tlp_first),
      .tl_rx_tlp_last   (dll.rx_tlp_last),
      .tl_rx_hdr_credit (dll.rx_hdr_credit),
      .tl_rx_data_credit(dll.rx_data_credit),
      .tl_rx_update_type(dll.rx_update_type),
      .tl_rx_packet_type(dll.rx_packet_type),
      .tl_rx_dllp_valid (dll.rx_dllp_valid),
      .o_DL_State       (dll.dl_state)
  );

  assign trn_link_up = (dll.dl_state == DL_ACTIVE);

  pcie_tl u_tl (
      .clk      (pipe.pclk),
      .rst_n    (core_rst_n),
      .dll      (dll),
      .s_axis_tx(s_axis_tx),
      .m_axis_rx(m_axis_rx),
      .cfg      (cfg)
  );

endmodule

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 18, 2026
// -----------------------------------------------------------------------------
