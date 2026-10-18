//=============================================================
// 
// Copyright (c) 2021 Simon Southwell. All rights reserved.
//
// Date: 28th June 2021
//
// Top level for the RISC-V ISS
//
// This file is part of the base RISC-V instruction set simulator
// (rv32i_cpu).
//
// This code is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This code is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this code. If not, see <http://www.gnu.org/licenses/>.
//
//=============================================================

// ------------------------------------------------
// INCLUDES
// ------------------------------------------------

#include <stdio.h>
#include <stdlib.h>

#if !defined _WIN32 && !defined _WIN64
#include <unistd.h>
#include <termios.h>
#include <sys/time.h>

#define STRDUP strdup
#else
# undef   UNICODE
# define  WIN32_LEAN_AND_MEAN

# include <windows.h>
# include <winsock2.h>
# include <ws2tcpip.h>

#define STRDUP _strdup

extern "C" {

    extern int getopt(int nargc, char** nargv, const char* ostr);
    extern char* optarg;
}
#endif

extern "C" {
#include "mem.h"
}

#include "rv32.h"
#include "rv32i_cpu.h"
#include "rv32_cpu_gdb.h"
#include "uart.h"
#include "ini.h"

// ------------------------------------------------
// DEFINES
// ------------------------------------------------

#define RV32I_GETOPT_ARG_STR               "hHgdbeEraCTt:n:D:A:p:S:s:xcm:M:u:BL:"

#define INT_ADDR                           0xaffffffc
#define UART0_BASE_ADDR                    0x80000000

#define MATCH(s, n)                        (strcmp(section, (s)) == 0 && strcmp(name, (n)) == 0)
#define IS_TRUE(s)                         (strcmp((s), "true") == 0 || strcmp(s, "TRUE") == 0)

// ------------------------------------------------
// LOCAL VARIABLES
// ------------------------------------------------

static uint32_t swirq            = 0;
static uint32_t uart0_base_addr  = UART0_BASE_ADDR;

static double    tv_diff_usec;

#if (!(defined _WIN32) && !(defined _WIN64))
static struct timeval tv_start, tv_stop;
#else
LARGE_INTEGER freq, start, stop;
#endif

// ------------------------------------------------
// TYPE DEFINITIONS
// ------------------------------------------------

// ------------------------------------------------
// FUNCTIONS
// ------------------------------------------------

// -------------------------------
// Set up actions prior to running
// CPU
//

static void pre_run_setup()
{
    // Initialise time
#if (!(defined _WIN32) && !(defined _WIN64)) || defined __CYGWIN__
    // For non-windows systems, turn off echoing of input key presses
    struct termios t;

    tcgetattr(STDIN_FILENO, &t);
    t.c_lflag &= ~ECHO;
    tcsetattr(STDIN_FILENO, TCSANOW, &t);

    // Log time just before running (LINUX only)
    (void)gettimeofday(&tv_start, NULL);
#else

    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&start);
#endif
}

// -------------------------------
// Actions to run after CPU
// returns from executing
//
static void post_run_actions(const uint64_t num_instr)
{
    // Calculate time difference, in microseconds, from now
    // to previously saved time stamp
#if (!(defined _WIN32) && !(defined _WIN64))
    // For non-windows systems, turn off echoing of input key presses
    struct termios t;

    tcgetattr(STDIN_FILENO, &t);
    t.c_lflag |= ECHO;
    tcsetattr(STDIN_FILENO, TCSANOW, &t);

    // Get time just after running, and calculate run time (LINUX only)
    (void)gettimeofday(&tv_stop, NULL);
    tv_diff_usec = ((float)(tv_stop.tv_sec - tv_start.tv_sec)*1e6) + ((float)(tv_stop.tv_usec - tv_start.tv_usec));
#else
    QueryPerformanceCounter(&stop);
    tv_diff_usec = (double)(stop.QuadPart - start.QuadPart)*1e6/(double)freq.QuadPart;
#endif

    // If number of instructions executed is non-zero, print out value and the
    // calculated MIPS rate
    if (num_instr)
    {
        if (num_instr < 1000)
        {
            printf("\nNumber of executed instructions = %u (%.3f MIPS)\n\n",
                (uint32_t)num_instr, (float)num_instr/(tv_diff_usec));
        }
        else if (num_instr < 1000000)
        {
            printf("\nNumber of executed instructions = %.3f thousand (%.3f MIPS)\n\n",
                (float)num_instr/1e3, (float)num_instr/(tv_diff_usec));
        }
        else
        {
            printf("\nNumber of executed instructions = %.1f million (%.3f MIPS)\n\n",
                (float)num_instr/1e6, (float)num_instr/(tv_diff_usec));
        }
    }
}

