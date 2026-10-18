# PCB Description

This is work area for the PCB-related thoughts and explanations, including the steps and results for conducting high-speed [openEMS](https://docs.openems.de) simulations.

### M2 card
<p align="center">
   <a href="https://canva.link/vyykwt6k7odhs3t" target="_blank" rel="noopener">
     <img width="70%" alt="ULX5M-M2 promo video (click to watch with sound)" src="../0.doc/1.pcb/Intergalaktik-ULX5M.png">
  </a>

  <img alt="ULX5M M.2 card, top side" width="36%" src="../0.doc/1.pcb/ulx5m-m2.1--Top.jpg">
  <img alt="ULX5M M.2 card, bottom side" width="45%" src="../0.doc/1.pcb/ulx5m-m2.2--Bottom.jpg">
  
</p>

For additional detail, check the source repo:
 - [x] https://github.com/intergalaktik/ulx5m-m2

  
### Edge card
Just for illustration, and to get the ball rolling, here is an earlier attempt at PCIE "Slot" EndPoint card. Stay tuned for more...

<p align="center">
  <img alt="Earlier ULX4M PCIe slot edge card prototype" width="45%" src="../0.doc/1.pcb/ULX4M-PCIe-IO.beta_v2.png">
</p>


### Form factors and hosts

The PCB part of the project shall deliver two cards: GateMate in **(i) PCIE "Slot"** and **(ii) M.2** form-factors
<p align="center">
  <img alt="PCIe slot connector" width="20%" src="../0.doc/1.pcb/PCIE-Slot-Connector.JPG">
  <img alt="NiteFury M.2 PCIe FPGA card" width="35%" src="../0.doc/1.pcb/NiteFury-PCIE-M2.JPG">
</p>

While the "Slot" variant is not critical, and could have been suplanted by one of the ready-made M.2-to-Slot adapters, 

<p align="center">
  <img alt="PCIe slot to M.2 adapter" width="40%" src="../0.doc/1.pcb/PCIE-Slot-to-M2-adapter.JPG">
</p>

it is more practical not to have an interposer. "Slot" is still the dominant PCIE form-factor for desktops and servers. The M.2 is typically found in the laptops. Initially, we will use the existing [CM4 ULX4M](https://github.com/intergalaktik/ULX4M) with off-the-shelf I/O boards:

<p align="center">
  <img alt="Raspberry Pi CM4 IO board with PCIe slot" width="40%" src="../0.doc/1.pcb/CM4-IO-with-PCIE-Slot.jpg">
  <img alt="Raspberry Pi CM4 IO board with PCIe M.2" width="40%" src="../0.doc/1.pcb/CM4-IO-with-PCIE-M2.jpg">
</p>

When our two new plug-in boards become available, the plan is to gradually switch thedev platform to our openPCIE backplane, which features:
- Slots on one side
- M.2s on the other
- RootComplex also as a plug-in card (as opposed to the more typical soldered-down), for interoperability testing with [RaspberryPi](https://www.raspberrypi.com) and Xilinx Artix-7 .
- on-board (soldered-down) PCIE Switch for interoperability testing of the most typical EP deployment scenario, which is when RootPort is not directly connected to EndPoints, but goes through a Switch.

<p align="center">
  <img alt="PCIe interoperability with Raspberry Pi 5" width="40%" src="../0.doc/1.pcb/PCIE-interop-with-RPI5.png">
</p>

#### References:
- [GateMate Evaluation Board, DS1003](../0.doc/1.pcb/ds1003-GateMate-EVB-datasheet.Jan2024.pdf) and its [schematics, rev 3v2](../0.doc/1.pcb/ds1003-GateMate-EVB-3v2-schematics.Jan2024.pdf) by Cologne Chip, January 2024: the board of the SerDes PRBS test
- [GateMate A2 GPIO Bank Allocation, UG1004](../0.doc/1.pcb/ug1004-GateMate-A2-GPIO-allocation.Jun2025.pdf) by Cologne Chip, June 2025
- [USB3 PHY for GateMate](https://nlnet.nl/project/GateMate-USB3-PHY)
- [KiCad and openEMS](https://www.youtube.com/watch?v=VcJqhsbzR3c)
- [Automated PCB trace selection for SI simulation](https://antmicro.com/blog/2024/07/automated-pcb-trace-selection-for-si-simulation)
- [ULX4M-PCIe-IO](https://github.com/intergalaktik/ULX4M-PCIe-IO)
- [openPCIE Backplane](https://github.com/chili-chips-ba/openPCIE/tree/main/1.pcb)
- [NiteFury-and-LiteFury](https://github.com/RHSResearchLLC/NiteFury-and-LiteFury)
- [4-port M.2 PCIE Switch](https://github.com/will127534/CM4-Nvme-NAS)
- [AntMicro EMS Sim](https://antmicro.com/blog/2025/07/recent-improvements-to-antmicros-signal-integrity-simulation-flow)
- [openEMS](https://docs.openems.de)

--------------------
#### End of Document
