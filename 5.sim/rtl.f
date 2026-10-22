// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause
//
// Verilator source list of the EP RTL for make DUT=rtl: pcie_top (MAC, DLL, TL,
// SOC with firmware) in the order of 4.build/hw_build/sources.sh, without
// top and phy_top: with PHY=vproc_rc the host sits in the phy_top socket
// (models/phy_vproc_rc.sv).

// Packages
../2.rtl/5.tlp/pcie_pkg.sv
../2.rtl/5.tlp/tl_pkg.sv
../4.build/csr_build/generated-files/csr_pkg.sv
../2.rtl/6.soc/CPU.eduBOS5/edubos5_pkg.sv

// Interfaces
../2.rtl/5.tlp/axis_if.sv
../2.rtl/5.tlp/cfg_if.sv
../2.rtl/6.soc/mem_if.sv
../2.rtl/2.pipe/pipe_if.sv
../2.rtl/4.dll/dll_if.sv
../2.rtl/6.soc/rvfi_if.sv

// Modules: ours, the generated CSRs, eduBOS5
../2.rtl/pcie_top.sv
../2.rtl/clk_rst_gen.sv
../2.rtl/pcie_core.sv
../2.rtl/5.tlp/pcie_tl.sv
../2.rtl/5.tlp/tlp_rx_handler.sv
../2.rtl/5.tlp/tlp_queue.sv
../2.rtl/5.tlp/tlp_order.sv
../2.rtl/5.tlp/tlp_rx_dispatch.sv
../2.rtl/5.tlp/config_space.sv
../2.rtl/5.tlp/cpl_gen.sv
../2.rtl/5.tlp/fc_credit.sv
../2.rtl/5.tlp/tlp_tx_arbiter.sv
../2.rtl/6.soc/riscv_pcie_soc.sv
../2.rtl/6.soc/soc_csr.sv
../4.build/csr_build/generated-files/csr.sv
../2.rtl/6.soc/CPU.eduBOS5/edubos5.sv
../2.rtl/6.soc/CPU.eduBOS5/edubos5_alu.sv
../2.rtl/6.soc/CPU.eduBOS5/edubos5_rf.sv

// Cologne Chip's MAC and DLL (arbiter.v is empty: one virtual channel)
../2.rtl/2.pipe/pipe_src/src/mac_src/ccfpga_LTSSM_fsm.v
../2.rtl/2.pipe/pipe_src/src/mac_src/ccfpga_LTSSM_logic.v
../2.rtl/2.pipe/pipe_src/src/mac_src/ccfpga_OS_process.v
../2.rtl/2.pipe/pipe_src/src/mac_src/ccfpga_SKP_generator.v
../2.rtl/2.pipe/pipe_src/src/mac_src/ccfpga_clk_counter.v
../2.rtl/2.pipe/pipe_src/src/mac_src/ccfpga_data_assembly.v
../2.rtl/2.pipe/pipe_src/src/mac_src/ccfpga_rx_MAC.v
../2.rtl/2.pipe/pipe_src/src/mac_src/ccfpga_rx_MAC_IDLE.v
../2.rtl/2.pipe/pipe_src/src/mac_src/ccfpga_rx_MAC_OS.v
../2.rtl/2.pipe/pipe_src/src/mac_src/ccfpga_rx_MAC_data.v
../2.rtl/2.pipe/pipe_src/src/mac_src/ccfpga_scrambler.v
../2.rtl/2.pipe/pipe_src/src/mac_src/ccfpga_scrambler_byte.v
../2.rtl/2.pipe/pipe_src/src/mac_src/ccfpga_scrambler_data.v
../2.rtl/2.pipe/pipe_src/src/mac_src/ccfpga_send_IDLE.v
../2.rtl/2.pipe/pipe_src/src/mac_src/ccfpga_send_OS.v
../2.rtl/2.pipe/pipe_src/src/mac_src/ccfpga_send_data.v
../2.rtl/2.pipe/pipe_src/src/mac_src/ccfpga_tx_MAC.v
../2.rtl/2.pipe/pipe_src/src/mac_src/ccfpga_tx_count.v
../2.rtl/2.pipe/pipe_src/src/dll_src/crc_byte.v
../2.rtl/2.pipe/pipe_src/src/dll_src/crc_gen.v
../2.rtl/2.pipe/pipe_src/src/dll_src/dll_clk_counter.v
../2.rtl/2.pipe/pipe_src/src/dll_src/dll_fsm.v
../2.rtl/2.pipe/pipe_src/src/dll_src/dll_logic.v
../2.rtl/2.pipe/pipe_src/src/dll_src/lcrc_byte.v
../2.rtl/2.pipe/pipe_src/src/dll_src/packet_handler.v
../2.rtl/2.pipe/pipe_src/src/dll_src/retry_buffer.v
../2.rtl/2.pipe/pipe_src/src/dll_src/send_DLLP.v
../2.rtl/2.pipe/pipe_src/src/dll_src/tlp_rx_buffer.v
../2.rtl/2.pipe/pipe_src/src/dll_src/virtual_channel.v
../2.rtl/2.pipe/pipe_src/src/dll_src/virtual_channel_rx.v
../2.rtl/2.pipe/pipe_src/src/dll_src/virtual_channel_tx.v

// GateMate primitives for simulation, and the phy_top socket
models/gatemate_cells_sim.sv
models/phy_vproc_rc.sv
