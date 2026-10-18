# VProc
Virtual processor co-simulation and co-design element for Verilog and VHDL environment. 

Allows native C/C++ programs or Python scripts to co-simulate with Verilog, SystemVerilog or VHDL simulations, with a memory mapped read/write interface and support to model interrupts. This enables virtually limitless possibilities for control of a simulation from C/C++ or Python programs, running as if on the instantiated virtual processor in the logic simulation. User code could be as simple as linear test program to drive pattrens on the bus, software models of processors and other SoC components, or embedded software, amongst other things. The software running on the virtual processor can be debugged using such standard tools such as <tt>gdb</tt> and related IDE applications such as Eclipse.

Currently supported simulators:

 * Questa : Verilog with VPI, VHDL with FLI
 * Icarus : Verilog with VPI
 * Vivado Xsim : SystemVerilog with DPI-C
 * Verilator : SystemVerilog with DPI-C
 * NVC : VHDL with VHPIDIRECT
 * GHDL : VHDL with VHPIDIRECT

More information can be found in the documentation located in <code>doc/VProc.pdf</code> and related articles on virtual processors, co-simulation and VProc can be found <a href="https://www.linkedin.com/pulse/vproc-virtual-processor-vip-simon-southwell-pjmpe">here</a> and <a href="https://www.linkedin.com/pulse/extending-power-logic-simulations-using-programming-part-southwell-1e">here</a> to complement the information in the manual.

<hr>

### VProc HDL component
The diagram below shows the VProc component that's instantiated in the HDL.
<p align="center">
<img src="https://github.com/wyvernSemi/vproc/assets/21970031/71f770ac-5c5f-401c-bab2-4e3f376dba65" width=800>
</p>
<hr>

### VProc stack with Python
The diagram below shows the stack for node 0 from the HDL environment (Verilog in this diagram) through to the user code&mdash;in this case, python. For the C/C++ environment, the stack tops out at <tt>VUserMain0()</tt> as the user code entry point, with any additional user hiearchy on top of this.
<p align="center">
<img src="https://github.com/wyvernSemi/vproc/assets/21970031/523db26f-e23b-4f26-9019-6fe985c9cb62" width=700>
</p>

Copyright &copy; 2024 Simon Southwell. All rights reserved.
