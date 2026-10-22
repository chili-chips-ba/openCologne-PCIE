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
//   Top-level test bench: the host, RCPIPEx1__pcieVHost at VProc node 1,
//   drives the DUT at its PIPE interface: the EP RTL + firmware, or the
//   mock EPPIPEx1__pcieVHost_DUT.
//==========================================================================

`timescale 1ps/1ps

module tb #(
   parameter RUN_SIM_US     = 10000,
             PIPE_DATAWIDTH = 64   
   
)();

//--------------------------------------------------------------
// Clock and reset generation
//--------------------------------------------------------------

  // Generate clocks and run sim for the specified amount of time
  localparam  HALF_CLK_P_PERIOD_PS      = 2_500; // 200MHz, reset timing
  localparam  HALF_PCIE_PERIOD_PS       = 2_000; // 250MHz (GEN1)
  localparam  HALF_PIPE_PERIOD_PS       = HALF_PCIE_PERIOD_PS*8;
  localparam  RST_CYLES                 = 10;

  logic       clk_p;
  wire        clk_n;
  logic       rst_n;
  logic       pcieclk;
  logic       pclk;

  initial begin
    clk_p      = 1'b0;
    //clk_n      = 1'b0;
    rst_n      = 1'b0;
    pcieclk    = 1'b0;
    pclk        = 1'b0;


    fork
      begin : board_rst_n
        #(HALF_CLK_P_PERIOD_PS*RST_CYLES)
          rst_n = 1'b1;
      end

      forever begin: clk_p_gen
        #(HALF_CLK_P_PERIOD_PS)
          clk_p  = ~clk_p;
      end

      forever begin: pcie_clock_gen
        #(HALF_PCIE_PERIOD_PS)
          pcieclk = ~pcieclk;
      end
      
      forever begin: pipe_clock_gen
        #(HALF_PIPE_PERIOD_PS)
          pclk = ~pclk;
      end

      begin: run_sim
        #(RUN_SIM_US * 64'd1_000_000);  // in ps, the timescale unit
          $finish(2);
      end
    join
  end

  assign clk_n = ~clk_p;


//--------------------------------------------------------------
// DUT
//--------------------------------------------------------------

  logic [PIPE_DATAWIDTH-1:0]           downdata;
  logic [PIPE_DATAWIDTH/8-1:0]         downdatak;
  logic [PIPE_DATAWIDTH-1:0]           updata;
  logic [PIPE_DATAWIDTH/8-1:0]         updatak;

  // Electrical idle side-band between the two models (Verilator only):
  // down = RC -> EP, up = EP -> RC
  logic                                elec_idle_down;
  logic                                elec_idle_up;

//--------------------------------------------------------------
// DUT: the EP, at its PIPE interface. Either the EP RTL + firmware
// (make DUT=rtl): pcie_top, with the host in the phy_top socket
// (phy_vproc_rc), or the mock EPPIPEx1__pcieVHost_DUT, a pcieVHost in EP
// mode (make DUT=mock)
//--------------------------------------------------------------

`ifdef DUT_RTL
  localparam  HALF_BRD_PERIOD_PS        = 50_000; // 10 MHz board clock

  logic       clk_brd;
  logic       phy_rdy_n;
  logic       link_up;
  logic       fw_pass;

  initial begin
    clk_brd = 1'b0;
    forever begin
      #(HALF_BRD_PERIOD_PS) clk_brd = ~clk_brd;
    end
  end

  pipe_if #(.DATA_BYTES(PIPE_DATAWIDTH/8)) pipe_mac ();

  phy_vproc_rc #(
    .DATA_BYTES                        (PIPE_DATAWIDTH/8)
  ) u_phy
  (
    .pclk                              (pclk),
    .rst_n                             (rst_n),
    .pipe                              (pipe_mac),
    .phy_rdy_n                         (phy_rdy_n),
    .host_txdata                       (downdata),
    .host_txdatak                      (downdatak),
`ifdef VERILATOR
    .host_elec_idle                    (elec_idle_down),
    .ep_elec_idle                      (elec_idle_up),
`else
    .host_elec_idle                    (1'b0),
    .ep_elec_idle                      (),
`endif
    .host_rxdata                       (updata),
    .host_rxdatak                      (updatak)
  );

  pcie_top dut
  (
    .clk_brd                           (clk_brd),
    .perst_n                           (rst_n),
    .pipe_mac                          (pipe_mac),
    .phy_rdy_n                         (phy_rdy_n),
    .clk_reg                           (),
    .rst_reg_n                         (),
    .trn_link_up                       (link_up),
    .fw_pass                           (fw_pass)
  );

  always @(link_up) $display("%t tb: trn_link_up = %b", $time, link_up);
  always @(fw_pass) $display("%t tb: fw_pass = %b", $time, fw_pass);
`else
  EPPIPEx1__pcieVHost_DUT #(
    .DataWidth                         (PIPE_DATAWIDTH)
  ) dut
  (
    .rst_n                             (rst_n),
    .pclk                              (pclk),
    .pcieclk                           (pcieclk),

`ifdef VERILATOR
    .elec_idle_out                     (elec_idle_up),
    .elec_idle_in                      (elec_idle_down),
`endif

    // PCIE PIPE data
    .txdata                            (updata),
    .txdatak                           (updatak),
    .rxdata                            (downdata),
    .rxdatak                           (downdatak)
  );
`endif

//--------------------------------------------------------------
// Host: RCPIPEx1__pcieVHost, a pcieVHost in RC mode at VProc node 1. Its
// ports are the RC's decoder page of the dump (tb.u_rc): the link at the
// PIPE, Data Link and Transaction layers, under the names WaveCrux
// auto-binds. The mock EP has the same, as it sees the link
// (tb.dut.bfm_pcie)
//--------------------------------------------------------------

  // Data Link: RC -> EP TLPs as a DLL hands them to its TL, on pclk; for a
  // TL under test without the MAC and DLL below it (nothing reads them yet)
  logic [PIPE_DATAWIDTH-1:0]           dll_rx_data;
  logic                                dll_rx_tlp_valid;
  logic                                dll_rx_tlp_first;
  logic                                dll_rx_tlp_last;

  RCPIPEx1__pcieVHost #(
    .NodeNum                           (1),
    .DataWidth                         (PIPE_DATAWIDTH),
    .DllBytes                          (PIPE_DATAWIDTH/8)
  ) u_rc
  (
    .pcieclk                           (pcieclk),
    .pclk                              (pclk),
    .nreset                            (rst_n),

`ifdef VERILATOR
    .ElecIdleOut                       (elec_idle_down),
    .ElecIdleIn                        (elec_idle_up),
`endif

    // PIPE: the link, and its copies by direction for the decoders
    .TxData                            (downdata),
    .TxDataK                           (downdatak),
    .RxData                            (updata),
    .RxDataK                           (updatak),
    .pipe_dn_pclk                      (),
    .pipe_dn_data                      (),
    .pipe_dn_datak                     (),
    .pipe_up_pclk                      (),
    .pipe_up_data                      (),
    .pipe_up_datak                     (),

    // Data Link
    .dll_clk                           (pclk),
    .dll_rx_data                       (dll_rx_data),
    .dll_rx_tlp_valid                  (dll_rx_tlp_valid),
    .dll_rx_tlp_first                  (dll_rx_tlp_first),
    .dll_rx_tlp_last                   (dll_rx_tlp_last),
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

    // Transaction: for waveform decoders, read from the dump
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

// Top level fatal task, which can be called from anywhere in verilog code.
// via the `fatal definition in pciedispheader.v. Any data logging, error
// message displays etc., on a fatal, should be placed in here.
task Fatal;
begin
    $display("***FATAL ERROR...calling $finish!");
    $finish;
end
endtask

// FST waveform, for WaveCrux and GTKWave (make DUMP=1 run): the signals of
// this level, i.e. the PIPE link both ways, its clocks and reset, and the
// host's ports (u_rc), the decoder page
`ifdef DUMP
initial begin
    $dumpfile("tb.fst");
    $dumpvars(1, tb);
    $dumpvars(1, tb.u_rc);
`ifndef DUT_RTL
    $dumpvars(1, tb.dut.bfm_pcie);
`endif
end
`endif

endmodule: tb

/*
------------------------------------------------------------------------------
Version History:
------------------------------------------------------------------------------
 2025/08/19 SS: initial creation

*/

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        April 2025
// -----------------------------------------------------------------------------
