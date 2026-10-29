#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Place and route of top for the GateMate (CCGM1A1), then the bitstream: the
# steps after run-synth.sh in the flow of 4.build/README.md. nextpnr-himbaechel
# takes the netlist, the pins from GateMateA1-EVB.ccf (a mock: the GateMate A1
# EVB until the openCologne-PCIE board exists) and the clocks from top.sdc;
# gmpack (Project Peppercorn) writes the bitstream.
#
# usage:  bash run-synth.sh && bash run-pnr.sh
#
# NEXTPNR and GMPACK override the commands, SEED the placer seed (default 1).
# The work directory is SYNTH_WORK, as for run-synth.sh (default
# ~/.cache/opencologne-pcie/synth); it gets:
#   top.txt       the placed and routed design
#   top.bit       the bitstream
#   report.json   timing and utilization
#   nextpnr.log   the full log

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
NEXTPNR=${NEXTPNR:-nextpnr-himbaechel}
GMPACK=${GMPACK:-gmpack}
SEED=${SEED:-1}
W=${SYNTH_WORK:-$HOME/.cache/opencologne-pcie/synth}

for t in "$NEXTPNR" "$GMPACK"; do
  command -v "$t" >/dev/null || { echo "run-pnr: $t not found" >&2; exit 2; }
done
[ -f "$W/top.json" ] || { echo "run-pnr: no $W/top.json, run run-synth.sh first" >&2; exit 2; }

cd "$W"
"$NEXTPNR" --device CCGM1A1 --json top.json --vopt ccf="$HERE/GateMateA1-EVB.ccf" --sdc "$HERE/top.sdc" \
  --vopt out=top.txt --router router2 --seed "$SEED" --report report.json -l nextpnr.log >/dev/null 2>&1
rc=$?
if [ $rc -ne 0 ]; then
  echo "run-pnr: nextpnr failed, see $W/nextpnr.log" >&2
  grep -E 'ERROR' nextpnr.log | head -20 >&2
  exit $rc
fi
grep -E 'Max frequency for clock|Device utilisation' -A0 nextpnr.log | sed 's/^Info: //'
"$GMPACK" top.txt top.bit || { echo "run-pnr: gmpack failed" >&2; exit 1; }
echo "run-pnr: done, $W/top.bit"

# -----------------------------------------------------------------------------
# Project:     openCologne-PCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        Oct 28, 2026
# -----------------------------------------------------------------------------
