# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause

# =============================================================================
# Co-simulation of the openCologne-PCIE test bench, in Verilator
#
# Run FROM THIS FOLDER, on Linux or WSL:
#   make          build the C/C++ models and the Verilator executable
#   make run      build and run
#   make clean
#
# Open-source simulators only: Verilator here (Icarus is used for the block
# level flows in 2.rtl). The VIP is the same as on openPCIE: VProc, the
# pcieVHost PCIE model, mem_model: upstream copies in vip/, built by
# tools/build-vip.sh into ~/.cache. models/ holds our own wrappers.
#
# Nodes: VProc node 1 is the host, RCPIPEx1__pcieVHost, a pcieVHost in RC mode
# (usercode/VUserMain1.cpp: IDs, BAR sizing and assignment); node 2 is the DUT.
# The DUT is selected with DUT: the EP RTL + firmware, or the mock
# EPPIPEx1__pcieVHost_DUT, a pcieVHost in EP mode (stubs/, usercode/VUserMain2.cpp),
# which proves the test bench and the host on their own.
# =============================================================================

# ---- simulator ------------------------------------------------------------------
#   verilator  (default) compiled to a native executable; the models talk DPI-C
#   icarus     Icarus Verilog; the same C/C++ models talk VPI
SIM           ?= verilator

# ---- DUT ----------------------------------------------------------------------
#   mock     EPPIPEx1__pcieVHost_DUT (default until the EP RTL exists)
#   rtl      the EP RTL + firmware
DUT           ?= mock
ifeq ($(DUT),rtl)
  $(error DUT=rtl: the EP RTL (TL in 2.rtl/5.tlp) is not there yet; use DUT=mock)
else ifneq ($(DUT),mock)
  $(error DUT must be mock or rtl (got "$(DUT)"))
endif

# ---- user code ----------------------------------------------------------------
# ltssm.c, the link-training helper, is part of the Icarus pcieVHost library;
# for Verilator it is compiled with the user code
USER_C        ?= VUserMain1.cpp VUserMain2.cpp
USRCODEDIR    ?= $(CURDIR)/usercode
OPTFLAG       ?= -g
USRSIMFLAGS   ?=

# ---- models -------------------------------------------------------------------
# VIP_DIR: lib/, include/, ltssm/, hdl/ of the VIP; built once, then reused
VIP_DIR       ?= $(shell bash $(CURDIR)/tools/build-vip.sh)
export VIP_DIR

# ---- tools --------------------------------------------------------------------
HOST_CC       ?= gcc
HOST_CXX      ?= g++
HOST_AR       ?= ar
VERILATOR     ?= verilator
IVERILOG      ?= iverilog
VVP           ?= vvp

CPPSTD         = -std=c++20
INCLPATHS      = -I$(USRCODEDIR) -I$(VIP_DIR)/include
OBJDIR         = $(CURDIR)/obj/$(SIM)
USERLIB        = $(OBJDIR)/libuser.a

ifeq ($(SIM),verilator)
  # LTSSM_ABBREVIATED: 16 TS1 in Polling.Active instead of 1024, as in the
  # Icarus library (tools/build-vip.sh), so both end at the same time
  DEFS         = -DVPROC_SV -DVPROC -DEXCLUDE_LTSSM -DLTSSM_ABBREVIATED
  USER_ALL     = $(USER_C) ltssm.c
  SIMEXE       = $(OBJDIR)/Vtb
else ifeq ($(SIM),icarus)
  ICA_INC      = $(dir $(shell command -v $(IVERILOG)))../include/iverilog
  ICA_LIB      = $(dir $(shell command -v $(IVERILOG)))../lib
  DEFS         = -DICARUS -DVPROC -DEXCLUDE_LTSSM -I$(ICA_INC)
  USER_ALL     = $(USER_C)
  SIMEXE       = $(OBJDIR)/sim
  VPROC_SO     = $(OBJDIR)/VProc.vpi
else
  $(error SIM must be verilator or icarus (got "$(SIM)"))
endif

VOBJS          = $(addprefix $(OBJDIR)/, $(patsubst %.cpp,%.o,$(patsubst %.c,%.o,$(notdir $(USER_ALL)))))

# ---- Verilator ----------------------------------------------------------------
# The C/C++ side: our user code (whole-archive, so VProc finds VUserMain<n>),
# then the VProc and pcieVHost libraries
LDLIBS         = -Wl,-whole-archive $(USERLIB) -Wl,-no-whole-archive \
                 -L$(VIP_DIR)/lib -lcosimlnx -lpcielnx \
                 -lpthread -lrt -ldl -rdynamic

