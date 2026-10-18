# PCIE TLP decoder for WaveCrux

openPCIE's [WaveCrux](https://wavecrux.app) plugin, copied unchanged: it names every TLP and pairs each completion with its request. Full documentation and pictures: [openPCIE's README](https://github.com/chili-chips-ba/openPCIE/blob/main/5.sim/tools/wavecrux-pcie-tlp/README.md). Needs WaveCrux 1.0.1 or later, any edition.

| File | |
|---|---|
| `pcie_tlp_decoder.c` | the decoder |
| `pcie_tlp_decoder.dll` | prebuilt, Windows x64 |
| `wavecrux_decoder.h` | the plugin C ABI, from the [WaveCrux open core](https://github.com/Ferrite-Engineering/wavecrux/blob/main/include/wavecrux_decoder.h) (Apache-2.0) |

Install: WaveCrux **Settings -> Extensions -> Decoder Plugins**, accept the notice, **Add directory...** this one, **Reload plugins**. Load only one copy: openPCIE's and this one register the same decoder IDs, and WaveCrux rejects the second.

Rebuild (WSL): `x86_64-w64-mingw32-gcc -shared -O2 -static-libgcc -o pcie_tlp_decoder.dll pcie_tlp_decoder.c`

Inputs: one TLP DW per clock (`clk`, `tlp_data`, `tlp_sop`, `tlp_eop`, `tlp_valid`, optional `peer_*`), as [`tlp_dw_monitor.sv`](../../models/tlp_dw_monitor.sv) produces it. With `DUT=mock` the test bench has no TLP stream to tap: both ends are pcieVHost, and only the scrambled PIPE link is visible. The TLP session comes with `DUT=rtl`, tapping the SOC's AXI-Stream as on openPCIE.
