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
//   Host program for the RC pcieVHost (RCPIPEx1__pcieVHost) at VProc node 1
//   with make DUT=rtl, the EP RTL + firmware: trains the link with scrambling
//   on, enumerates the EP (IDs, class code, the six BARs sized, BAR0 assigned,
//   Memory Space and Bus Master enabled, capabilities), then reads and writes
//   DWORDs in BAR0, which the firmware serves (3.sw/EP/main.c), and finishes
//   the simulation. Every value is checked; the last line says how many
//   checks failed.
//==========================================================================

#include <stdio.h>
#include <stdlib.h>

#include "VProcClass.h"
#include "pcieModelClass.h"

extern "C"
{
#include "ltssm.h"
}

#define RST_DEASSERT_INT 4

#define WaitForInput()  {while (!ip_byte_count) pcie->sendIdle(1); ip_byte_count = 0;}

#define WordToBuf(_word, _byteoff) {buff[_byteoff + 0] =  (_word        & 0xff); \
                                    buff[_byteoff + 1] = ((_word >>  8) & 0xff); \
                                    buff[_byteoff + 2] = ((_word >> 16) & 0xff); \
                                    buff[_byteoff + 3] = ((_word >> 24) & 0xff);}

#define GetNextTag(_tag){_tag = (_tag + 1)%32;}

#define EP_VENDOR_ID     0x1234
#define EP_DEVICE_ID     0x0001
#define EP_CLASS_REV     0xff000000
#define EP_BAR0_SIZE     0x1000
#define EP_BAR0_ADDR     0x2a784000
#define CMD_MEM_BM       0x0006

static unsigned int Interrupt = 0;

static uint8_t      ipbuf[4096];
static int          ip_byte_count = 0;

static int          errors = 0;

static int ResetDeasserted(int irq)
{
    Interrupt |= irq & RST_DEASSERT_INT;

    return 0;
}

static void VUserInput_1(pPkt_t pkt, int status, void* usrptr)
{
    if (pkt->seq == DLLP_SEQ_ID)
    {
        free(pkt->data);
        free(pkt);
    }
    else
    {
        if (pkt->ByteCount)
        {
            pPktData_t payload = GET_TLP_PAYLOAD_PTR(pkt->data);

            for (int idx = 0; idx < pkt->ByteCount; idx++)
            {
                ipbuf[idx] = payload[idx];
            }
            ip_byte_count = pkt->ByteCount;
        }

        DISCARD_PACKET(pkt);
    }
}

static void Check(const char* what, const uint32_t got, const uint32_t expected)
{
    if (got == expected)
    {
        VPrint("===> %s 0x%08x\n", what, got);
    }
    else
    {
        VPrint("**** ERROR: %s 0x%08x, expected 0x%08x\n", what, got, expected);
        errors++;
    }
}

