#!/bin/bash

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
MODEL_DIR="$(cd "${HERE}/.." && pwd)"
YOSYS=${YOSYS:-yosys}

if command -v cygpath >/dev/null 2>&1; then
  HERE_Y=$(cygpath -m "${HERE}")
  MODEL_DIR_Y=$(cygpath -m "${MODEL_DIR}")
else
  HERE_Y="${HERE}"
  MODEL_DIR_Y="${MODEL_DIR}"
fi

if ! command -v "${YOSYS}" >/dev/null 2>&1; then
  echo "ERROR: yosys not found on PATH"
  exit 1
fi

pass=0
fail=0

run_prop () {
  local top="$1"
  local desc="$2"

  printf '  %-22s %s\n' "${top}" "${desc}"

  out=$("${YOSYS}" -p "
      read_slang ${MODEL_DIR_Y}/ccfpga_serdes_pkg.sv ${HERE_Y}/fv_8b10b.sv --top ${top}
      hierarchy -top ${top}
      proc; opt; memory; opt -full
      sat -verify -prove ok 1 -show-inputs
  " 2>&1)

  if echo "${out}" | grep -q "SAT proof finished - no model found: SUCCESS"; then
    echo "      PROVED (unsat: no input makes the property fail)"
    pass=$((pass+1))
  else
    echo "      FAILED / INCONCLUSIVE"
    echo "${out}" | sed 's/^/        /' | tail -40
    fail=$((fail+1))
  fi
}

echo ""
echo "============================================================="
echo "  Formal verification - open 8b/10b codec"
echo "  source under proof: ${MODEL_DIR_Y}/ccfpga_serdes_pkg.sv"
echo "  (the exact same file the simulation model includes)"
echo "============================================================="
echo ""

echo "--- SAT proofs (yosys) --------------------------------------"
run_prop fv_enc_disparity  "encoder never emits an illegal disparity"
run_prop fv_enc_rd_tracking "reported running disparity matches the symbol"
run_prop fv_comma_format   "K28.5 encodings match the vendor comma constants"
run_prop fv_injective      "encoding is injective (decode table well defined)"
run_prop fv_run_length     "no run of more than five identical bits on the wire"

echo ""
echo "--- exhaustive enumeration (icarus) -------------------------"
echo "  the decode table is a procedurally initialised memory, which SAT"
echo "  cannot take. Its input space is small enough to enumerate in full,"
echo "  which is an equally complete argument."
echo ""

IVL=${IVL:-iverilog}
VVP=${VVP:-vvp}
if command -v "${IVL}" >/dev/null 2>&1; then
  BUILD="${SERDES_BUILD_DIR:-$HOME/.cache/opencologne-pcie}/formal"
  mkdir -p "${BUILD}"
  if "${IVL}" -g2012 -I "${MODEL_DIR}" \
       -o "${BUILD}/fv_exh.vvp" "${MODEL_DIR}/ccfpga_serdes_pkg.sv" "${HERE}/fv_8b10b_exhaustive.sv" 2>&1; then
    if "${VVP}" -N "${BUILD}/fv_exh.vvp" | tee "${BUILD}/fv_exh.log" \
         | grep -q "PASSED"; then
      pass=$((pass+1))
    else
      cat "${BUILD}/fv_exh.log"
      fail=$((fail+1))
    fi
  else
    echo "  ERROR: could not compile the exhaustive harness"
    fail=$((fail+1))
  fi
else
  echo "  SKIPPED: iverilog not on PATH"
fi

echo ""
echo "============================================================="
echo "  ${pass} proved, ${fail} failed"
echo "============================================================="
echo ""

[ "${fail}" -eq 0 ]
