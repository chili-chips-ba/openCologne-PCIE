#!/bin/bash
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
RTL="$(cd "${HERE}/../.." && pwd)"
TLP="${RTL}/5.tlp"

BUILD="${SERDES_BUILD_DIR:-$HOME/.cache/opencologne-pcie}/tl"

VERILATOR=${VERILATOR:-verilator}

DUMP=""
SEED=1
while [ $# -gt 0 ]; do
  case "$1" in
    --dump)    DUMP="-DDUMP --trace-fst" ;;
    --seed)    shift; SEED="$1" ;;
    -h|--help) echo "usage: $0 [--dump] [--seed N]"; exit 0 ;;
    *) echo "unknown option: $1"; exit 1 ;;
  esac
  shift
done

mkdir -p "${BUILD}/sim"
cd "${BUILD}"

${VERILATOR} --binary --timing -Wno-fatal -Wno-lint -Wno-style --timescale 1ns/100fs ${DUMP} \
    --top-module tb_pcie_tl -Mdir obj -o tb_pcie_tl \
    "${TLP}/pcie_pkg.sv" \
    "${TLP}/tl_pkg.sv" \
    "${TLP}/axis_if.sv" \
    "${TLP}/trn_if.sv" \
    "${TLP}/cfg_if.sv" \
    "${RTL}/4.dll/dll_if.sv" \
    "${TLP}/tlp_queue.sv" \
    "${TLP}/tlp_order.sv" \
    "${TLP}/tlp_rx_handler.sv" \
    "${TLP}/tlp_rx_dispatch.sv" \
    "${TLP}/config_space.sv" \
    "${TLP}/cpl_gen.sv" \
    "${TLP}/fc_credit.sv" \
    "${TLP}/tlp_tx_arbiter.sv" \
    "${TLP}/pcie_tl.sv" \
    "${TLP}/trn_rx.sv" \
    "${TLP}/trn_tx.sv" \
    "${TLP}/trn_tx_throttle.sv" \
    "${TLP}/trn_bridge.sv" \
    "${HERE}/tb_pcie_tl.sv" > verilator.log 2>&1 || { cat verilator.log; exit 1; }

./obj/tb_pcie_tl +seed="${SEED}"
if [ -n "${DUMP}" ]; then
  echo "waveform: ${BUILD}/sim/tb_pcie_tl.fst"
fi
