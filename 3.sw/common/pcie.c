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
//   PCIe request layer of the EP firmware. See pcie.h.
//==========================================================================

#include "pcie.h"

__attribute__((noreturn)) void halt(uint32_t marker) {
    PCIE_RESULT = marker;
    while (1) {}
}

// Waits until the Tx FSM is idle and the core has a free buffer, then loads
// the three header DWORDs. Writing tx.data last is what sends the TLP.
void send_tlp(uint32_t h0, uint32_t h1, uint32_t h2, uint32_t data) {
    while (((PCIE_PHY_STATUS & TX_STATE_MASK) != 0) ||
           ((PCIE_PHY_STATUS & TX_BUF_MASK) == 0));

    PCIE_TX_HEADER0 = h0;
    PCIE_TX_HEADER1 = h1;
    PCIE_TX_HEADER2 = h2;
    PCIE_TX_DATA    = data;
}

// Waits for the next TLP from the host. While rx.valid is set, the SOC holds
// the link off, so nothing is lost while the firmware works on this one.
void wait_for_request(tlp_t *req) {
    while ((PCIE_RX_VALID & RX_VALID_MASK) == 0);

    req->dw0  = PCIE_RX_HEADER0;
    req->dw1  = PCIE_RX_HEADER1;
    req->dw2  = PCIE_RX_HEADER2;
    req->data = PCIE_RX_DATA;
}

// rx.valid is write-1-to-clear: the Rx window opens for the next TLP
void release_request(void) {
    PCIE_RX_VALID = RX_VALID_MASK;
}

// Our own Bus/Device/Function, as the TL captured it from the host's last
// Type 0 Configuration Write. It goes into the Completer ID of every
// Completion. Behind a switch the bus number is not the one of a direct link,
// so it is read here, never hard-coded.
uint32_t completer_id(void) {
    return PCIE_CFG_ID & CFG_ID_MASK;
}

// Posted requests get no Completion: Memory Writes and Messages
int is_posted(const tlp_t *req) {
    uint32_t fmt  = TLP_FMT(req->dw0);
    uint32_t type = TLP_TYPE(req->dw0);

    if (type == TYPE_MEM && (fmt == FMT_3DW_DATA || fmt == FMT_4DW_DATA)) {
        return 1;
    }
    return (type & TYPE_MSG_MASK) == TYPE_MSG;
}

// Bits of the payload DWORD that the First DW Byte Enables select. On the TRN
// interface the payload travels big-endian: byte 0 in bits [31:24], so byte
// enable bit i covers bits [31-8i : 24-8i].
uint32_t be_mask(uint32_t first_be) {
    uint32_t mask = 0;

    for (int i = 0; i < 4; i++) {
        if (first_be & (1u << i)) {
            mask |= 0xFFu << (24 - 8 * i);
        }
    }
    return mask;
}

// Byte Count and Lower Address of a 1-DW read, from its First DW Byte
// Enables (Base Specification 2.1, tables 2-21 and 2-22): the count runs from
// the first to the last enabled byte, the low address bits point at the first
// enabled byte. No byte enabled still counts as 1 byte, at offset 0.
static uint32_t cpl_byte_count(uint32_t be) {
    if (be == 0) {
        return 1;
    }
    int first = 0, last = 3;
    while (!(be & (1u << first))) first++;
    while (!(be & (1u << last)))  last--;
    return (uint32_t)(last - first + 1);
}

static uint32_t cpl_lower_addr(const tlp_t *req) {
    uint32_t be    = REQ_FIRST_BE(req->dw1);
    uint32_t addr  = (TLP_FMT(req->dw0) & 0x1) ? req->data : req->dw2;  // 4-DW: low address in DW3
    uint32_t first = 0;

    if (be != 0) {
        while (!(be & (1u << first))) first++;
    }
    return (addr & 0x7C) | first;
}

// Builds and sends the Completion of a non-posted request. TC and Attr are
// copied from the request; Requester ID and Tag route it back to the host's
// request; the Completer ID says who answers.
void send_completion(const tlp_t *req, uint32_t status, int with_data, uint32_t data) {
    uint32_t dw0 = (with_data ? (TLP_CPLD | 1) : TLP_CPL) | TLP_TC_ATTR(req->dw0);
    uint32_t dw1 = (completer_id() << 16) | ((status & 0x7) << 13) |
                   cpl_byte_count(REQ_FIRST_BE(req->dw1));
    uint32_t dw2 = (REQ_REQUESTER_ID(req->dw1) << 16) | (REQ_TAG(req->dw1) << 8) |
                   cpl_lower_addr(req);

    send_tlp(dw0, dw1, dw2, data);
}

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        April 2025
// -----------------------------------------------------------------------------
