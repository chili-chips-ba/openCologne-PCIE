# SW Architecture

This is where the developers of **PIO TestApp** (the software part of) describe their work.

### HW/SW Architecture

<p align="center"><img src="../0.doc/3.sw/sw-structure.drawio.png" width="100%" alt="Firmware layers: application, PCIE driver, HAL, register map and startup, talking to the CSR block over the CPU memory bus, then through pcie_top to the PCIE link"></p>

### EP firmware

The EP firmware runs bare-metal on the eduBOS5 core of our GateMate SOC. It is the twin of the openPCIE RC firmware, with the roles swapped: there, the CPU sends requests and waits for Completions; here, it waits for the host's requests and sends the Completions.

| File | What it does |
|---|---|
| [`EP/main.c`](EP/main.c) | the PIO target: stores each MemWr DWORD, answers each MemRd with a CplD, any other non-posted request with Unsupported Request |
| [`common/pcie.c`](common/pcie.c), [`pcie.h`](common/pcie.h) | the request layer: wait for a TLP in the CSR Rx window, decode its header, build and send the Completion, release the window |
| [`common/start.S`](common/start.S), [`sections.lds`](common/sections.lds) | set the stack, jump to `main()`; code and data in the 8 KB RAM at 0x0000_0000 |

What a reader should take from it:

- **The TL does the configuration, not the firmware.** The host's CfgRd0/CfgWr0 (IDs, Command register, BAR0 sizing) are answered by the soft TL, as on the AMD hard macro. Only Memory requests reach the firmware, so enumeration works even before the firmware has started.
- **One TLP at a time, nothing lost.** The SOC captures the first two beats of each incoming TLP into the Rx window and sets `rx.valid`. While it is set, the link is held off; the firmware clears it once it has answered.
- **A Completion routes back by the request's IDs.** Requester ID and Tag come from the request, TC and Attr are copied from it, and the Completer ID is our own Bus/Device/Function, read from `status.cfg_id`. That value comes from the host's configuration writes and differs between a direct link and a link behind a switch, so it is never hard-coded.
- **Byte enables matter even for one DWORD.** A MemWr updates only the enabled bytes; a MemRd's Byte Count and Lower Address follow from its First DW Byte Enables (Base Specification 2.1, tables 2-21 and 2-22). On the TRN interface, payload byte 0 travels in bits [31:24].
- **PASS means the host reached us.** `status.result` reads 0x0000_0001 while the firmware waits, and 0x0000_FACE (the `fw_pass` LED) once it has answered the host's first read.

Build (WSL, with the xPack RISC-V GCC on `PATH`):

```sh
cd 4.build/sw_build && make      # firmware.elf, .bin and .hex for the SOC RAM
```

We plan on creating not one, but three "Getting Started" examples, for the three representative compute platforms:
1) **Hard Embedded / Hosted**: RaspberryPi
2) **Soft Embedded / BareMetal**: Artix-7 FPGA acting as a RootComplex with soft on-chip RISC-V CPU
3) **General-purpose desktop/server class**: PC

## 1) RaspberryPi as RootPort

## 2) Artix-7 FPGA as RootPort

## 3) PC as RootPort


--------------------
#### End of Document
