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
//   PCIe request layer of the EP firmware: CSR access, waiting for the next
//   request from the host, decoding it, and sending the Completion back.
//   main.c adds only what the EP does with the requests.
//
//   The TL answers the host's Configuration requests itself, as the AMD
//   PCIE_2_1 hard macro does; only Memory requests (and anything the TL
//   passes on) reach the firmware, one TLP at a time through the CSR Rx
//   window.
//==========================================================================

#ifndef OPENCOLOGNE_PCIE_H
#define OPENCOLOGNE_PCIE_H

#include <stdint.h>

// -------------------------------------------------------------------------
// CSR access: register offsets and field positions come from the headers
// PeakRDL generates out of 4.build/csr_build/csr.rdl, so hardware and
// software cannot drift apart.
// -------------------------------------------------------------------------
#include "opencologne_pcie_regs.h"

#define PCIE_TX_HEADER0      CSR_REG32(tx.header0)
#define PCIE_TX_HEADER1      CSR_REG32(tx.header1)
#define PCIE_TX_HEADER2      CSR_REG32(tx.header2)
#define PCIE_TX_DATA         CSR_REG32(tx.data)

#define PCIE_RX_HEADER0      CSR_REG32(rx.header0)
#define PCIE_RX_HEADER1      CSR_REG32(rx.header1)
#define PCIE_RX_HEADER2      CSR_REG32(rx.header2)
#define PCIE_RX_DATA         CSR_REG32(rx.data)
#define PCIE_RX_VALID        CSR_REG32(rx.valid)
#define PCIE_ERR_STATUS      CSR_REG32(status.err)
#define PCIE_PHY_STATUS      CSR_REG32(status.phy)
#define PCIE_RESULT          CSR_REG32(status.result)
#define PCIE_CFG_ID          CSR_REG32(status.cfg_id)

// Field masks come from the generated csr.h
#define TX_STATE_MASK        CSR__STATUS__PHY__TX_STATE_bm
#define TX_BUF_MASK          CSR__STATUS__PHY__TX_BUF_AVAIL_bm
#define RX_VALID_MASK        CSR__RX__VALID__VALID_bm
#define CFG_ID_MASK          CSR__STATUS__CFG_ID__ID_bm

// -------------------------------------------------------------------------
// TLP header fields (PCI Express Base Specification), the same layout as
// the pcie_pkg structs of the RTL
// -------------------------------------------------------------------------
// DW0, all TLPs
#define TLP_FMT(dw0)       (((dw0) >> 29) & 0x3)   // [0]: 4-DW header, [1]: with data
#define TLP_TYPE(dw0)      (((dw0) >> 24) & 0x1F)
#define TLP_TC_ATTR(dw0)   ((dw0) & 0x00703000)    // TC [22:20], Attr [13:12]
#define TLP_LENGTH(dw0)    ((dw0) & 0x3FF)         // in DW, 0 = 1024

#define FMT_3DW_NODATA     0x0
#define FMT_4DW_NODATA     0x1
#define FMT_3DW_DATA       0x2
#define FMT_4DW_DATA       0x3

#define TYPE_MEM           0x00  // MemRd / MemWr, by Fmt
#define TYPE_MSG_MASK      0x18  // Type[4:3] = 10: Message (posted)
#define TYPE_MSG           0x10

// Request DW1
#define REQ_REQUESTER_ID(dw1) (((dw1) >> 16) & 0xFFFF)
#define REQ_TAG(dw1)          (((dw1) >> 8) & 0xFF)
#define REQ_FIRST_BE(dw1)     ((dw1) & 0xF)

// Completion headers
#define TLP_CPLD           0x4A000000  // Fmt 10 (3 DW, data), Type 01010
#define TLP_CPL            0x0A000000  // Fmt 00 (3 DW, no data), Type 01010

#define CPL_STAT_SC        0  // Successful Completion
#define CPL_STAT_UR        1  // Unsupported Request

// One TLP as the Rx window captured it
typedef struct {
    uint32_t dw0;
    uint32_t dw1;
    uint32_t dw2;   // 3-DW request: the address
    uint32_t data;  // 3-DW MemWr: the payload; 4-DW request: the low address
} tlp_t;

__attribute__((noreturn)) void halt(uint32_t marker);
void     send_tlp(uint32_t h0, uint32_t h1, uint32_t h2, uint32_t data);
void     wait_for_request(tlp_t *req);
void     release_request(void);
uint32_t completer_id(void);
void     send_completion(const tlp_t *req, uint32_t status, int with_data, uint32_t data);
int      is_posted(const tlp_t *req);
uint32_t be_mask(uint32_t first_be);

#endif // OPENCOLOGNE_PCIE_H

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        April 2025
// -----------------------------------------------------------------------------
