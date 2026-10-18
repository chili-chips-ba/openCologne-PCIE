# The _pcieVHost_ VIP

[_pcieVHost_](https://github.com/wyvernSemi/pcievhost) is a C model of a PCIE 1.1/2.0 link partner, running on a [_VProc_](https://github.com/wyvernSemi/vproc) virtual processor. Here it plays the host, `RCPIPEx1__pcieVHost` ([`../RCPIPEx1__pcieVHost.sv`](../RCPIPEx1__pcieVHost.sv)), and the mock EP, `EPPIPEx1__pcieVHost_DUT` ([`../../stubs`](../../stubs/README.md)).

The model is not copied into this repository: [`5.sim/tools/fetch-vip.sh`](../../tools/fetch-vip.sh) fetches the pinned upstream sources and builds them for Verilator and Icarus. How it is used here: [5.sim README](../../README.md).

Documentation, from upstream:

- [README](https://github.com/wyvernSemi/pcievhost/blob/master/README.md): the HDL component, the C API, the link traffic display, running the model as an EP
- [manual (PDF)](https://github.com/wyvernSemi/pcievhost/blob/master/doc/pcieVHost.pdf)
