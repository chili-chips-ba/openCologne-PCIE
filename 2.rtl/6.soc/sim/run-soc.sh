#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# tb_soc on Verilator: the SOC alone, eduBOS5 with its RVFI outputs
# (RISCV_FORMAL), running 4.build/sw_build/firmware.hex. Writes tb_soc.fst
# here, for tb_soc.RISCV-ISA.wavecrux.
#
# usage:  bash run-soc.sh
#
# SOC_BUILD (default ~/.cache/opencologne-pcie/soc) is the build directory.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
R=$(cd "$HERE/../.." && pwd)
G=$R/../4.build/csr_build/generated-files
E=$R/6.soc/CPU.eduBOS5
B=${SOC_BUILD:-$HOME/.cache/opencologne-pcie/soc}
mkdir -p "$B"
verilator --binary --timing --trace-fst -Wno-fatal -Wno-lint -Wno-style --timescale 1ns/1ps \
  -DRISCV_FORMAL --top-module tb_soc --Mdir "$B/obj" -o Vtb_soc \
  "$R/5.tlp/pcie_pkg.sv" "$G/csr_pkg.sv" "$E/edubos5_pkg.sv" \
  "$R/5.tlp/axis_if.sv" "$R/5.tlp/cfg_if.sv" "$R/6.soc/mem_if.sv" "$R/6.soc/rvfi_if.sv" \
  "$E/edubos5_rf.sv" "$E/edubos5_alu.sv" "$E/edubos5.sv" "$G/csr.sv" \
  "$R/6.soc/soc_csr.sv" "$R/6.soc/riscv_pcie_soc.sv" "$E/wavecrux/soc_cpu_view.sv" \
  "$HERE/tb_soc.sv" > "$B/build.log" 2>&1 || { tail -20 "$B/build.log"; exit 1; }
cp "$R/../4.build/sw_build/firmware.hex" "$HERE/"
cd "$HERE"
"$B/obj/Vtb_soc"
rm -f "$HERE/firmware.hex"
echo "waveform: $HERE/tb_soc.fst"

# -----------------------------------------------------------------------------
# Project:     openCologne-PCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        Oct 18, 2026
# -----------------------------------------------------------------------------