// -------------------------------
// Parse command line arguments
//
int parse_args(int argc, char** argv, rv32i_cfg_s &cfg)
{
    int    option;

    int error = 0;

    // Parse the command line arguments and/or configuration file
    // Process the command line options *only* for the INI filename, as we
    // want the command line options to override the INI options
    while ((option = getopt(argc, argv, RV32I_GETOPT_ARG_STR)) != EOF)
    {
        switch (option)
        {
        case 't':
            cfg.exec_fname = optarg;
            cfg.user_fname = true;
            break;
        case 'n':
            cfg.num_instr = (uint32_t)strtoll(optarg, NULL, 0);
            break;
        case 'b':
            cfg.en_brk_on_addr = true;
            break;
        case 'A':
            cfg.brk_addr = (uint32_t)strtoll(optarg, NULL, 0);
            break;
        case 'r':
            cfg.rt_dis = true;
            break;
        case 'a':
            cfg.abi_en = true;
            break;
        case 'd':
            cfg.dis_en          = true;
            cfg.hlt_on_inst_err = true;
            break;
        case 'H':
            cfg.hlt_on_inst_err = true;
            break;
        case 'e':
            cfg.hlt_on_ecall = true;
            break;
        case 'E':
            cfg.hlt_on_ebreak = true;
            break;
        case 'D':
            if ((cfg.dbg_fp = fopen(optarg, "wb")) == NULL)
            {
                fprintf(stderr, "**ERROR: unable to open specified debug file (%s) for writing.\n", optarg);
                error = 1;
            }
            break;
        case 'x':
            cfg.dump_regs = true;
            break;
        case 'c':
            cfg.dump_csrs = true;
            break;
        case 'C':
            cfg.use_cycles_for_mtime = true;
            break;
        case 'T':
            cfg.use_external_timer = true;
            break;
        case 'm':
            cfg.num_mem_dump_words = (uint32_t)strtoll(optarg, NULL, 0);
            break;
        case 'M':
            cfg.mem_dump_start = (uint32_t)strtoll(optarg, NULL, 0);
            break;
        case 'g':
            cfg.gdb_mode = true;
            break;
        case 'p':
            cfg.gdb_ip_portnum = strtol(optarg, NULL, 0);
            break;
        case 'S':
            cfg.update_rst_vec = true;
            cfg.new_rst_vec    = (uint32_t)strtoll(optarg, NULL, 0);
            break;
        case 's':
            cfg.update_sp = true;
            cfg.new_sp    = (uint32_t)strtoll(optarg, NULL, 0);
            break;
        case 'u':
            uart0_base_addr    = (uint32_t)strtoll(optarg, NULL, 0);
            break;
        case 'B':
            cfg.load_binary    = true;
            break;
        case 'L':
            cfg.load_bin_addr  = (uint32_t)strtoll(optarg, NULL, 0);
            break;
        case 'h':
        default:
            fprintf(stderr, "\nrv32 version %d.%d.%d. Copyright (c) 2021-2026 Simon Southwell.\n\n", rv32::major_ver, rv32::minor_ver, rv32::patch_ver);
            fprintf(stderr, "Usage: %s [-hHeEbdragxcCTB][-t <test executable>][-n <num instructions>]\n", argv[0]);
            fprintf(stderr, "      [-S <start addr>][-s <sp addr>][-A <brk addr>][-D <debug o/p filename>][-p <port num>]\n");
            fprintf(stderr, "      [-m <num words>][-M <addr>][-u <uart addr>][-L<binary load addr>]\n\n");
            fprintf(stderr, "   -t specify test executable (default test.exe)\n");
            fprintf(stderr, "   -B specify to load a raw binary file (default load ELF executable)\n");
            fprintf(stderr, "   -L specify address to load binary, if -B specified (default 0x00000000)\n");
            fprintf(stderr, "   -n specify number of instructions to run (default 0, i.e. run until unimp)\n");
            fprintf(stderr, "   -d Enable disassemble mode (default off)\n");
            fprintf(stderr, "   -r Enable run-time disassemble mode (default off. Overridden by -d)\n");
            fprintf(stderr, "   -a display ABI register names when disassembling (default x names)\n");
            fprintf(stderr, "   -C Use cycle count for internal mtime timer (default real-time)\n");
            fprintf(stderr, "   -T Use external memory mapped timer model (default internal)\n");
            fprintf(stderr, "   -H Halt on unimplemented instructions (default trap)\n");
            fprintf(stderr, "   -e Halt on ecall instruction (default trap)\n");
            fprintf(stderr, "   -E Halt on ebreak instruction (default trap)\n");
            fprintf(stderr, "   -b Halt at a specific address (default off)\n");
            fprintf(stderr, "   -A Specify halt address if -b active (default 0x00000040)\n");
            fprintf(stderr, "   -D Specify file for debug output (default stdout)\n");
            fprintf(stderr, "   -x Dump x0 to x31 on exit (default no dump)\n");
            fprintf(stderr, "   -c Dump CSR registers on exit (default no dump)\n");
            fprintf(stderr, "   -m Dump specified number of 32 bit words from data memory on exit (default 0)\n");
            fprintf(stderr, "   -M Start byte address of memory dump (default 0x1000)\n");
            fprintf(stderr, "   -g Enable remote gdb mode (default disabled)\n");
            fprintf(stderr, "   -p Specify remote GDB port number (default 49152)\n");
            fprintf(stderr, "   -S Specify start address (default 0)\n");
            fprintf(stderr, "   -s Specify stack pointer address (default 0)\n");
            fprintf(stderr, "   -u Specify UART base address (default 0x80000000)\n");
            fprintf(stderr, "   -h display this help message\n");
            error = 1;
            break;
        }
    }

    return error;
}

