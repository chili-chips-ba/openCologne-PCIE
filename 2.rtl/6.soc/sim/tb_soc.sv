// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openCologne-PCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
// Description:
//   tb_soc: the SOC alone, eduBOS5 running firmware.hex, for WaveCrux's
//   RISC-V views (tb_soc.RISCV-ISA.wavecrux). The PCIE side is idle: no TLP
//   arrives, and the SOC's own TLPs are taken and dropped, so the firmware
//   starts up and then waits for a request from the host. cpu_view shows
//   the CPU's retired instructions (riscv_pcie_soc's rvfi) under the RVFI
//   names. Run: bash run-soc.sh
//==========================================================================

`timescale 1ns / 1ps

module tb_soc
  import pcie_pkg::*;
;
  localparam int RUN_NS = 20_000;

  logic clk = 1'b0;
  logic resetn = 1'b0;

  always #16 clk = ~clk;  // 31.25 MHz, the PCLK the SOC runs on in top

  initial begin
    repeat (10) @(posedge clk);
    resetn = 1'b1;
  end

  axis_if #(
      .DATA_W(TRN_DATA_W),
      .USER_W($bits(pcie_tx_tuser_t))
  ) s_axis_tx ();
  axis_if #(
      .DATA_W(TRN_DATA_W),
      .USER_W($bits(pcie_rx_tuser_t))
  ) m_axis_rx ();
  cfg_if cfg ();

  // the PCIE stack stand-in: takes every TLP, sends none
  assign s_axis_tx.tready    = 1'b1;
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

  logic fw_pass;

  riscv_pcie_soc dut (
      .clk      (clk),
      .resetn   (resetn),
      .s_axis_tx(s_axis_tx),
      .m_axis_rx(m_axis_rx),
      .cfg      (cfg),
      .fw_pass  (fw_pass)
  );

  // The CPU under RVFI names, for WaveCrux (CPU.eduBOS5/wavecrux/soc_cpu_view.sv)
  soc_cpu_view cpu_view (
      .clk      (clk),
      .valid    (dut.rvfi.rvfi_valid),
      .order    (dut.rvfi.rvfi_order),
      .insn     (dut.rvfi.rvfi_insn),
      .trap     (dut.rvfi.rvfi_trap),
      .halt     (dut.rvfi.rvfi_halt),
      .intr     (dut.rvfi.rvfi_intr),
      .rs1_addr (dut.rvfi.rvfi_rs1_addr),
      .rs2_addr (dut.rvfi.rvfi_rs2_addr),
      .rs1_rdata(dut.rvfi.rvfi_rs1_rdata),
      .rs2_rdata(dut.rvfi.rvfi_rs2_rdata),
      .rd_addr  (dut.rvfi.rvfi_rd_addr),
      .rd_wdata (dut.rvfi.rvfi_rd_wdata),
      .pc_rdata (dut.rvfi.rvfi_pc_rdata),
      .pc_wdata (dut.rvfi.rvfi_pc_wdata),
      .mem_addr (dut.rvfi.rvfi_mem_addr),
      .mem_rmask(dut.rvfi.rvfi_mem_rmask),
      .mem_wmask(dut.rvfi.rvfi_mem_wmask),
      .mem_rdata(dut.rvfi.rvfi_mem_rdata),
      .mem_wdata(dut.rvfi.rvfi_mem_wdata)
  );

  initial begin
    $dumpfile("tb_soc.fst");
    $dumpvars(1, cpu_view);
    #(RUN_NS);
    $display("tb_soc: %0d ns, fw_pass=%0b", RUN_NS, fw_pass);
    $finish;
  end

endmodule : tb_soc

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 18, 2026
// -----------------------------------------------------------------------------
