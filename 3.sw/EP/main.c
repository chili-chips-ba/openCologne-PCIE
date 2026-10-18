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
//   EP firmware: a PIO target. The host (openPCIE Artix-7 RC, Raspberry Pi or
//   PC) enumerates the EP and gives BAR0 an address -- the TL handles all of
//   that -- then reads and writes DWORDs inside BAR0. Each Memory request
//   reaches the firmware here:
//     - MemWr: the payload DWORD is stored, byte enables honoured; posted,
//       so no answer
//     - MemRd: the stored DWORD goes back in a Completion with Data
//     - any other non-posted request: a Completion with Unsupported Request
//   The PIO window is a small array in the SOC RAM, PIO_WORDS DWORDs; BAR0
//   offsets wrap around it. Only single-DWORD requests are served: a MemWr
//   stores its first DWORD, a longer MemRd gets Unsupported Request.
//==========================================================================

#include "pcie.h"

#define PIO_WORDS    256          // 1 KB of the 8 KB RAM
#define PIO_INDEX(a) (((a) >> 2) & (PIO_WORDS - 1))

// Result markers written to PCIE_RESULT
#define RESULT_RUNNING 0x00000001 // waiting for the host
#define RESULT_PASS    0x0000FACE // the host has read from us: the PIO path works end to end

static uint32_t pio_mem[PIO_WORDS];

// 3-DW request: the address is DW2; 4-DW (64-bit) request: the low half is DW3
static uint32_t req_addr(const tlp_t *req) {
    return (TLP_FMT(req->dw0) & 0x1) ? req->data : req->dw2;
}

int main() {

    PCIE_RESULT = RESULT_RUNNING;

    for (int i = 0; i < PIO_WORDS; i++) {
        pio_mem[i] = 0;
    }

    while (1) {
        tlp_t req;

        wait_for_request(&req);

        uint32_t fmt  = TLP_FMT(req.dw0);
        uint32_t type = TLP_TYPE(req.dw0);

        if (type == TYPE_MEM && fmt == FMT_3DW_DATA) {
            // A 4-DW MemWr carries its payload in the 3rd beat, outside the
            // Rx window; with a 32-bit BAR0 the host sends 3-DW ones
            uint32_t idx  = PIO_INDEX(req.dw2);
            uint32_t mask = be_mask(REQ_FIRST_BE(req.dw1));

            pio_mem[idx] = (pio_mem[idx] & ~mask) | (req.data & mask);

        } else if (type == TYPE_MEM && (fmt == FMT_3DW_NODATA || fmt == FMT_4DW_NODATA)) {
            if (TLP_LENGTH(req.dw0) == 1) {
                send_completion(&req, CPL_STAT_SC, 1, pio_mem[PIO_INDEX(req_addr(&req))]);
                PCIE_RESULT = RESULT_PASS;
            } else {
                send_completion(&req, CPL_STAT_UR, 0, 0);
            }

        } else if (!is_posted(&req)) {
            send_completion(&req, CPL_STAT_UR, 0, 0);
        }
        // anything else posted (a 4-DW MemWr, a Message) is dropped

        release_request();
    }
}

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        April 2025
// -----------------------------------------------------------------------------
