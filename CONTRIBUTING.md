[Back to **README**](README.md)

# Contributing to openCologne-PCIE

## Found something?

Open an [Issue](https://github.com/chili-chips-ba/openCologne-PCIE/issues). For bugs, include how to reproduce it: a modified [co-sim](5.sim), a waveform, or logs.

## Want to change something?

1. Bigger change? Open an Issue first, so we agree on the approach
2. Fork, branch off `main`, make the change
3. QA process:
   - **[run-lint](4.build/hw_build/run-lint.sh)** shows no errors. Fix lint findings at the root. Waive only as the last resort, following steps in [run-lint-waivers.txt](4.build/hw_build/run-lint-waivers.txt).
   - **[run-format --check](4.build/hw_build/run-format.sh)** passes.
   - Ensure that **[co-sim](5.sim)** and the block-level flows you touched (**[PHY](2.rtl/1.phy/3.sim)**, **[DLL over PHY](2.rtl/4.dll/sim)**) pass
   - and that the **[GateMate build](4.build)** completes.
   - For a mere cleanup: **[run-leq](4.build/hw_build/run-leq.sh)** to prove that are no functional changes.

4. Open a Pull Request against `main`.

RTL changes go to [2.rtl](2.rtl). Code from [gatemate-pipe](https://github.com/colognechip/gatemate-pipe) (the `2.rtl/2.pipe/pipe_src` submodule: PIPE, MAC/LTSSM, DLL) changes upstream first. Observe our [RTL coding rules](2.rtl/README.md#rtl-coding-rules).

## License

Soft code is BSD-3-Clause. PCB hardware is CC-BY-SA-4.0 ([REUSE.toml](REUSE.toml)). Your contribution takes the license of the files it goes into. New files need an SPDX header; `reuse lint` must pass.

## GenAI

GenAI may be used read-only, as [NLnet's GenAI policy v2.0](https://nlnet.nl/foundation/policies/generativeAI/2.0/) asks of the projects it funds, us included:

- **Allowed:** reviews, a second pair of eyes for QA, suggestions. You write the code, design, docs and fixes yourself.
- **Not allowed:** code, design or docs produced by GenAI.
- You understand and take responsibility for every line, and can explain it.
- No third-party copyrighted content gets in.
- Say in the Pull Request which tool and model (with version) you used, and for what. Best also in the commit message, as a `GenAI:` line.

-----------
#### End-of-Document