// -------------------------------
// .ini file handler
//
static int handler(void* user, const char* section, const char* name, const char* value)
{
    rv32i_cfg_s* pconfig = (rv32i_cfg_s*)user;

    if (MATCH("program", "executable"))
    {
        pconfig->exec_fname = STRDUP(value);
        pconfig->user_fname = true;
    }
    else if (MATCH("program", "start_addr"))
    {
        pconfig->new_rst_vec = (uint32_t)strtoll(value, NULL, 0);
        pconfig->update_rst_vec = true;
    }
    else if (MATCH("program", "stack_pointer"))
    {
        pconfig->new_sp = (uint32_t)strtoll(value, NULL, 0);
        pconfig->update_sp = true;
    }
    else if (MATCH("program", "load_binary_addr"))
    {
        pconfig->load_bin_addr = (uint32_t)strtoll(value, NULL, 0);
    }
    else if (MATCH("program", "load_binary"))
    {
        pconfig->load_binary = IS_TRUE(value);
    }
    else if (MATCH("control", "num_instructions"))
    {
        pconfig->num_instr = (uint32_t)strtoll(value, NULL, 0);
    }
    else if (MATCH("control", "halt_on_unimp"))
    {
        pconfig->hlt_on_inst_err = IS_TRUE(value);
    }
    else if (MATCH("control", "halt_on_ecall"))
    {
        pconfig->hlt_on_ecall = IS_TRUE(value);
    }
    else if (MATCH("control", "halt_on_ebreak"))
    {
        pconfig->hlt_on_ebreak = IS_TRUE(value);
    }
    else if (MATCH("control", "halt_on_addr"))
    {
        pconfig->en_brk_on_addr = IS_TRUE(value);
    }
    else if (MATCH("control", "halt_address"))
    {
        pconfig->brk_addr = (uint32_t)strtoll(value, NULL, 0);
    }
    else if (MATCH("debug", "static_disassemble"))
    {
        pconfig->dis_en = IS_TRUE(value);
    }
    else if (MATCH("debug", "run_time_disassemble"))
    {
        pconfig->rt_dis = IS_TRUE(value);
    }
    else if (MATCH("debug", "use_abi"))
    {
        pconfig->abi_en = IS_TRUE(value);
    }
    else if (MATCH("debug", "debug_file"))
    {
        if (!strcmp(value, "stdout"))
        {
            pconfig->dbg_fp = stdout;
        }
        else if (!strcmp(value, "stderr"))
        {
            pconfig->dbg_fp = stderr;
        }
        else if ((pconfig->dbg_fp = fopen(value, "wb")) == NULL)
        {
            fprintf(stderr, "**ERROR: unable to open specified debug file (%s) for writing.\n", value);
            return 0;
        }
    }
    else if (MATCH("debug", "dump_registers"))
    {
        pconfig->dump_regs = IS_TRUE(value);
    }
    else if (MATCH("debug", "dump_csrs"))
    {
        pconfig->dump_csrs = IS_TRUE(value);
    }
    else if (MATCH("debug", "mem_dump_words"))
    {
        pconfig->num_mem_dump_words = (uint32_t)strtoll(value, NULL, 0);
    }
    else if (MATCH("debug", "mem_dump_start_addr"))
    {
        pconfig->mem_dump_start = (uint32_t)strtoll(value, NULL, 0);
    }
    else if (MATCH("debug", "gdb_mode"))
    {
        pconfig->gdb_mode = IS_TRUE(value);
    }
    else if (MATCH("debug", "gdb_port_num"))
    {
        pconfig->gdb_ip_portnum = (uint32_t)strtoll(value, NULL, 0);
    }
    else if (MATCH("peripherals", "uart_base_addr"))
    {
        uart0_base_addr = (uint32_t)strtoll(value, NULL, 0);
    }
    else if (MATCH("cpu", "use_cycles_for_mtime"))
    {
        pconfig->use_cycles_for_mtime = IS_TRUE(value);
    }
    else if (MATCH("cpu", "use_external_timer"))
    {
        pconfig->use_external_timer = IS_TRUE(value);
    }

    return 1;
}

