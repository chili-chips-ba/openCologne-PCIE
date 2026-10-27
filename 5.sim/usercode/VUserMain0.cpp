// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openCologne-PCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
// Description:
//   VProc node 0 for the "CPU=vproc" build: runs the real firmware natively.
//
//   The Makefile compiles 3.sw/common/pcie.c and 3.sw/EP/main.c for the
//   host, as C++, with main() renamed fw_main(). Their register accesses
//   (CSR_REG32 in csr_regs.h) become VProc bus cycles on the
//   SOC's CPU memory interface, at the same CSR addresses eduBOS5 uses. So
//   CPU=rtl, iss and vproc all run one firmware source; only the way it
//   executes differs.
//==========================================================================

extern "C" {
#include "VUser.h"
}

int fw_main();

extern "C" void VUserMain0(int node)
{
    VPrint("\n[CPU=vproc] native firmware entered on VProc node %d\n", node);
    fw_main();
}

/*
-----------------------------------------------------------------------------
Version History:
-----------------------------------------------------------------------------
 2026/10/26   : runs the 3.sw firmware itself, as openPCIE (was a write and
                read-back sanity test)
*/

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        April 2025
// -----------------------------------------------------------------------------
