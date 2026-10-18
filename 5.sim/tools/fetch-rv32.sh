#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Fetch the rv32 RISC-V ISS sources instead of keeping a copy here: upstream
# wyvernSemi/rv32 at RV32_REF, with openPCIE's rv32-openpcie.patch on top (the
# timer-compare cycle fix and store timing for sw/sh). Prints the source
# directory, for the 5.sim make file (CPU=iss):
#
#   RV32SRC=$(bash 5.sim/tools/fetch-rv32.sh)
#
# RV32_REF and OPENPCIE_REF pin the two inputs; the patch comes from the same
# openPCIE checkout 4.build/fetch-edubos5.sh uses. DEPS_WORK defaults to
# ~/.cache/opencologne-pcie-deps. Needs git and patch.
set -euo pipefail
RV32_REF=${RV32_REF:-774d84fa}
OPENPCIE_REF=${OPENPCIE_REF:-8bb9566d91a878b615e77158e9db953eacd1b80f}
W=${DEPS_WORK:-$HOME/.cache/opencologne-pcie-deps}
HERE=$(cd "$(dirname "$0")" && pwd)

# the patch: from openPCIE, next to eduBOS5
PATCH_SUB=5.sim/models/rv32/rv32-openpcie.patch
OPENPCIE=$W/openPCIE
OPENPCIE_REF=$OPENPCIE_REF bash "$HERE/../../4.build/fetch-edubos5.sh" >/dev/null
if [ ! -f "$OPENPCIE/$PATCH_SUB" ]; then
    git -C "$OPENPCIE" sparse-checkout add "$(dirname "$PATCH_SUB")" >&2  # cone mode: folders only
fi

# the ISS sources: upstream, at RV32_REF
R=$W/rv32
if [ ! -d "$R/.git" ]; then
    git clone -q https://github.com/wyvernSemi/rv32.git "$R"
fi
git -C "$R" cat-file -e "$RV32_REF^{commit}" 2>/dev/null || git -C "$R" fetch -q origin
git -C "$R" checkout -q "$RV32_REF"

# a patched copy per (rv32, openPCIE) pair, so a pin change rebuilds cleanly
OUT=$W/rv32-src.$RV32_REF.$(echo "$OPENPCIE_REF" | cut -c1-12)
if [ ! -f "$OUT/.patched" ]; then
    rm -rf "$OUT"
    mkdir -p "$OUT"
    for f in "$R"/iss/src/*; do
        tr -d '\r' < "$f" > "$OUT/$(basename "$f")"  # upstream mixes CRLF and LF
    done
    patch -s --no-backup-if-mismatch -p0 -d "$OUT" < "$OPENPCIE/$PATCH_SUB"
    touch "$OUT/.patched"
fi
echo "$OUT"

# -----------------------------------------------------------------------------
# Project:     openCologne-PCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        April 2025
# -----------------------------------------------------------------------------
