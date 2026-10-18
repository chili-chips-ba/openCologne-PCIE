# High speed C/C++ based behavioural Verilog an VHDL co-simulation memory model 

<p align="center">
<img src="https://github.com/user-attachments/assets/909dd373-976a-4d48-97ba-32c3c46f76df" width=800>
</p>

The mem_model component is a Verilog/VHDL simulation test component that allows for a very large memory address space without reserving large amounts of memory, defining large HDL arrays, or building a truncated memory map into a test bench which could be subject to change in the design. The model uses the simulators' programming interfaces to access a C model, pushing the majority of the functionality away from the simulator, making the test bench lightweight, and the memory accesses very fast in simulation compute time.

A direct access API is also provided to allow any other PLI C/C++ code to transfer data directly, without the overhead of simulating bus transactions (see <tt>src/mem.h</tt>). Wrapper HDL is also provided to map the ports to an AXI subordinate interface (<tt>mem_model_axi.v</tt> and <tt>mem_model_axi.vhd</tt>). The default memory mapped slave port and burst ports are Altera Avalon bus compatible.

By default memory is uninitialised but, if compiled with <tt>MEM_ZERO_NEW_PAGES</tt> defined, memory will be initialised with zeros. By default, the model is big endian, but this can be overridden by defining <tt>MEM_MODEL_DEFAULT_ENDIAN=1</tt>.

The model's software can be compiled for supporting various HDL languages, with the default being Verilog and using the PLI programming interface. To compile for the VPI interface, <tt>MEM_MODEL_PLI_VPI</tt> should be defined when compiling the <tt>mem_model.c</tt> code. When using VHDL then <tt>MEM_MODEL_VHDL</tt> should be defined. If using the SystemVerilog model then <tt>MEM_MODEL_SV</tt> should be defined. The model's code, when used with VProc, will also recognise the VProc definitions (<tt>VPROC_PLI_VPI</tt>, <tt>VPROC_VHDL</tt>, and <tt>VPROC_SV</tt>) and if these are defined when compiling the code, then the <tt>MEM_MODEL_XXX</tt> definitions do not need to be set which are needed only when compiling as a standalone model. If compiling as a stand alone model (i.e. not compiled with VProc) then <tt>MEM_MODEL_INTERNAL_PLI</tt> must be defined to enable registration of PLI routines when compiling Verilog in Questa and Icarus.

If using Verilog or SystemVerilog models, then the <tt>tx_byteenable</tt> port is enabled by defining <tt>MEM_EN_TX_BYTEENABLE</tt> when analysing either <tt>mem_model.v</tt> or <tt>mem_model.sv</tt>.

## Summary of HDL files and minimum compile options for each simulator

| Simulator          | HDL files                      | C compilation definitions                 |
|:-------------------|:-------------------------------|:------------------------------------------|
| *Questa Verilog*   | <tt>mem_model_q.v</tt>         | <tt>[-DMEM_MODEL_PLI_VPI]</tt> <tt>[-DMEM_MODEL_INTERNAL_PLI]</tt> |
|                    | <tt>mem_model.v</tt>           |                                           |
|                    | <tt>[mem_model_axi.v]</tt>     |                                           |
|                    |                                |                                           |
| *Icarus Verilog*   | <tt>mem_model_q.v</tt>         | <tt>[-DICARUS -DMEM_MODEL_INTERNAL_PLI]</tt>|
|                    | <tt>mem_model.v</tt>           |                                           |
|                    | <tt>[mem_model_axi.v]</tt>     |                                           |
|                    |                                |                                           |
| *Verilator*        | <tt>mem_model_q.v</tt>         | <tt>-DMEM_MODEL_SV</tt>                   |
|                    | <tt>mem_model.sv</tt>          |                                           |
|                    | <tt>[mem_model_axi.sv]</tt>    |                                           |
|                    |                                |                                           |
| *Vivado xsim*      | <tt>mem_model_q.v</tt>         | <tt>-DMEM_MODEL_SV</tt>                   |
|                    | <tt>mem_model.sv</tt>          |                                           |
|                    | <tt>[mem_model_axi.sv]</tt>    |                                           |
|                    |                                |                                           |
| *Questa VHDL*      | <tt>mem_model_pkg.vhd</tt>     | <tt>-DMEM_MODEL_VHDL</tt>                 |
|                    | <tt>mem_model_q.vhd</tt>       |                                           |
|                    | <tt>mem_model.vhd</tt>         |                                           |
|                    | <tt>[mem_model_axi.vhd]</tt>   |                                           |
|                    |                                |                                           |
| *NVC*              | <tt>mem_model_pkg_nvc.vhd</tt> | <tt>-DMEM_MODEL_VHDL</tt>                 |
|                    | <tt>mem_model_q.vhd</tt>       |                                           |
|                    | <tt>mem_model.vhd</tt>         |                                           |
|                    | <tt>[mem_model_axi.vhd]</tt>   |                                           |
|                    |                                |                                           |
| *GHDL*             | <tt>mem_model_pkg_ghdl.vhd</tt>| <tt>-DMEM_MODEL_VHDL</tt>                 |
|                    | <tt>mem_model_q.vhd</tt>       |                                           |
|                    | <tt>mem_model.vhd</tt>         |                                           |
|                    | <tt>[mem_model_axi.vhd]</tt>   |                                           |

More details can be found in the manual&mdash;<tt>doc/mem_model_manual.pdf</tt>.
