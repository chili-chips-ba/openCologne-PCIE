
![announce](https://github.com/user-attachments/assets/4f693d40-657f-4ce8-b9b1-38bef1d5c17c)

# rv32 RISC-V 32-bit Instruction Set Simulator

The rv32 instruction set simulator (ISS) is a highly configurable and extensible C++ model of a 32-bit
RISC-V core capable of running at speeds of >10MIPS (executing a test program with
concurrent processes on FreeRTOS, running on an i5-8400 core @2.80GHz). A summary of
the model's main features is shown below.

* RV32I ISA model
  * Support for RV32E via compile option
* Standard extensions support
  * Zicsr extensions, with CSR instructions and registers
  * RV32G extensions (configurable)
    * RV32M (multiply/divide)
    * RV32A (atomic)
    * RV32F (floating point)
    * RV32D (double precision floating point)
  * RV32C compression extensions (configurable)
  * RV32B (bit manipulation)
    * RV32Zba, RV32Zbb, RV32Zbs
  * RV32Zbc (carry-less multiply)
  * Zicntr extensions, with emulated `rdtime[h]` instructions
* Single HART
* Machine (M) privilege mode supported
* Trap handling (with Zicsr extension)
* Configurable instruction timing model
* Internal timer model using cycle count or real-time clock
* Instructions retired count
* Interrupt handling (with Zicsr extension)
  * External interrupts
  * Timer interrupts
  * Software interrupts
* Internal memory model (1MBytes)
* User registerable external callback functions
  * For memory accesses
  * For interrupts
  * For unimplemented instructions
* Disassembler, both run-time and static
* Loading of ELF or binary programs to memory
* Model execution performance metrics
* Debugging interface for gdb remote target
* Co-simulation support

The model can be configured to enable/disable the instruction extensions before compilation via a supplied python GUI. A `makefile` is provide in the `iss/` directory to compile either for Linux or under Windows with MSYS2/mingw-w64, but a Visual Studio environment is also supplied. This can be used with the IDE, but the `makefile` also allows building with a target of `MSVC` to build the x86_64 Debug build, or a target of `ALLMSVC` to build all target types.
