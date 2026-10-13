CCFPGA_SERDES_SRC="${CCFPGA_SERDES_SRC:-$HOME/Downloads/ccfpga_serdes/src}"
SERDES_BUILD_DIR="${SERDES_BUILD_DIR:-$HOME/.cache/opencologne-pcie}"

guard_repo_clean () {
  local repo_root="$1"
  local stray

  stray=$(find "${repo_root}" \
            -path "${repo_root}/.git" -prune -o \
            \( -name 'ccfpga_serdes_regfile.v' \
            -o -name 'ccfpga_serdes_pd.v' \
            -o -name 'ccfpga_serdes_rx.v' \
            -o -name 'ccfpga_serdes_tx.v' \
            -o -name 'ri_adpll_dco_lj.v' \
            -o -name 'RI_SERDES_TX.v' \
            -o -name 'RI_SERDES_RX.v' \) -print 2>/dev/null | head -20)

  if [ -n "${stray}" ]; then
    echo ""
    echo "  ##################################################################"
    echo "  #  STOP - proprietary SerDes sources found INSIDE the repository #"
    echo "  ##################################################################"
    echo ""
    echo "${stray}" | sed 's/^/      /'
    echo ""
    echo "  These are CologneChip/RacyICs NDA sources. They must never be in"
    echo "  this tree - one 'git add -A' and they are on GitHub permanently."
    echo ""
    echo "  Move them outside the repo and point the flow at them instead:"
    echo ""
    echo "      export CCFPGA_SERDES_SRC=\$HOME/Downloads/ccfpga_serdes/src"
    echo ""
    exit 1
  fi
}

prepare_vendor_copy () {
  local dest="$1"

  if [ ! -d "${CCFPGA_SERDES_SRC}" ]; then
    echo "ERROR: vendor SerDes sources not found at:"
    echo "         ${CCFPGA_SERDES_SRC}"
    echo ""
    echo "       They are proprietary and are NOT part of this repository."
    echo "       Unpack the CologneChip archive somewhere outside the repo and"
    echo "       point the flow at it:"
    echo ""
    echo "         export CCFPGA_SERDES_SRC=/path/to/ccfpga_serdes/src"
    echo ""
    return 1
  fi

  rm -rf "${dest}"
  mkdir -p "${dest}"
  ( cd "${CCFPGA_SERDES_SRC}"
    find . -type f \( -name '*.v' -o -name '*.sv' \) ! -path './.git/*' | while read -r f; do
      mkdir -p "${dest}/$(dirname "$f")"
      sed -E 's/^([[:space:]]*)parameter([[:space:]]+)([A-Za-z_][A-Za-z0-9_]*)([[:space:]]*=[[:space:]]*[0-9]+\.[0-9]+)/\1parameter\2real \3\4/' \
          "$f" > "${dest}/$f"
    done )
  return 0
}
