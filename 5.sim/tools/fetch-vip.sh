#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Build the co-simulation VIP from upstream sources instead of keeping copies
# here: VProc, the pcieVHost PCIE model and mem_model (github.com/wyvernSemi),
# at the versions openPCIE uses. Builds the two DPI-C libraries, collects the
# headers and HDL, applies the local changes this test bench needs, and prints
# the directory, for the 5.sim make file:
#
#   VIP_DIR=$(bash 5.sim/tools/fetch-vip.sh)
#
#   $VIP_DIR/lib        libcosimlnx.a (VProc), libpcielnx.a (pcieVHost)
#   $VIP_DIR/include    their C/C++ headers, ltssm.h
#   $VIP_DIR/ltssm      ltssm.c, the link-training helper for the user code
#   $VIP_DIR/hdl        f_VProc.v, f_mem_model.v, pcieVHost*.v, clkmux.v,
#                       Serialiser.v; headers/ for the include path
#
# Local changes (the rest is upstream as is):
#   - pcieVHost.v: VProc's byte-enable port left open (we build VProc with
#     VPROC_BYTE_ENABLE), as on openPCIE
#   - test_defs.v: `fatal calls tb.Fatal, our test bench top
# openPCIE's LTSSM patch is NOT applied: it makes the model a spec-correct
# upstream port (EP) against a real downstream port, and deadlocks when the
# model plays the RC against another copy of itself. See 5.sim/README.md.
#
# Pins: VPROC_REF, PCIEVHOST_REF, MEM_MODEL_REF. DEPS_WORK defaults to
# ~/.cache/opencologne-pcie-deps. Needs git, gcc, ar, sed.
set -euo pipefail
VPROC_REF=${VPROC_REF:-VERSION_1_13_4}
PCIEVHOST_REF=${PCIEVHOST_REF:-VESRSION_1_9_3}   # sic: upstream's tag name
MEM_MODEL_REF=${MEM_MODEL_REF:-c7b9c62}
W=${DEPS_WORK:-$HOME/.cache/opencologne-pcie-deps}
mkdir -p "$W"

# clone or update a repo, check out $2
fetch() {
    local repo=$1 ref=$2
    [ -d "$W/$repo/.git" ] || git clone -q "https://github.com/wyvernSemi/$repo.git" "$W/$repo"
    git -C "$W/$repo" cat-file -e "$ref^{commit}" 2>/dev/null || git -C "$W/$repo" fetch -q --tags origin
    git -C "$W/$repo" checkout -q "$ref"
}

OUT=$W/vip.$VPROC_REF.$PCIEVHOST_REF.$MEM_MODEL_REF
if [ -f "$OUT/.built" ]; then
    echo "$OUT"
    exit 0
fi

fetch vproc "$VPROC_REF"
fetch pcievhost "$PCIEVHOST_REF"
fetch mem_model "$MEM_MODEL_REF"

V=$W/vproc
P=$W/pcievhost
rm -rf "$OUT"
mkdir -p "$OUT"/{lib,include,ltssm,hdl/headers,obj}
lf() { tr -d '\r' < "$1"; }  # upstream mixes CRLF and LF; we keep LF

# ---- VProc: libcosimlnx.a (DPI-C), headers, HDL --------------------------------
for f in VSched VUser; do
    gcc -c -fPIC -m64 -I"$V/code" -DVPROC_SV "$V/code/$f.c" -o "$OUT/obj/$f.o"
done
ar cr "$OUT/lib/libcosimlnx.a" "$OUT"/obj/VSched.o "$OUT"/obj/VUser.o
for f in VProc.h VProcClass.h VProcIrqClass.h VSched_pli.h VUser.h; do
    lf "$V/code/$f" > "$OUT/include/$f"
done
for f in f_VProc.v extradefs.v vprocdefs.vh vprocdpi.vh; do lf "$V/$f" > "$OUT/hdl/$f"; done

# ---- mem_model: HDL only (its C model is part of pcieVHost) ------------------
lf "$W/mem_model/mem_model.v" > "$OUT/hdl/f_mem_model.v"
lf "$W/mem_model/mem_model_dpi.vh" > "$OUT/hdl/mem_model_dpi.vh"

