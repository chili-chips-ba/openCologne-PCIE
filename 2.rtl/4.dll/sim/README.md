# DLL simulation

| testbench | what it exercises | run |
|---|---|---|
| `tb_dll_wavecrux.v` | a fork of gatemate-pipe's `tb_dll_logic.v` with real TLP headers, makes the WaveCrux pictures | see [../README.md](../README.md#viewing-the-dll-in-wavecrux) |
| `tb_dll_phy.sv` | the DLL over a real PHY: two link partners over a serial link | `bash run-dll-phy.sh` |

## DLL over the PHY: `run-dll-phy.sh`

Two complete stacks, an Endpoint and a Root Complex, connected by a bit-level serial link in both directions:

```
       EP                                                    RC
  TL stimulus           tb_dll_phy.sv                   TL stimulus
       |                                                     |
  dll_logic             2.rtl/2.pipe/pipe_src           dll_logic
       |                                                     |
  ccfpga_LTSSM_logic    2.rtl/2.pipe/pipe_src           ccfpga_LTSSM_logic
       |                                                     |
  phy_model             2.rtl/4.dll/sim                 phy_model
  (ccfpga_pipe_logic + ccfpga_serdes model)
       |                                                     |
       +--------------- serial link, 2.5 Gb/s ---------------+
```

`pcie_stack.sv` is one side: the DLL, the MAC and the test-bench PHY [`phy_model.sv`](phy_model.sv). That model is the PIPE logic, the SerDes model and the SerDes bring-up sequence as a small FSM, so the layers above see a plain PIPE interface. The synthesizable `phy_top` will be the same with the `CC_SERDES` primitive in place of the SerDes model.

```sh
git submodule update --init                   # DLL, MAC and PIPE sources: the gatemate-pipe submodule
bash 2.rtl/4.dll/sim/run-dll-phy.sh           # ~15 s
bash 2.rtl/4.dll/sim/run-dll-phy.sh --dump    # with a waveform
```

Build products and the waveform go to `$SERDES_BUILD_DIR/dll` (default `~/.cache/opencologne-pcie`). Tested with Icarus Verilog 13.

The test:

1. both LTSSMs train from Detect.Quiet to L0, every state change is printed
2. both DLLs go through InitFC1/InitFC2 to DL_Active
3. three TLPs EP to RC and two TLPs RC to EP, every word is checked
4. bits of a TLP are flipped on the EP to RC wire, the RC NAKs it and the EP replays it
5. an UpdateFC-P DLLP EP to RC

```
[  141124.0 ns] EP LTSSM : Config.Linkwidth.Start (link#)
  ...
[  152900.0 ns] EP LTSSM : L0
[  153988.0 ns] RC LTSSM : L0
=== Step 1: DLL initialisation, InitFC1/InitFC2 across the link ===
[  158788.0 ns]   both DLLs DL_Active
  ...
=== Step 4: TLP corrupted on the EP -> RC wire, expect NAK and replay ===
[  187524.0 ns]   RC received 3 words, checked
[  189508.0 ns]   EP sent the TLP 2 times, NAK and replay worked
  ...
  SUMMARY: 0 errors
  TEST PASSED
```

### The Root Complex side

The MAC implements the upstream port. The Root Complex is a second instance of the same MAC, which the testbench gives the downstream port role with `force`:

* in Configuration it transmits link number 0, and from Config.Linkwidth.Accept on lane number 0 (`expected_Link`, `expected_Lane`)
* in Config.Linkwidth.Accept and Config.Lanenum.Accept it accepts TS2 as well as TS1 (`TS2_pattern_en`)

### Settings

* scrambling is disabled in both MACs, as with `DISABLE_SCRAMBLING` in the MAC's pcievhost test
* the PIPE reset is released 256 `clk_reg` cycles after the global reset, the MAC and DLL reset once the SerDes reports ready, synchronised to PCLK
* the DLL gets `phy_linkup` when the MAC reports link up and the LTSSM is in L0
* the bit errors in step 4 are short inversions of the serial pair, starting 320 ns after the STP leaves the EP's MAC
