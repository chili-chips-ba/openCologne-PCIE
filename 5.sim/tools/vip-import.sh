#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Import the co-simulation VIP from upstream (github.com/wyvernSemi) into
# 5.sim/vip, with our changes applied. Run it only to upgrade a model: set
# the pins below, run, then run both simulators and update vip/README.md.
#
#   bash 5.sim/tools/vip-import.sh
#
# Copies only the files the build uses, with LF line endings, then applies:
#   - pcieVHost.v: VProc's BE and Burst ports, left open (we build VProc with
#     VPROC_BYTE_ENABLE)
#   - test_defs.v: `fatal calls tb.Fatal, our test bench top
#   - pcieVHost: transaction taps, TLP and DLLP ports
#     (models/pcievhost/pcievhost-taps.patch)
#   - pcie_vhost_map.v: generated from pcie_vhost_map.h, as upstream's make
#     files do
#   - rv32: openPCIE's rv32-openpcie.patch (models/rv32)
# openPCIE's LTSSM patch is NOT applied (see 5.sim/README.md).
#
# DEPS_WORK (default ~/.cache/opencologne-pcie-deps) holds the upstream
# clones. Needs git, patch, sed.
set -euo pipefail
VPROC_REF=${VPROC_REF:-VERSION_1_13_4}
PCIEVHOST_REF=${PCIEVHOST_REF:-VESRSION_1_9_3}   # sic: upstream's tag name
MEM_MODEL_REF=${MEM_MODEL_REF:-c7b9c62}
RV32_REF=${RV32_REF:-774d84fa}
HERE=$(cd "$(dirname "$0")" && pwd)
D=$(cd "$HERE/.." && pwd)/vip
U=${DEPS_WORK:-$HOME/.cache/opencologne-pcie-deps}
mkdir -p "$U"

fetch() {  # <repo> <ref>: clone or update, check out
  [ -d "$U/$1/.git" ] || git clone -q "https://github.com/wyvernSemi/$1.git" "$U/$1"
  git -C "$U/$1" cat-file -e "$2^{commit}" 2>/dev/null || git -C "$U/$1" fetch -q --tags origin
  git -C "$U/$1" checkout -q "$2"
}
cp_lf() {  # <src> <dst>: upstream mixes CRLF and LF; we keep LF
  mkdir -p "$(dirname "$2")"
  tr -d '\r' < "$1" > "$2"
}

fetch vproc "$VPROC_REF"
fetch pcievhost "$PCIEVHOST_REF"
fetch mem_model "$MEM_MODEL_REF"
fetch rv32 "$RV32_REF"
rm -rf "$D"/{vproc,pcievhost,mem_model,rv32}

# ---- VProc --------------------------------------------------------------------
for f in VSched.c VUser.c VProc.h VProcClass.h VProcIrqClass.h VSched_pli.h VUser.h; do
  cp_lf "$U/vproc/code/$f" "$D/vproc/code/$f"
done
for f in f_VProc.v extradefs.v vprocdefs.vh vprocdpi.vh LICENSE README.md; do
  cp_lf "$U/vproc/$f" "$D/vproc/$f"
done

# ---- pcieVHost ----------------------------------------------------------------
P=$D/pcievhost
for f in "$U"/pcievhost/src/*.c "$U"/pcievhost/src/*.h; do cp_lf "$f" "$P/src/$(basename "$f")"; done
for f in allheaders.v pciedispheader.v pciexpress_header.v timescale.v; do
  cp_lf "$U/pcievhost/verilog/headers/$f" "$P/verilog/headers/$f"
done
cp_lf "$U/pcievhost/verilog/test/test_defs.v" "$P/verilog/test/test_defs.v"
for f in pcieVHost.v pcieVHostPipex1.v; do cp_lf "$U/pcievhost/verilog/pcieVHost/$f" "$P/verilog/pcieVHost/$f"; done
for f in clkmux.v Serialiser.v; do cp_lf "$U/pcievhost/verilog/lib/$f" "$P/verilog/lib/$f"; done
for f in LICENSE README.md; do cp_lf "$U/pcievhost/$f" "$P/$f"; done

# change: `fatal calls tb.Fatal
sed -i 's/`define fatal test\.Fatal;/`define fatal tb.Fatal;/' "$P/verilog/test/test_defs.v"
grep -q 'define fatal tb\.Fatal' "$P/verilog/test/test_defs.v"

# change: VProc byte-enable and burst ports, left open
F=$P/verilog/pcieVHost/pcieVHost.v
grep -qE '^\s*\.RD\s*\(RD\),$' "$F"
sed -i -E '/^\s*\.RD\s*\(RD\),$/a\
`ifdef VPROC_BYTE_ENABLE\
           .BE             (),\
`endif\
`ifdef VPROC_BURST_IF\
           .Burst          (),\
           .BurstFirst     (),\
           .BurstLast      (),\
`endif' "$F"

# change: transaction taps, TLP and DLLP ports (models/pcievhost/README.md)
patch -s --no-backup-if-mismatch -p1 -d "$P" < "$HERE/../models/pcievhost/pcievhost-taps.patch"

# change: the register map, generated from the C header
sed "s/0x/32'h/;s/#/\`/;s/DEFINES/AUTO GENERATED. DO NOT EDIT!/;" "$P/src/pcie_vhost_map.h" \
  > "$P/verilog/headers/pcie_vhost_map.v"

# ---- mem_model (its C model is part of pcieVHost) -------------------------------
for f in mem_model.v mem_model_dpi.vh LICENSE README.md; do cp_lf "$U/mem_model/$f" "$D/mem_model/$f"; done

# ---- rv32 ISS -------------------------------------------------------------------
for f in "$U"/rv32/iss/src/*; do cp_lf "$f" "$D/rv32/iss/src/$(basename "$f")"; done
for f in LICENSE README.md; do cp_lf "$U/rv32/$f" "$D/rv32/$f"; done
# change: openPCIE's two ISS fixes
patch -s --no-backup-if-mismatch -p0 -d "$D/rv32/iss/src" < "$HERE/../models/rv32/rv32-openpcie.patch"

echo "imported: VProc $VPROC_REF, pcieVHost $PCIEVHOST_REF, mem_model $MEM_MODEL_REF, rv32 $RV32_REF"
echo "next: update vip/README.md, then run both simulators"

# -----------------------------------------------------------------------------
# Project:     openCologne-PCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        Oct 18, 2026
# -----------------------------------------------------------------------------
