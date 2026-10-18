#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Fetch the eduBOS5 RISC-V core from openPCIE, where it is maintained, instead
# of keeping a copy here. Sparse-clones openPCIE at OPENPCIE_REF (only
# 2.rtl/0.common.opensource/src/CPU.eduBOS5) into DEPS_WORK and prints the
# directory, for use as EDUBOS5_DIR:
#
#   EDUBOS5_DIR=$(bash 4.build/fetch-edubos5.sh)
#
# OPENPCIE_REF pins the openPCIE commit; raise it to take a newer eduBOS5.
# DEPS_WORK defaults to ~/.cache/opencologne-pcie-deps. Needs git.
set -euo pipefail
OPENPCIE_REF=${OPENPCIE_REF:-8bb9566d91a878b615e77158e9db953eacd1b80f}
W=${DEPS_WORK:-$HOME/.cache/opencologne-pcie-deps}
R=$W/openPCIE
SUB=2.rtl/0.common.opensource/src/CPU.eduBOS5

if [ ! -d "$R/.git" ]; then
    mkdir -p "$W"
    git clone -q --filter=blob:none --no-checkout https://github.com/chili-chips-ba/openPCIE.git "$R"
    git -C "$R" sparse-checkout set "$SUB" >&2
fi
if [ ! -d "$R/$SUB" ] || [ "$(git -C "$R" rev-parse HEAD)" != "$OPENPCIE_REF" ]; then
    git -C "$R" fetch -q origin "$OPENPCIE_REF" 2>/dev/null || git -C "$R" fetch -q origin
    git -C "$R" checkout -q "$OPENPCIE_REF"
fi
echo "$R/$SUB"

# -----------------------------------------------------------------------------
# Project:     openCologne-PCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        April 2025
# -----------------------------------------------------------------------------