# ---- pcieVHost: libpcielnx.a, headers, HDL, LTSSM helper ----------------------
for f in codec mem pcie pcie_utils pcicrc32 displink; do
    gcc -c -fPIC -m64 -I"$V/code" -DVPROC_SV -DLTSSM_ABBREVIATED "$P/src/$f.c" -o "$OUT/obj/$f.o"
done
ar cr "$OUT/lib/libpcielnx.a" "$OUT"/obj/{codec,mem,pcie,pcie_utils,pcicrc32,displink}.o
for f in codec.h mem.h pci_express.h pcie.h pcieModelClass.h pcie_utils.h pcie_vhost_map.h ltssm.h; do
    lf "$P/src/$f" > "$OUT/include/$f"
done
lf "$P/src/ltssm.c" > "$OUT/ltssm/ltssm.c"

H=$OUT/hdl/headers
for f in allheaders.v pciedispheader.v pciexpress_header.v timescale.v; do
    lf "$P/verilog/headers/$f" > "$H/$f"
done
# register map, generated from the C header as upstream's make files do
lf "$P/src/pcie_vhost_map.h" |
    sed "s/0x/32'h/;s/#/\`/;s/DEFINES/AUTO GENERATED. DO NOT EDIT!/;" > "$H/pcie_vhost_map.v"
# local change: our test bench top is tb
lf "$P/verilog/test/test_defs.v" | sed 's/`define fatal test\.Fatal;/`define fatal tb.Fatal;/' > "$H/test_defs.v"
grep -q 'define fatal tb\.Fatal' "$H/test_defs.v"

for f in pcieVHost.v pcieVHostPipex1.v; do lf "$P/verilog/pcieVHost/$f" > "$OUT/hdl/$f"; done
for f in clkmux.v Serialiser.v; do lf "$P/verilog/lib/$f" > "$OUT/hdl/$f"; done
# local change: VProc byte-enable/burst ports, left open
F=$OUT/hdl/pcieVHost.v
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

# ---- Icarus: the same C models, over VPI instead of DPI-C ------------------------
#   libcosimica.a  VProc, its VPI table supplied by pcieVHost's veriuser.c
#   libpcieica.a   pcieVHost with veriuser.c, mem_model.c and ltssm.c
ICA_INC=$(dirname "$(command -v iverilog 2>/dev/null || echo /usr/bin/iverilog)")/../include/iverilog
if [ -f "$ICA_INC/vpi_user.h" ]; then
    ICA="-DICARUS -DVPROC_PLI_VPI -DEXTERN_VPI_TABLE -D_REENTRANT -I$ICA_INC"
    for f in VSched VUser; do
        gcc -c -fPIC -m64 -I"$V/code" $ICA -Wno-int-to-pointer-cast "$V/code/$f.c" -o "$OUT/obj/ica_$f.o"
    done
    ar cr "$OUT/lib/libcosimica.a" "$OUT"/obj/ica_VSched.o "$OUT"/obj/ica_VUser.o
    for f in codec mem mem_model pcie pcie_utils pcicrc32 ltssm displink veriuser; do
        gcc -c -fPIC -m64 -Wno-incompatible-pointer-types -Wno-format -I"$V/code" -I"$ICA_INC" \
            -DICARUS -DLTSSM_ABBREVIATED "$P/src/$f.c" -o "$OUT/obj/ica_$f.o"
    done
    ar cr "$OUT/lib/libpcieica.a" "$OUT"/obj/ica_{codec,mem,mem_model,pcie,pcie_utils,pcicrc32,ltssm,displink,veriuser}.o
else
    echo "note: no Icarus VPI headers at $ICA_INC, Icarus libraries not built" >&2
fi

rm -rf "$OUT/obj"
echo "VProc $VPROC_REF, pcieVHost $PCIEVHOST_REF, mem_model $MEM_MODEL_REF" > "$OUT/VERSIONS"
touch "$OUT/.built"
echo "$OUT"

# -----------------------------------------------------------------------------
# Project:     openCologne-PCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        April 2025
# -----------------------------------------------------------------------------
