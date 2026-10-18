[Back to **README**](README.md)

# Contributing to openCologne-PCIE

## Found something?

Open an [Issue](https://github.com/chili-chips-ba/openCologne-PCIE/issues). For bugs, include how to reproduce it: a modified [co-sim](5.sim), a waveform, or logs.

## Want to change something?

1. Bigger change? Open an Issue first, so we agree on the approach
2. Fork, branch off `main`, make the change
3. QA process:
   - **[run-lint](https://github.com/chili-chips-ba/openPCIE/blob/main/4.build/hw_build.openXC7/run-lint.sh)** shows no errors. Fix lint findings at the root. Waive only as the last resort, following steps in [run-lint-waivers.txt](https://github.com/chili-chips-ba/openPCIE/blob/main/4.build/hw_build.openXC7/run-lint-waivers.txt).
   - **[run-format --check](https://github.com/chili-chips-ba/openPCIE/blob/main/4.build/hw_build.openXC7/run-format.sh)** passes.
   - Ensure that **[co-sim](5.sim)** and the block-level flows you touched (**[PHY](2.rtl/1.phy/3.sim)**, **[DLL over PHY](2.rtl/4.dll/sim)**) pass
   - and that the **[GateMate build](4.build)** completes.
   - For a mere cleanup: **[run-leq](https://github.com/chili-chips-ba/openPCIE/blob/main/4.build/hw_build.openXC7/run-leq.sh)** to prove that are no functional changes.

4. Open a Pull Request against `main`.

RTL changes go to [2.rtl](2.rtl). Code mirrored from [gatemate-pipe](https://github.com/colognechip/gatemate-pipe) (`2.rtl/4.dll/dll_src`, the `pipe_src` and `mac_src` submodules) changes upstream first. Observe our [RTL coding rules](2.rtl/README.md#rtl-coding-rules).

## License

Soft code is BSD-3-Clause. PCB hardware is CC-BY-SA-4.0 ([REUSE.toml](REUSE.toml)). Your contribution takes the license of the files it goes into. New files need an SPDX header; `reuse lint` must pass.

## GenAI

Allowed, if:

- you understand and take responsibility for every line,
- no third-party copyrighted content gets in,
- you say in the Pull Request which tool and model you used, and for what.

Purely AI-generated work is not accepted. This follows [NLnet's GenAI policy](https://nlnet.nl/foundation/policies/generativeAI/), our funder.

-----------
#### End-of-Document
