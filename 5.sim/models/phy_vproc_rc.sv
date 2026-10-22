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
//   phy_vproc_rc: the phy_top socket with PHY=vproc_rc, the host at the PIPE.
//   It is the PHY side of pipe_if for our MAC: PCLK from the test bench, the
//   host's PIPE data in and out, electrical idle both ways (Verilator: the
//   pcieVHost side-band), and receiver detection: while the MAC asks for it
//   (tx_detect_rx), RxStatus reports a receiver present (3'b011).
//==========================================================================

`timescale 1ps/1ps

module phy_vproc_rc #(
    parameter int DATA_BYTES = 8
) (
    input  logic                    pclk,
    input  logic                    rst_n,
           pipe_if.phy              pipe,
    output logic                    phy_rdy_n,
    input  logic [DATA_BYTES*8-1:0] host_txdata,
    input  logic [  DATA_BYTES-1:0] host_txdatak,
    input  logic                    host_elec_idle,
    output logic [DATA_BYTES*8-1:0] host_rxdata,
    output logic [  DATA_BYTES-1:0] host_rxdatak,
    output logic                    ep_elec_idle
);
  logic [3:0] rdy_cnt;

  always_ff @(posedge pclk or negedge rst_n) begin
    if (!rst_n) begin
      rdy_cnt <= '0;
    end
    else if (rdy_cnt != 4'hF) begin
      rdy_cnt <= rdy_cnt + 4'd1;
    end
  end

  assign phy_rdy_n         = (rdy_cnt != 4'hF);

  assign pipe.pclk         = pclk;
  assign pipe.rx_data      = host_txdata;
  assign pipe.rx_datak     = host_txdatak;
  assign pipe.rx_elec_idle = host_elec_idle;
  assign pipe.rx_valid     = !host_elec_idle;

  always_ff @(posedge pclk or negedge rst_n) begin
    if (!rst_n) begin
      pipe.phy_status <= 1'b1;
      pipe.rx_status  <= 3'b000;
    end
    else begin
      pipe.phy_status <= !pipe.reset_n || pipe.tx_detect_rx;
      pipe.rx_status  <= pipe.tx_detect_rx ? 3'b011 : 3'b000;
    end
  end

  assign host_rxdata  = pipe.tx_data;
  assign host_rxdatak = pipe.tx_datak;
  assign ep_elec_idle = pipe.tx_elec_idle;
endmodule: phy_vproc_rc

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 21, 2026
// -----------------------------------------------------------------------------
