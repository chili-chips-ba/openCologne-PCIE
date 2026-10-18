#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# DLL over a real PHY (tb_dll_phy.sv), Icarus Verilog: an Endpoint and a Root
# Complex, each DLL + MAC/LTSSM + PIPE + open SerDes model (pcie_stack.sv),
# connected by a bit-level serial link in both directions.
#
# usage:  bash run-dll-phy.sh [--dump] [--scramble]
#
# Build products and the waveform go to $SERDES_BUILD_DIR/dll (default
# ~/.cache/opencologne-pcie).
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${HERE}/../../.." && pwd)"
PHY_DIR="${REPO_ROOT}/2.rtl/1.phy"
MODEL_DIR="${PHY_DIR}/2.serdes-model"
PIPE_DIR="${REPO_ROOT}/2.rtl/2.pipe/pipe_src/src/pipe_src"
MAC_DIR="${REPO_ROOT}/2.rtl/3.mac/mac_src/src/mac_src"
DLL_DIR="${REPO_ROOT}/2.rtl/4.dll/dll_src"

BUILD="${SERDES_BUILD_DIR:-$HOME/.cache/opencologne-pcie}/dll"

IVL=${IVL:-iverilog}
VVP=${VVP:-vvp}

DUMP=""
DEFS=""
for arg in "$@"; do
  case "$arg" in
    --dump)     DUMP="-DDUMP" ;;
    --scramble) DEFS="${DEFS} -DSCRAMBLE" ;;
    -h|--help)  echo "usage: $0 [--dump] [--scramble]"; exit 0 ;;
    *) echo "unknown option: $arg"; exit 1 ;;
  esac
done

for d in "${PIPE_DIR}" "${MAC_DIR}" "${DLL_DIR}"; do
  if [ -z "$(find "$d" -name '*.v' 2>/dev/null)" ]; then
    echo "ERROR: no sources in $d"
    echo "       run: git submodule update --init"
    exit 1
  fi
done

mkdir -p "${BUILD}/sim"

DLL_SRC=$(find "${DLL_DIR}" -name '*.v' ! -name 'arbiter.v')
MAC_SRC=$(find "${MAC_DIR}" -name '*.v')
PIPE_SRC=$(find "${PIPE_DIR}" -name '*.v' ! -name 'ccfpga_pipe_wrapper.v')

${IVL} -g2012 -gspecify -Ttyp ${DUMP} ${DEFS} \
       -I "${MODEL_DIR}" \
       -o "${BUILD}/dll_phy.vvp" \
       ${DLL_SRC} \
       ${MAC_SRC} \
       ${PIPE_SRC} \
       "${MODEL_DIR}/ccfpga_serdes_pkg.sv" \
       "${MODEL_DIR}/ccfpga_serdes.sv" \
       "${HERE}/phy_model.sv" \
       "${HERE}/pcie_stack.sv" \
       "${HERE}/tb_dll_phy.sv"

cd "${BUILD}"
${VVP} -N dll_phy.vvp ${DUMP:+-fst}
if [ -n "${DUMP}" ]; then
  echo "waveform: ${BUILD}/sim/dll_phy.fst"
fi
