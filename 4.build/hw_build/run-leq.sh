#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Formal equivalence check of the whole design (top: PHY wrapper, MAC, DLL,
# TL, SOC, CPU, CSR) between two versions of the RTL, with Yosys
# (read_slang), chip view (SYNTHESIS defined). Use it to prove that a cleanup
# does not change behaviour.
#
# usage:  bash run-leq.sh <gold 2.rtl> <gate 2.rtl> [sed script]
#         LEQ_EXTRA=<file> bash run-leq.sh ... Yosys commands run after equiv_make,
#                                              e.g. equiv_add for registers that
#                                              were regrouped into a struct
#                                              (gold: name_gold, gate: name_gate):
#           cd eq
#           equiv_add -try \u_x.ng_cur_state_gold \u_x.ng_q_gate[12]
#           cd ..
#   <gold 2.rtl>, <gate 2.rtl>  copies of 2.rtl, with the submodule, e.g.
#                               cp -r 2.rtl /tmp/gold   (before the change)
#   [sed script]                renames gold objects to their gate names, for a
#                               change that moves logic between modules, e.g.
#                               's|^u_pcie_top\.u_core\.u_x\.|u_pcie_top.u_core.|'
#
# Both versions use the same generated CSR (4.build/csr_build/generated-files)
# and the same firmware.hex (4.build/sw_build) for the RAM contents.
#
# The GateMate primitives (CC_SERDES, CC_PLL, CC_USR_RSTN, CC_BUFG) are black
# boxes turned into ports (expose -evert): their inputs are compared, their
# outputs are shared free inputs. equiv_induct starts from any state, so logic
# that is only constant after reset shows up as unproven and needs a look by
# hand.
#
# Needs Yosys with the read_slang plugin: YOSYS_ARGS defaults to "-m slang";
# point it at the plugin, e.g. YOSYS_ARGS="-m ~/opt/src/sv-elab-main/build/slang.so".
# YOSYS and YOSYS_CONFIG override the commands.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/sources.sh"
GOLD=$(cd "$1" && pwd); GATE=$(cd "$2" && pwd); MAP=${3:-}
CSR=$HERE/../csr_build/generated-files
TOP=top
YOSYS=${YOSYS:-yosys}
YOSYS_CONFIG=${YOSYS_CONFIG:-yosys-config}
YOSYS_ARGS=${YOSYS_ARGS:--m slang}
W=$(mktemp -d); cd "$W"
cp "$HERE/../sw_build/firmware.hex" .

# GateMate primitives: the Yosys blackboxes, plus CC_BUFG, which Yosys has
# only as a simulation model
{ cat "$("$YOSYS_CONFIG" --datdir)/gatemate/cells_bb.v"
  printf '(* blackbox *)\nmodule CC_BUFG (input I, output O);\nendmodule\n'
} > bb.v

files() {  # $1 = 2.rtl dir
  echo bb.v $(design_rtl "$1" "$CSR" | tr '\n' ' ')
}
BB="t:CC_SERDES t:CC_PLL t:CC_USR_RSTN t:CC_BUFG"
PREP="hierarchy -top $TOP; proc; flatten; memory; async2sync"

REN=""
if [ -n "$MAP" ]; then   # rename gold objects to their gate names (skip names the gold already has)
  cat > names.ys <<EOF
read_slang -D SYNTHESIS --top $TOP $(files $GOLD)
$PREP
tee -q -o names.txt select -list $TOP/w:* $TOP/c:*
EOF
  "$YOSYS" $YOSYS_ARGS -q names.ys >/dev/null
  sed "s|^$TOP/||" names.txt | sed -n "h; $MAP; G; s/\n/ /; p" |
    awk 'NR==FNR {have[$1]=1; next} $1!=$2 && substr($2,1,1)!="$" && !($1 in have) {print "rename \\" $2 " \\" $1}' \
        <(sed "s|^$TOP/||" names.txt) - > ren.ys
  echo "renamed: $(wc -l < ren.ys)"
  REN="cd $TOP; script ren.ys; cd .."
fi

EXTRA=""
[ -n "${LEQ_EXTRA:-}" ] && EXTRA="script $(cd "$(dirname "$LEQ_EXTRA")" && pwd)/$(basename "$LEQ_EXTRA")"

cat > eq.ys <<EOF
read_slang -D SYNTHESIS --top $TOP $(files $GOLD)
$PREP
$REN
expose -evert $BB; opt_clean; rename $TOP gold; design -stash gold
read_slang -D SYNTHESIS --top $TOP $(files $GATE)
$PREP
expose -evert $BB; opt_clean; rename $TOP gate; design -stash gate
design -copy-from gold -as gold gold
design -copy-from gate -as gate gate
equiv_make gold gate eq
hierarchy -top eq
$EXTRA
equiv_simple -seq 3
equiv_induct -seq 3
equiv_status
EOF
"$YOSYS" $YOSYS_ARGS -q -l eq.log eq.ys >/dev/null || true
grep -E "Found [0-9]+ .equiv|Of those cells|^ERROR" eq.log | tail -3
grep "Unproven" eq.log | sed -E 's/.*: .([^ ]*)_gold.*/\1/; s/\[[0-9]+\]//g' | sort | uniq -c
echo "log: $W/eq.log"

# -----------------------------------------------------------------------------
# Project:     openCologne-PCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        Oct 18, 2026
# -----------------------------------------------------------------------------
