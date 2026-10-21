module tlp_order #(
    parameter int TLP_ADDR_W = 4
) (
    input  logic clk,
    input  logic rst_n,
    input  logic p_commit,
    input  logic p_done,
    input  logic np_commit,
    input  logic np_done,
    output logic np_ready
);

  localparam int TLP_DEPTH = 1 << TLP_ADDR_W;

  logic [           7:0] p_seen       [TLP_DEPTH];
  logic [TLP_ADDR_W-1:0] wr_ptr;
  logic [TLP_ADDR_W-1:0] rd_ptr;
  logic [           7:0] p_commit_cnt;
  logic [           7:0] p_done_cnt;
  logic [           7:0] np_wait;

  assign np_wait  = p_seen[rd_ptr] - p_done_cnt;
  assign np_ready = (np_wait == 8'd0) || np_wait[7];

  always_ff @(posedge clk) begin
    if (np_commit) begin
      p_seen[wr_ptr] <= p_commit_cnt;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr       <= '0;
      rd_ptr       <= '0;
      p_commit_cnt <= '0;
      p_done_cnt   <= '0;
    end
    else begin
      if (np_commit) begin
        wr_ptr <= wr_ptr + 1'b1;
      end
      if (np_done) begin
        rd_ptr <= rd_ptr + 1'b1;
      end
      if (p_commit) begin
        p_commit_cnt <= p_commit_cnt + 8'd1;
      end
      if (p_done) begin
        p_done_cnt <= p_done_cnt + 8'd1;
      end
    end
  end

endmodule
