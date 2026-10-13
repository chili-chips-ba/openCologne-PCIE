# Formal verification of the open 8b/10b codec

Proofs for the 8b/10b encoder and decoder used by the open GateMate SerDes model
([2.rtl/1.phy/2.serdes-model](../../2.rtl/1.phy/2.serdes-model/)). The
properties include `ccfpga_serdes_8b10b.vh`, the same file the simulation model
includes, so what is proved here is the code that runs in simulation.

```sh
cd 4.build/formal
./run_formal.sh
```

Needs `yosys` (tested with 0.30) and `iverilog` on `PATH`.

| property | proved by | statement |
|---|---|---|
| `fv_enc_disparity` | yosys SAT | the encoder never emits a symbol with illegal disparity |
| `fv_enc_rd_tracking` | yosys SAT | the reported running disparity matches the emitted symbol |
| `fv_comma_format` | yosys SAT | K28.5 encodes to the vendor's `ALIGN_PCOMMA_VALUE` / `ALIGN_MCOMMA_VALUE` |
| `fv_injective` | yosys SAT | no two inputs share an encoding, so the decode table is well defined |
| `fv_run_length` | yosys SAT | no run of more than five identical bits on the wire |
| exhaustive decode | Icarus | every data and control character decodes back to itself, in both disparities |

Each SAT property is a combinational module with a single `ok` output. Yosys
asks its SAT solver for any input that makes `ok` 0; "no model found" means the
property holds for every input. The decode table is a procedurally initialised
memory, which the SAT flow cannot take, so it is checked by enumerating its whole
input space instead.

Background, and why full equivalence checking against the vendor model is not
applicable: [equivalence-checking.md](../../2.rtl/1.phy/2.serdes-model/0.doc/equivalence-checking.md).
