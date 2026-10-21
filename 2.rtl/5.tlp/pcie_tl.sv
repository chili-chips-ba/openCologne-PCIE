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
//   pcie_tl: the Transaction Layer. The TL sits
//   between the DLL (dll_if) and the SOC, and has the same user interface as
//   the AMD PCIE_2_1 hard block in EP mode (UG477): TLPs as two AXI-Stream
//   streams, and the cfg sideband. Its job:
//
//   - flow control: send UpdateFC credits to the DLL, and hold a
//     TLP back until the link partner has advertised room for it;
//   - the configuration space: answer Configuration Requests itself (Vendor
//     and Device ID, BAR0, the capability list), and capture the bus, device
//     and function number the host assigns (cfg);
//   - the rest: hand Memory Requests to the SOC on m_axis_rx, and send its
//     Completions from s_axis_tx.
//==========================================================================

module pcie_tl
  import pcie_pkg::*;
  import tl_pkg::*;
#(
    parameter logic [15:0] VENDOR_ID        = 16'h1234,
    parameter logic [15:0] DEVICE_ID        = 16'h0001,
    parameter logic [ 7:0] REVISION_ID      = 8'h00,
    parameter logic [23:0] CLASS_CODE       = 24'hFF0000,
    parameter logic [15:0] SUBSYS_VENDOR_ID = 16'h1234,
    parameter logic [15:0] SUBSYS_ID        = 16'h0001,
    parameter int          BAR0_SIZE_BITS   = 12,
    parameter logic [ 7:0] INIT_PH          = 8'd8,
    parameter logic [11:0] INIT_PD          = 12'd32,
    parameter logic [ 7:0] INIT_NPH         = 8'd8,
    parameter logic [11:0] INIT_NPD         = 12'd8,
    parameter int          P_ADDR_W         = 7,
    parameter int          NP_ADDR_W        = 6,
    parameter logic [ 1:0] ASPM_SUPPORT     = 2'b01,
    parameter logic [ 2:0] L0S_EXIT_LATENCY = 3'b111,
    parameter logic [ 2:0] L1_EXIT_LATENCY  = 3'b111,
    parameter logic [ 2:0] L0S_ACCEPT_LAT   = 3'b111,
    parameter logic [ 2:0] L1_ACCEPT_LAT    = 3'b111,
    parameter logic        SLOT_CLOCK       = 1'b1
) (
    input logic clk,   // PCLK
    input logic rst_n, // core_rst_n

    dll_if.tl dll,

    axis_if.slave  s_axis_tx,  // TLPs from the SOC (tuser: pcie_tx_tuser_t)
    axis_if.master m_axis_rx,  // TLPs to the SOC   (tuser: pcie_rx_tuser_t)

    cfg_if.core cfg  // status sideband to the SOC
);

  localparam logic [TRN_KEEP_W-1:0] KEEP_ALL    = '1;
  localparam logic [TRN_KEEP_W-1:0] KEEP_LOW_DW = KEEP_ALL >> (TRN_KEEP_W / 2);

  logic                  dl_up;
  logic                  dl_inactive;

  tl_beat_t              rx;
  tl_beat_t              tx;
  logic                  tx_half;
  fc_dllp_t              rx_dllp;
  fc_dllp_t              tx_dllp;

  tl_beat_t              app_tx;
  logic                  app_tx_ready;
  logic                  app_tx_mid;
  tl_app_rx_t            app_rx;
  pcie_rx_tuser_t        rx_tuser;

  tl_qwr_t               p_wr;
  tl_qwr_t               np_wr;
  logic                  p_full;
  logic                  np_full;
  logic                  p_commit;
  logic                  np_commit;
  logic                  p_pop;
  logic                  np_pop;
  tl_qrd_t               p_rd;
  tl_qrd_t               np_rd;
  logic                  p_done;
  logic                  np_done;
  logic                  np_ready;

  fc_cred_t              p_alloc;
  fc_cred_t              np_alloc;
  fc_rel_t               rx_rel;
  fc_rel_t               dp_rel;
  fc_rel_t               consume;
  fc_tx_t         [ 2:0] tx_fc;

  logic                  rx_err_malformed;
  logic                  rx_err_overflow;
  logic                  dp_ev_ur;
  logic                  dp_ev_poisoned;
  tl_err_t               err;
  tl_cfg_acc_t           cfg_acc;
  logic           [31:0] cfg_rdata;
  tl_id_t                id;
  tl_sspl_t              sspl;
  tl_cfg_t               tl_cfg;
  logic                  msg_nonfatal;
  logic                  msg_fatal;

  logic                  cpl_ready;
  logic                  cpl_hold;
  logic                  cpl_req;
  tl_cpl_t               cpl;
  tl_src_t               int_src;
  logic                  int_ready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dl_up       <= 1'b0;
      dl_inactive <= 1'b1;
    end
    else begin
      dl_up       <= (dll.dl_state == DL_INITFC2) || (dll.dl_state == DL_ACTIVE);
      dl_inactive <= (dll.dl_state == DL_INACTIVE);
    end
  end

  assign rx.valid             = dll.rx_tlp_valid;
  assign rx.first             = dll.rx_tlp_first;
  assign rx.last              = dll.rx_tlp_last;
  assign rx.data              = trn_byte_swap(dll.rx_data);

  assign dll.tx_data          = trn_byte_swap(tx.data);
  assign dll.tx_tlp_valid     = tx.valid;
  assign dll.tx_tlp_first     = tx.first;
  assign dll.tx_tlp_last      = tx.last;
  assign dll.tx_tlp_last_half = tx_half;

  assign rx_dllp.valid        = dll.rx_dllp_valid;
  assign rx_dllp.packet_type  = dll.rx_packet_type;
  assign rx_dllp.update_type  = dll.rx_update_type;
  assign rx_dllp.cred.hdr     = dll.rx_hdr_credit;
  assign rx_dllp.cred.data    = dll.rx_data_credit;

  assign dll.tx_dllp_valid    = tx_dllp.valid;
  assign dll.tx_packet_type   = tx_dllp.packet_type;
  assign dll.tx_update_type   = tx_dllp.update_type;
  assign dll.tx_hdr_credit    = tx_dllp.cred.hdr;
  assign dll.tx_data_credit   = tx_dllp.cred.data;

  always_ff @(posedge clk or negedge dl_up) begin
    if (!dl_up) begin
      app_tx_mid <= 1'b0;
    end
    else if (s_axis_tx.tvalid && s_axis_tx.tready) begin
      app_tx_mid <= !s_axis_tx.tlast;
    end
  end

  assign app_tx.valid        = s_axis_tx.tvalid;
  assign app_tx.first        = !app_tx_mid;
  assign app_tx.last         = s_axis_tx.tlast;
  assign app_tx.data         = s_axis_tx.tdata;
  assign s_axis_tx.tready    = app_tx_ready;

  assign rx_tuser.bar_hit    = {2'b00, app_rx.bar_hit};
  assign rx_tuser.err_fwd    = app_rx.poisoned;
  assign rx_tuser.ecrc_err   = 1'b0;

  assign m_axis_rx.tdata     = app_rx.data;
  assign m_axis_rx.tkeep     = (app_rx.last && app_rx.half) ? KEEP_LOW_DW : KEEP_ALL;
  assign m_axis_rx.tuser     = rx_tuser;
  assign m_axis_rx.tlast     = app_rx.last;
  assign m_axis_rx.tvalid    = app_rx.valid;

  assign cfg.msg_err_fatal   = 1'b0;
  assign cfg.tx_buf_avail    = {5'd0, dll.tx_tlp_ready};
  assign cfg.bus_number      = tl_cfg.bus_number;
  assign cfg.device_number   = tl_cfg.device_number;
  assign cfg.function_number = 3'd0;

  assign err.malformed       = rx_err_malformed;
  assign err.overflow        = rx_err_overflow;
  assign err.ur              = dp_ev_ur;
  assign err.poisoned        = dp_ev_poisoned;

  tlp_rx_handler u_rx_handler (
      .clk             (clk),
      .rst_n           (dl_up),
      .rx              (rx),
      .max_payload_size(tl_cfg.max_payload_size),
      .p_alloc         (p_alloc),
      .np_alloc        (np_alloc),
      .p_wr            (p_wr),
      .p_full          (p_full),
      .np_wr           (np_wr),
      .np_full         (np_full),
      .rel             (rx_rel),
      .err_malformed   (rx_err_malformed),
      .err_overflow    (rx_err_overflow)
  );

  tlp_queue #(
      .ADDR_W(P_ADDR_W)
  ) u_p_queue (
      .clk    (clk),
      .rst_n  (dl_up),
      .wr     (p_wr),
      .wr_full(p_full),
      .commit (p_commit),
      .pop    (p_pop),
      .rd     (p_rd),
      .done   (p_done)
  );

  tlp_queue #(
      .ADDR_W(NP_ADDR_W)
  ) u_np_queue (
      .clk    (clk),
      .rst_n  (dl_up),
      .wr     (np_wr),
      .wr_full(np_full),
      .commit (np_commit),
      .pop    (np_pop),
      .rd     (np_rd),
      .done   (np_done)
  );

  tlp_order u_order (
      .clk      (clk),
      .rst_n    (dl_up),
      .p_commit (p_commit),
      .p_done   (p_done),
      .np_commit(np_commit),
      .np_done  (np_done),
      .np_ready (np_ready)
  );

  tlp_rx_dispatch #(
      .BAR0_SIZE_BITS(BAR0_SIZE_BITS)
  ) u_rx_dispatch (
      .clk          (clk),
      .rst_n        (dl_up),
      .p_rd         (p_rd),
      .p_pop        (p_pop),
      .np_rd        (np_rd),
      .np_ready     (np_ready),
      .np_pop       (np_pop),
      .app_rx       (app_rx),
      .app_rx_ready (m_axis_rx.tready),
      .memory_enable(tl_cfg.memory_enable),
      .bar0_base    (tl_cfg.bar0_base),
      .cfg_acc      (cfg_acc),
      .cfg_rdata    (cfg_rdata),
      .id           (id),
      .sspl         (sspl),
      .cpl_ready    (cpl_ready),
      .cpl_hold     (cpl_hold),
      .cpl_req      (cpl_req),
      .cpl          (cpl),
      .rel          (dp_rel),
      .ev_ur        (dp_ev_ur),
      .ev_poisoned  (dp_ev_poisoned)
  );

  config_space #(
      .VENDOR_ID       (VENDOR_ID),
      .DEVICE_ID       (DEVICE_ID),
      .REVISION_ID     (REVISION_ID),
      .CLASS_CODE      (CLASS_CODE),
      .SUBSYS_VENDOR_ID(SUBSYS_VENDOR_ID),
      .SUBSYS_ID       (SUBSYS_ID),
      .BAR0_SIZE_BITS  (BAR0_SIZE_BITS),
      .ASPM_SUPPORT    (ASPM_SUPPORT),
      .L0S_EXIT_LATENCY(L0S_EXIT_LATENCY),
      .L1_EXIT_LATENCY (L1_EXIT_LATENCY),
      .L0S_ACCEPT_LAT  (L0S_ACCEPT_LAT),
      .L1_ACCEPT_LAT   (L1_ACCEPT_LAT),
      .SLOT_CLOCK      (SLOT_CLOCK)
  ) u_cfg_space (
      .clk         (clk),
      .rst_n       (dl_up),
      .acc         (cfg_acc),
      .rdata       (cfg_rdata),
      .id          (id),
      .sspl        (sspl),
      .err         (err),
      .msg_nonfatal(msg_nonfatal),
      .msg_fatal   (msg_fatal),
      .cfg         (tl_cfg)
  );

  cpl_gen u_cpl_gen (
      .clk         (clk),
      .rst_n       (dl_up),
      .own_id      ({tl_cfg.bus_number, tl_cfg.device_number, 3'b000}),
      .cpl_req     (cpl_req),
      .cpl         (cpl),
      .cpl_hold    (cpl_hold),
      .cpl_ready   (cpl_ready),
      .msg_nonfatal(msg_nonfatal),
      .msg_fatal   (msg_fatal),
      .src         (int_src),
      .src_ready   (int_ready)
  );

  fc_credit #(
      .INIT_PH (INIT_PH),
      .INIT_PD (INIT_PD),
      .INIT_NPH(INIT_NPH),
      .INIT_NPD(INIT_NPD)
  ) u_fc_credit (
      .clk        (clk),
      .rst_n      (rst_n),
      .rx_rst_n   (dl_up),
      .dl_inactive(dl_inactive),
      .rx_dllp    (rx_dllp),
      .tx_fc      (tx_fc),
      .consume    (consume),
      .p_alloc    (p_alloc),
      .np_alloc   (np_alloc),
      .rel_a      (rx_rel),
      .rel_b      (dp_rel),
      .tx_dllp    (tx_dllp)
  );

  tlp_tx_arbiter u_tx_arbiter (
      .clk              (clk),
      .rst_n            (dl_up),
      .int_src          (int_src),
      .int_ready        (int_ready),
      .app_tx           (app_tx),
      .app_tx_ready     (app_tx_ready),
      .bus_master_enable(tl_cfg.bus_master_enable),
      .tx_fc            (tx_fc),
      .consume          (consume),
      .tx               (tx),
      .tx_half          (tx_half),
      .tx_ready         (dll.tx_tlp_ready)
  );

endmodule

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 18, 2026
// -----------------------------------------------------------------------------