// -------------------------------
// External memory map access
// callback function
//
int ext_mem_access(const uint32_t byte_addr, uint32_t& data, const int type, const rv32i_time_t time)
{
    
    // By default, the processed variable indicates that this callback did not
    // process the access (a negatiave value). Otherwise it is the additional
    // access wait states (0 upwards). In this model, writes have no wait states,
    // whilst reads have 2 wait states.
    int processed = RV32I_EXT_MEM_NOT_PROCESSED;

    // If accessing the UART addresses then process here
    if ((byte_addr & UART_REG_ADDR_MASK) == uart0_base_addr)
    {
        processed = 0;
        // If writing to the UART registers, call the model's write function
        if (type == MEM_WR_ACCESS_BYTE || type == MEM_WR_ACCESS_HWORD || type == MEM_WR_ACCESS_WORD)
        {
            uart_write(byte_addr & 0x1f, data & 0xff);
        }
        else if (type == MEM_RD_ACCESS_BYTE || type == MEM_RD_ACCESS_HWORD || type == MEM_RD_ACCESS_WORD)
        {
            uint32_t rxdata;
            uart_read(byte_addr & 0x1f, &rxdata);
            data = rxdata;
        }
    }
    // If not interrupt address, access memory model
    else if (byte_addr != INT_ADDR)
    {
        uint32_t addr = byte_addr;
        processed = 0;

        if (byte_addr == 0xfffffff8)
            printf("help\n");

        switch (type & MEM_NOT_DBG_MASK)
        {
        case MEM_RD_ACCESS_BYTE:
            data = ReadRamByte(addr, 0);
            processed = 2;
            break;
        case MEM_RD_ACCESS_HWORD:
            data = ReadRamHWord(addr, true, 0);
            processed = 2;
            break;
        case MEM_RD_ACCESS_WORD:
            processed = 2;
        case MEM_RD_ACCESS_INSTR:
            data = ReadRamWord(addr, true, 0);
            break;
        case MEM_WR_ACCESS_BYTE:
            WriteRamByte(addr, data, 0);
            break;
        case MEM_WR_ACCESS_HWORD:
            WriteRamHWord(addr, data, true, 0);
            break;
        case MEM_WR_ACCESS_INSTR:
        case MEM_WR_ACCESS_WORD:
            WriteRamWord(addr, data, true, 0);
            break;
        default:
            processed = RV32I_EXT_MEM_NOT_PROCESSED;
            break;
        }
    }
    else if ((type & MEM_NOT_DBG_MASK) == MEM_WR_ACCESS_WORD && byte_addr == INT_ADDR)
    {
        swirq       = data & 0x1;
        processed = 0;
    }
    
    //fprintf(stderr, "addr=%08x data=%08x type=%d processed=%d\n", byte_addr, data, type, processed);

    return processed;
}

