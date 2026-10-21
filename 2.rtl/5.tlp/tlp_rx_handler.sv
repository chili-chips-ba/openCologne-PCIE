module tlp_rx_handler
  import pcie_pkg::*;
  import tl_pkg::*;
(
    input  logic           clk,
    input  logic           rst_n,
    input  tl_beat_t       rx,
    input  logic     [2:0] max_payload_size,
    input  fc_cred_t       p_alloc,
    input  fc_cred_t       np_alloc,
    output tl_qwr_t        p_wr,
    input  logic           p_full,
    output tl_qwr_t        np_wr,
    input  logic           np_full,
    output fc_rel_t        rel,
    output logic           err_malformed,
    output logic           err_overflow
);

  typedef enum logic {
    IDLE,
    RECEIVE
  } state_e;

  pcie_trn_desc_t        rx_hdr_dw01;
  pcie_req_dw1_t         rx_req_dw1;
  pcie_msg_dw1_t         rx_msg_dw1;

  tlp_kind_e             d_kind;
  fc_class_e             d_class;
  logic           [10:0] d_length_dw;
  logic           [11:0] d_data_credits;
  logic           [10:0] d_words;

  logic           [10:0] mps_dw;
  logic                  d_cfg_io;
  logic                  d_bad_cfg_io;
  logic                  d_bad_mps;
  logic                  d_bad_msg;
  logic                  d_static_bad;

  state_e                state;
  logic                  known_r;
  fc_class_e             class_r;
  logic           [10:0] words_expected_r;
  logic           [10:0] words_seen_r;
  logic                  static_bad_r;
  logic           [11:0] need_data_r;
  logic                  full_r;

  fc_cred_t              p_recv;
  fc_cred_t              np_recv;

  logic                  first_word;
  logic                  in_tlp;
  logic                  cur_known;
  fc_class_e             cur_class;
  logic                  cur_np;
  logic           [10:0] cur_expect;
  logic           [10:0] cur_seen;
  logic                  cur_bad;
  logic           [11:0] cur_need;
  logic                  cur_qfull;

  logic                  write;
  logic                  last_word;
  logic                  full_now;

  fc_cred_t              alloc;
  fc_cred_t              recv;
  fc_cred_t              recv_new;
  logic                  credit_ovf;

  logic                  overflow;
  logic                  malformed;
  logic                  accept;
  logic                  counted;
  logic                  drop;

  assign rx_hdr_dw01    = rx.data;
  assign rx_req_dw1     = rx_hdr_dw01.dw1;
  assign rx_msg_dw1     = rx_hdr_dw01.dw1;

  assign d_kind         = tlp_kind(rx_hdr_dw01.dw0);
  assign d_class        = tlp_class(d_kind);
  assign d_length_dw    = tlp_length_dw(rx_hdr_dw01.dw0);
  assign d_data_credits = tlp_data_credits(rx_hdr_dw01.dw0);
  assign d_words        = tlp_words(rx_hdr_dw01.dw0);

  always_comb begin
    mps_dw = 11'd1024;
    unique0 case (max_payload_size)
      3'd0: mps_dw = 11'd32;
      3'd1: mps_dw = 11'd64;
      3'd2: mps_dw = 11'd128;
      3'd3: mps_dw = 11'd256;
      3'd4: mps_dw = 11'd512;
    endcase
  end

  assign d_cfg_io = (d_kind == K_CFGRD0) || (d_kind == K_CFGWR0) || (d_kind == K_CFGRD1) ||
      (d_kind == K_CFGWR1) || (d_kind == K_IORD) || (d_kind == K_IOWR);

  assign d_bad_cfg_io = d_cfg_io && ((rx_hdr_dw01.dw0.tc != 3'd0) ||
      (rx_hdr_dw01.dw0.attr != 2'd0) || (rx_hdr_dw01.dw0.length != 10'd1) ||
      (rx_req_dw1.last_be != 4'd0));
  assign d_bad_mps = tlp_has_data(
      rx_hdr_dw01.dw0
  ) && (d_kind != K_ATOMIC) && (d_length_dw > mps_dw);
  assign d_bad_msg = (d_kind == K_MSGD) && (rx_msg_dw1.msg_code == MSG_SET_SLOT_POWER) &&
      (rx_hdr_dw01.dw0.tc != 3'd0);
  assign d_static_bad = d_bad_cfg_io || d_bad_mps || d_bad_msg;

  assign first_word = rx.valid && rx.first;
  assign in_tlp = first_word || (state == RECEIVE);
  assign cur_known = first_word ? (d_kind != K_UNKNOWN) : known_r;
  assign cur_class = first_word ? d_class : class_r;
  assign cur_np = (cur_class == FC_NP);
  assign cur_expect = first_word ? d_words : words_expected_r;
  assign cur_seen = first_word ? 11'd1 : words_seen_r + 11'd1;
  assign cur_bad = first_word ? d_static_bad : static_bad_r;
  assign cur_need = first_word ? d_data_credits : need_data_r;
  assign cur_qfull = cur_np ? np_full : p_full;

  assign write = rx.valid && in_tlp && cur_known;
  assign last_word = rx.valid && rx.last && in_tlp;
  assign full_now = full_r || (write && cur_qfull);

  assign alloc = cur_np ? np_alloc : p_alloc;
  assign recv = cur_np ? np_recv : p_recv;
  assign recv_new.hdr = recv.hdr + 8'd1;
  assign recv_new.data = recv.data + cur_need;
  assign credit_ovf = (cur_class != FC_CPL) &&
      ((alloc.hdr - recv_new.hdr) >= 8'd128 || (alloc.data - recv_new.data) >= 12'd2048);

  assign overflow = credit_ovf || full_now;
  assign malformed = !cur_known || (cur_seen != cur_expect) || cur_bad;
  assign accept = last_word && cur_known && !overflow && !malformed;
  assign counted = last_word && cur_known && !overflow && (cur_class != FC_CPL);
  assign drop = last_word && !accept;

  assign p_wr.en = write && !cur_np;
  assign p_wr.drop = drop && !cur_np;
  assign p_wr.word.last = rx.last;
  assign p_wr.word.data = rx.data;

  assign np_wr.en = write && cur_np;
  assign np_wr.drop = drop && cur_np;
  assign np_wr.word.last = rx.last;
  assign np_wr.word.data = rx.data;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= IDLE;
      known_r          <= 1'b0;
      class_r          <= FC_P;
      words_expected_r <= 11'd0;
      words_seen_r     <= 11'd0;
      static_bad_r     <= 1'b0;
      need_data_r      <= 12'd0;
      full_r           <= 1'b0;
    end
    else if (rx.valid && in_tlp) begin
      known_r          <= cur_known;
      class_r          <= cur_class;
      words_expected_r <= cur_expect;
      words_seen_r     <= cur_seen;
      static_bad_r     <= cur_bad;
      need_data_r      <= cur_need;
      full_r           <= full_now && !rx.last;
      state            <= rx.last ? IDLE : RECEIVE;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      p_recv  <= '0;
      np_recv <= '0;
    end
    else if (counted) begin
      if (cur_np) begin
        np_recv <= recv_new;
      end
      else begin
        p_recv <= recv_new;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rel           <= '0;
      err_malformed <= 1'b0;
      err_overflow  <= 1'b0;
    end
    else begin
      rel.valid     <= counted && malformed;
      rel.fc_class  <= cur_class;
      rel.data      <= cur_need;
      err_malformed <= last_word && malformed && !(cur_known && overflow);
      err_overflow  <= last_word && cur_known && overflow;
    end
  end

endmodule
