// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openCologne-PCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
// Description:
//   ep_wavecrux_view: simulation-only view of our EP's layer boundaries, for
//   the WaveCrux decoders (make DUT=rtl DUMP=1). Bound into pcie_core as
//   "wavecrux", so it is the same with PHY=vproc_rc and PHY=rtl. Nothing in
//   the design reads it.
//
//   Each boundary is offered under the names the decoders auto-bind (a
//   decoder signal matches the suffix of a signal name under a shared
//   prefix), by link direction as on the host's page, tb.u_rc
//   (dn = RC -> EP, up = EP -> RC):
//
//     PIPE         pipe_dn_*, pipe_up_* (pclk, data, datak; rxvalid and
//     PHY <-> MAC  rxstatus dn, txelecidle up): scrambled, with the ordered
//                  sets. wcx-pcie PCIe PIPE and PCIe Data Link Layer,
//                  ferrite.pcie_pipe_w64 / pcie_dll_w64
//     MAC <-> DLL  mac_dn_*, mac_up_* (pclk, data, datak): descrambled,
//                  framed packets only. wcx-pcie PCIe Data Link Layer,
//                  scrambling off
//     DLL <-> TL   dll_*: dll_if, its TLPs. WaveCrux Pro PCIe TLP, generic,
//     (dll_if)     Data Width 64: clk, rst_n, tlp_* the DLL -> TL direction,
//                  peer_* TL -> DLL, with peer_keep from tx_tlp_last_half.
//                  One instance shows both directions and pairs each
//                  Completion with its request. Each DW byte-swapped to
//                  byte 0 in [31:24], as the TL reads it (trn_byte_swap)
//     TL <->       trn_*: trn_if, the same decoder: tlp_* TRN RX, peer_* TRN
//     trn_bridge   TX; DW0 moved to [31:0], ready from the TRN handshake,
//     (trn_if)     keep from rrem / trem
//     trn_bridge   m_axis_rx_*, s_axis_tx_*, user_clk_out, user_reset_out:
//     <-> SOC      as they are, the names of the Pro decoder's Xilinx 7
//     (AXI-Stream) Series preset (PG054); m_axis_rx_tuser padded to its 22
//                  bits. tlp_view.tx_* / rx_*: one DW per clock, for our
//                  free TLP decoder (tools/wavecrux-pcie-tlp)
//
//   and the link state as rows: ltssm_state, dl_state (enums), the same as
//   text (ltssm_name, dl_name: ASCII format), link_up.
//
//   The SOC CPU's retired instructions, for WaveCrux's RISC-V decoder, are
//   bound at the end of this file: riscv_pcie_soc.cpu_view.
//==========================================================================

module ep_wavecrux_view
  import pcie_pkg::*;
