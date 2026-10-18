// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause
//
// Verilator source list of the openCologne-PCIE co-simulation test bench.
// $VIP_DIR is the VIP that tools/build-vip.sh builds from vip/; the make
// file sets it. The DUT here is the mock, EPPIPEx1__pcieVHost_DUT.

+incdir+$VIP_DIR/hdl/headers
+incdir+$VIP_DIR/hdl

// pcieVHost's macros (timescale, display flags, register map, `fatal) first,
// so every model below sees them, whatever the simulator
$VIP_DIR/hdl/headers/allheaders.v

// Co-simulation models
models/cosim/mem_model.sv
$VIP_DIR/hdl/f_VProc.v
$VIP_DIR/hdl/clkmux.v
$VIP_DIR/hdl/Serialiser.v
$VIP_DIR/hdl/pcieVHost.v
$VIP_DIR/hdl/pcieVHostPipex1.v
models/RCPIPEx1__pcieVHost.sv

// DUT: the mock EP (make DUT=mock)
stubs/EPPIPEx1__pcieVHost_DUT.sv

// Test bench
tb.sv
