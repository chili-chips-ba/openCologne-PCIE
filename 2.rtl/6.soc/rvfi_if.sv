// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openCologne-PCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
//                   Copyright (C) 2026 Chili.CHIPS
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// 1. Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
// contributors may be used to endorse or promote products derived
// from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
// IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//              https://opensource.org/license/bsd-3-clause
//--------------------------------------------------------------------------
// Description:
//   rvfi_if: the retired-instruction stream of the SOC CPU, under the
//   standard RVFI names (riscv-formal, github.com/YosysHQ/riscv-formal). The
//   CPU raises rvfi_valid once per retired instruction, with the instruction,
//   its PC, the registers it read and wrote, and its memory access.
//
//   Nothing in the design reads it. It exists for the tools that watch the
//   CPU: WaveCrux's RISC-V decoder (disassembly) and its RVFI Commit
//   Inspector, and formal checks. eduBOS5 drives it when RISCV_FORMAL is
//   defined (simulation and formal only); otherwise it reads 0.
//==========================================================================

interface rvfi_if;
  logic        rvfi_valid;  // one clock per retired instruction
  logic [63:0] rvfi_order;  // its number
  logic [31:0] rvfi_insn;
  logic        rvfi_trap;
  logic        rvfi_halt;
  logic        rvfi_intr;
  logic [ 1:0] rvfi_mode;  // 3: machine mode
  logic [ 1:0] rvfi_ixl;  // 1: 32-bit
  logic [ 4:0] rvfi_rs1_addr;  // 0: not read
  logic [ 4:0] rvfi_rs2_addr;
  logic [31:0] rvfi_rs1_rdata;
  logic [31:0] rvfi_rs2_rdata;
  logic [ 4:0] rvfi_rd_addr;  // 0: no register written
  logic [31:0] rvfi_rd_wdata;
  logic [31:0] rvfi_pc_rdata;  // its address
  logic [31:0] rvfi_pc_wdata;  // the next one
  logic [31:0] rvfi_mem_addr;
  logic [ 3:0] rvfi_mem_rmask;
  logic [ 3:0] rvfi_mem_wmask;
  logic [31:0] rvfi_mem_rdata;
  logic [31:0] rvfi_mem_wdata;

  modport cpu(
      output rvfi_valid, rvfi_order, rvfi_insn, rvfi_trap, rvfi_halt, rvfi_intr, rvfi_mode,
      output rvfi_ixl, rvfi_rs1_addr, rvfi_rs2_addr, rvfi_rs1_rdata, rvfi_rs2_rdata,
      output rvfi_rd_addr, rvfi_rd_wdata, rvfi_pc_rdata, rvfi_pc_wdata, rvfi_mem_addr,
      output rvfi_mem_rmask, rvfi_mem_wmask, rvfi_mem_rdata, rvfi_mem_wdata
  );
endinterface

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 18, 2026
// -----------------------------------------------------------------------------
