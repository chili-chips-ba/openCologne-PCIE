# PHY block-level simulation

`tb_phy.sv` tests the PHY: the PIPE layer of [gatemate-pipe](https://github.com/colognechip/gatemate-pipe) on a GateMate SerDes model, or the open SerDes model ([2.serdes-model](../2.serdes-model/)) on its own. `run-phy.sh` compiles one of its tests with Icarus Verilog and runs it. None of them needs the proprietary SerDes sources. The layers above get their own block-level flows (the DLL over this PHY: [4.dll/sim](../../4.dll/sim/)); the top level is [5.sim](../../../5.sim/).

| test | what it exercises | run time |
|---|---|---|
| `pipe64` | 64-bit PIPE + SerDes: TS1 ordered sets, test data, error detection and RxStatus | ~14 s |
| `pipe16` | the same with a 16-bit PIPE: **fails today**, see below | ~14 s |
| `equiv` | the open SerDes model alone, looped back: training, alignment, a marker word through, its latency | ~2 s |
| `equiv --ref` | the open and the vendor model side by side, same stimulus, outputs and latency compared | ~30 s |
| `equiv --ref --cross` | each model's TX into the other's RX: the two models talking to each other | ~30 s |

```sh
git submodule update --init                # the PIPE sources are a submodule
bash 2.rtl/1.phy/3.sim/run-phy.sh pipe64   # open SerDes model
bash 2.rtl/1.phy/3.sim/run-phy.sh pipe64 --vendor
bash 2.rtl/1.phy/3.sim/run-phy.sh equiv
bash 2.rtl/1.phy/3.sim/run-phy.sh equiv --ref --cross
```

`--dump` writes a waveform. Build products and waveforms go to `$SERDES_BUILD_DIR` (default `~/.cache/opencologne-pcie`), outside the repository. Tested with Icarus Verilog 13.

## The two tests in `tb_phy.sv`

One file, one `module tb_phy` per test, chosen at compile time:

* **PIPE test** (default): the testbench and testcase of gatemate-pipe (`tb_ccfpga_serdes.v`, `testcase_pipe.v`, merged here). `DATA_BYTES` sets the PIPE width (`-Ptb_phy.DATA_BYTES=2` or `8`). The SerDes bring-up is done with `writeCfg` / `writeRegfile` tasks.
* **Model check** (`TB_PHY_EQUIV`): the open model with its TX looped back to its RX. Training words (a comma and fillers) until the receiver aligns, then a marker word, which must come out intact; the latency is printed. With `HAVE_VENDOR_SERDES` the vendor model runs beside it, `CROSS_LINK` links the two.

## Known failure: `pipe16`

The 16-bit PIPE gets its PCLK from a `CC_PLL` at 4x the SerDes core clock, which feeds a 4-to-1 multiplexer onto the 64-bit SerDes word. In gatemate-pipe (`ccfpga_pipe_logic.v`, 16-bit branch) that `CC_PLL` is commented out and PCLK is the core clock itself, so three of every four 16-bit words are lost. The fault is in the PIPE RTL ([#18](https://github.com/chili-chips-ba/openCologne-PCIE/issues/18)); the test passes once the PLL is back.

## The vendor model

The vendor SerDes model is under NDA and is never in this repository. `--vendor` and `--ref` copy it from `$CCFPGA_SERDES_SRC` (default `~/Downloads/ccfpga_serdes/src`) into the build folder for the run and delete the copy afterwards (`--keep` keeps it). `serdes_nda_env.sh` stops every run if vendor sources are found inside the repository.

```sh
export CCFPGA_SERDES_SRC=/path/to/ccfpga_serdes/src
bash 2.rtl/1.phy/3.sim/run-phy.sh equiv --ref
```
