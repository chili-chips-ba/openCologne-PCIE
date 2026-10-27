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
6. TLPs of 3, 5 and 7 DW in both directions, the last word marked with `tl_tx_tlp_last_half`: each is sent once, with 12, 20 or 28 TLP bytes on the line
7. step 4 with a 5 DW TLP

**Known failure:** the test fails from step 4 until [#24](https://github.com/chili-chips-ba/openCologne-PCIE/issues/24) is fixed (upstream [gatemate-pipe#15](https://github.com/colognechip/gatemate-pipe/issues/15)): the DLL has no REPLAY_TIMER, so a TLP whose END is hit is never Naked or replayed, and the EP stops sending TLPs. Steps 1 to 3 pass. The run below is from before the SerDes model update, when the step-4 flips passed by chance.

Every TLP the two DLLs send has its LCRC checked on the way out, against a CRC-32 the testbench computes over the sequence number and the TLP bytes; in step 6 also its length.

```
[   80256.0 ns] LINK : both MACs in L0, LinkUp
=== Step 1: DLL initialisation, InitFC1/InitFC2 across the link ===
[   83164.0 ns]   both DLLs DL_Active
  ...
=== Step 4: TLP corrupted on the EP -> RC wire, expect NAK and replay ===
[  100348.0 ns]   RC received 6 DW, checked
[  101596.0 ns]   RC 8b/10b decoder flagged 2 symbol beats
[  101596.0 ns]   EP sent the TLP 2 times, NAK and replay worked
  ...
=== Step 6: TLPs with an odd number of DW, the last word half ===
[  104540.0 ns]   RC received 3 DW, checked
[  107100.0 ns]   EP sent it once, 12 TLP bytes on the line
  ...
[  135196.0 ns] LINE : 15 TLPs, LCRC checked, 0 wrong
  SUMMARY: 0 errors
  TEST PASSED
```

### The Root Complex side

The MAC implements the upstream port. The Root Complex is a second instance of the same MAC, which the testbench gives the downstream port role with `force`:

* in Configuration it transmits link number 0, and from Config.Linkwidth.Accept on lane number 0 (`expected_Link`, `expected_Lane`)
* in Config.Linkwidth.Accept and Config.Lanenum.Accept it accepts both TS1 and TS2 (`TS1_pattern_en`, `TS2_pattern_en`)

### Settings

* scrambling is disabled in both MACs, as with `DISABLE_SCRAMBLING` in the MAC's pcievhost test
* the SerDes is set up and clocked as in Cologne Chip's `ccfpga_pipe_wrapper.v`: `PLL_FCNTRL = 6'h1A`, a 62.5 MHz PLL clock, the SerDes TX and RX core clock on the PIPE logic's `o_tx_clk`, so PCLK and the SerDes word clock are both 31.25 MHz
* the PIPE reset is released 256 `clk_reg` cycles after the global reset, the MAC and DLL reset once the SerDes reports ready, synchronised to PCLK
* the DLL gets `phy_linkup` when the MAC reports link up and the LTSSM is in L0
* the bit errors in steps 4 and 7 are short inversions of the serial pair, starting 176 ns after the STP leaves the EP's MAC, so they hit the TLP; the RC NAKs it only once #24 is fixed