(
    input logic rst_n,  // core_rst_n

           pipe_if.mac    pipe,
           dll_if.tl      dll,
           trn_if.core    trn,
           axis_if.slave  s_axis_tx,
           axis_if.master m_axis_rx,

    input logic [63:0] mac_tx_data,   // DLL -> MAC
    input logic [ 7:0] mac_tx_datak,
    input logic [63:0] mac_rx_data,   // MAC -> DLL
    input logic [ 7:0] mac_rx_datak,
    input logic [ 4:0] ltssm,
    input logic        link
);

  // ccfpga_LTSSM_fsm, dll_fsm
  typedef enum logic [4:0] {
    DETECT_QUIET                    = 5'b00000,
    DETECT_ACTIVE                   = 5'b00001,
    POLLING_ACTIVE                  = 5'b00010,
    POLLING_CONFIG                  = 5'b00011,
    CONFIG_LINKWIDTH_START          = 5'b00100,
    CONFIG_LINKWIDTH_ACCEPT         = 5'b00101,
    CONFIG_LANENUM_WAIT             = 5'b00110,
    CONFIG_LANENUM_ACCEPT           = 5'b00111,
    CONFIG_COMPLETE                 = 5'b01000,
    CONFIG_IDLE                     = 5'b01001,
    L0                              = 5'b01010,
    RECOVERY_RCVRLOCK               = 5'b01011,
    PRE_CONFIG_LINKWIDTH_START      = 5'b01100,
    PRE_CONFIG_LINKWIDTH_ACCEPT     = 5'b01101,
    PRE_CONFIG_LANENUM_WAIT         = 5'b01110,
    PRE_CONFIG_LANENUM_ACCEPT       = 5'b01111,
    PRE_CONFIG_COMPLETE             = 5'b10000,
    PRE_CONFIG_IDLE                 = 5'b10001,
    CONFIG_LINKWIDTH_START_LINKNUM  = 5'b10010,
    CONFIG_LINKWIDTH_ACCEPT_LANENUM = 5'b10011,
    RECOVERY_RCVRCFG                = 5'b10100,
    RECOVERY_IDLE                   = 5'b10101,
    PRE_L0                          = 5'b10110,
    PRE_RECOVERY_RCVRLOCK           = 5'b10111,
    PRE_RECOVERY_RCVRCFG            = 5'b11000,
    PRE_RECOVERY_IDLE               = 5'b11001,
    PRE_DETECT_ACTIVE               = 5'b11010,
    PRE_DETECT_QUIET                = 5'b11011,
    PRE_POLLING_CONFIG              = 5'b11100,
    PRE_CONFIG_LINKWIDTH_START_CNT  = 5'b11101,
    PRE_CONFIG_LINKWIDTH_ACCEPT_CNT = 5'b11110
  } ltssm_e;

  typedef enum logic [2:0] {
    DL_INACTIVE = 3'b000,
    DL_INITFC1  = 3'b001,
    DL_INITFC2  = 3'b010,
    DL_ACTIVE   = 3'b011
  } dl_state_e;

  //------------------------------------------------------------------------
  // Rows: the link state, as enums and as text
  //------------------------------------------------------------------------
  localparam int TEXT_W = 32 * 8;  // 32 characters

  ltssm_e            ltssm_state;
  dl_state_e         dl_state;
  logic [TEXT_W-1:0] ltssm_text;
  logic [TEXT_W-1:0] dl_text;
  logic [TEXT_W-1:0] ltssm_name;
  logic [TEXT_W-1:0] dl_name;
  logic              link_up;

  // A string literal is right-justified, NULs in front, which a viewer's
  // ASCII format shows as \x00: move the text to the left, spaces after it
  function automatic logic [TEXT_W-1:0] ljust(input logic [TEXT_W-1:0] s);
    for (int i = 0; i < TEXT_W / 8; i++) begin
      if (s != '0 && s[TEXT_W-1-:8] == 8'h00) begin
        s = {s[TEXT_W-9:0], 8'h20};
      end
    end
    return s;
  endfunction

  always_comb begin
    ltssm_state = ltssm_e'(ltssm);
    dl_state    = dl_state_e'(dll.dl_state);
    link_up     = link;
    ltssm_name  = ljust(ltssm_text);
    dl_name     = ljust(dl_text);
  end

  always_comb begin
    unique0 case (ltssm_state)
      DETECT_QUIET:                    ltssm_text = "Detect.Quiet";
      DETECT_ACTIVE:                   ltssm_text = "Detect.Active";
      POLLING_ACTIVE:                  ltssm_text = "Polling.Active";
      POLLING_CONFIG:                  ltssm_text = "Polling.Configuration";
      CONFIG_LINKWIDTH_START:          ltssm_text = "Config.Linkwidth.Start";
      CONFIG_LINKWIDTH_ACCEPT:         ltssm_text = "Config.Linkwidth.Accept";
      CONFIG_LANENUM_WAIT:             ltssm_text = "Config.Lanenum.Wait";
      CONFIG_LANENUM_ACCEPT:           ltssm_text = "Config.Lanenum.Accept";
      CONFIG_COMPLETE:                 ltssm_text = "Config.Complete";
      CONFIG_IDLE:                     ltssm_text = "Config.Idle";
      L0:                              ltssm_text = "L0";
      RECOVERY_RCVRLOCK:               ltssm_text = "Recovery.RcvrLock";
      PRE_CONFIG_LINKWIDTH_START:      ltssm_text = "pre Config.Linkwidth.Start";
      PRE_CONFIG_LINKWIDTH_ACCEPT:     ltssm_text = "pre Config.Linkwidth.Accept";
      PRE_CONFIG_LANENUM_WAIT:         ltssm_text = "pre Config.Lanenum.Wait";
      PRE_CONFIG_LANENUM_ACCEPT:       ltssm_text = "pre Config.Lanenum.Accept";
      PRE_CONFIG_COMPLETE:             ltssm_text = "pre Config.Complete";
      PRE_CONFIG_IDLE:                 ltssm_text = "pre Config.Idle";
      CONFIG_LINKWIDTH_START_LINKNUM:  ltssm_text = "Config.Linkwidth.Start link#";
      CONFIG_LINKWIDTH_ACCEPT_LANENUM: ltssm_text = "Config.Linkwidth.Accept lane#";
      RECOVERY_RCVRCFG:                ltssm_text = "Recovery.RcvrCfg";
      RECOVERY_IDLE:                   ltssm_text = "Recovery.Idle";
      PRE_L0:                          ltssm_text = "pre L0";
      PRE_RECOVERY_RCVRLOCK:           ltssm_text = "pre Recovery.RcvrLock";
      PRE_RECOVERY_RCVRCFG:            ltssm_text = "pre Recovery.RcvrCfg";
      PRE_RECOVERY_IDLE:               ltssm_text = "pre Recovery.Idle";
      PRE_DETECT_ACTIVE:               ltssm_text = "pre Detect.Active";
      PRE_DETECT_QUIET:                ltssm_text = "pre Detect.Quiet";
      PRE_POLLING_CONFIG:              ltssm_text = "pre Polling.Configuration";
      PRE_CONFIG_LINKWIDTH_START_CNT:  ltssm_text = "pre Config.Linkwidth.Start cnt";
      PRE_CONFIG_LINKWIDTH_ACCEPT_CNT: ltssm_text = "pre Config.Linkwidth.Accept cnt";
      default:                         ltssm_text = "?";
    endcase
  end

  always_comb begin
    unique0 case (dl_state)
      DL_INACTIVE: dl_text = "DL_Inactive";
      DL_INITFC1:  dl_text = "DL_Init FC1";
      DL_INITFC2:  dl_text = "DL_Init FC2";
      DL_ACTIVE:   dl_text = "DL_Active";
      default:     dl_text = "?";
    endcase
  end

  //------------------------------------------------------------------------
  // PIPE, PHY <-> MAC: wcx-pcie PIPE and Data Link Layer decoders
  //------------------------------------------------------------------------
  logic        pipe_dn_pclk;
  logic [63:0] pipe_dn_data;
  logic [ 7:0] pipe_dn_datak;
  logic        pipe_dn_rxvalid;
  logic [ 2:0] pipe_dn_rxstatus;
  logic        pipe_up_pclk;
  logic [63:0] pipe_up_data;
  logic [ 7:0] pipe_up_datak;
  logic        pipe_up_txelecidle;

  always_comb begin
    pipe_dn_pclk       = pipe.pclk;
    pipe_dn_data       = pipe.rx_data;
    pipe_dn_datak      = pipe.rx_datak;
    pipe_dn_rxvalid    = pipe.rx_valid;
    pipe_dn_rxstatus   = pipe.rx_status;
    pipe_up_pclk       = pipe.pclk;
    pipe_up_data       = pipe.tx_data;
    pipe_up_datak      = pipe.tx_datak;
    pipe_up_txelecidle = pipe.tx_elec_idle;
  end

  //------------------------------------------------------------------------
  // MAC <-> DLL: wcx-pcie Data Link Layer decoder, scrambling off
  //------------------------------------------------------------------------
  logic        mac_dn_pclk;
  logic [63:0] mac_dn_data;
  logic [ 7:0] mac_dn_datak;
  logic        mac_up_pclk;
  logic [63:0] mac_up_data;
  logic [ 7:0] mac_up_datak;

  always_comb begin
    mac_dn_pclk  = pipe.pclk;
    mac_dn_data  = mac_rx_data;
    mac_dn_datak = mac_rx_datak;
    mac_up_pclk  = pipe.pclk;
    mac_up_data  = mac_tx_data;
    mac_up_datak = mac_tx_datak;
  end

  //------------------------------------------------------------------------
  // DLL <-> TL (dll_if): WaveCrux Pro PCIe TLP decoder, generic, Data Width
  // 64. A beat moves on every clock with valid high (no ready on dll_if)
  //------------------------------------------------------------------------
  logic        dll_clk;
  logic        dll_rst_n;
  logic [63:0] dll_tlp_data;
  logic        dll_tlp_sop;
  logic        dll_tlp_eop;
  logic        dll_tlp_valid;
  logic [63:0] dll_peer_data;
  logic        dll_peer_sop;
  logic        dll_peer_eop;
  logic        dll_peer_valid;
  logic [ 7:0] dll_peer_keep;

  always_comb begin
    dll_clk        = pipe.pclk;
    dll_rst_n      = rst_n;
    dll_tlp_data   = trn_byte_swap(dll.rx_data);
    dll_tlp_sop    = dll.rx_tlp_first;
    dll_tlp_eop    = dll.rx_tlp_last;
    dll_tlp_valid  = dll.rx_tlp_valid;
    dll_peer_data  = trn_byte_swap(dll.tx_data);
    dll_peer_sop   = dll.tx_tlp_first;
    dll_peer_eop   = dll.tx_tlp_last;
    dll_peer_valid = dll.tx_tlp_valid;
    dll_peer_keep  = dll.tx_tlp_last && dll.tx_tlp_last_half ? 8'h0F : 8'hFF;
  end

  //------------------------------------------------------------------------
  // TL <-> trn_bridge (trn_if): the same decoder. tlp is TRN RX, peer TRN
  // TX; a beat moves when src_rdy and dst_rdy are both high
  //------------------------------------------------------------------------
  logic        trn_clk;
  logic        trn_rst_n;
  logic [63:0] trn_tlp_data;
  logic        trn_tlp_sop;
  logic        trn_tlp_eop;
  logic        trn_tlp_valid;
  logic        trn_tlp_ready;
  logic [ 7:0] trn_tlp_keep;
  logic [63:0] trn_peer_data;
  logic        trn_peer_sop;
  logic        trn_peer_eop;
  logic        trn_peer_valid;
  logic        trn_peer_ready;
  logic [ 7:0] trn_peer_keep;

  always_comb begin
    trn_clk        = pipe.pclk;
    trn_rst_n      = rst_n;
    trn_tlp_data   = {trn.rd[31:0], trn.rd[63:32]};
    trn_tlp_sop    = trn.rsof;
    trn_tlp_eop    = trn.reof;
    trn_tlp_valid  = trn.rsrc_rdy;
    trn_tlp_ready  = trn.rdst_rdy;
    trn_tlp_keep   = trn.rrem ? 8'hFF : 8'h0F;
    trn_peer_data  = {trn.td[31:0], trn.td[63:32]};
    trn_peer_sop   = trn.tsof;
    trn_peer_eop   = trn.teof;
    trn_peer_valid = trn.tsrc_rdy;
    trn_peer_ready = trn.tdst_rdy;
    trn_peer_keep  = trn.trem ? 8'hFF : 8'h0F;
  end

  //------------------------------------------------------------------------
  // trn_bridge <-> SOC (AXI-Stream): the Pro decoder's Xilinx 7 Series
  // preset, under PG054's names
  //------------------------------------------------------------------------
  logic        user_clk_out;
  logic        user_reset_out;

  logic [63:0] m_axis_rx_tdata;
  logic [ 7:0] m_axis_rx_tkeep;
  logic        m_axis_rx_tlast;
  logic        m_axis_rx_tvalid;
  logic        m_axis_rx_tready;
  logic [21:0] m_axis_rx_tuser;

  logic [63:0] s_axis_tx_tdata;
  logic [ 7:0] s_axis_tx_tkeep;
  logic        s_axis_tx_tlast;
  logic        s_axis_tx_tvalid;
  logic        s_axis_tx_tready;
  logic [ 3:0] s_axis_tx_tuser;

  always_comb begin
    user_clk_out     = pipe.pclk;
    user_reset_out   = !rst_n;

    m_axis_rx_tdata  = m_axis_rx.tdata;
    m_axis_rx_tkeep  = m_axis_rx.tkeep;
    m_axis_rx_tlast  = m_axis_rx.tlast;
    m_axis_rx_tvalid = m_axis_rx.tvalid;
    m_axis_rx_tready = m_axis_rx.tready;
    m_axis_rx_tuser  = 22'(m_axis_rx.tuser);

    s_axis_tx_tdata  = s_axis_tx.tdata;
    s_axis_tx_tkeep  = s_axis_tx.tkeep;
    s_axis_tx_tlast  = s_axis_tx.tlast;
    s_axis_tx_tvalid = s_axis_tx.tvalid;
    s_axis_tx_tready = s_axis_tx.tready;
    s_axis_tx_tuser  = s_axis_tx.tuser;
  end

  //------------------------------------------------------------------------
  // trn_bridge <-> SOC, one DW per clock, for our free TLP decoder:
  // tlp_view.tx_* (RC -> EP, m_axis_rx), tlp_view.rx_* (EP -> RC, s_axis_tx)
  //------------------------------------------------------------------------
  tlp_dw_if dw_dn (.clk(pipe.pclk));
  tlp_dw_if dw_up (.clk(pipe.pclk));

  tlp_dw_monitor u_mon_dn (
      .axis_tdata (m_axis_rx.tdata),
      .axis_tkeep (m_axis_rx.tkeep),
      .axis_tlast (m_axis_rx.tlast),
      .axis_tvalid(m_axis_rx.tvalid),
      .axis_tready(m_axis_rx.tready),
      .dw         (dw_dn)
  );

  tlp_dw_monitor u_mon_up (
      .axis_tdata (s_axis_tx.tdata),
      .axis_tkeep (s_axis_tx.tkeep),
      .axis_tlast (s_axis_tx.tlast),
      .axis_tvalid(s_axis_tx.tvalid),
      .axis_tready(s_axis_tx.tready),
      .dw         (dw_up)
  );

  tlp_wavecrux_view tlp_view (
      .tx(dw_dn),
      .rx(dw_up)
  );

endmodule: ep_wavecrux_view

bind pcie_core ep_wavecrux_view wavecrux (
    .rst_n       (core_rst_n),
    .pipe        (pipe),
    .dll         (dll),
    .trn         (trn),
    .s_axis_tx   (s_axis_tx),
    .m_axis_rx   (m_axis_rx),
    .mac_tx_data (dll_tx_data),
    .mac_tx_datak(dll_tx_datak),
    .mac_rx_data (mac_rx_data),
    .mac_rx_datak(mac_rx_datak),
    .ltssm       (ltssm_state),
    .link        (trn_link_up)
);

// The SOC CPU's retired instructions under the RVFI names, for WaveCrux's
// RISC-V decoder and RVFI Commit Inspector (CPU.eduBOS5/wavecrux). eduBOS5
// drives rvfi with RISCV_FORMAL, which the make file adds with DUMP=1
bind riscv_pcie_soc soc_cpu_view cpu_view (
    .clk      (clk),
    .valid    (rvfi.rvfi_valid),
    .order    (rvfi.rvfi_order),
    .insn     (rvfi.rvfi_insn),
    .trap     (rvfi.rvfi_trap),
    .halt     (rvfi.rvfi_halt),
    .intr     (rvfi.rvfi_intr),
    .rs1_addr (rvfi.rvfi_rs1_addr),
    .rs2_addr (rvfi.rvfi_rs2_addr),
    .rs1_rdata(rvfi.rvfi_rs1_rdata),
    .rs2_rdata(rvfi.rvfi_rs2_rdata),
    .rd_addr  (rvfi.rvfi_rd_addr),
    .rd_wdata (rvfi.rvfi_rd_wdata),
    .pc_rdata (rvfi.rvfi_pc_rdata),
    .pc_wdata (rvfi.rvfi_pc_wdata),
    .mem_addr (rvfi.rvfi_mem_addr),
    .mem_rmask(rvfi.rvfi_mem_rmask),
    .mem_wmask(rvfi.rvfi_mem_wmask),
    .mem_rdata(rvfi.rvfi_mem_rdata),
    .mem_wdata(rvfi.rvfi_mem_wdata)
);

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        Oct 23, 2026
// -----------------------------------------------------------------------------
