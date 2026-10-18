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
//   pcie_top: everything above the PIPE interface, as in the RTL block
//   diagram (0.doc/2.rtl/block-diagram.drawio):
//
//   - pcie_core: the soft PCIE stack, MAC (LTSSM) -> DLL -> TL ->
//     trn_bridge. It meets the PHY at pipe_mac and the SOC at two AXI-Stream
//     TLP streams and the cfg sideband, the same user interface as the AMD
//     PCIE_2_1 hard block in EP mode (UG477).
//   - riscv_pcie_soc: eduBOS5 and its CSRs, the firmware that answers the
//     host's requests.
//   - clk_rst_gen: clocks and resets.
//
//   Everything here runs on PCLK, which comes from the PHY with pipe_mac.
//==========================================================================

module pcie_top
  import pcie_pkg::*;
(
    input logic clk_brd,  // board oscillator
    input logic perst_n,  // PERST# from the connector, active low

          pipe_if.mac pipe_mac,  // to phy_top
    input logic       phy_rdy_n, // from phy_top: SerDes TX out of reset

    // clock and reset for the SerDes model in phy_top
    output logic clk_reg,
    output logic rst_reg_n,

    output logic trn_link_up,  // data link up
    output logic fw_pass       // the firmware has reported PASS
);

  logic pipe_rst_n;
  logic mac_rst_n;
  logic core_rst_n;

  // TLP streams between the SOC and the PCIE stack
  axis_if #(
      .DATA_W(TRN_DATA_W),
      .USER_W($bits(pcie_tx_tuser_t))
  ) s_axis_tx ();
  axis_if #(
      .DATA_W(TRN_DATA_W),
      .USER_W($bits(pcie_rx_tuser_t))
  ) m_axis_rx ();

  cfg_if cfg ();

  clk_rst_gen u_clk_rst_gen (
      .clk_brd    (clk_brd),
      .perst_n    (perst_n),
      .pclk       (pipe_mac.pclk),
      .phy_rdy_n  (phy_rdy_n),
      .trn_link_up(trn_link_up),
      .clk_reg    (clk_reg),
      .rst_reg_n  (rst_reg_n),
      .pipe_rst_n (pipe_rst_n),
      .mac_rst_n  (mac_rst_n),
      .core_rst_n (core_rst_n)
  );

  pcie_core u_core (
      .pipe_rst_n (pipe_rst_n),
      .mac_rst_n  (mac_rst_n),
      .core_rst_n (core_rst_n),
      .pipe       (pipe_mac),
      .trn_link_up(trn_link_up),
      .s_axis_tx  (s_axis_tx),
      .m_axis_rx  (m_axis_rx),
      .cfg        (cfg)
  );

  riscv_pcie_soc u_soc (
      .clk      (pipe_mac.pclk),
      .resetn   (core_rst_n),
      .s_axis_tx(s_axis_tx),
      .m_axis_rx(m_axis_rx),
      .cfg      (cfg),
      .fw_pass  (fw_pass)
  );

endmodule

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 18, 2026
// -----------------------------------------------------------------------------
