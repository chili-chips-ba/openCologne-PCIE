#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Lint of the RTL of top (sources.sh): syntax and limited semantic checks with
# a set of opensource tools, run in this order:
#
#   tags       every /*LINT:OK*/ sits on an output port (no tool needed)
#   verilator  Verilator --lint-only -Wall: unused/undriven signals, widths,
#              implicit nets, multiple drivers, blocking vs non-blocking, case
#   yosys      Yosys check on the read_slang netlist: combinational loops,
#              conflicting drivers, used-but-undriven wires, latches
#   slang      read_slang -Wextra: strict IEEE parse, second opinion
#   verible    Verible style rules (run-lint.verible) on our own RTL: our case
#              rule -- signals and ports lower case, constants UPPER case --
#              and Verible's defaults
#
# There is no opensource CDC checker mature enough to replace openPCIE's
# Vivado cdc phase.
#
# usage:  bash run-lint.sh [phase ...]    default: all phases
#         VIEW=sim bash run-lint.sh        lint the simulation view of phy_top
#                                          (default chip: SYNTHESIS defined)
#
# A phase whose tool is not found is skipped. The tool commands can be
# overridden: VERILATOR, YOSYS (+ YOSYS_ARGS), YOSYS_CONFIG, PYTHON, VERIBLE.
# read_slang is a Yosys plugin here: YOSYS_ARGS defaults to "-m slang"; point
# it at the plugin, e.g. YOSYS_ARGS="-m ~/opt/src/sv-elab-main/build/slang.so".
# The GateMate primitives (CC_SERDES, CC_PLL, ...) come from the Yosys
# library (yosys-config --datdir), as blackboxes.
#
# The Cologne Chip submodule code (2.pipe/pipe_src) keeps its own style and
# is not changed here: its style findings are waived (run-lint-waivers.txt)
# and slang's are not shown, while the ones that can be bugs (latches,
# undriven wires) stay; they belong upstream. Its waivers are temporary: closer to the
# first release, that code is brought up to our standard and through this
# flow. The SerDes BFM is a behavioural model, not RTL, and is left out the
# same way.
#
# Sources are copied into a work directory (LINT_WORK, default mktemp -d) and
# every tool gets relative paths. Logs stay there: <phase>.log is the tool
# output, <phase>.findings the findings left after the waivers.
#
# Accepted findings are waived in two ways, each one reviewed:
#   - inline, on an unused output of an instance:  .PIN (/*LINT:OK*/)
#     waives the findings about that pin, from any phase; the tags phase flags
#     a /*LINT:OK*/ on an input, so it cannot hide a floating input
#   - run-lint-waivers.txt (or LINT_WAIVERS=<file>), for findings without a
#     source line of ours (generated code, ...)
# Exit status is non-zero when any phase has findings that are not waived.

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$HERE/../..
. "$HERE/sources.sh"
TOP=top
VERILATOR=${VERILATOR:-verilator}
YOSYS=${YOSYS:-yosys}
YOSYS_CONFIG=${YOSYS_CONFIG:-yosys-config}
PYTHON=${PYTHON:-python3}
YOSYS_ARGS=${YOSYS_ARGS:--m slang}
VERIBLE=${VERIBLE:-verible-verilog-lint}
VIEW=${VIEW:-chip}
case $VIEW in
  chip) VL_DEFS="-DSYNTHESIS"; SL_DEFS="-D SYNTHESIS"; SIM="" ;;
  sim)  VL_DEFS=""; SL_DEFS=""; SIM=sim ;;
  *) echo "VIEW must be chip or sim, got \"$VIEW\""; exit 1 ;;
esac

WAIVERS=${LINT_WAIVERS:-$HERE/run-lint-waivers.txt}
PHASES=${*:-tags verilator yosys slang verible}
W=${LINT_WORK:-$(mktemp -d)}
mkdir -p "$W"

