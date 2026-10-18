#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Synthesis of top for the GateMate (CCGM1A1): Yosys read_slang, then
# synth_gatemate, the first step of the flow in 4.build/README.md. It writes
# the netlist and the cell statistics; place & route (nextpnr-himbaechel with
# the board's .ccf pins) and gmpack follow once the board constraints exist.
#
# usage:  bash run-synth.sh
#
# Needs Yosys with the read_slang plugin: YOSYS_ARGS defaults to "-m slang";
# point it at the plugin, e.g. YOSYS_ARGS="-m ~/opt/src/sv-elab-main/build/slang.so".
# YOSYS and YOSYS_CONFIG override the commands. The work directory is
# SYNTH_WORK (default ~/.cache/opencologne-pcie/synth); it gets:
#   top.json   the netlist, for nextpnr-himbaechel
#   stat.txt   the cells used
#   yosys.log  the full log

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
. "$HERE/sources.sh"
YOSYS=${YOSYS:-yosys}
YOSYS_CONFIG=${YOSYS_CONFIG:-yosys-config}
YOSYS_ARGS=${YOSYS_ARGS:--m slang}
W=${SYNTH_WORK:-$HOME/.cache/opencologne-pcie/synth}
mkdir -p "$W"

for t in "$YOSYS" "$YOSYS_CONFIG"; do
  command -v "$t" >/dev/null || { echo "run-synth: $t not found" >&2; exit 2; }
done

# GateMate primitives as blackboxes, plus CC_BUFG, which Yosys has only as a
# simulation model; synth_gatemate maps them to the real cells
{ cat "$("$YOSYS_CONFIG" --datdir)/gatemate/cells_bb.v"
  printf '(* blackbox *)\nmodule CC_BUFG (input I, output O);\nendmodule\n'
} > "$W/bb.v"

# the firmware is the RAM's initial content ($readmemh in riscv_pcie_soc)
cp "$REPO/4.build/sw_build/firmware.hex" "$W/"
SV=$(design_rtl "$REPO/2.rtl" "$REPO/4.build/csr_build/generated-files" | tr '\n' ' ')

cd "$W"
"$YOSYS" $YOSYS_ARGS -l yosys.log -p "read_slang -D SYNTHESIS --top top bb.v $SV; \
    synth_gatemate -top top -luttree -nomx8; \
    tee -q -o stat.txt stat; write_json top.json" >/dev/null
rc=$?
if [ $rc -ne 0 ]; then
  echo "run-synth: failed, see $W/yosys.log" >&2
  grep -E 'error|ERROR' yosys.log | head -20 >&2
  exit $rc
fi
grep -E '^ +[0-9]+ +CC_' stat.txt
echo "run-synth: done, $W/top.json"

# -----------------------------------------------------------------------------
# Project:     openCologne-PCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        Oct 18, 2026
# -----------------------------------------------------------------------------
