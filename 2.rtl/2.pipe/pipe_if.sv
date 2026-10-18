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
//   pipe_if: the PIPE interface between the MAC (in pcie_core) and the PHY
//   (phy_top), one lane, DATA_BYTES symbols per PCLK. PIPE ("PHY Interface
//   for PCI Express", Intel) splits the Physical Layer in two: the MAC above
//   does link training (LTSSM), scrambling and framing; the PHY below does
//   8b/10b, serialization and clock recovery. The PHY also makes the clock:
//   PCLK is a PHY output, and the MAC side runs on it.
//==========================================================================

interface pipe_if #(
    parameter int DATA_BYTES = 8  // 8: 64-bit PIPE at 31.25 MHz for Gen1
);
  localparam int DATA_W = DATA_BYTES * 8;

  // MAC -> PHY
  logic                  reset_n;  // PIPE Reset#
  logic [           1:0] power_down;  // P0, P0s, P1, P2
  logic                  tx_detect_rx;  // receiver detection (in P1)
  logic                  tx_elec_idle;
  logic [DATA_BYTES-1:0] tx_compliance;
  logic                  rx_polarity;  // invert the received bits
  logic [    DATA_W-1:0] tx_data;
  logic [DATA_BYTES-1:0] tx_datak;  // per symbol: 1 = K (control) symbol

  // PHY -> MAC
  logic                  pclk;
  logic                  rx_valid;
  logic                  phy_status;
  logic [           2:0] rx_status;
  logic                  rx_elec_idle;
  logic [    DATA_W-1:0] rx_data;
  logic [DATA_BYTES-1:0] rx_datak;

  modport mac(
      output reset_n, power_down, tx_detect_rx, tx_elec_idle, tx_compliance, rx_polarity,
      output tx_data, tx_datak,
      input pclk, rx_valid, phy_status, rx_status, rx_elec_idle, rx_data, rx_datak
  );
  modport phy(
      input reset_n, power_down, tx_detect_rx, tx_elec_idle, tx_compliance, rx_polarity,
      input tx_data, tx_datak,
      output pclk, rx_valid, phy_status, rx_status, rx_elec_idle, rx_data, rx_datak
  );
endinterface

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 18, 2026
// -----------------------------------------------------------------------------
