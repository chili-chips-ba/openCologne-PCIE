#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Build the co-simulation VIP from the upstream copies in 5.sim/vip: VProc,
# the pcieVHost PCIE model and mem_model (github.com/wyvernSemi, versions in
# 5.sim/vip/README.md). Builds the DPI-C (Verilator) and VPI (Icarus)
# libraries, collects the headers and HDL, applies the local changes this
# test bench needs, and prints the directory, for the 5.sim make file:
#
#   VIP_DIR=$(bash 5.sim/tools/build-vip.sh)
#
#   $VIP_DIR/lib        libcosimlnx.a (VProc), libpcielnx.a (pcieVHost)
#   $VIP_DIR/include    their C/C++ headers, ltssm.h
#   $VIP_DIR/ltssm      ltssm.c, the link-training helper for the user code
#   $VIP_DIR/hdl        f_VProc.v, f_mem_model.v, pcieVHost*.v, clkmux.v,
#                       Serialiser.v; headers/ for the include path
#
# Our changes to upstream are already in 5.sim/vip (tools/vip-import.sh).
#
# VIP_BUILD (default ~/.cache/opencologne-pcie/vip) is the output; it is
# rebuilt when a file in 5.sim/vip or this script is newer. Needs gcc, ar.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$(cd "$HERE/../vip" && pwd)
OUT=${VIP_BUILD:-$HOME/.cache/opencologne-pcie/vip}

if [ -f "$OUT/.built" ] && [ -z "$(find "$SRC" "$0" -newer "$OUT/.built" -print -quit)" ]; then
    echo "$OUT"
    exit 0
fi

V=$SRC/vproc
P=$SRC/pcievhost
rm -rf "$OUT"
mkdir -p "$OUT"/{lib,include,ltssm,hdl/headers,obj}
lf() { cat "$1"; }  # the copies are LF already
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
lf "$SRC/mem_model/mem_model.v" > "$OUT/hdl/f_mem_model.v"
lf "$SRC/mem_model/mem_model_dpi.vh" > "$OUT/hdl/mem_model_dpi.vh"

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
lf "$P/verilog/headers/pcie_vhost_map.v" > "$H/pcie_vhost_map.v"
lf "$P/verilog/test/test_defs.v" > "$H/test_defs.v"

for f in pcieVHost.v pcieVHostPipex1.v; do lf "$P/verilog/pcieVHost/$f" > "$OUT/hdl/$f"; done
for f in clkmux.v Serialiser.v; do lf "$P/verilog/lib/$f" > "$OUT/hdl/$f"; done

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
cp "$SRC/README.md" "$OUT/VERSIONS.md"
touch "$OUT/.built"
echo "$OUT"

# -----------------------------------------------------------------------------
# Project:     openCologne-PCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        April 2025
# -----------------------------------------------------------------------------
