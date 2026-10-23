// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause
//
// Verilator source list of the EP's WaveCrux views, for make DUT=rtl DUMP=1:
// simulation only, bound into pcie_core and riscv_pcie_soc; nothing in the
// design reads them (models/ep_wavecrux_view.sv).

models/tlp_dw_if.sv
models/tlp_dw_monitor.sv
models/tlp_wavecrux_view.sv
../2.rtl/6.soc/CPU.eduBOS5/wavecrux/soc_cpu_view.sv
models/ep_wavecrux_view.sv