# ---- work copy ----------------------------------------------------------------
(cd "$REPO" && cp -r --parents 2.rtl/*.sv 2.rtl/1.phy/phy_top.sv 2.rtl/1.phy/2.serdes-model \
   2.rtl/2.pipe/pipe_if.sv 2.rtl/2.pipe/pipe_src/src 2.rtl/4.dll/dll_if.sv 2.rtl/5.tlp 2.rtl/6.soc \
   "$W/")
mkdir -p "$W/csr"
cp "$REPO"/4.build/csr_build/generated-files/{csr_pkg,csr}.sv "$W/csr/"
cp "$REPO/4.build/sw_build/firmware.hex" "$W/"
cd "$W"
SV=$(design_rtl 2.rtl csr $SIM | tr '\n' ' ')
OWN=$(own_rtl 2.rtl)

have() { command -v "$1" >/dev/null 2>&1; }
declare -A RESULT
skip() { RESULT[$1]="skipped ($2)"; echo "-- $1: skipped, $2"; }

# waiver regexes of one phase: the lines "<phase> <regex>" of the waivers file
waivers() {
  [ -f "$WAIVERS" ] || return 0
  awk -v ph="$1" '{ sub(/\r$/, "") } $1 == ph { sub(/^[ \t]*[^ \t]+[ \t]+/, ""); print }' "$WAIVERS"
}

# inline waivers .PIN (/*LINT:OK*/), as file:line:PIN (the first line keeps
# awk's NR==FNR test working when there is none)
{ echo "#"
  grep -n -o -E '\.[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\([[:space:]]*/\*LINT:OK\*/[[:space:]]*\)' $SV |
    sed -E 's/^([^:]*:[0-9]+):\.([A-Za-z0-9_]*).*/\1:\2/'
} > lint_ok.txt

found() {  # $1 phase; one finding per line on stdin (not a pipe: RESULT must stay in this shell)
  cat > $1.all
  # drop findings about a pin waived inline: file:line plus the 'PIN' the tools
  # quote (Windows tools print \ in paths)
  awk 'NR == FNR { ok[$0] = 1; next }
       { l = $0; gsub(/\\/, "/", l)
         if (match(l, /[A-Za-z0-9_.\/-]+\.s?v:[0-9]+/)) {
           k = substr(l, RSTART, RLENGTH)
           if (match(l, /\047[A-Za-z_][A-Za-z0-9_]*\047/) && (k ":" substr(l, RSTART + 1, RLENGTH - 2)) in ok) next
         }
         print }' lint_ok.txt $1.all > $1.inline
  grep -E -v -f <(waivers $1) $1.inline > $1.findings
  local n=$(wc -l < $1.findings) t=$(wc -l < $1.all) i=$(wc -l < $1.inline)
  RESULT[$1]="$n finding(s), $((t - n)) waived ($((t - i)) inline), see $W/$1.findings"
  echo "-- $1: $n finding(s), $((t - n)) waived ($((t - i)) inline)"
}

# /*LINT:OK*/ on anything but an output port; the port directions come from the
# module headers of the design and the primitive stubs, plus the SerDes model:
# phy_top instantiates it behind `ifndef SYNTHESIS
run_tags() {
  bb || { skip tags "no GateMate stubs (yosys-config)"; return; }
  "$PYTHON" - 2.rtl/1.phy/2.serdes-model/ccfpga_serdes.sv -- bb.v $SV > tags.log <<'EOF'
import re, sys
ports_only = sys.argv[1:sys.argv.index('--')]
files = sys.argv[sys.argv.index('--') + 1:]
text = {f: open(f).read() for f in ports_only + files}
types = {'logic', 'wire', 'reg', 'signed', 'unsigned', 'var', 'bit', 'integer', 'tri'}
dirs = {}
for t in text.values():
    t = re.sub(r'//[^\n]*|/\*.*?\*/', '', t, flags=re.S)
    for m in re.finditer(r'\bmodule\s+(\w+)(.*?)\bendmodule', t, flags=re.S):
        d = dirs.setdefault(m.group(1), {})
        for p in re.finditer(r'\b(input|output|inout)\b(.*?)(?=\b(?:input|output|inout)\b|[;()]|$)',
                             m.group(2), flags=re.S):
            for part in re.sub(r'\[[^\]]*\]', ' ', p.group(2)).split(','):
                w = [x for x in re.findall(r'[A-Za-z_]\w*', part) if x not in types]
                if w:
                    d.setdefault(w[-1], p.group(1))
tag  = re.compile(r'\.(\w+)\s*\(\s*/\*LINT:OK\*/\s*\)')
inst = re.compile(r'\s*([A-Za-z_]\w*)\s*(#|\s\w+\s*\()')
kw   = {'if', 'else', 'for', 'begin', 'end', 'case', 'assign', 'module', 'always', 'always_ff',
        'always_comb', 'initial', 'function', 'task', 'return', 'generate'}
for f in files:
    lines = text[f].split('\n')
    for n, line in enumerate(lines, 1):
        for m in tag.finditer(line):
            typ = next((t.group(1) for i in range(n - 1, -1, -1)
                        for t in [inst.match(lines[i])] if t and t.group(1) not in kw), None)
            d = dirs.get(typ, {}).get(m.group(1))
            if d != 'output':
                print(f'{f}:{n}: LINT:OK on {d or "unknown"} port {typ}.{m.group(1)}')
EOF
  found tags < tags.log
}

# GateMate primitive stubs, for the tags, Verilator, Yosys and slang phases:
# the Yosys blackboxes, plus CC_BUFG, which Yosys has only as a simulation
# model
bb() {
  [ -s bb.v ] && return 0
  have "$YOSYS_CONFIG" || return 1
  { cat "$("$YOSYS_CONFIG" --datdir)/gatemate/cells_bb.v"
    printf '(* blackbox *)\nmodule CC_BUFG (input I, output O);\nendmodule\n'
  } > bb.v
}

run_verilator() {
  have "$VERILATOR" || { skip verilator "$VERILATOR not found"; return; }
  bb || { skip verilator "no GateMate stubs (yosys-config)"; return; }
  cat > waive.vlt <<'VLT'
`verilator_config
lint_off -file "*bb.v"
lint_off -file "*/pipe_src/*"
lint_off -file "*/2.serdes-model/*"
VLT
  # --timescale: the Cologne Chip code sets one, our RTL does not (no delays)
  "$VERILATOR" --lint-only -Wall -Wno-fatal --timing --timescale 1ns/1ps --top-module $TOP $VL_DEFS \
    waive.vlt bb.v $SV > verilator.log 2>&1
  found verilator < <(grep -E '^%(Warning|Error)' verilator.log)
}

run_yosys() {
  have "$YOSYS" || { skip yosys "$YOSYS not found"; return; }
  bb || { skip yosys "no GateMate stubs"; return; }
  "$YOSYS" $YOSYS_ARGS -q -l yosys.log -p "read_slang $SL_DEFS --top $TOP bb.v $SV; \
      hierarchy -check -top $TOP; proc; check -nolatches -initdrv" >/dev/null 2>&1
  if grep -q '^ERROR' yosys.log; then
    RESULT[yosys]="error, see $W/yosys.log"; echo "-- yosys: error"; return
  fi
  # read_slang's own warnings are the slang phase's business; take check's
  found yosys < <(awk '/Executing CHECK pass/ { c = 1 } c && /^Warning:/' yosys.log)
}

run_slang() {
  have "$YOSYS" || { skip slang "$YOSYS not found"; return; }
  bb || { skip slang "no GateMate stubs"; return; }
  "$YOSYS" $YOSYS_ARGS -q -l slang.log -p "read_slang $SL_DEFS --top $TOP -Wextra bb.v $SV" \
      >/dev/null 2>&1
  # the yosys-slang plugin prints "file:line: Warning:", the built-in read_slang
  # "file:line:col: warning:"; bring both to the second form so the waivers
  # match either. Paths come relative to the work directory, after any ../
  found slang < <(sed -E 's#^(\.\./)+[^ ]*/(2\.rtl|csr)/#\2/#;
                          s/^([^ :]+:[0-9]+): Warning:/\1:0: warning:/;
                          s/^([^ :]+:[0-9]+): Error:/\1:0: error:/' slang.log |
                  grep -E 'warning:|error:' | grep -v -E '^(bb\.v|2\.rtl/2\.pipe/pipe_src/|2\.rtl/1\.phy/2\.serdes-model/)')
}

run_verible() {
  have "$VERIBLE" || { skip verible "$VERIBLE not found"; return; }
  cp "$HERE/run-lint.verible" .
  "$VERIBLE" --rules_config=run-lint.verible $OWN > verible.log 2>&1
  found verible < <(grep -E ':[0-9]+:[0-9]+' verible.log)
}

for ph in $PHASES; do
  case $ph in
    tags|verilator|yosys|slang|verible) echo "== $ph"; run_$ph ;;
    *) echo "unknown phase: $ph (tags verilator yosys slang verible)"; exit 2 ;;
  esac
done

echo; echo "== summary  ($VIEW view, $W)"
FAIL=0
for ph in $PHASES; do
  printf '  %-10s %s\n' "$ph" "${RESULT[$ph]}"
  case ${RESULT[$ph]} in skipped*|"0 finding"*) ;; *) FAIL=1 ;; esac
done
exit $FAIL

# -----------------------------------------------------------------------------
# Project:     openCologne-PCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        Oct 18, 2026
# -----------------------------------------------------------------------------
