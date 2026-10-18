# SOC: eduBOS5 + PCIE CSR window

`riscv_pcie_soc` is the user side of our EP: a small RISC-V SOC that talks to the PCIE core over the same AXI-Stream / TRN interface an AMD Artix-7 EP gives its user logic. It is the twin of the openPCIE SOC; only the CSR window and the firmware change, because the roles are swapped: the RC sends requests and waits for Completions, the EP waits for requests and sends Completions.

| File | What it is |
|---|---|
| [`riscv_pcie_soc.sv`](riscv_pcie_soc.sv) | CPU, 8 KB RAM, address decode, Tx FSM and Rx capture around the CSR block |
| [`soc_csr.sv`](soc_csr.sv) | bridges the CPU bus to the PeakRDL-generated register block |
| [`mem_if.sv`](mem_if.sv) | the CPU memory bus: valid / addr / wdata / wstrb, ready / rdata |
| [`4.build/csr_build/csr.rdl`](../../4.build/csr_build/csr.rdl) | the register map, the single source of the CSR RTL, C headers and docs |
| [`../5.tlp/`](../5.tlp) | `pcie_pkg`, `axis_if`, `cfg_if`: the interfaces to the PCIE core |

### CPU

- **eduBOS5** (default): Chili.CHIPS' RV32I core, maintained in openPCIE and fetched from there, not copied: `EDUBOS5_DIR=$(bash 4.build/fetch-edubos5.sh)`. `` `define SOC_EDUBOS5_3STG `` selects its 3-stage pipeline.
- **VProc** (`` `define SOC_CPU_VPROC ``, co-simulation only): the same bus driven by native C/C++ or by the rv32 ISS, see [5.sim](../../5.sim).

### Address map

| Address | What |
|---|---|
| 0x0000_0000 | 8 KB RAM: code, data and the PIO buffer, loaded from `firmware.hex` |
| 0x3000_0000 | PCIE CSR window, see below |

### CSR window

| Offset | Register | Use |
|---|---|---|
| 0x00 – 0x0C | `tx.header0..2`, `tx.data` | the TLP to send; writing `tx.data` sends it |
| 0x10 – 0x1C | `rx.header0..2`, `rx.data` | the last TLP received, as it came |
| 0x20 | `rx.valid` | a TLP is waiting; write 1 to clear |
| 0x24, 0x28 | `status.err`, `status.phy` | fatal-error message; Tx FSM state and free core buffers |
| 0x2C | `status.result` | firmware result marker; 0x0000_FACE lights `fw_pass` |
| 0x30 | `status.cfg_id` | our own Bus/Device/Function |

Things worth knowing:

- **The Rx window takes any TLP as-is.** The RC version decoded only Completions; an EP must see Memory requests, so the first two beats of every incoming TLP land in `rx.header0..2` and `rx.data`, and the firmware decodes them. That makes the window generic: the same RTL could serve the RC too.
- **`rx.valid` is the flow control.** It is set at the end of a TLP and holds `m_axis_rx.tready` low until the firmware clears it, so a slow CPU never loses a request; the PCIE core simply waits.
- **Configuration requests never get here.** The TL answers them itself, as the AMD hard macro does, and reports what it learned: `status.cfg_id` is the Bus/Device/Function the host gave us, captured from its Type 0 Configuration Writes (UG477 `cfg_bus_number`, `cfg_device_number`, `cfg_function_number`). Every Completion carries it as the Completer ID.
- **`tx.data` is a trigger.** PeakRDL's `swmod` strobe on that field starts the Tx FSM, which is why the firmware writes the three headers first and the data last.

Lint (WSL, from the repo root):

```sh
E=$(bash 4.build/fetch-edubos5.sh); G=4.build/csr_build/generated-files
verilator --lint-only -Wall -Wno-DECLFILENAME --top-module riscv_pcie_soc \
  2.rtl/5.tlp/pcie_pkg.sv $E/edubos5_pkg.sv $G/csr_pkg.sv 2.rtl/5.tlp/axis_if.sv 2.rtl/5.tlp/cfg_if.sv \
  2.rtl/6.soc/mem_if.sv $E/edubos5_rf.sv $E/edubos5_alu.sv $E/edubos5.sv $G/csr.sv \
  2.rtl/6.soc/soc_csr.sv 2.rtl/6.soc/riscv_pcie_soc.sv
```

--------------------
#### End of Document
