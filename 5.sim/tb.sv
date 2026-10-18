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
//   stand-in EPPIPEx1__pcieVHost_DUT.
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
// (make DUT=rtl, once it exists) or the stand-in EPPIPEx1__pcieVHost_DUT,
// a pcieVHost in EP mode (make DUT=mock)
//--------------------------------------------------------------

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

//--------------------------------------------------------------
// Host: RCPIPEx1__pcieVHost, a pcieVHost in RC mode at VProc node 1
//--------------------------------------------------------------

  RCPIPEx1__pcieVHost #(
    .NodeNum                           (1),
    .DataWidth                         (PIPE_DATAWIDTH)
  ) u_rc
  (
    .pcieclk                           (pcieclk),
    .pclk                              (pclk),
    .nreset                            (rst_n),

`ifdef VERILATOR
    .ElecIdleOut                       (elec_idle_down),
    .ElecIdleIn                        (elec_idle_up),
`endif

    .TxData                            (downdata),
    .TxDataK                           (downdatak),

    .RxData                            (updata),
    .RxDataK                           (updatak)
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
