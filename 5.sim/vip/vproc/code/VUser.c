//=====================================================================
//
// VUser.c                                            Date: 2004/12/13
//
// Copyright (c) 2004-2025 Simon Southwell.
//
// This file is part of VProc.
//
// VProc is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// VProc is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with VProc. If not, see <http://www.gnu.org/licenses/>.
//
//=====================================================================
//
// Top level VP user thread routines. Sets up connection to
// queue and calls relevant user function for node number.
//
//=====================================================================

#include <errno.h>
#include "VProc.h"
#include "VUser.h"

// Forward declaration
static void VUserInit (const unsigned node);

// =========================================================================
// Simulation interface functions
// =========================================================================

// -------------------------------------------------------------------------
// VUser()
//
// Entry point for new user process. Creates a new thread
// calling VUserInit().
// -------------------------------------------------------------------------

int VUser (const unsigned node)
{
    pthread_t thread;
    int       status;
    int       idx, jdx;

    debug_io_printf("VUser(): node %d\n", node);

    // Callback intialisation
    ns[node]->VUserIrqCB = NULL;
    ns[node]->VUserCB    = NULL;

    debug_io_printf("VUser(): initialised callbacks at node %d\n", node);

    // Set off the user code thread using VUserInit to initialise before entering user code
    if (status = pthread_create(&thread, NULL, (pThreadFunc_t)VUserInit, (void *)((nodecast_t)node)))
    {
        debug_io_printf("VUser(): pthread_create returned %d\n", status);
        return 1;
    }

    debug_io_printf("VUser(): spawned user thread for node %d\n", node);

    return 0;
}

// -------------------------------------------------------------------------
// VUserInit()
//
// New thread initialisation procedure. Synchronises with
// simulation before calling user procedure.
// -------------------------------------------------------------------------

static void VUserInit (const unsigned node)
{
    handle_t     hdl;
    pVUserMain_t VUserMain_func;
    char         funcname[DEFAULT_STR_BUF_SIZE];
    int          status;

    debug_io_printf("VUserInit(%d)\n", node);

    // Get function pointer of user entry routine
    sprintf(funcname, "%s%d",    "VUserMain", node);
    if ((VUserMain_func = (pVUserMain_t) dlsym(RTLD_DEFAULT, funcname)) == NULL)
    {
#ifndef VERILATOR
        // If the lookup failed, try loading the shared object immediately
        // and trying again. This addresses an issue seen with ModelSim on
        // Windows where the symbols are *sometimes* not loaded by this point.
        void* hdl = dlopen("VProc.so", RTLD_NOW);

        if ((VUserMain_func = (pVUserMain_t) dlsym(hdl, funcname)) == NULL)
#endif
        {
            VPrint("***Error: failed to find user code symbol %s (VUserInit)\n", funcname);
            exit(1);
        }
    }

    debug_io_printf("VUserInit(): got user function (%s) for node %d (%p)\n", funcname, node, VUserMain_func);

    // Wait for first message from simulator
    debug_io_printf("VUserInit(): waiting for first message semaphore rcv[%d]\n", node);

    if ((status = sem_wait(&(ns[node]->rcv))) == -1)
    {
        VPrint("***Error: bad sem_post status (%d) on node %d (VUserInit)\n", status, node);
        exit(1);
    }

    debug_io_printf("VUserInit(): calling user code for node %d\n", node);

    // Call user program
    debug_io_printf("VUserInit(): calling VUserMain%d\n", node);

    VUserMain_func(node);
}

// -------------------------------------------------------------------------
// VExch()
//
// Message exchange routine. Handles all messages to and from
// simulation process (apart from initialisation. Each sent
// message has a reply. Interrupt messages require that
// the original IO message reply is waited for again.
// -------------------------------------------------------------------------

static void VExch (const psend_buf_t psbuf, prcv_buf_t prbuf, const unsigned node)
{
    int status;
    // Send message to simulator
    ns[node]->send_buf = *psbuf;

    debug_io_printf("VExch(): setting snd[%d] semaphore\n", node);

    if ((status = sem_post(&(ns[node]->snd))) == -1)
    {
        VPrint("***Error: bad sem_post status (%d) on node %d (VExch)\n", status, node);
        exit(1);
    }

    // Wait for response message from simulator
    debug_io_printf("VExch(): waiting for rcv[%d] semaphore\n", node);
    sem_wait(&(ns[node]->rcv));

    *prbuf = ns[node]->rcv_buf;

    debug_io_printf("VExch(): returning to user code from node %d\n", node);

}

// =========================================================================
// User API functions
// =========================================================================

// -------------------------------------------------------------------------
// VWrite()
//
// Invokes a write message exchange
// -------------------------------------------------------------------------

int VWrite (const unsigned addr, const unsigned data, const int delta, const unsigned node)
{
    return VWriteBE(addr, data, 0xf, delta, node);
}

// -------------------------------------------------------------------------
// VWriteBE()
//
// Invokes a write message exchange with byte enables
// -------------------------------------------------------------------------

