# _openCologne-PCIE_ DUT stand-in: `EPPIPEx1__pcieVHost_DUT`

[`EPPIPEx1__pcieVHost_DUT.sv`](EPPIPEx1__pcieVHost_DUT.sv) can take the place of the DUT, the EP RTL + firmware, so the test bench and the host can be brought up and checked on their own. It is an option we keep, next to the RTL: `make DUT=mock` runs it, `make DUT=rtl` the real EP once it exists. Its name mirrors the host's, `RCPIPEx1__pcieVHost`: the same model, in the other role.

The stand-in is a single `pcieVHostPipex1`, the PIPE wrapper of the pcieVHost model, configured as an EP at VProc node 2 and running [`../usercode/VUserMain2.cpp`](../usercode/VUserMain2.cpp). It has the ports the real EP will show the test bench:

- PIPE data out and in, 64 bits wide with one K flag per byte, as Cologne Chip's PIPE
- `pclk` (the PIPE clock, `pcieclk`/8 for 64 bits) and `pcieclk` (the 250 MHz symbol clock of Gen1)
- an active-low reset
- under Verilator only, the electrical-idle side-band `elec_idle_out` / `elec_idle_in` (see [Running the co-simulation](../README.md#running-the-co-simulation))

Why keep a model-against-model run? It proves the test bench and the host on their own, before and alongside the RTL: when the real EP fails to train, `DUT=mock` shows at once whether the link partner and the test bench are still good, and so whether the fault is on our side.

-----------
#### End-of-Document
