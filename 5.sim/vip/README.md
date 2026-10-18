# Co-simulation VIP: upstream copies

The files of the [wyvernSemi](https://github.com/wyvernSemi) models this test bench builds, with LF line endings and [our changes](../README.md#vip-versions-and-local-changes). GPL-3.0-or-later, by Simon Southwell (each folder has its `LICENSE`).

| Folder | Upstream | Version |
|---|---|---|
| `vproc` | [wyvernSemi/vproc](https://github.com/wyvernSemi/vproc) | `VERSION_1_13_4` (8fa7a6d) |
| `pcievhost` | [wyvernSemi/pcievhost](https://github.com/wyvernSemi/pcievhost) | `VESRSION_1_9_3` (sic, 77d6462) |
| `mem_model` | [wyvernSemi/mem_model](https://github.com/wyvernSemi/mem_model) | `main` c7b9c62 |
| `rv32` | [wyvernSemi/rv32](https://github.com/wyvernSemi/rv32) | `main` 774d84f |

Only the files the build uses are here; docs and examples stay upstream. [`../tools/build-vip.sh`](../tools/build-vip.sh) builds them.

To upgrade: set the new version in [`../tools/vip-import.sh`](../tools/vip-import.sh), run it, update this table, run both simulators.
