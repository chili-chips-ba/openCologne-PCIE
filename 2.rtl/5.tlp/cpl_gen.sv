module cpl_gen
  import pcie_pkg::*;
  import tl_pkg::*;
(
    input  logic           clk,
    input  logic           rst_n,
    input  logic    [15:0] own_id,
    input  logic           cpl_req,
    input  tl_cpl_t        cpl,
    input  logic           cpl_hold,
    output logic           cpl_ready,
    input  logic           msg_nonfatal,
    input  logic           msg_fatal,
    output tl_src_t        src,
    input  logic           src_ready
);

  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    WORD0 = 2'b01,
    WORD1 = 2'b10
  } state_e;

  state_e                 state;
  pcie_trn_desc_t         word0_hdr_dw01;
  pcie_trn_desc2_t        word1_hdr_dw23;
  logic                   half;
  fc_class_e              src_class;
  logic            [11:0] src_credits;
  logic                   pending_nonfatal;
  logic                   pending_fatal;

  logic                   pending;
  logic                   start_cpl;
  logic                   start_msg;

  pcie_tlp_dw0_t          cpl_dw0;
  pcie_cpl_dw1_t          cpl_dw1;
  pcie_cpl_dw2_t          cpl_dw2;
  pcie_tlp_dw0_t          msg_dw0;
  pcie_msg_dw1_t          msg_dw1;

  assign pending          = pending_nonfatal || pending_fatal;
  assign start_cpl        = (state == IDLE) && cpl_req;
  assign start_msg        = (state == IDLE) && !cpl_req && !cpl_hold && pending;

  assign cpl_ready        = (state == IDLE) && !cpl_req;
  assign src.valid        = (state == WORD0) || (state == WORD1);
  assign src.first        = (state == WORD0);
  assign src.last         = (state == WORD1);
  assign src.half         = half;
  assign src.fc_class     = src_class;
  assign src.data_credits = src_credits;
  assign src.data         = (state == WORD1) ? word1_hdr_dw23 : word0_hdr_dw01;

  always_comb begin
    cpl_dw0 = '0;
    cpl_dw0.fmt = cpl.with_data ? TLP_FMT_3DW_DATA : TLP_FMT_3DW;
    cpl_dw0.tlp_type = TLP_TYPE_CPL;
    cpl_dw0.tc = cpl.tc;
    cpl_dw0.attr = cpl.attr;
    cpl_dw0.length = cpl.with_data ? 10'd1 : 10'd0;

    cpl_dw1 = '0;
    cpl_dw1.completer_id = own_id;
    cpl_dw1.cpl_status = cpl.status;
    cpl_dw1.byte_count = cpl.byte_count;

    cpl_dw2 = '0;
    cpl_dw2.requester_id = cpl.requester_id;
    cpl_dw2.tag = cpl.tag;
    cpl_dw2.lower_addr = cpl.lower_addr;

    msg_dw0 = '0;
    msg_dw0.fmt = TLP_FMT_4DW;
    msg_dw0.tlp_type = {TLP_TYPE_MSG, cpl_req ? cpl.msg_route : MSG_ROUTE_TO_RC};

    msg_dw1 = '0;
    msg_dw1.requester_id = own_id;
    msg_dw1.msg_code = cpl_req ? cpl.msg_code : (pending_fatal ? MSG_ERR_FATAL : MSG_ERR_NONFATAL);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= IDLE;
      word0_hdr_dw01 <= '0;
      word1_hdr_dw23 <= '0;
      half           <= 1'b0;
      src_class      <= FC_CPL;
      src_credits    <= 12'd0;
    end
    else begin
      unique case (state)
        IDLE: begin
          if (start_cpl && !cpl.is_msg) begin
            word0_hdr_dw01.dw1 <= cpl_dw1;
            word0_hdr_dw01.dw0 <= cpl_dw0;
            word1_hdr_dw23.dw3 <= cpl.with_data ? dw_byte_swap(cpl.data) : 32'h0000_0000;
            word1_hdr_dw23.dw2 <= cpl_dw2;
            half               <= !cpl.with_data;
            src_class          <= FC_CPL;
            src_credits        <= cpl.with_data ? 12'd1 : 12'd0;
            state              <= WORD0;
          end
          else if (start_cpl || start_msg) begin
            word0_hdr_dw01.dw1 <= msg_dw1;
            word0_hdr_dw01.dw0 <= msg_dw0;
            word1_hdr_dw23     <= '0;
            half               <= 1'b0;
            src_class          <= FC_P;
            src_credits        <= 12'd0;
            state              <= WORD0;
          end
        end
        WORD0: begin
          if (src_ready) begin
            state <= WORD1;
          end
        end
        WORD1: begin
          if (src_ready) begin
            state <= IDLE;
          end
        end
      endcase
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pending_nonfatal <= 1'b0;
      pending_fatal    <= 1'b0;
    end
    else begin
      if (msg_nonfatal) begin
        pending_nonfatal <= 1'b1;
      end
      else if (start_msg && !pending_fatal) begin
        pending_nonfatal <= 1'b0;
      end
      if (msg_fatal) begin
        pending_fatal <= 1'b1;
      end
      else if (start_msg) begin
        pending_fatal <= 1'b0;
      end
    end
  end

endmodule
