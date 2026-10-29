# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Clocks of top for nextpnr-himbaechel (run-pnr.sh). The board clock feeds the
# CC_PLL in clk_rst_gen.sv (BRD_CLK_MHZ); the SOC and the PIPE logic run on
# PCLK, 31.25 MHz (5.sim tb_soc.sv).

create_clock -period 100 [get_ports clk_brd]
create_clock -period 32 [get_nets pipe_mac.pclk]