// ------------------------------
// Interrupt callback function
//
uint32_t interrupt_callback(const rv32i_time_t time, rv32i_time_t *wakeup_time)
{
    bool terminate;

    *wakeup_time = time + 1;
    
    bool uart_irq = uart_tick(time, terminate);

    return swirq | (uart_irq ? 1 : 0);
}

// -------------------------------
//

int unimp_callback(const p_rv32i_decode_t d, unimp_args_t& args)
{
    //fprintf(stderr, "unimp_callback: opcode = 0x%08x. Executing NOP\n", d->instr);

    // --------- Do a nop ---------
    
    // Update PC if needed
    args.pc += 4;
    args.pc_updated = false /* true */;

    // Update regs if needed
    args.regs[17] = 0x5d;
    args.regs_updated = false /* true */;

    // No trap condition
    args.trap = 0;

    return RV32I_UNIMP_NOT_PROCESSED; // 0 or more for added wait states, or RV32I_UNIMP_NOT_PROCESSED;
}

// -------------------------------
// Dump registers
//

void reg_dump(rv32* pCpu, FILE* dfp, bool abi_en)
{
    fprintf(dfp, "\nRegister state:\n\n  ");

    // Loop through all the registers
    for (int idx = 0; idx < rv32i_consts::RV32I_NUM_OF_REGISTERS; idx++)
    {
        // Get the appropriate mapped register name (ABI or x)
        const char* map_str = abi_en ? pCpu->rmap_str[idx] : pCpu->xmap_str[idx];

        // Get the length of the register name string
        size_t  slen = strlen(map_str);

        // Fetch the value of the register indexed
        uint32_t rval = pCpu->regi_val(idx);

        // Print out the register name (right justified) followed by the value
        fprintf(dfp, "%s%s = 0x%08x ", (slen == 2) ? "  " : (slen == 3) ? " ": "",
                                         map_str,
                                         rval);

        // After every fourth value, output a new line
        if ((idx % 4) == 3)
        {
            fprintf(dfp, "\n  ");
        }
    }

    // Add a final new line
    fprintf(dfp, "\n");
}