int VWriteBE (const unsigned addr, const unsigned data, const unsigned be, const int delta, const unsigned node)
{
    rcv_buf_t  rbuf;
    send_buf_t sbuf;
    rw_t*      p_rw = (rw_t*)&sbuf.rw;

    sbuf.addr     = addr;
    sbuf.data_out = data;
    sbuf.ticks    = delta ? DELTA_CYCLE : 0;

    sbuf.rw       = 0;  // clear RW fields
    p_rw->write   = 1;
    p_rw->fbe     = be & 0xf;

    VExch(&sbuf, &rbuf, node);

    return rbuf.data_in ;
}

// -------------------------------------------------------------------------
// VRead()
//
// Invokes a read message exchange
// -------------------------------------------------------------------------

int VRead (const unsigned addr, unsigned *rdata, const int delta, const unsigned node)
{
    rcv_buf_t  rbuf;
    send_buf_t sbuf;
    rw_t*      p_rw = (rw_t*)&sbuf.rw;

    sbuf.addr     = addr;
    sbuf.data_out = 0;
    sbuf.ticks    = delta ? DELTA_CYCLE : 0;

    sbuf.rw       = 0;  // clear RW fields
    p_rw->read    = 1;
    p_rw->fbe     = 0xf;

    VExch(&sbuf, &rbuf, node);

    *rdata        = rbuf.data_in;

    return 0;
}

// -------------------------------------------------------------------------
// VBurstWrite()
//
// Invokes a burst write message exchange
// -------------------------------------------------------------------------

int VBurstWrite (const unsigned addr, void *data, const unsigned wordlen, const unsigned node)
{
    rcv_buf_t  rbuf;
    send_buf_t sbuf;
    rw_t*      p_rw = (rw_t*)&sbuf.rw;

    sbuf.addr      = addr;
    sbuf.data_out  = 0;
    sbuf.data_p    = data;
    sbuf.ticks     = 0;

    sbuf.rw        = 0;  // clear RW fields
    p_rw->write    = 1;
    p_rw->burstlen = wordlen & 0xfff;
    p_rw->fbe      = 0xf;
    p_rw->lbe      = 0xf;

    VExch(&sbuf, &rbuf, node);

    return 0;
}

// -------------------------------------------------------------------------
// VBurstWriteBE()
//
// Invokes a burst write message exchange with byte enables
// -------------------------------------------------------------------------

int VBurstWriteBE (const unsigned addr, void *data, const unsigned wordlen, const unsigned fbe, const unsigned lbe, const unsigned node)
{
    rcv_buf_t  rbuf;
    send_buf_t sbuf;
    rw_t*      p_rw = (rw_t*)&sbuf.rw;

    sbuf.addr      = addr;
    sbuf.data_out  = 0;
    sbuf.data_p    = data;
    sbuf.ticks     = 0;

    sbuf.rw        = 0;  // clear RW fields
    p_rw->write    = 1;
    p_rw->burstlen = wordlen & 0xfff;
    p_rw->fbe      = fbe & 0xf;
    p_rw->lbe      = lbe & 0xf;

    VExch(&sbuf, &rbuf, node);

    return 0;
}

// -------------------------------------------------------------------------
// VBurstRead()
//
// Invokes a burst read message exchange
// -------------------------------------------------------------------------

int VBurstRead (const unsigned int addr, void *data, const unsigned wordlen, const unsigned node)
{
    rcv_buf_t  rbuf;
    send_buf_t sbuf;
    rw_t*      p_rw = (rw_t*)&sbuf.rw;

    sbuf.addr      = addr;
    sbuf.data_out  = 0;
    sbuf.data_p    = data;
    sbuf.ticks     = 0;

    sbuf.rw        = 0;  // clear RW fields
    p_rw->read     = 1;
    p_rw->burstlen = wordlen & 0xfff;
    p_rw->fbe      = 0xf;
    p_rw->lbe      = 0xf;

    VExch(&sbuf, &rbuf, node);

    return 0;
}

// -------------------------------------------------------------------------
// VTick()
//
// Invokes a tick message exchange
// -------------------------------------------------------------------------

int VTick (const unsigned ticks, const unsigned node)
{
    rcv_buf_t  rbuf;
    send_buf_t sbuf;

    sbuf.addr     = 0;
    sbuf.data_out = 0;
    sbuf.rw       = V_IDLE;
    sbuf.ticks    = ticks;

    VExch(&sbuf, &rbuf, node);

    return 0;
}

// -------------------------------------------------------------------------
// VRegIrq()
//
// Registers a user function as a vector IRQ callback
// -------------------------------------------------------------------------

void VRegIrq (const pVUserIrqCB_t func, const unsigned node)
{
    debug_io_printf("VRegIrq(): at node %d, registering irq callback\n", node);

    ns[node]->VUserIrqCB = func;
}

// -------------------------------------------------------------------------
// VRegIrqPy()
//
// Registers a python interface function as a vector IRQ
// callback
// -------------------------------------------------------------------------

void VRegIrqPy (const pPyIrqCB_t func, const unsigned node)
{
    ns[node]->PyIrqCB = func;
}

// -------------------------------------------------------------------------
// VRegUser()
//
// Registers a user function as a callback against
// $vprocuser
// -------------------------------------------------------------------------

void VRegUser (const pVUserCB_t func, const unsigned node)
{
    debug_io_printf("VRegUser(): at node %d, registering user callback function\n", node);

    ns[node]->VUserCB = func;
}

