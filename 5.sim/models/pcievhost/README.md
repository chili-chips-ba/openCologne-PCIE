# The _pcieVHost_ VIP

[_pcieVHost_](https://github.com/wyvernSemi/pcievhost) is a C model of a PCIE 1.1/2.0 link partner, running on a [_VProc_](https://github.com/wyvernSemi/vproc) virtual processor. Here it plays the host, `RCPIPEx1__pcieVHost` ([`../RCPIPEx1__pcieVHost.sv`](../RCPIPEx1__pcieVHost.sv)), and the mock EP, `EPPIPEx1__pcieVHost_DUT` ([`../../stubs`](../../stubs/README.md)).

The upstream sources are in [`5.sim/vip/pcievhost`](../../vip/pcievhost); [`5.sim/tools/build-vip.sh`](../../tools/build-vip.sh) builds them for Verilator and Icarus. How it is used here: [5.sim README](../../README.md).

## Transaction taps (our change)

[`pcievhost-taps.patch`](pcievhost-taps.patch), applied by [`5.sim/tools/vip-import.sh`](../../tools/vip-import.sh), adds TLP and DLLP ports to the model: every TLP and DLLP it sends (`Tx`) or receives (`Rx`).

- **C side** (`src/displink.c`): `TapTl()` / `TapDll()`, called from `DispTl()` / `DispDll()`, write each TLP DW and each DLLP word to new addresses in `src/pcie_vhost_map.h`, with VProc delta writes, so no simulation time passes.
- **HDL side** (`pcieVHost.v`): SystemVerilog queues take those words and play them out one per clock on `TlpTx*` / `TlpRx*` (`Data`, `Sop`, `Eop`, `Valid`) and `DllpTx*` / `DllpRx*` (`Data`, `Valid`). `pcieVHostPipex1.v` passes them through.
- **TLP format:** byte 0 in bits 31:24, no framing, sequence number or LCRC. Nullified TLPs (EDB) are left out. DLLPs carry their 4 bytes, no CRC.

Our wrapper [`../PIPEx1__pcieVHost.sv`](../PIPEx1__pcieVHost.sv), used by both sides, offers them with the PIPE link, and as `dll_if` RX beats to drive a TL, under the names WaveCrux auto-binds.

Documentation, from upstream:

- [README](https://github.com/wyvernSemi/pcievhost/blob/master/README.md): the HDL component, the C API, the link traffic display, running the model as an EP
- [manual (PDF)](https://github.com/wyvernSemi/pcievhost/blob/master/doc/pcieVHost.pdf)