// -------------------------------
// Dump CSRs
//
void csr_dump(rv32* pCpu, FILE* dfp)
{
    fprintf(dfp, "CSR state:\n\n");
    fprintf(dfp, "  mstatus    = 0x%08x\n",     pCpu->csr_val(rv32csr_consts::RV32CSR_ADDR_MSTATUS));
    fprintf(dfp, "  mie        = 0x%08x\n",     pCpu->csr_val(rv32csr_consts::RV32CSR_ADDR_MIE));
    fprintf(dfp, "  mvtec      = 0x%08x\n",     pCpu->csr_val(rv32csr_consts::RV32CSR_ADDR_MTVEC));
    fprintf(dfp, "  mscratch   = 0x%08x\n",     pCpu->csr_val(rv32csr_consts::RV32CSR_ADDR_MSCRATCH));
    fprintf(dfp, "  mepc       = 0x%08x\n",     pCpu->csr_val(rv32csr_consts::RV32CSR_ADDR_MEPC));
    fprintf(dfp, "  mcause     = 0x%08x\n",     pCpu->csr_val(rv32csr_consts::RV32CSR_ADDR_MCAUSE));
    fprintf(dfp, "  mtval      = 0x%08x\n",     pCpu->csr_val(rv32csr_consts::RV32CSR_ADDR_MTVAL));
    fprintf(dfp, "  mip        = 0x%08x\n",     pCpu->csr_val(rv32csr_consts::RV32CSR_ADDR_MIP));
    fprintf(dfp, "  mcycle     = 0x%08x%08x\n", pCpu->csr_val(rv32csr_consts::RV32CSR_ADDR_MCYCLEH),   pCpu->csr_val(rv32csr_consts::RV32CSR_ADDR_MCYCLE));
    fprintf(dfp, "  minstret   = 0x%08x%08x\n", pCpu->csr_val(rv32csr_consts::RV32CSR_ADDR_MINSTRETH), pCpu->csr_val(rv32csr_consts::RV32CSR_ADDR_MINSTRET));

    bool fault;
    uint32_t mtimel = pCpu->read_mem(rv32i_consts::RV32I_RTCLOCK_ADDRESS,   rv32i_consts::RV32I_MEM_RD_ACCESS_WORD, fault);
    uint32_t mtimeh = pCpu->read_mem(rv32i_consts::RV32I_RTCLOCK_ADDRESS+4, rv32i_consts::RV32I_MEM_RD_ACCESS_WORD, fault);
    fprintf(dfp, "  mtime      = 0x%08x%08x\n", mtimeh, mtimel);

    mtimel = pCpu->read_mem(rv32i_consts::RV32I_RTCLOCK_CMP_ADDRESS,   rv32i_consts::RV32I_MEM_RD_ACCESS_WORD, fault);
    mtimeh = pCpu->read_mem(rv32i_consts::RV32I_RTCLOCK_CMP_ADDRESS+4, rv32i_consts::RV32I_MEM_RD_ACCESS_WORD, fault);
    fprintf(dfp, "  mtimecmp   = 0x%08x%08x\n", mtimeh, mtimel);

}

// -------------------------------
// Dump memory
//

void mem_dump(uint32_t num, uint32_t start, rv32* pCpu, FILE* dfp)
{
    bool fault;

    fprintf(dfp, "\nMEM state:\n\n");
    for (uint32_t idx = start; idx < ((start & 0xfffffffc) + num*4); idx+=4)
    {
        uint32_t rval = pCpu->read_mem(idx, rv32i_consts::RV32I_MEM_RD_ACCESS_WORD, fault);
        fprintf(dfp, "  0x%08x : 0x%08x\n", idx, rval);
    }
    fprintf(dfp, "\n");
}

