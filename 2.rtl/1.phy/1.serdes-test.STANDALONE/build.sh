#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Build the standalone PRBS loopback test for the GateMate evaluation board,
# on its own, without the rest of the repo. The flow is the one UG1002
# describes (0.doc/4.build/ug1002-GateMate-toolchain.May2026.pdf):
#
#   yosys (read_slang, synth_gatemate) -> nextpnr-himbaechel -> gmpack
#
# usage:  bash build.sh [CCGM1A1|CCGM1A2]      (default CCGM1A1)
#         OUT=<dir> bash build.sh              (default ./build)
#
# Needs yosys with slang, nextpnr-himbaechel with the gatemate uarch, and
# gmpack, e.g. from the OSS CAD Suite. openXC7's nextpnr-himbaechel has the
# xilinx uarch only. Load the result over JTAG with
#   openFPGALoader -b gatemate_evb_jtag <OUT>/serdes_top.bit
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$HERE/PRBS-Loopback-Test-for-GateMate-EVK
OUT=${OUT:-$HERE/build}
DEVICE=${1:-CCGM1A1}

for t in yosys yosys-config nextpnr-himbaechel gmpack; do
    command -v "$t" >/dev/null || { echo "ERROR: $t not found on PATH"; exit 1; }
done
if ! nextpnr-himbaechel --list-uarch 2>&1 | grep -q gatemate; then
    echo "ERROR: $(command -v nextpnr-himbaechel) has no gatemate uarch;"
    echo "       use one that has, e.g. from the OSS CAD Suite"
    exit 1
fi
mkdir -p "$OUT"

# the GateMate primitives (CC_SERDES, CC_USR_RSTN, ...) as blackboxes for slang
CELLS=$(yosys-config --datdir)/gatemate/cells_bb.v

yosys -q -l "$OUT/yosys.log" -p "
    read_slang $CELLS $SRC/serdes_top.sv --top serdes_top;
    synth_gatemate -top serdes_top -luttree -nomx8;
    write_json $OUT/serdes_top.json"

nextpnr-himbaechel --device="$DEVICE" --json "$OUT/serdes_top.json" \
    -o ccf="$SRC/Pins.ccf" -o out="$OUT/impl.txt" --router router2 \
    -l "$OUT/pnr.log"

gmpack "$OUT/impl.txt" "$OUT/serdes_top.bit"

echo "Done: $OUT/serdes_top.bit"
echo "Load: openFPGALoader -b gatemate_evb_jtag $OUT/serdes_top.bit"

# -----------------------------------------------------------------------------
# Project:     openCologne-PCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        April 2025
# -----------------------------------------------------------------------------
