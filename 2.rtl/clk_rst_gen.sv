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
//   clk_rst_gen: the clocks and resets of the EP.
//
//   Clocks:
//   - clk_reg: CC_PLL from the board clock. Runs the reset sequencing below
//     and, in simulation, the SerDes model's regfile and its bring-up FSM.
//   - PCLK is not made here: the PHY makes it (pipe_if.pclk), and the MAC,
//     DLL, TL, trn_bridge and the SOC all run on it.
//
//   Resets, one per clock domain, each asserted asynchronously and released
//   on its own clock:
//   - root: CC_USR_RSTN (end of FPGA configuration) and PERST# from the
//     connector. CC_USR_RSTN replaces the INIT-value flops a Xilinx design
//     needs for a reset after configuration.
//   - rst_reg_n (clk_reg): root, and the PLL locked (a lost lock resets).
//   - pipe_rst_n (clk_reg): PIPE Reset#, 255 clk_reg cycles after rst_reg_n.
//   - mac_rst_n (PCLK): held until the SerDes TX is out of reset (phy_rdy_n).
//   - core_rst_n (PCLK): the TL, trn_bridge and the SOC, released once the
//     data link is up (trn_link_up); a link drop asserts it again.
//==========================================================================

module clk_rst_gen #(
    // In MHz, as strings: Yosys's CC_PLL takes them so (UG1001 shows reals)
    parameter string BRD_CLK_MHZ = "10.0",  // board clock (10 MHz on the GateMate EVK)
    parameter string REG_CLK_MHZ = "125.0"
) (
    input logic clk_brd,  // board oscillator, on a dedicated clock pin
    input logic perst_n,  // PERST# from the connector, active low

    input logic pclk,        // PCLK, from the PHY
    input logic phy_rdy_n,   // PCLK: SerDes TX out of reset
    input logic trn_link_up, // PCLK: data link up

    output logic clk_reg,
    output logic rst_reg_n,
    output logic pipe_rst_n,
    output logic mac_rst_n,
    output logic core_rst_n
);

  logic usr_rstn;
  logic pll_clk0;
  logic pll_locked;
  logic root_rst_n;

  CC_USR_RSTN u_usr_rstn (.USR_RSTN(usr_rstn));

  CC_PLL #(
      .REF_CLK    (BRD_CLK_MHZ),
      .OUT_CLK    (REG_CLK_MHZ),
      .PERF_MD    ("ECONOMY"),
      .LOW_JITTER (1),
      .LOCK_REQ   (1),
      .CLK270_DOUB(0),
      .CLK180_DOUB(0)
  ) u_pll (
      .CLK_REF            (clk_brd),
      .USR_CLK_REF        (1'b0),
      .CLK_FEEDBACK       (1'b0),
      .USR_LOCKED_STDY_RST(1'b0),
      .USR_PLL_LOCKED_STDY(  /*LINT:OK*/),
      .USR_PLL_LOCKED     (pll_locked),
      .CLK0               (pll_clk0),
      .CLK90              (  /*LINT:OK*/),
      .CLK180             (  /*LINT:OK*/),
      .CLK270             (  /*LINT:OK*/),
      .CLK_REF_OUT        (  /*LINT:OK*/)
  );

  // Every PLL output that drives FPGA logic goes through a global buffer
  // (UG1001)
  CC_BUFG u_clk_reg (
      .I(pll_clk0),
      .O(clk_reg)
  );

  assign root_rst_n = usr_rstn & perst_n & pll_locked;

  // rst_reg_n: root, released on clk_reg
  logic rst_reg_meta, rst_reg_q;

  always_ff @(posedge clk_reg or negedge root_rst_n) begin
    if (!root_rst_n) begin
      rst_reg_meta <= 1'b0;
      rst_reg_q    <= 1'b0;
    end
    else begin
      rst_reg_meta <= 1'b1;
      rst_reg_q    <= rst_reg_meta;
    end
  end

  assign rst_reg_n = rst_reg_q;

  // pipe_rst_n: PIPE Reset#, held for 255 clk_reg cycles after rst_reg_n
  logic [7:0] pipe_rst_cnt;

  assign pipe_rst_n = (pipe_rst_cnt == 8'hFF);

  always_ff @(posedge clk_reg or negedge rst_reg_n) begin
    if (!rst_reg_n) begin
      pipe_rst_cnt <= '0;
    end
    else if (!pipe_rst_n) begin
      pipe_rst_cnt <= pipe_rst_cnt + 8'd1;
    end
  end

  // mac_rst_n: released on PCLK once the SerDes TX is out of reset
  logic mac_rst_meta, mac_rst_q;

  always_ff @(posedge pclk or posedge phy_rdy_n) begin
    if (phy_rdy_n) begin
      mac_rst_meta <= 1'b0;
      mac_rst_q    <= 1'b0;
    end
    else begin
      mac_rst_meta <= 1'b1;
      mac_rst_q    <= mac_rst_meta;
    end
  end

  assign mac_rst_n = mac_rst_q;

  // core_rst_n: the TL, trn_bridge and SOC reset, follows the data link
  always_ff @(posedge pclk or negedge mac_rst_n) begin
    if (!mac_rst_n) begin
      core_rst_n <= 1'b0;
    end
    else begin
      core_rst_n <= trn_link_up;
    end
  end

endmodule

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 18, 2026
// -----------------------------------------------------------------------------