extern "C" void VUserMain1(int node)
{
    PktData_t buff[4096];
    char      sbuf[128];
    int       rid = node+1;
    int       tag = 0;
    uint32_t  val;

    VProc* vp1 = new VProc(node);

    pcieModelClass* pcie = new pcieModelClass(node);

    pcie->initialisePcie(VUserInput_1, NULL);

    pcie->getPcieVersionStr(sbuf, 128);
    VPrint("  %s\n", sbuf);

    vp1->write(LINK_STATE, 0, 0);

    pcie->configurePcie(CONFIG_ENABLE_SKIPS, 20000);
#ifndef PHY_RTL
    pcie->configurePcie(CONFIG_DISABLE_8B10B);
#endif

    vp1->regIrq(ResetDeasserted);

    pcie->pcieSeed(node);

    do
    {
        pcie->sendOs(IDL);
    }
    while (!Interrupt);

    Interrupt &= ~RST_DEASSERT_INT;

    InitLink(1, node);

    pcie->initFc();

    pcie->cfgRead (CFG_VENDOR_ID_OFFSET, 4, tag, rid, SEND); GetNextTag(tag);
    WaitForInput();
    Check("Vendor ID", ((uint16_t*)ipbuf)[0], EP_VENDOR_ID);
    Check("Device ID", ((uint16_t*)ipbuf)[1], EP_DEVICE_ID);

    pcie->cfgRead (CFG_REVISION_ID_OFFSET, 4, tag, rid, SEND); GetNextTag(tag);
    WaitForInput();
    Check("Class code and revision", ((uint32_t*)ipbuf)[0], EP_CLASS_REV);

    pcie->cfgRead (CFG_HEADER_TYPE_OFFSET & ~0x3, 4, tag, rid, SEND); GetNextTag(tag);
    WaitForInput();
    Check("Header type", ((uint8_t*)ipbuf)[2], 0x00);

    WordToBuf(0xffffffff, 0);
    for (int bidx = 0; bidx < 6; bidx++)
    {
        pcie->cfgWrite (CFG_BAR_HDR_OFFSET + bidx*4, buff, 4, tag, rid, SEND); GetNextTag(tag);
        pcie->cfgRead  (CFG_BAR_HDR_OFFSET + bidx*4, 4, tag, rid, SEND); GetNextTag(tag);
        WaitForInput();
        val = ((uint32_t*)ipbuf)[0];
        sprintf(sbuf, "BAR%d sized", bidx);
        Check(sbuf, val, bidx == 0 ? (uint32_t)(~(EP_BAR0_SIZE - 1)) : 0);
    }

    WordToBuf(EP_BAR0_ADDR, 0);
    pcie->cfgWrite (CFG_BAR_HDR_OFFSET, buff, 4, tag, rid, SEND); GetNextTag(tag);
    pcie->cfgRead  (CFG_BAR_HDR_OFFSET, 4, tag, rid, SEND); GetNextTag(tag);
    WaitForInput();
    Check("BAR0 assigned", ((uint32_t*)ipbuf)[0] & ~0xfU, EP_BAR0_ADDR);

    buff[0] = CMD_MEM_BM & 0xff;
    buff[1] = (CMD_MEM_BM >> 8) & 0xff;
    pcie->cfgWrite (CFG_COMMAND_OFFSET, buff, 2, tag, rid, SEND); GetNextTag(tag);
    pcie->cfgRead  (CFG_COMMAND_OFFSET, 4, tag, rid, SEND); GetNextTag(tag);
    WaitForInput();
    Check("Command, Memory Space and Bus Master", ((uint16_t*)ipbuf)[0] & CMD_MEM_BM, CMD_MEM_BM);

    pcie->cfgRead (CFG_CAPABILITIES_PTR_OFFSET, 4, tag, rid, SEND); GetNextTag(tag);
    WaitForInput();
    uint32_t next_cap_ptr = ((uint8_t*)ipbuf)[0];
    int      caps         = 0;

    while (next_cap_ptr && caps < 8)
    {
        pcie->cfgRead (next_cap_ptr, 4, tag, rid, SEND); GetNextTag(tag);
        WaitForInput();
        uint32_t capId = ((uint8_t*)ipbuf)[0];

        switch (capId)
        {
        case PWRMGMTCAPTYPE:
            VPrint("===> Power Management capability at 0x%02x: 0x%08x\n", next_cap_ptr, ((uint32_t*)ipbuf)[0]);
            break;
        case PCIECAPTYPE:
            VPrint("===> PCIe capability at 0x%02x: 0x%08x\n", next_cap_ptr, ((uint32_t*)ipbuf)[0]);
            break;
        default:
            VPrint("**** ERROR: unexpected capability 0x%02x at 0x%02x\n", capId, next_cap_ptr);
            errors++;
            break;
        }
        next_cap_ptr = ((uint8_t*)ipbuf)[1];
        caps++;
    }
    Check("Capabilities found", caps, 2);

    WordToBuf(0xcafef00d, 0);
    pcie->memWrite (EP_BAR0_ADDR + 0x10, buff, 4, tag, rid, SEND); GetNextTag(tag);
    pcie->memRead  (EP_BAR0_ADDR + 0x10, 4, tag, rid, SEND); GetNextTag(tag);
    WaitForInput();
    Check("BAR0+0x010 read back", ((uint32_t*)ipbuf)[0], 0xcafef00d);

    WordToBuf(0x11223344, 0);
    pcie->memWrite (EP_BAR0_ADDR + 0x20, buff, 4, tag, rid, SEND); GetNextTag(tag);
    buff[0] = 0xaa;
    buff[1] = 0xbb;
    pcie->memWrite (EP_BAR0_ADDR + 0x21, buff, 2, tag, rid, SEND); GetNextTag(tag);
    pcie->memRead  (EP_BAR0_ADDR + 0x20, 4, tag, rid, SEND); GetNextTag(tag);
    WaitForInput();
    Check("BAR0+0x020 after a 2-byte write at 0x021", ((uint32_t*)ipbuf)[0], 0x11bbaa44);

    WordToBuf(0x5a5aa5a5, 0);
    pcie->memWrite (EP_BAR0_ADDR + 0x3fc, buff, 4, tag, rid, SEND); GetNextTag(tag);
    pcie->memRead  (EP_BAR0_ADDR + 0x3fc, 4, tag, rid, SEND); GetNextTag(tag);
    WaitForInput();
    Check("BAR0+0x3fc read back", ((uint32_t*)ipbuf)[0], 0x5a5aa5a5);

    pcie->memRead  (EP_BAR0_ADDR + 0x10, 4, tag, rid, SEND); GetNextTag(tag);
    WaitForInput();
    Check("BAR0+0x010 read again", ((uint32_t*)ipbuf)[0], 0xcafef00d);

    if (errors)
    {
        VPrint("\n****ERROR: Finished with %d errors\n\n", errors);
    }
    else
    {
        VPrint("\n===> Finished with no errors\n\n");
    }

    pcie->sendIdle(100);

    vp1->write(PVH_FINISH, 0, 0);
}

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 21, 2026
// -----------------------------------------------------------------------------
