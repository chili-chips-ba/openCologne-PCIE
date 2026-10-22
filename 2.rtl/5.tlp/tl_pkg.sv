package tl_pkg;

  import pcie_pkg::*;

  typedef enum logic [3:0] {
    K_MRD     = 4'd0,
    K_MRDLK   = 4'd1,
    K_MWR     = 4'd2,
    K_IORD    = 4'd3,
    K_IOWR    = 4'd4,
    K_CFGRD0  = 4'd5,
    K_CFGWR0  = 4'd6,
    K_CFGRD1  = 4'd7,
    K_CFGWR1  = 4'd8,
    K_MSG     = 4'd9,
    K_MSGD    = 4'd10,
    K_CPL     = 4'd11,
    K_CPLD    = 4'd12,
    K_ATOMIC  = 4'd13,
    K_UNKNOWN = 4'd15
  } tlp_kind_e;

  typedef enum logic [1:0] {
    FC_P   = 2'b00,
    FC_NP  = 2'b01,
    FC_CPL = 2'b10
  } fc_class_e;

  localparam logic [1:0] DLLP_INITFC1       = 2'b01;
  localparam logic [1:0] DLLP_UPDATEFC      = 2'b10;
  localparam logic [1:0] DLLP_INITFC2       = 2'b11;

  localparam logic [2:0] DL_INACTIVE        = 3'b000;
  localparam logic [2:0] DL_INITFC2         = 3'b010;
  localparam logic [2:0] DL_ACTIVE          = 3'b011;

  localparam logic [7:0] MSG_UNLOCK         = 8'h00;
  localparam logic [7:0] MSG_PM_ASPM_NAK    = 8'h14;
  localparam logic [7:0] MSG_PME_TURN_OFF   = 8'h19;
  localparam logic [7:0] MSG_PME_TO_ACK     = 8'h1B;
  localparam logic [7:0] MSG_ERR_NONFATAL   = 8'h31;
  localparam logic [7:0] MSG_ERR_FATAL      = 8'h33;
  localparam logic [7:0] MSG_IGNORED_FIRST  = 8'h40;
  localparam logic [7:0] MSG_IGNORED_LAST   = 8'h48;
  localparam logic [7:0] MSG_SET_SLOT_POWER = 8'h50;
  localparam logic [7:0] MSG_VENDOR_TYPE1   = 8'h7F;

  localparam logic [2:0] MSG_ROUTE_TO_RC    = 3'b000;
  localparam logic [2:0] MSG_ROUTE_GATHER   = 3'b101;

  localparam logic [2:0] CPL_SC             = 3'b000;
  localparam logic [2:0] CPL_UR             = 3'b001;

  function automatic logic [2:0] tlp_fmt(input pcie_tlp_dw0_t hdr_dw0);
    return {hdr_dw0.rsvd0, hdr_dw0.fmt};
  endfunction

  function automatic tlp_kind_e tlp_kind(input pcie_tlp_dw0_t hdr_dw0);
    tlp_kind_e       kind;
    logic      [2:0] fmt;
    fmt  = tlp_fmt(hdr_dw0);
    kind = K_UNKNOWN;
    if (hdr_dw0.tlp_type[4:3] == TLP_TYPE_MSG && hdr_dw0.tlp_type[2:0] <= 3'b101) begin
      if (fmt == {1'b0, TLP_FMT_4DW}) begin
        kind = K_MSG;
      end
      else if (fmt == {1'b0, TLP_FMT_4DW_DATA}) begin
        kind = K_MSGD;
      end
    end
    unique0 case ({
      fmt, hdr_dw0.tlp_type
    })
      {1'b0, TLP_FMT_3DW, TLP_TYPE_MEM}, {1'b0, TLP_FMT_4DW, TLP_TYPE_MEM} : kind = K_MRD;
      {1'b0, TLP_FMT_3DW, TLP_TYPE_MEM_LK}, {1'b0, TLP_FMT_4DW, TLP_TYPE_MEM_LK} : kind = K_MRDLK;
      {1'b0, TLP_FMT_3DW_DATA, TLP_TYPE_MEM}, {1'b0, TLP_FMT_4DW_DATA, TLP_TYPE_MEM} : kind = K_MWR;
      {1'b0, TLP_FMT_3DW, TLP_TYPE_IO} : kind = K_IORD;
      {1'b0, TLP_FMT_3DW_DATA, TLP_TYPE_IO} : kind = K_IOWR;
      {1'b0, TLP_FMT_3DW, TLP_TYPE_CFG, 1'b0} : kind = K_CFGRD0;
      {1'b0, TLP_FMT_3DW_DATA, TLP_TYPE_CFG, 1'b0} : kind = K_CFGWR0;
      {1'b0, TLP_FMT_3DW, TLP_TYPE_CFG, 1'b1} : kind = K_CFGRD1;
      {1'b0, TLP_FMT_3DW_DATA, TLP_TYPE_CFG, 1'b1} : kind = K_CFGWR1;
      {1'b0, TLP_FMT_3DW, TLP_TYPE_CPL}, {1'b0, TLP_FMT_3DW, TLP_TYPE_CPL_LK} : kind = K_CPL;
      {
        1'b0, TLP_FMT_3DW_DATA, TLP_TYPE_CPL
      }, {
        1'b0, TLP_FMT_3DW_DATA, TLP_TYPE_CPL_LK
      } :
      kind = K_CPLD;
      {
        1'b0, TLP_FMT_3DW_DATA, TLP_TYPE_FETCH_ADD
      }, {
        1'b0, TLP_FMT_4DW_DATA, TLP_TYPE_FETCH_ADD
      }, {
        1'b0, TLP_FMT_3DW_DATA, TLP_TYPE_SWAP
      }, {
        1'b0, TLP_FMT_4DW_DATA, TLP_TYPE_SWAP
      }, {
        1'b0, TLP_FMT_3DW_DATA, TLP_TYPE_CAS
      }, {
        1'b0, TLP_FMT_4DW_DATA, TLP_TYPE_CAS
      } :
      kind = K_ATOMIC;
    endcase
    return kind;
  endfunction

  function automatic fc_class_e tlp_class(input tlp_kind_e kind);
    fc_class_e fc_class;
    fc_class = FC_NP;
    if (kind == K_CPL || kind == K_CPLD) begin
      fc_class = FC_CPL;
    end
    else if (kind == K_MWR || kind == K_MSG || kind == K_MSGD || kind == K_UNKNOWN) begin
      fc_class = FC_P;
    end
    return fc_class;
  endfunction

  function automatic logic tlp_has_data(input pcie_tlp_dw0_t hdr_dw0);
    return hdr_dw0.fmt[1];
  endfunction

  function automatic logic tlp_4dw(input pcie_tlp_dw0_t hdr_dw0);
    return hdr_dw0.fmt[0];
  endfunction

  function automatic logic [10:0] tlp_length_dw(input pcie_tlp_dw0_t hdr_dw0);
    return (hdr_dw0.length == 10'd0) ? 11'd1024 : {1'b0, hdr_dw0.length};
  endfunction

  function automatic logic [11:0] tlp_data_credits(input pcie_tlp_dw0_t hdr_dw0);
    return tlp_has_data(hdr_dw0) ? ({1'b0, tlp_length_dw(hdr_dw0)} + 12'd3) >> 2 : 12'd0;
  endfunction

  function automatic logic [11:0] tlp_total_dw(input pcie_tlp_dw0_t hdr_dw0);
    return (tlp_4dw(hdr_dw0) ? 12'd4 : 12'd3) +
        (tlp_has_data(hdr_dw0) ? {1'b0, tlp_length_dw(hdr_dw0)} : 12'd0) + {11'd0, hdr_dw0.td};
  endfunction

  function automatic logic [10:0] tlp_words(input pcie_tlp_dw0_t hdr_dw0);
    return 11'((tlp_total_dw(hdr_dw0) + 12'd1) >> 1);
  endfunction

  function automatic logic tlp_last_half(input pcie_tlp_dw0_t hdr_dw0);
    return tlp_total_dw(hdr_dw0) % 12'd2 == 12'd1;
  endfunction

  typedef struct packed {
    logic                  valid;
    logic                  first;
    logic                  last;
    logic [TRN_DATA_W-1:0] data;
  } tl_beat_t;

  typedef struct packed {
    logic                  valid;
    logic                  last;
    logic                  half;
    logic                  poisoned;
    logic [5:0]            bar_hit;
    logic [TRN_DATA_W-1:0] data;
  } tl_app_rx_t;

  typedef struct packed {
    logic                  valid;
    logic                  first;
    logic                  last;
    logic                  half;
    fc_class_e             fc_class;
    logic [11:0]           data_credits;
    logic [TRN_DATA_W-1:0] data;
  } tl_src_t;

  typedef struct packed {
    logic                  last;
    logic [TRN_DATA_W-1:0] data;
  } tl_qword_t;

  typedef struct packed {
    logic      en;
    logic      drop;
    tl_qword_t word;
  } tl_qwr_t;

  typedef struct packed {
    logic                  avail;
    logic                  valid;
    tl_qword_t             head;
    logic [TRN_DATA_W-1:0] next;
  } tl_qrd_t;

  typedef struct packed {
    logic [7:0]  hdr;
    logic [11:0] data;
  } fc_cred_t;

  typedef struct packed {
    logic        valid;
    fc_class_e   fc_class;
    logic [11:0] data;
  } fc_rel_t;

  typedef struct packed {
    fc_cred_t limit;
    fc_cred_t consumed;
    logic     inf_hdr;
    logic     inf_data;
    logic     init;
  } fc_tx_t;

  typedef struct packed {
    logic       valid;
    logic [1:0] packet_type;
    logic [1:0] update_type;
    fc_cred_t   cred;
  } fc_dllp_t;

  typedef struct packed {
    logic        is_msg;
    logic        with_data;
    logic [2:0]  tc;
    logic [1:0]  attr;
    logic [15:0] requester_id;
    logic [7:0]  tag;
    logic [2:0]  status;
    logic [11:0] byte_count;
    logic [6:0]  lower_addr;
    logic [31:0] data;
    logic [7:0]  msg_code;
    logic [2:0]  msg_route;
  } tl_cpl_t;

  typedef struct packed {
    logic        write;
    logic [9:0]  regnum;
    logic [3:0]  be;
    logic [31:0] wdata;
  } tl_cfg_acc_t;

  typedef struct packed {
    logic       capture;
    logic [7:0] bus;
    logic [4:0] device;
  } tl_id_t;

  typedef struct packed {
    logic       capture;
    logic [1:0] scale;
    logic [7:0] value;
  } tl_sspl_t;

  typedef struct packed {
    logic ur;
    logic malformed;
    logic overflow;
    logic poisoned;
  } tl_err_t;

  typedef struct packed {
    logic [7:0]  bus_number;
    logic [4:0]  device_number;
    logic        memory_enable;
    logic        bus_master_enable;
    logic [31:0] bar0_base;
    logic [2:0]  max_payload_size;
  } tl_cfg_t;

  typedef struct packed {
    logic [4:0] rsvd0;
    logic       int_disable;
    logic       fast_b2b;
    logic       serr_en;
    logic       idsel_stepping;
    logic       parity_err_resp;
    logic       vga_snoop;
    logic       mwi_en;
    logic       special_cycles;
    logic       bus_master;
    logic       mem_space;
    logic       io_space;
  } pci_command_t;

  typedef struct packed {
    logic       detected_parity_err;
    logic       signaled_sys_err;
    logic       rcvd_master_abort;
    logic       rcvd_target_abort;
    logic       signaled_target_abort;
    logic [1:0] devsel_timing;
    logic       master_data_parity_err;
    logic       fast_b2b_capable;
    logic       rsvd0;
    logic       capable_66mhz;
    logic       cap_list;
    logic       int_status;
    logic [2:0] rsvd1;
  } pci_status_t;

  typedef struct packed {
    pci_status_t  status;
    pci_command_t command;
  } cfg_cmd_dw_t;

  typedef struct packed {
    logic       pme_status;
    logic [1:0] data_scale;
    logic [3:0] data_select;
    logic       pme_en;
    logic [3:0] rsvd0;
    logic       no_soft_reset;
    logic       rsvd1;
    logic [1:0] power_state;
  } pm_csr_t;

  typedef struct packed {
    logic [15:0] bse_data;
    pm_csr_t     csr;
  } cfg_pm_dw_t;

  typedef struct packed {
    logic [2:0] rsvd0;
    logic       flr_capable;
    logic [1:0] slot_power_scale;
    logic [7:0] slot_power_value;
    logic [1:0] rsvd1;
    logic       role_based_err;
    logic [2:0] rsvd2;
    logic [2:0] l1_accept_lat;
    logic [2:0] l0s_accept_lat;
    logic       ext_tag;
    logic [1:0] phantom_func;
    logic [2:0] max_payload;
  } pcie_dev_cap_t;

  typedef struct packed {
    logic       initiate_flr;
    logic [2:0] max_read_req;
    logic       no_snoop_en;
    logic       aux_power_en;
    logic       phantom_func_en;
    logic       ext_tag_en;
    logic [2:0] max_payload;
    logic       relaxed_ord_en;
    logic       ur_report_en;
    logic       fatal_report_en;
    logic       nonfatal_report_en;
    logic       corr_report_en;
  } pcie_dev_ctl_t;

  typedef struct packed {
    logic [9:0] rsvd0;
    logic       trans_pending;
    logic       aux_power;
    logic       ur_detected;
    logic       fatal_detected;
    logic       nonfatal_detected;
    logic       corr_detected;
  } pcie_dev_sta_t;

  typedef struct packed {
    pcie_dev_sta_t status;
    pcie_dev_ctl_t control;
  } cfg_dev_dw_t;

  typedef struct packed {
    logic [7:0] port_number;
    logic [1:0] rsvd0;
    logic       bw_notify_cap;
    logic       dll_active_report_cap;
    logic       surprise_down_cap;
    logic       clock_pm;
    logic [2:0] l1_exit_lat;
    logic [2:0] l0s_exit_lat;
    logic [1:0] aspm_support;
    logic [5:0] max_width;
    logic [3:0] max_speed;
  } pcie_lnk_cap_t;

  typedef struct packed {
    logic [6:0] rsvd0;
    logic       clock_pm_en;
    logic       ext_synch;
    logic       common_clock;
    logic       retrain;
    logic       link_disable;
    logic       rcb;
    logic       rsvd1;
    logic [1:0] aspm_ctl;
  } pcie_lnk_ctl_t;

  typedef struct packed {
    logic [1:0] rsvd0;
    logic       dll_active;
    logic       slot_clock;
    logic       training;
    logic       rsvd1;
    logic [5:0] width;
    logic [3:0] speed;
  } pcie_lnk_sta_t;

  typedef struct packed {
    pcie_lnk_sta_t status;
    pcie_lnk_ctl_t control;
  } cfg_lnk_dw_t;

  typedef struct packed {
    logic [2:0] rsvd0;
    logic       compliance_deemph;
    logic       compliance_sos;
    logic       enter_mod_compliance;
    logic [2:0] tx_margin;
    logic       sel_deemph;
    logic       hw_auto_speed_dis;
    logic       enter_compliance;
    logic [3:0] target_speed;
  } pcie_lnk_ctl2_t;

  function automatic logic [31:0] cfg_write_merge(input logic [31:0] old, input logic [31:0] wdata,
                                                  input logic [3:0] be, input logic [31:0] wmask);
    logic [3:0][7:0] be_mask;
    for (int i = 0; i < 4; i++) begin
      be_mask[i] = {8{be[i]}};
    end
    return (old & ~(wmask & be_mask)) | (wdata & wmask & be_mask);
  endfunction

  function automatic logic [31:0] cfg_w1c(input logic [31:0] wdata, input logic [3:0] be,
                                          input logic [31:0] w1c_mask);
    logic [3:0][7:0] be_mask;
    for (int i = 0; i < 4; i++) begin
      be_mask[i] = {8{be[i]}};
    end
    return wdata & w1c_mask & be_mask;
  endfunction

endpackage
