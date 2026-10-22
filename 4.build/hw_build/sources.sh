# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# The RTL file lists, one place for run-lint.sh, run-format.sh and
# run-synth.sh. Source it, then call a function with the 2.rtl directory:
#
#   own_rtl <2.rtl>         our own RTL: what run-format.sh formats
#   design_rtl <2.rtl> <csr generated-files dir> [sim]
#                           every file of top, in compile order: packages,
#                           interfaces, then modules. With "sim", also the
#                           opensource SerDes BFM that phy_top uses in
#                           simulation.

own_rtl() {
  local r=$1
  echo "$r"/5.tlp/*.sv "$r"/2.pipe/pipe_if.sv "$r"/4.dll/dll_if.sv "$r"/6.soc/*.sv \
       "$r"/1.phy/phy_top.sv "$r"/*.sv
}

design_rtl() {
  local r=$1 g=$2 e=$1/6.soc/CPU.eduBOS5 cc=$1/2.pipe/pipe_src/src
  # packages
  echo "$r"/5.tlp/pcie_pkg.sv "$r"/5.tlp/tl_pkg.sv "$g"/csr_pkg.sv "$e"/edubos5_pkg.sv
  # interfaces
  echo "$r"/5.tlp/axis_if.sv "$r"/5.tlp/trn_if.sv "$r"/5.tlp/cfg_if.sv "$r"/6.soc/mem_if.sv "$r"/2.pipe/pipe_if.sv \
       "$r"/4.dll/dll_if.sv "$r"/6.soc/rvfi_if.sv
  # modules: ours, the generated CSRs, eduBOS5, Cologne Chip's PIPE logic,
  # MAC and DLL (arbiter.v is empty: one virtual channel)
  echo "$r"/top.sv "$r"/pcie_top.sv "$r"/clk_rst_gen.sv "$r"/pcie_core.sv "$r"/5.tlp/pcie_tl.sv \
       "$r"/1.phy/phy_top.sv
  echo "$r"/5.tlp/tlp_rx_handler.sv "$r"/5.tlp/tlp_queue.sv "$r"/5.tlp/tlp_order.sv \
       "$r"/5.tlp/tlp_rx_dispatch.sv "$r"/5.tlp/config_space.sv "$r"/5.tlp/cpl_gen.sv \
       "$r"/5.tlp/fc_credit.sv "$r"/5.tlp/tlp_tx_arbiter.sv
  echo "$r"/5.tlp/trn_bridge.sv "$r"/5.tlp/trn_rx.sv "$r"/5.tlp/trn_tx.sv "$r"/5.tlp/trn_tx_throttle.sv
  echo "$r"/6.soc/riscv_pcie_soc.sv "$r"/6.soc/soc_csr.sv "$g"/csr.sv
  echo "$e"/edubos5.sv "$e"/edubos5_alu.sv "$e"/edubos5_rf.sv
  ls "$cc"/pipe_src/*.v | grep -v ccfpga_pipe_wrapper
  ls "$cc"/mac_src/*.v
  ls "$cc"/dll_src/*.v | grep -v arbiter
  if [ "${3:-}" = sim ]; then
    echo "$r"/1.phy/2.serdes-model/ccfpga_serdes_pkg.sv "$r"/1.phy/2.serdes-model/ccfpga_serdes.sv
  fi
}

# -----------------------------------------------------------------------------
# Project:     openCologne-PCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        Oct 18, 2026
# -----------------------------------------------------------------------------
