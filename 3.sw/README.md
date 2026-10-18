# SW Architecture

This is where the developers of **PIO TestApp** (the software part of) describe their work.

### HW/SW Architecture

<p align="center"><img src="../0.doc/3.sw/sw-structure.drawio.svg" width="100%" alt="Firmware layers: application, PCIE driver, HAL, register map and startup, talking to the CSR block over the CPU memory bus, then through pcie_top to the PCIE link"></p>

We plan on creating not one, but three "Getting Started" examples, for the three representative compute platforms:
1) **Hard Embedded / Hosted**: RaspberryPi
2) **Soft Embedded / BareMetal**: Artix-7 FPGA acting as a RootComplex with soft on-chip RISC-V CPU
3) **General-purpose desktop/server class**: PC

## 1) RaspberryPi as RootPort

## 2) Artix-7 FPGA as RootPort

## 3) PC as RootPort


--------------------
#### End of Document
