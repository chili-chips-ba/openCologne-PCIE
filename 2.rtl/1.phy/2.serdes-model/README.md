# Open-source behavioural model of the GateMate SerDes

`ccfpga_serdes.v` is an open-source behavioural simulation model of the GateMate
SerDes hard macro. It has the same module name, port list, parameter names and
defaults as the CologneChip simulation model, so it is a drop-in replacement:
point the file list at this directory and nothing else in the design or the
testbenches changes.

It is a protocol-level model for simulation only. For hardware, the design
instantiates the `CC_SERDES` primitive, as `ccfpga_pipe_wrapper.v` does.

| file | content |
|---|---|
| `ccfpga_serdes.v` | the model |
| `ccfpga_serdes_8b10b.vh` | 8b/10b encoder, also used by the formal proofs in `4.build/formal` |
| `ccfpga_serdes_8b10b_dec.vh` | 8b/10b decode table |
| `0.doc/equivalence-checking.md` | how the model is verified against the vendor model |

Running the PIPE testcase `5.sim/testcase_pipe.v` (64-bit datapath, Icarus
Verilog 12, wall clock including compilation):

| model | wall clock | simulated time | result |
|---|---|---|---|
| vendor `ccfpga_serdes` | 5 min 16 s | 314.7 us | PASSED |
| this model | ~14 s | 314.7 us | PASSED |

---

## Usage

```sh
iverilog -g2012 -I 2.rtl/1.phy/2.serdes-model \
         2.rtl/1.phy/2.serdes-model/ccfpga_serdes.v  <design and testbench files>
```

The bring-up is the same as for the silicon: enable the SerDes in the config
file (`0x5C = 0x0001`), then select the configuration and enable the ADPLL in
`PLL_CFG0` (`0x50 = 0x0002`, then `0x0003`). `5.sim/phy_pipe_serdes.v` does this
with a small FSM, `5.sim/testcase_pipe.v` with `writeCfg` / `writeRegfile` tasks.

---

## What is modelled

Everything the PIPE layer and the PCIE stack above it can observe:

* **Register file / config file** - the address map (`0x00`-`0x42` RX/TX,
  `0x50`-`0x5B` PLL, `0x5C` SERDES_CFG), masked writes, the `regfile_rdy_o`
  handshake, and the `serdes_en` / `en_adpll_ctrl` decode used by the bring-up
  sequence. Status registers of unmodelled blocks read back as "converged", so
  code that polls them completes.
* **PLL** - line rate derived from `PLL_FCNTRL` / `PLL_MAIN_DIVSEL` /
  `PLL_OUT_DIVSEL`: `f_line = f_ref * N1*N2*N3*2 / M3`, core clock
  `= f_line / 80`. For the Gen1 setup (100 MHz reference, `MAIN_DIVSEL`
  `6'b011011`, `OUT_DIVSEL` `2'b01`) that is 2.5 Gb/s and a 31.25 MHz core clock.
  The reference period is measured at run time.
* **TX** - 8b/10b encoding with running disparity, `tx_char_dispmode` /
  `tx_char_dispval` forcing, per-byte `tx_8b10b_bypass`, elastic TX buffer with
  overflow/underflow reporting, serializer, electrical idle, polarity inversion,
  PRBS7/15/23/31 generator with error injection.
* **Serial link** - a bit-level serial interface on `TX_SERIO_P_B` /
  `TX_SERIO_N_B`, one simulation event per unit interval.
* **RX** - bang-bang CDR with phase and lock detector, deserializer, comma
  detect, byte and word alignment honouring `ALIGN_MCOMMA_VALUE` /
  `ALIGN_PCOMMA_VALUE` / `ALIGN_COMMA_ENABLE` / `ALIGN_COMMA_WORD`, manual bit
  slide, polarity inversion, 8b/10b decode with `rx_not_in_table_o` and
  `rx_disp_err_o`, elastic RX buffer, PRBS checker.
* **Reset sequencers** - TX and RX, honouring the PMA/PCS/CDR/EQA/BUF reset
  timers and `RX_RESET_TIMER_PRESC`, and gating `rx_resetdone_o` on CDR lock when
  `RX_WAIT_CDR_LOCK` is set.
* **Receiver detect**, **electrical idle detect**, **PCS and PMA loopback**.

### Implementation notes

**Electrical idle is time-filtered.** `TX_SERIO_P_B` and `TX_SERIO_N_B` are
separate signals, so at every bit transition there is a delta cycle in which
they read equal. Like the envelope detector in silicon, the model declares idle
only after the pair has been quiet for 20 UI. 8b/10b guarantees a transition at
least every 5 UI, so live traffic never looks idle.