# DUMP=1: tb.fst, written natively (Verilator --trace-fst, vvp -fst)
DUMP          ?= 0
ifeq ($(DUMP),1)
  VLTDUMP      = --trace-fst --trace-depth 1 +define+DUMP
  ICADUMP      = -DDUMP
  VVPDUMP      = -fst
endif

# --timing: the test bench and the models use delays and event controls
# CFG_LDFLAGS_VERILATED cleared: a Verilator built with mold links through it
# (-fuse-ld=mold), and mold fails on network shares (fchmod); the default
# linker works everywhere
VLTFLAGS       = --binary -sv --timing --top-module tb -Mdir $(OBJDIR) $(VLTDUMP) \
                 -Wno-fatal -Wno-WIDTH -Wno-lint -Wno-style                     \
                 +define+VPROC_SV +define+VPROC_BYTE_ENABLE                      \
                 -F tb.f $(USRSIMFLAGS)                                         \
                 -MAKEFLAGS "--quiet CFG_LDFLAGS_VERILATED="                    \
                 -CFLAGS "$(CPPSTD) -Wno-attributes"                            \
                 -LDFLAGS "$(LDLIBS)"

# ---- Icarus -------------------------------------------------------------------
# The same file list, with $VIP_DIR filled in; mem_model.sv is left out, as
# this test bench does not instantiate it
ICA_FILES      = $(OBJDIR)/tb.icarus.f
ICAFLAGS       = -g2012 -DVPROC_BYTE_ENABLE $(ICADUMP) -s tb -c $(ICA_FILES) $(USRSIMFLAGS)

# =============================================================================
# TARGETS
# =============================================================================

.PHONY: all run clean help FORCE
.DEFAULT_GOAL := all

all: $(SIMEXE)

$(OBJDIR):
	@mkdir -p $@

$(OBJDIR)/%.o: $(USRCODEDIR)/%.c | $(OBJDIR)
	@$(HOST_CC) -c -fPIC $(OPTFLAG) $(DEFS) $(INCLPATHS) $< -o $@

$(OBJDIR)/%.o: $(USRCODEDIR)/%.cpp | $(OBJDIR)
	@$(HOST_CXX) -c -fPIC $(OPTFLAG) $(CPPSTD) -Wno-write-strings $(DEFS) $(INCLPATHS) $< -o $@

$(OBJDIR)/%.o: $(VIP_DIR)/ltssm/%.c | $(OBJDIR)
	@$(HOST_CC) -c -fPIC $(OPTFLAG) $(DEFS) $(INCLPATHS) $< -o $@

$(USERLIB): $(VOBJS)
	@rm -f $@
	@$(HOST_AR) cr $@ $(VOBJS)

ifeq ($(SIM),verilator)
# Verilator decides itself what to rebuild; always ask it
$(SIMEXE): $(USERLIB) FORCE
	@$(VERILATOR) $(VLTFLAGS)
else
$(VPROC_SO): $(USERLIB)
	@$(HOST_CXX) -shared -fPIC -pthread -rdynamic -o $@ \
	    -Wl,-whole-archive $(USERLIB) -L$(VIP_DIR)/lib -lpcieica -lcosimica -Wl,-no-whole-archive \
	    -L$(ICA_LIB) -lvpi -lrt -ldl

$(ICA_FILES): tb.f FORCE | $(OBJDIR)
	@sed -e 's#$$VIP_DIR#$(VIP_DIR)#g' -e '/mem_model\.sv/d' $< > $@

$(SIMEXE): $(VPROC_SO) $(ICA_FILES) FORCE
	@$(IVERILOG) -o $@ $(ICAFLAGS)
endif

FORCE:

run: all
ifeq ($(SIM),verilator)
	@cd $(CURDIR) && $(SIMEXE)
else
	@cd $(CURDIR) && $(VVP) -n -M $(OBJDIR) -m VProc $(SIMEXE) $(VVPDUMP)
endif

help:
	@echo "make [SIM=verilator|icarus] [DUT=mock|rtl]   build the models and the simulation"
	@echo "make [SIM=verilator|icarus] run    build and run"
	@echo "make DUMP=1 run                    also write tb.fst (WaveCrux: tb.DLL-PIPE.wavecrux)"
	@echo "make clean                         remove obj/"
	@echo "USER_C, USRCODEDIR, OPTFLAG, USRSIMFLAGS (extra simulator flags) can be overridden"

clean:
	@rm -rf $(CURDIR)/obj

# -----------------------------------------------------------------------------
# Project:     openCologne-PCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        April 2025
# -----------------------------------------------------------------------------
