# openCologne-PCIE Simulation Top Level Test Bench

## Table of Contents

* [Block-level flows](#block-level-flows)
* [Running the co-simulation](#running-the-co-simulation)
  * [Modeling options: DUT, PHY, CPU](#modeling-options-dut-phy-cpu)
  * [WaveCrux decoders](#wavecrux-decoders)
  * [Transaction taps: a test platform at every layer](#transaction-taps-a-test-platform-at-every-layer)
  * [Choosing the user code](#choosing-the-user-code)
  * [Verilator and Icarus, side by side](#verilator-and-icarus-side-by-side)
  * [Build defines](#build-defines)
  * [From XSIM to Verilator, via Icarus](#from-xsim-to-verilator-via-icarus)
  * [VIP versions and local changes](#vip-versions-and-local-changes)
* [Introduction](#introduction)
* [Scope: unit debug, then top-level validation](#scope-unit-debug-then-top-level-validation)
  * [A host already proven against real silicon](#a-host-already-proven-against-real-silicon)
* [VProc Software](#vproc-software)
  * [The CPU node: three ways to run the SOC's software](#the-cpu-node-three-ways-to-run-the-socs-software)
* [Debugging Code](#debugging-code)
* [The mem_model Co-Simulation Sparse Memory Model](#the-mem_model-co-simulation-sparse-memory-model)
* [Driving the PCIE Link](#driving-the-pcie-link)
* [Co-simulation HAL](#co-simulation-hal)
* [References](#references)


## Block-level flows

This directory is the top-level test bench. The layers below it have their own Icarus Verilog flows, next to their RTL: the PHY (PIPE + SerDes, and the opensource SerDes BFM) in [2.rtl/1.phy/3.sim](../2.rtl/1.phy/3.sim/), the DLL over that PHY in [2.rtl/4.dll/sim](../2.rtl/4.dll/sim/).

## Running the co-simulation

Open-source simulators only: Verilator (default) or Icarus Verilog. From `5.sim`, on Linux or WSL:

```sh
make run                 # Verilator
make SIM=icarus run      # Icarus Verilog
make DUMP=1 run          # also write tb.fst
```

`DUMP=1` writes the FST natively (Verilator `--trace-fst`, Icarus `vvp -fst`): the PIPE link both ways, its clock and reset, and the decoder pages of both pcieVHosts (`tb.u_rc`, `tb.dut.bfm_pcie`): every decoder input on one page per side (PIPE, DLL, TLPs), under the names WaveCrux auto-binds. [`tb.DLL-PIPE.wavecrux`](tb.DLL-PIPE.wavecrux) opens the tracked [`tb.fst`](tb.fst) (Verilator run) in WaveCrux with Ferrite's PIPE and DLL decoders on both directions. It binds signals by their number in the file, so after a change to the dumped signals, run [`tools/wavecrux-rebind.py`](tools/wavecrux-rebind.py) on it.

The VIP (VProc, the pcieVHost PCIE model, mem_model) is copied from upstream into [`vip`](vip/README.md). The first build compiles it once into `~/.cache/opencologne-pcie/vip` ([`tools/build-vip.sh`](tools/build-vip.sh)). Our own wrappers are in `models/`.

The DUT is selected with `DUT`: the EP RTL + firmware (`DUT=rtl`: [`rtl.f`](rtl.f), with the host in the `phy_top` socket through [`models/phy_vproc_rc.sv`](models/phy_vproc_rc.sv)), or the mock `EPPIPEx1__pcieVHost_DUT`, a second pcieVHost in EP mode ([`stubs`](stubs/README.md); `DUT=mock`, the default for now). The host is `RCPIPEx1__pcieVHost`, a pcieVHost in RC mode at node 1, running [`usercode/VUserMain1.cpp`](usercode/VUserMain1.cpp). A passing run shows the link train to L0 on both sides, then the host enumerate the EP: Vendor and Device ID, class code, all six BARs sized and assigned, the capability list walked, ending with `===> Finished with no errors`. The host program ends the simulation itself when it is done.

With `DUT=rtl` the host program is [`usercode/VUserMain1_rtl.cpp`](usercode/VUserMain1_rtl.cpp): the same enumeration for our one BAR0 (4 KB), Memory Space and Bus Master enabled, then DWORD writes and reads in BAR0 that the firmware serves, all checked, with scrambling on. Today the run stops in flow-control initialisation, on gatemate-pipe's DLL:

- it repeats InitFC1/InitFC2 only every 34 µs, and pcieVHost leaves its own FC init only after one more complete set of InitFC DLLPs, so the host never sends a TLP;
- its InitFC credits are fixed ([#22](https://github.com/chili-chips-ba/openCologne-PCIE/issues/22)): the first UpdateFC of our TL then looks to the host like a jump of 233 header credits, and the host stops;
- a TLP that arrives right after another one is dropped without a Nak.

With these three worked around locally, the run ends with `===> Finished with no errors` and `fw_pass` set.

### Modeling options: DUT, PHY, CPU

Three `make` switches choose the models, as in the [block diagram](#introduction):

| Switch | Values | Selects | Today |
|---|---|---|---|
| `DUT` | `mock` (default), `rtl` | the EP: a second pcieVHost in EP mode (`EPPIPEx1__pcieVHost_DUT`, node 2), or our MAC + DLL + TL RTL with firmware | both; `rtl` stops in FC init, [above](#running-the-co-simulation) |
| `PHY` | `vproc_rc`, `rtl` | the `phy_top` socket: the host `RCPIPEx1__pcieVHost` (node 1), or the real PHY | not a switch yet; the host is wired in |
| `CPU` | `rtl`, `vproc`, `iss` | the SOC CPU, with `DUT=rtl`: eduBOS5 RTL, a native C/C++ program at node 0, or the rv32 ISS ([below](#the-cpu-node-three-ways-to-run-the-socs-software)) | not a switch yet; needs `DUT=rtl` |

`SIM` (`verilator`, `icarus`) and `DUMP` (`0`, `1`) choose the simulator and the waveform, not the models.

### WaveCrux decoders

Three sets of decoders, one per layer, that complement each other:

| Decoders | Show | Where |
|---|---|---|
| Ferrite's PIPE, Data Link Layer and serial-line decoders (free) | ordered sets, DLLPs, Ack/Nak, flow control, LCRC, TLP framing | [wavecrux-decoders `decoders/pcie`](https://github.com/Ferrite-Engineering/wavecrux-decoders/tree/main/decoders/pcie) |
| Our TLP decoder (free) | every TLP named, each completion paired with its request | [`tools/wavecrux-pcie-tlp`](tools/wavecrux-pcie-tlp), moving to wavecrux-decoders ([PR #13](https://github.com/Ferrite-Engineering/wavecrux-decoders/pull/13)) |
| WaveCrux Pro PCIe TLP analysis | latency, timeouts, Base Spec rule checks, bus statistics | [WaveCrux docs](https://github.com/Ferrite-Engineering/wavecrux/blob/main/docs-site/docs/protocol-decoders.md#pcie-tlp-analysis) |

Here today: Ferrite's DLL decoder names each TLP from the PIPE bits (`TLP seq=5 MWr32 len=1`). Our TLP decoder reads the host's TLP stream from `tb.u_rc` (prefix `tx_` for RC -> EP, `rx_` for EP -> RC): transaction taps we added to pcieVHost ([details](models/pcievhost/README.md#transaction-taps-our-change)).

### Transaction taps: a test platform at every layer

Each pcieVHost reports every TLP and DLLP it sends and receives on ports of its own: [transaction taps](models/pcievhost/README.md#transaction-taps-our-change) we added to the model. Our wrapper [`PIPEx1__pcieVHost`](models/PIPEx1__pcieVHost.sv) offers each packet at three layers, from one run, all always present. Both sides use it: the host `RCPIPEx1__pcieVHost` (`EndPoint=0`) and the mock EP `EPPIPEx1__pcieVHost_DUT` (`EndPoint=1`). Each side has its decoder page, with the same names, by link direction (dn = RC -> EP, up = EP -> RC): `tb.u_rc` and `tb.dut.bfm_pcie`. A packet shows on both, a link latency apart.

<p align="center">
<img alt="Inside PIPEx1__pcieVHost, used by both sides: the pcieVHost C model writes each TLP and DLLP through VProc, in zero time, into four SV queues in pcieVHost.v, which play them out one per clock on TlpTx/TlpRx/DllpTx/DllpRx ports; our wrapper turns them into dll_rx beats for a TL under test and into the names WaveCrux decoders auto-bind, next to the PIPE link" width="100%" src="../0.doc/5.sim/pcievhost-taps.drawio.png">
</p>

| Layer | Ports of `tb.u_rc`, `tb.dut.bfm_pcie` | For |
|---|---|---|
| PIPE | `pipe_dn_*`, `pipe_up_*` (`pclk`, `data`, `datak`) | the link; PIPE and DLL decoders |
| Data Link | `dll_rx_*`, on `dll_clk`: TLPs (`data`, `tlp_valid`, `tlp_first`, `tlp_last`) and DLLPs (`hdr_credit`, `data_credit`, `update_type`, `packet_type`, `dllp_valid`) | RC -> EP traffic as an EP's DLL hands it to its TL (`dll_if` RX side): drives a TL under test |
| Data Link | `dllp_dn_*`, `dllp_up_*` | every DLLP, one word each |
| Transaction | `tx_*` (RC -> EP), `rx_*` (EP -> RC) | the TLP decoder |

The `dll_rx_*` fields follow Cologne Chip's DLL ([DLL draft v2](../2.rtl/0.doc/260711-DLL_draft_v2.pdf), slides 7 and 9): TLP byte 0 in `data[7:0]`, the first byte on the wire; DLLP Type = {`packet_type`, `update_type`, 0, VC}, so `packet_type` 01 InitFC1, 11 InitFC2, 10 UpdateFC, and `update_type` 00 P, 01 NP, 10 Cpl. Like that DLL, every DLLP raises `dllp_valid`.

What it gives us:

- **RTL driven from the model.** `dll_rx_*` has the shape of `dll_if`'s RX side, so a TL can be tested without the MAC and DLL below it, on its own clock.
- **A reference for the DUT.** What the host sent and received, packet by packet, to compare against the DUT's own TL and DLL interfaces once `DUT=rtl` is in.
- **Self-checking tests.** A checker reads the taps, not the console log.
- **Decoder fixtures from an open simulator.** Verilator and Icarus give the same TLPs at the same times (50 each way in the enumeration run), with expected values from the model, not from a decoder.
- **Any link partner.** The host's taps work with the mock EP and the EP RTL alike; with the mock EP, both ends of the link are tapped.

### Choosing the user code

Each VProc node runs a C/C++ program whose entry point is `VUserMain<n>()`, `n` being the node number. The make file compiles these programs into `obj/<sim>/libuser.a` and links it into the simulation. Four variables, set on the command line, choose what goes in:

| Variable | Default | What it does |
|---|---|---|
| `USER_C` | `VUserMain1.cpp VUserMain2.cpp` | the source files: one `VUserMain<n>` per node (1 = host, 2 = mock EP), plus any helper files they need |
| `USRCODEDIR` | `5.sim/usercode` | the directory all of `USER_C` is read from; it is also on the include path |
| `OPTFLAG` | `-g` | compiler flag for the user code; `-g` keeps it debuggable, `-O2` makes it faster |
| `USRSIMFLAGS` | empty | extra simulator flags, e.g. a define: `+define+X` for Verilator, `-DX` for Icarus |

```sh
make USER_C="VUserMain1.cpp VUserMain2.cpp my_checks.cpp" run   # add a helper file
make USRCODEDIR=$HOME/tests/cfg-walk run                         # another host program, same file names
```

A different test is therefore a different `USER_C` or `USRCODEDIR`, with no change to the make file. Run `make clean` after changing `OPTFLAG`: object files already built are not recompiled. `make help` lists the variables.

### Verilator and Icarus, side by side

The same test bench on both simulators (2026-10-20, WSL2, Verilator 5.052, Icarus Verilog 13.0, single runs; wall-clock times depend on host load):

| | Verilator | Icarus |
|---|---|---|
| Host results (`===>` lines) | 30, identical | 30, identical |
| LTSSM steps (`--->` lines) | 26 | 26 |
| Link display lines (TL, DL) | 980 | 980 |
| Simulated time at the end | 19.194 µs | 19.194 µs |
| Wall-clock time | 0.7 s | 32.5 s |
| Speed | 27 µs simulated per s | 0.59 µs simulated per s |
| C models reached via | DPI-C | VPI |
| Electrical idle on the line | `0` plus a side-band | `Z` on the wire |

Same results, same link-training steps, same end time. Verilator, compiled to a native executable, is about 46 times faster.

Both build `ltssm.c` with `LTSSM_ABBREVIATED` ([build defines](#build-defines)). Until 2026-10-20 only the Icarus library had it, so Verilator sent 1024 TS1 (65 µs more) and ended at 84 µs.

### Build defines

`LTSSM_ABBREVIATED` shortens pcieVHost's link training (`ltssm.c`): 16 TS1 in Polling.Active instead of the spec's 1024, and a Detect.Quiet timeout of 1500 cycles instead of 12 ms. The link reaches L0 through the same steps, only sooner. Both simulators use it.

| Define | Set in | Effect | Origin |
|---|---|---|---|
| `LTSSM_ABBREVIATED` | `Makefile` (Verilator), `tools/build-vip.sh` (Icarus) | shortened link training, above | VIP |
| `EXCLUDE_LTSSM` | `Makefile` | leaves the LTSSM out of the pcieVHost model; the user code links `ltssm.c` instead | VIP |
| `VPROC_SV` | `Makefile`, `tools/build-vip.sh`, `tb.f` | VProc over SystemVerilog DPI-C (Verilator) | VIP |
| `ICARUS` | `Makefile`, `tools/build-vip.sh` | VProc over VPI (Icarus) | VIP |
| `EXTERN_VPI_TABLE` | `tools/build-vip.sh` (Icarus) | VProc takes its system-task table from pcieVHost's `veriuser.c` | VIP |
| `VPROC_BYTE_ENABLE` | `Makefile`, `tb.f` | byte enables on the VProc bus, in VProc and pcieVHost | VIP |
| `_REENTRANT` | `tools/build-vip.sh` (Icarus) | thread-safe C library: each VProc node runs in a thread | C library |
| `VPROC`, `VPROC_PLI_VPI` | `Makefile`, `tools/build-vip.sh` | none in this VIP version | VIP |
| `DUMP` | `Makefile` (`DUMP=1`) | `tb.sv` writes `tb.fst` | ours |

### From XSIM to Verilator, via Icarus

openPCIE runs its co-simulation on AMD's XSIM, because the encrypted Artix-7 hard macros left no other choice. **The pcieVHost setup we took from openPCIE did not run on Verilator.** The upstream model has had Verilator support since `VERSION_1_0_0` (2024-08-27), with its own Verilator make flow since `VERSION_1_0_1` (2024-09-29); both twins use `VESRSION_1_9_3` (sic, 2026-06-13). But the openPCIE integration (libraries, file list, wiring) was built for XSIM only. Here all RTL is open, so the co-simulation moved to Verilator, the fast one, and Icarus. Each step on the way taught something about the models:

1. **Libraries built from source, per simulator.** XSIM loaded prebuilt `libcosimlnx.a` / `libpcielnx.a`. Verilator reaches the C models through DPI-C, Icarus through VPI, and the two need different builds of the same sources, so [`tools/build-vip.sh`](tools/build-vip.sh) builds both: `libcosimlnx.a` / `libpcielnx.a` for DPI-C, `libcosimica.a` / `libpcieica.a` for VPI. The VPI library also carries pcieVHost's `veriuser.c`, the table that registers the models' system tasks with Icarus.
2. **Every referenced module must exist.** The pcieVHost wrappers instantiate `clkmux` and `Serialiser` (from pcieVHost's `verilog/lib`), which the earlier XSIM file list never compiled. Verilator wants every module the design references, so the VIP build now collects them.
3. **Electrical idle: `Z` or a side-band.** A PCIE line that is electrically idle carries no signal, which a 4-state simulator (Icarus, XSIM) models as `Z`. Verilator is 2-state, it has no `Z`, so under Verilator `pcieVHostPipex1` drives idle as all zeros and adds two ports, `ElecIdleOut` and `ElecIdleIn`, for the models to tell each other. The test bench cross-connects them. Left open, the run still gives the same results, but about 15 times slower (35.4 s instead of 2.4 s, 2026-10-18): the side-band is what keeps Verilator fast through link training. Icarus needs none of this; it has `Z`.
4. **openPCIE's LTSSM patch does not belong here.** On openPCIE the model plays the EP, an upstream port, against a real `PCIE_2_1` downstream port, and the patch makes it spec-correct: an upstream port keeps sending Link/Lane = PAD in its TS1 ordered sets until the downstream port assigns the numbers. Upstream's model takes a shortcut that only works against another copy of itself. Our mock EP pairs the patched EP model with the model's own RC side, which still expects that shortcut, and the link deadlocks in Configuration.Start, on both simulators. Here the model plays the RC, so there is nothing for the patch to fix: we use upstream's `ltssm.c` as is, and both sides reach L0.
5. **Macros before models.** The pcieVHost models use macros (`WsTimeScale`, `RegDel`, the comma symbols, the register map) defined in its headers. Under Verilator the first file in the list happened to pull them in for all others; Icarus has no such luck. [`tb.f`](tb.f) now names `allheaders.v` first, for both.
6. **Portable delays.** Icarus rejected the test bench's `#(N * 1ps)` delays. The file's timescale is 1 ps, so plain numbers mean the same and work everywhere; the run limit is a 64-bit constant, as 10 ms in picoseconds overflows 32 bits.

### VIP versions and local changes

| Component | In use | Source |
|---|---|---|
| VProc | 1.13.4 | [wyvernSemi/vproc](https://github.com/wyvernSemi/vproc) |
| pcieVHost **(modified, see below)** | 1.9.3 | [wyvernSemi/pcievhost](https://github.com/wyvernSemi/pcievhost) |
| mem_model **(wrapped, see below)** | `main` c7b9c62 | [wyvernSemi/mem_model](https://github.com/wyvernSemi/mem_model) |
| rv32 ISS **(modified, see below)** | `main` 774d84fa | [wyvernSemi/rv32](https://github.com/wyvernSemi/rv32) |

The upstream files are copied in [`vip`](vip/README.md), with these changes made by [`tools/vip-import.sh`](tools/vip-import.sh):

| File | Change | Why |
|---|---|---|
| pcieVHost `verilog/pcieVHost/pcieVHost.v` | VProc `BE` and `Burst` ports, left open | we build VProc with `VPROC_BYTE_ENABLE` |
| pcieVHost `verilog/headers/test_defs.v` | `` `fatal`` calls `tb.Fatal` | our test bench top is `tb` |
| pcieVHost `src/displink.c`, `src/pcie_vhost_map.h`, `pcieVHost.v`, `pcieVHostPipex1.v` | transaction taps: TLP and DLLP ports ([`pcievhost-taps.patch`](models/pcievhost/pcievhost-taps.patch)) | waveform decoders need the TLP stream; the model keeps it in C |
| pcieVHost `verilog/headers/pcie_vhost_map.v` | added: generated from `src/pcie_vhost_map.h` | upstream's make files generate it |
| pcieVHost `src/ltssm.c` | none: upstream as is | openPCIE's LTSSM patch deadlocks here (step 4 above) |
| [`models/cosim/mem_model.sv`](models/cosim/mem_model.sv) | wraps upstream `mem_model.v` (as `f_mem_model.v`) in Verilator `lint_off` pragmas | keeps third-party code out of our lint |
| rv32 `src/rv32csr_cpu.cpp` (in openPCIE's `rv32-openpcie.patch`) | the timer-compare check in `process_interrupts()` no longer charges cycles | it added 2 cycles to every instruction |
| rv32 `src/rv32i_cpu.cpp` (same patch) | `sw`, `sh` add the store extra cycles | upstream adds the load ones |
| [`models/rv32/usercode/rv32_timing_config.h`](models/rv32/usercode/rv32_timing_config.h) | PicoRV32, eduBOS5 2-/3-stage timing tables, measured on openPCIE's SOC RTL | see openPCIE's [Our Local VIP Improvements](https://github.com/chili-chips-ba/openPCIE/blob/main/5.sim/README.md#our-local-vip-improvements) |
| [`models/rv32/usercode/VUserMain0.cpp`](models/rv32/usercode/VUserMain0.cpp) | no fetch/load wait states; bus credit; waits for reset release, restarts on reset | the same |

The rv32 integration code in `models/rv32/usercode` is the same as openPCIE's.

## Introduction

The top-level test bench drives the DUT's PCIE link with the [pcieVHost](https://github.com/wyvernSemi/pcievhost) VIP: a C model of a PCIE 1.1/2.0 link partner, connected to the logic simulation through the [VProc](https://github.com/wyvernSemi/vproc) virtual processor. VProc lets a program compiled natively on the host run "inside" an HDL component, in lock-step with the simulation; pcieVHost is such a program, wrapped so that its PCIE lanes appear as ports. It was designed as a root complex, the role it plays here, and has endpoint features too, enabled by a parameter; they are [limited](models/pcievhost/README.md#endpoint-feature-limitations) and meant as a target for testing the root complex side.

<p align=center>
<img alt="openCologne-PCIE test bench: the host RCPIPEx1__pcieVHost at VProc node 1 on top, driving the DUT at its 64-bit PIPE interface below it: MAC, DLL and TL RTL, the CSR registers and the SOC CPU socket (soc_cpu.VPROC at node 0, or eduBOS5)" width=1000 src="../0.doc/5.sim/tb-structure.drawio.png">
</p>

The picture is forward-looking: it shows the final setup, with the EP RTL in place, to guide developers in building it. Parts of it do not exist yet: `PHY=rtl`, the real `phy_top` under the host, and the `CPU=rtl | vproc | iss` switch. With `DUT=rtl`, `tb.sv` puts `pcie_top` (MAC + DLL + TL + SOC with eduBOS5) under the host, which sits in the `phy_top` socket; with `DUT=mock` it connects the host straight to the mock EP.

Each VProc instance is a node with its own program, `VUserMain<n>` for node `n`:

| Node | Model | Program | Role |
|---|---|---|---|
| 1 | `RCPIPEx1__pcieVHost` | [`usercode/VUserMain1.cpp`](usercode/VUserMain1.cpp) | the host: trains the link, enumerates the EP (IDs, BAR sizing and assignment, capabilities), then reads and writes BAR0 |
| 2 | `EPPIPEx1__pcieVHost_DUT` | [`usercode/VUserMain2.cpp`](usercode/VUserMain2.cpp) | the mock EP ([`stubs`](stubs/README.md)), an option next to the EP RTL + firmware: `DUT=mock` |
| 0 | `soc_cpu.VPROC` | native C/C++, or the rv32 ISS | the SOC's CPU, in place of eduBOS5, once the EP RTL is in (below) |

The model can print the traffic of both link directions to the console, layer by layer; [`hex/ContDisps.hex`](hex/ContDisps.hex) selects what is shown.

## Scope: unit debug, then top-level validation

Every layer is covered twice, on purpose. Block-level test benches debug each unit on its own. The top level then validates them together, with an independent host. This matters most for the PHY: it comes from Cologne Chip, and only the top level checks it against our MAC, DLL, TL and firmware.

| Level | Where | Purpose | Link partner |
|---|---|---|---|
| Top | `5.sim` (here) | validates the units together: MAC + DLL + TL RTL and firmware (enumeration, configuration, PIO); with `PHY=rtl`, also Cologne Chip's PIPE and SerDes | `RCPIPEx1__pcieVHost` |
| DLL over PIPE + PHY | [`2.rtl/4.dll/sim`](../2.rtl/4.dll/sim) | unit debug: DLL, MAC/LTSSM, PIPE and SerDes BFM on the serial line | a second copy of the same stack |
| PIPE + PHY | [`2.rtl/1.phy/3.sim`](../2.rtl/1.phy/3.sim) | unit debug: Cologne Chip's PIPE logic over the GateMate SerDes; the [SerDes BFM](../2.rtl/1.phy/2.serdes-model) against the vendor model | the vendor's PIPE test case; the BFM, looped back |

How to run each, and today's status: [Simulation, layer by layer](../2.rtl/README.md#simulation-layer-by-layer).

`PHY` sets the top level's depth:

- **`vproc_rc`**: the host sits at the PIPE. Fast (eight symbols per 31.25 MHz clock), and a failure points at MAC, DLL, TL or firmware.
- **`rtl`**: the real PHY is in, and the host drives the serial line. Slower (2.5 Gb/s bit rate), but it covers the whole stack. It runs on the open-source [SerDes BFM](../2.rtl/1.phy/2.serdes-model), which is checked against the vendor's NDA model ([equivalence checking](../2.rtl/1.phy/2.serdes-model/0.doc/equivalence-checking.md)), so anyone can run it.

### A host already proven against real silicon

`RCPIPEx1__pcieVHost` is the pcieVHost model in our wrapper [`PIPEx1__pcieVHost`](models/PIPEx1__pcieVHost.sv), around upstream's `pcieVHostPipex1`, fixed to the RC role ([`models/RCPIPEx1__pcieVHost.sv`](models/RCPIPEx1__pcieVHost.sv)). The same model and PIPE wrapper were validated on [openPCIE](https://github.com/chili-chips-ba/openPCIE/tree/main/5.sim) against the AMD `PCIE_2_1` hard macro: link training, flow control, TLPs and completions, end to end. There the roles were the other way round, the model the EP and the hard macro the RC. What that run established is that the model and the AMD hard macro speak the same PCIE. An EP that passes against this model in simulation therefore stands a better chance of working on the first try in hardware, when a physical Artix-7, running openPCIE as the RC, drives our GateMate EP over the [openPCIE backplane](https://github.com/chili-chips-ba/openPCIE/tree/main/1.pcb).

## VProc Software

A VProc program is ordinary C or C++ with one difference: its entry point is `VUserMain<n>()`, with C linkage, instead of `main()`, because the simulator already has a `main()` and each node has its own program. Under it, VProc's scheduler talks to the simulator over DPI-C (Verilator) or VPI (Icarus); the program does not see the difference. VProc offers a low-level C API and a C++ one, the `VProc` class in `VProcClass.h` (its headers are in `$VIP_DIR/include`, see [Running the co-simulation](#running-the-co-simulation)):

```c++
VProc (const uint32_t node);

int  write (const unsigned addr, const unsigned  data, const int delta=0);
int  read  (const unsigned addr,       unsigned *data, const int delta=0);
int  tick  (const unsigned ticks);
```

Addresses are byte addresses; `delta` stays at its default. `tick()` advances simulation time by a number of clock cycles of the clock the node is connected to, without a bus transaction. Finer accesses exist too, `writeByte`, `writeHword`, `writeWord` and their `read` twins; the [VProc manual](https://github.com/wyvernSemi/vproc/blob/master/doc/VProc.pdf) has the rest.

A program can also reach the sparse memory model directly, through `mem.h` (C functions, so `extern "C"` from C++):

```c++
void     WriteRamByte  (const uint64_t addr, const uint32_t data, const uint32_t node);
void     WriteRamHWord (const uint64_t addr, const uint32_t data, const int little_endian, const uint32_t node);
void     WriteRamWord  (const uint64_t addr, const uint32_t data, const int little_endian, const uint32_t node);
uint32_t ReadRamByte   (const uint64_t addr, const uint32_t node);
uint32_t ReadRamHWord  (const uint64_t addr, const int little_endian, const uint32_t node);
uint32_t ReadRamWord   (const uint64_t addr, const int little_endian, const uint32_t node);
```

Being C, they have no default arguments. `node` here selects a memory space, not a VProc node; we use one, 0. Every `mem_model` instance in the HDL sees the same memory as this API, so programs and logic can exchange data through it.

<p align="center">
<img alt="soc_cpu VProc software stack" src="../0.doc/5.sim/soc-cpu-vproc-stack.png" width=800>
</p>

### The CPU node: three ways to run the SOC's software

Once the EP RTL is in, node 0 can stand in for eduBOS5 in the SOC's CPU socket ([`models/soc_cpu.VPROC.sv`](models/soc_cpu.VPROC.sv), on the same `mem_if` bus), in the same three ways as on openPCIE:

- **RTL:** eduBOS5 itself runs `firmware.hex`, as in the bitstream. The reference.
- **Native:** a C/C++ program compiled for the host drives the bus. With the co-simulation HAL ([below](#co-simulation-hal)) the firmware's own sources compile this way, and run much faster than on the RTL core.
- **ISS:** the [rv32](https://github.com/wyvernSemi/rv32) instruction set simulator runs the real RISC-V `firmware.elf`: real instructions, interpreted rather than executed by RTL. Its integration program ([`models/rv32/usercode`](models/rv32/usercode)) routes each load and store to the memory model, to a bus transaction on the SOC, or back to the ISS. The ISS sources, with openPCIE's fixes, are in [`vip/rv32`](vip/rv32).

The ISS reads its options from `vusermain.cfg`, in the form of a command line for `vusermain0`. A set of timing models makes it count cycles like a given core; `-V EDUBOS5STG2` (2-stage eduBOS5) or `-V EDUBOS5STG3` match ours.

**The ISS in WaveCrux.** The SOC's `rvfi` stays 0 under the ISS: the ISS runs its instruction loop in C and calls back only for memory, unimplemented instructions and interrupts, so no retired instruction reaches the HDL. Its loads and stores to the SOC still show as bus transactions (`mem_if`). A subset (`rvfi_valid`, `rvfi_pc_rdata`, `rvfi_insn`) would need a per-instruction hook in the ISS and a VProc write for every instruction, slowing it down. Not worth it: the ISS has better tools of its own, `-r` (run-time disassembly in the log) and `-g` (gdb). WaveCrux matters for the RTL CPU, which has neither.

One of the options is <tt>-h</tt> for a help message, which is as shown below:
```
Usage:vusermain0 -t <test executable> [-hHebdrgxXRcI][-n <num instructions>]
      [-S <start addr>][-A <brk addr>][-D <debug o/p filename>][-p <port num>]
      [-l <line bytes>][-w <ways>][-s <sets>][-j <imem base addr>][-J <imem top addr>]
      [-P <cycles>][-x <base addr>][-X <top addr>][-V <core>]
   -t specify test executable/binary file (default test.exe)
   -B specify to load a raw binary file (default load ELF executable)
   -L specify address to load binary, if -B specified (default 0x00000000)
   -n specify number of instructions to run (default 0, i.e. run until unimp)
   -d Enable disassemble mode (default off)
   -r Enable run-time disassemble mode (default off. Overridden by -d)
   -C Use cycle count for internal mtime timer (default real-time)
   -a display ABI register names when disassembling (default x names)
   -T Use external memory mapped timer model (default internal)
   -H Halt on unimplemented instructions (default trap)
   -e Halt on ecall instruction (default trap)
   -E Halt on ebreak instruction (default trap)
   -b Halt at a specific address (default off)
   -A Specify halt address if -b active (default 0x00000040)
   -D Specify file for debug output (default stdout)
   -R Dump x0 to x31 on exit (default no dump)
   -c Dump CSR registers on exit (default no dump)
   -g Enable remote gdb mode (default disabled)
   -p Specify remote GDB port number (default 49152)
   -S Specify start address (default 0)
   -I Enable instruction cache timing model (default disabled)
   -l Specify number of bytes in icache line (default 8)
   -w Specify number of ways in icache (default 2)
   -s Specify number of sets in icache (default 256)
   -j Specify cached IMEM base address (default 0x00000000)
   -J Specify cached IMEM top address (default 0x7fffffff)
   -P Specify penalty, in cycles, of one slow mem access (default 4)
   -x Specify base address of external access region (default 0xFFFFFFFF)
   -X Specify top address of external access region (default 0xFFFFFFFF)
   -V Specify RISC-V core timing model to use (default "DEFAULT")
   -h display this help message
```

## Debugging Code

The simulation is a native process, and the user programs are part of it, so the host `gdb` debugs them directly; build them with `-g` (the default `OPTFLAG`):

```sh
gdb --args obj/verilator/Vtb                                          # Verilator
gdb --args vvp -n -M obj/icarus -m VProc obj/icarus/sim               # Icarus
(gdb) break VUserMain1
(gdb) run
```

There is no simulator kernel to attach to, as there was with XSIM: the breakpoint stops the whole simulation, and inspecting the C++ state of the host program, a TLP it built or the BAR values it read, works as in any program.

Code running on the rv32 ISS is debugged with the RISC-V `gdb` instead: with `-g` in `vusermain.cfg`, the ISS opens a TCP port and prints its number (e.g. `RV32GDB: Using TCP port number: 49152`), and `(gdb) target remote :49152` connects to it. The [ISS manual](https://github.com/wyvernSemi/rv32/blob/main/iss/doc/iss_manual.pdf) has the details.

## The mem_model Co-Simulation Sparse Memory Model

[mem_model](https://github.com/wyvernSemi/mem_model) is a sparse memory, written in C as part of the pcieVHost software: it maps a 64-bit address space and allocates pages only when they are touched. Programs reach it through the API above; logic reaches the same memory through the `mem_model` HDL component, which may be instantiated any number of times. That shared space is how a VProc program and the simulated logic hand data to each other. Details: [`models/cosim/README.md`](models/cosim/README.md).

## Driving the PCIE Link

The EP has a single x1 PIPE port, 64 bits wide, as Cologne Chip's PIPE. `pcieVHostPipex1`, the PIPE wrapper of the pcieVHost model, drives it with Gen1 traffic:

<p align=center>
<img alt="pcieVHost module ports" width=750 src="../0.doc/5.sim/pcievhost_module.png">
</p>

On a 64-bit PIPE, eight symbols travel per PIPE clock, so `pclk` runs at `pcieclk`/8: 31.25 MHz against the 250 MHz symbol clock of Gen1. Configuring and driving the model: [`models/pcievhost/README.md`](models/pcievhost/README.md).

## Co-simulation HAL

`make -f MakefileCSR` in `4.build` generates, from the single register map `csr_build/csr.rdl`, the CSR RTL, the C header the firmware uses (`csr.h`), and two C++ HALs: `csr_hw.h` for the hardware and `csr_cosim.h` for co-simulation ([`sysrdl_cosim.py`](../4.build/sysrdl_cosim.py)). Both present the same API, a hierarchy of register objects that mirrors the RDL, so the same application source compiles for the RISC-V target and for a native VProc program on node 0; only the header behind it changes, and with it whether an access is a pointer dereference or a VProc bus transaction.

Two more things differ between the two builds, and the generated headers cover both:

- **The entry point.** The hardware build starts at `main()`, the co-simulation at `VUserMain0()`. The headers define `PCIEMAIN` as one or the other, so the application writes `void PCIEMAIN (void)`.
- **Delays.** A delay loop on the target is wasted simulation time in co-simulation. Wrap delays in one function whose co-simulation version converts time into clock cycles and calls VProc's tick. `csr_cosim.h` defines `SOC_CPU_CLK_PERIOD_PS` for that (16000 ps unless defined before the include) and `SOC_CPU_VPNODE`, the CPU node (0; option `-v` of `sysrdl_cosim.py`).

## References:
- [Logic sim using pcieVHost and 3rd Party PCIe](https://www.linkedin.com/pulse/case-study-logic-simulation-environment-using-third-party-southwell-tyere)
- [VProc](https://github.com/wyvernSemi/vproc)
- [mem_model](https://github.com/wyvernSemi/mem_model)
- [PCIe VHost Model](https://github.com/wyvernSemi/pcievhost)
- [rv32 RISC-V ISS](https://github.com/wyvernSemi/rv32/tree/main/iss)
- [cocotbext-pcie](https://github.com/alexforencich/cocotbext-pcie): Alex Forencich's PCIE models for cocotb (Python)
- [WaveCrux PCIE decoders](https://github.com/Ferrite-Engineering/wavecrux-decoders/tree/main/decoders/pcie): PIPE and DLL traffic as transactions in the waveform
- [WaveCrux RV32 ISA decoder](https://github.com/Ferrite-Engineering/wavecrux/tree/main/assets/decoders/isa/riscv): RISC-V instructions in the waveform
- [SystemRDL](https://www.accellera.org/downloads/standards/systemrdl)
- [PeakRDL and SystemRDLcompiler](https://github.com/SystemRDL)
