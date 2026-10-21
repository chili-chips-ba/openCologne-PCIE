module tlp_tx_arbiter
  import pcie_pkg::*;
  import tl_pkg::*;
(
    input  logic           clk,
    input  logic           rst_n,
    input  tl_src_t        int_src,
    output logic           int_ready,
    input  tl_beat_t       app_tx,
    output logic           app_tx_ready,
    input  logic           bus_master_enable,
    input  fc_tx_t   [2:0] tx_fc,
    output fc_rel_t        consume,
    output tl_beat_t       tx,
    output logic           tx_half,
    input  logic           tx_ready
);

  typedef enum logic [1:0] {
    IDLE     = 2'b00,
    SEND     = 2'b01,
    WAIT_LOW = 2'b10
  } state_e;

  typedef enum logic {
    SRC_INT = 1'b0,
    SRC_APP = 1'b1
  } src_e;

  function automatic logic credit_ok(input fc_tx_t fc, input logic [11:0] need_data);
    logic [ 7:0] hdr_left;
    logic [11:0] data_left;
    hdr_left  = fc.limit.hdr - (fc.consumed.hdr + 8'd1);
    data_left = fc.limit.data - (fc.consumed.data + need_data);
    return fc.init && (fc.inf_hdr || hdr_left <= 8'd128) &&
        (need_data == 12'd0 || fc.inf_data || data_left <= 12'd2048);
  endfunction

  pcie_trn_desc_t        app_hdr_dw01;
  tlp_kind_e             app_kind;
  fc_class_e             app_class;
  logic           [11:0] app_credits;

  logic                  app_is_req;
  logic                  app_allowed;
  logic                  app_head;
  logic                  app_ok;
  logic                  int_head;
  logic                  int_blocked;
  logic                  int_ok;

  state_e                state;
  src_e                  sel;
  src_e                  last_sel;
  logic                  app_half_r;

  logic                  can_start;
  logic                  pick_app;
  logic                  pick_int;
  logic                  src_valid;
  logic                  src_last;
  logic                  src_take;

  assign app_hdr_dw01 = app_tx.data;
  assign app_kind = tlp_kind(app_hdr_dw01.dw0);
  assign app_class = tlp_class(app_kind);
  assign app_credits = tlp_data_credits(app_hdr_dw01.dw0);

  assign app_is_req = (app_kind == K_MRD) || (app_kind == K_MRDLK) || (app_kind == K_MWR) ||
      (app_kind == K_IORD) || (app_kind == K_IOWR) || (app_kind == K_ATOMIC);
  assign app_allowed = !app_is_req || bus_master_enable;
  assign app_head = app_tx.valid && app_tx.first && app_allowed;
  assign app_ok = app_head && credit_ok(tx_fc[app_class], app_credits);
  assign int_head = int_src.valid && int_src.first;
  assign int_blocked = (int_src.fc_class == FC_CPL) && app_head && (app_class == FC_P) && !app_ok;
  assign int_ok = int_head && credit_ok(
      tx_fc[int_src.fc_class], int_src.data_credits
  ) && !int_blocked;

  assign can_start = (state == IDLE) && tx_ready;
  assign pick_app = app_ok && (!int_ok || last_sel == SRC_INT);
  assign pick_int = int_ok && !pick_app;

  assign src_valid = (sel == SRC_APP) ? app_tx.valid : int_src.valid;
  assign src_last = (sel == SRC_APP) ? app_tx.last : int_src.last;
  assign src_take = (state == SEND) && src_valid;

  assign int_ready = src_take && (sel == SRC_INT);
  assign app_tx_ready = src_take && (sel == SRC_APP);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= IDLE;
      sel              <= SRC_INT;
      last_sel         <= SRC_APP;
      app_half_r       <= 1'b0;
      consume.valid    <= 1'b0;
      consume.fc_class <= FC_P;
      consume.data     <= 12'd0;
    end
    else begin
      consume.valid <= 1'b0;
      unique case (state)
        IDLE: begin
          if (can_start && (pick_app || pick_int)) begin
            sel              <= pick_app ? SRC_APP : SRC_INT;
            last_sel         <= pick_app ? SRC_APP : SRC_INT;
            app_half_r       <= tlp_last_half(app_hdr_dw01.dw0);
            consume.valid    <= 1'b1;
            consume.fc_class <= pick_app ? app_class : int_src.fc_class;
            consume.data     <= pick_app ? app_credits : int_src.data_credits;
            state            <= SEND;
          end
        end
        SEND: begin
          if (src_take && src_last) begin
            state <= WAIT_LOW;
          end
        end
        WAIT_LOW: begin
          if (!tx_ready) begin
            state <= IDLE;
          end
        end
      endcase
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx      <= '0;
      tx_half <= 1'b0;
    end
    else if (src_take) begin
      tx.valid <= 1'b1;
      tx.first <= (sel == SRC_APP) ? app_tx.first : int_src.first;
      tx.last  <= src_last;
      tx.data  <= (sel == SRC_APP) ? app_tx.data : int_src.data;
      tx_half  <= src_last && ((sel == SRC_APP) ? app_half_r : int_src.half);
    end
    else begin
      tx      <= '0;
      tx_half <= 1'b0;
    end
  end

endmodule