**Comma alignment is an acquisition request.** A K28.5 bit pattern also appears
inside ordinary data, straddling two symbols. The first comma after a rising
edge on `rx_mcomma_align_i` / `rx_pcomma_align_i` sets the framing, later commas
do not move it. This is how `ccfpga_pipe_fsm_word_align.v` uses the interface:
it raises the align enables in `ALIGN_START` and drops them once
`rx_byte_is_aligned_o` is set.

**RX parallel outputs have a clock-to-q delay.** The RX data, K, comma and error
outputs change `BHV_RX_TCO_NS` (100 ps) after the `clk_core_rx_i` edge, like a
flip-flop output. Logic clocked by a clock that is derived from the same edge,
such as the 64-bit PIPE PCLK divided from `clk_core_pll_o`, therefore samples
them consistently.

---

## What is not modelled

None of this is observable at the PIPE interface:

* **Analog / PMA internals** - driver taps and pre/post emphasis, termination
  calibration, AFE gain and peaking, DFE adaptation, eye measurement, common-mode
  detection.
* **ADPLL internals** - DCO tuning words, BISC, SAR calibration. The PLL locks
  after `BHV_PLL_LOCK_TIME_NS`.
* **Scan chain and debug SRAM capture.**

Their status registers report "done" / "locked".

Signal integrity, jitter tolerance and equalisation are outside the scope of a
digital simulation. On this project they are covered by hardware measurements on
the GateMate EVK, see [`../1.serdes-tests/`](../1.serdes-tests/).

---

## Model-only parameters

Additions to the vendor parameter list. Instantiation is by name, so the vendor
parameter set works unchanged.

| parameter | default | meaning |
|---|---|---|
| `BHV_PLL_LOCK_TIME_NS` | `500.0` | PLL lock delay. `35200.0` matches the vendor timing. |
| `BHV_REF_CLK_MHZ` | `0.0` | Reference frequency. `0.0` = measure `clk_ref_i` at run time. |
| `BHV_RX_PRESENT` | `1` | Result reported on `rx_present_o` for a receiver detect. |
| `BHV_RX_DETECT_TIME_NS` | `120.0` | Receiver detect duration. |
| `BHV_CDR_KP` | `0.125` | CDR loop gain. `1.0` = instant relock on every edge. |
| `BHV_CDR_LOCK_EDGES` | `32` | In-window edges required before CDR lock. |
| `BHV_VERBOSE` | `0` | Non-zero enables `$display` tracing of internal events. |
| `BHV_RX_PIPE_STAGES` | `9` | RX output pipeline depth, matches the vendor latency. |
| `BHV_RX_TCO_NS` | `0.1` | Clock-to-q of the RX parallel outputs. |

---

## Where it is used

| flow | what runs on top of the model |
|---|---|
| [`5.sim/serdesflow_dll`](../../../5.sim/serdesflow_dll) | DLL, MAC/LTSSM, PIPE and this SerDes, two link partners over a serial link |
| [`5.sim/serdesflow_mod`](../../../5.sim/serdesflow_mod) | the PIPE testcase, with `SERDES_MODEL=open` |
| [`5.sim/serdesflow_equiv`](../../../5.sim/serdesflow_equiv) | equivalence and interoperability against the vendor model |

---

## Verification

Described in [`0.doc/equivalence-checking.md`](0.doc/equivalence-checking.md).

```sh
cd 5.sim
./serdesflow_equiv                 # self-check, ~2 s
./serdesflow_equiv --ref           # against the vendor model
./serdesflow_equiv --ref --cross   # the two models linked to each other

cd ../4.build/formal
./run_formal.sh                    # SAT proofs and exhaustive decode check
```

Current results:

```
formal          6 proved, 0 failed
equivalence     400 words, 0 divergences, latency delta 0.0 ns
cross-linked    400 words, 0 mismatches in both directions
testcase_pipe.v PASSED, 101 check tasks, 0 errors
```

### Vendor sources

The vendor model is under NDA and is not part of this repository.
`serdesflow_equiv` and `serdesflow_mod` take it from outside the repository
through `5.sim/serdes_nda_env.sh`:

| | |
|---|---|
| originals | `$CCFPGA_SERDES_SRC`, default `$HOME/Downloads/ccfpga_serdes/src`, read only |
| working copy | `$SERDES_BUILD_DIR`, default `$HOME/.cache/opencologne-pcie` |
| after the run | the copy is deleted (`serdesflow_equiv --keep` keeps it) |
| vendor files inside this tree | the scripts stop and ask to move them out |

The working copy declares the untyped real parameters of the vendor sources as
`parameter real`, which Icarus Verilog 12 needs. The originals are not changed.