// -------------------------------
// MAIN
//
int main(int argc, char** argv)
{
    int           error = 0;

    rv32* pCpu;
    rv32i_cfg_s   cfg;

    // Look for an INI file and parse it if it exsists
    int parse_status = ini_parse("rv32.ini", handler, &cfg);

    // If not OK and not an unfound file, then flag an error
    if (parse_status != 0 && parse_status != -1)
    {
        error = 1;
    }
    // Process command line arguments
    else if (!(error = parse_args(argc, argv, cfg)))
    {
        // Create and configure the top level cpu object
        pCpu = new rv32(cfg.dbg_fp);

        // Register external memory callback function
        pCpu->register_ext_mem_callback(ext_mem_access);

        // Register interrupt callback function
        pCpu->register_int_callback(interrupt_callback);

        // Register unimp callback
        pCpu->register_unimp_callback(unimp_callback);

        // If GDB mode, pass execution to the remote GDB interface
        if (cfg.gdb_mode)
        {
            // Set to halt on ebreak when in gdb mode
            cfg.hlt_on_ebreak = true;

            // Load an executable if specified on the command line
            if (cfg.user_fname)
            {
                if (cfg.load_binary)
                {
                    error = pCpu->read_binary(cfg.exec_fname, cfg.load_bin_addr);
                }
                else
                {
                    error = pCpu->read_elf(cfg.exec_fname);
                }
            }

            if (!error)
            {
                // Start procssing commands from GDB
                if (rv32gdb_process_gdb(pCpu, cfg.gdb_ip_portnum, cfg))
                {
                    fprintf(stderr, "***ERROR in opening PTY\n");
                    return PTY_ERROR;
                }
            }
        }
        else
        {
            // Load an executable
            if (cfg.load_binary)
            {
                error = pCpu->read_binary(cfg.exec_fname, cfg.load_bin_addr);
            }
            else
            {
                error = pCpu->read_elf(cfg.exec_fname);
            }
            
            if (!error)
            {
                pre_run_setup();

                // Run processor
                pCpu->run(cfg);

                // If number of instructions to run is not zero, get the instruction retired count from CSR registers, else set it to 0
                uint64_t instr_ret = cfg.num_instr ? ((uint64_t)pCpu->csr_val(rv32csr_consts::RV32CSR_ADDR_MINSTRET) | ((uint64_t)pCpu->csr_val(rv32csr_consts::RV32CSR_ADDR_MINSTRETH) << 32)) : 0;
                post_run_actions(instr_ret);

#ifdef RV32_DEBUG
                for (int idx = 0; idx < RV32I_NUM_OF_REGISTERS; idx++)
                {
                    printf("%sx%d=0x%08x\n", (idx < 10) ? " " : "", idx, pCpu->regi_val(idx));
                }

                printf(" pc=0x%08x\n", pCpu->pc_val());
#endif
                // If enabled, dump the registers
                if (cfg.dump_regs)
                {
                    reg_dump(pCpu, cfg.dbg_fp, cfg.abi_en);
                }

                // If enabled, dump the CSRs
                if (cfg.dump_csrs)
                {
                    csr_dump(pCpu, cfg.dbg_fp);
                }

                // If specified dump the numbr of DMEM words
                if (cfg.num_mem_dump_words)
                {
                    mem_dump(cfg.num_mem_dump_words, cfg.mem_dump_start, pCpu, cfg.dbg_fp);
                }

                // Print result
                if (!cfg.dis_en)
                {
                    if (pCpu->regi_val(10) || pCpu->regi_val(17) != 93)
                    {
                        printf("\n*FAIL*: exit code = 0x%08x finish code = 0x%08x\n", pCpu->regi_val(10) >> 1, pCpu->regi_val(17));
                    }
                    else
                    {
                        printf("\nPASS: exit code = 0x%08x\n", pCpu->regi_val(10));
                    }
                }
            }
        }

        // Clean up
        if (cfg.dbg_fp != stdout)
        {
            fclose(cfg.dbg_fp);
        }
        delete pCpu;
    }

    return error;
}
