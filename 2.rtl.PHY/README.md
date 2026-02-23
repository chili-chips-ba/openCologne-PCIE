# PIPE PHY

This is work area for the CologneChip PHY PIPE developers.

#### References:
- [GateMate PIPE repo](https://github.com/colognechip/gatemate-pipe) ✔
- [GateMate datasheet](https://colognechip.com/docs/ds1001-gatemate1-datasheet-latest.pdf)
- [CologneChip PHY/PIPE Overview](0.doc/PIPE_overview.pdf)
- [Unified PIPE Spec, Sept.2025, v7.1](0.doc/Intel.643108_PIPE_Arch_Spec_Rev_7_1.pdf)
- [Optimizing PCIE PIPE Power Management](https://www.synopsys.com/blogs/chip-design/optimizing-pcie-pipe-power-management.html)
- [TUSB1310A USB SuperSpeed PHY with PIPE](https://www.ti.com/product/TUSB1310A)
- [Mithro on SerDes](https://docs.google.com/presentation/d/e/2PACX-1vSgIGVCZtNt8RdifZXOLOJDDCj7g05zxr9WS2NjmQtM_E0GfZKCBYhASCto4eURL-86uNwJaXfo1qMC/pub?start=false&loop=false&delayms=3000#slide=id.g151286a907e_0_230)
- [Yumewatari (whitequark) PHY segments with rudimentary LTSSM](https://github.com/whitequark/Yumewatari/tree/master/yumewatari/gateware)

<p align="center">
  <img width="60%" src="0.doc/images/PHY-Layers.jpg">
</p>

<p align="center">
  <img width="60%" src="0.doc/images/PHY-Layers-GateMate.png">
</p>



## Implementation Details
See [block diagram](0.doc/Physical_layer_block_diagram.pdf).


### SerDes
<p align="center">
  <img width="60%" src="0.doc/images/SerDes-BlockDiagram.png">
</p>

<p align="center">
  <img width="60%" src="0.doc/images/optimizing-pcie-pipe-pwr-mgmt.png">
</p>


**Hai:**
> _"... our PIPE interface does not contain any functionality of the so called "MAC layer" which handles the training sequences, OSs and LTSSM..."_


**Simon**
> The LTSSM, I'd suggest, just needs to be the linear power up sequence from Detect.Quiet  to L0 (Link UP) for first functionality (as per the table on page 14 of the PCIe Primer). Not part of the pcievhost proper, but the model comes with some demonstration code to implement the LTSSM to this spec., so we have a means to test this first implementation.


**Async RefClock?**
> Does GateMate PHY support `Async RefClock`? 

That's when your 100MHz reference clock source comes from a different oscillator that the oscillator used by the Root Complex. They are both nominally 100MHz, but they are still different.


--------------------
#### End of Document
