// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause
//
// Verilator source list of the PHY for make PHY=rtl (with DUT=rtl): top, with
// phy_top, Cologne Chip's PIPE logic and the opensource SerDes BFM, so the host
// drives the serial line.

../2.rtl/top.sv
../2.rtl/1.phy/phy_top.sv
../2.rtl/2.pipe/pipe_src/src/pipe_src/ccfpga_pipe_clk_counter.v
../2.rtl/2.pipe/pipe_src/src/pipe_src/ccfpga_pipe_clk_divider.v
../2.rtl/2.pipe/pipe_src/src/pipe_src/ccfpga_pipe_fsm.v
../2.rtl/2.pipe/pipe_src/src/pipe_src/ccfpga_pipe_fsm_word_align.v
../2.rtl/2.pipe/pipe_src/src/pipe_src/ccfpga_pipe_logic.v
../2.rtl/2.pipe/pipe_src/src/pipe_src/ccfpga_pipe_rx_mux.v
../2.rtl/2.pipe/pipe_src/src/pipe_src/ccfpga_pipe_tx_demux.v
../2.rtl/1.phy/2.serdes-model/ccfpga_serdes_pkg.sv
../2.rtl/1.phy/2.serdes-model/ccfpga_serdes.sv
