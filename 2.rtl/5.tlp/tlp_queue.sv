module tlp_queue
  import tl_pkg::*;
#(
    parameter int ADDR_W = 7
) (
    input  logic    clk,
    input  logic    rst_n,
    input  tl_qwr_t wr,
    output logic    wr_full,
    output logic    commit,
    input  logic    pop,
    output tl_qrd_t rd,
    output logic    done
);

  localparam int DEPTH = 1 << ADDR_W;

  tl_qword_t              mem         [DEPTH];

  logic      [ADDR_W-1:0] wr_ptr;
  logic      [ADDR_W-1:0] commit_ptr;
  logic      [ADDR_W-1:0] fetch_ptr;
  logic      [ADDR_W-1:0] tlp_cnt;

  tl_qword_t              ram_q;
  logic                   ram_q_valid;
  tl_qword_t              out0;
  tl_qword_t              out1;
  logic                   out0_valid;
  logic                   out1_valid;

  logic      [ADDR_W-1:0] wr_ptr_next;
  logic                   write;
  logic                   take;
  logic      [       1:0] held;
  logic                   fetch;

  assign wr_ptr_next = wr_ptr + 1'b1;
  assign write       = wr.en && !wr.drop && !wr_full;
  assign commit      = write && wr.word.last;
  assign take        = pop && out0_valid;
  assign done        = take && out0.last;

  assign held        = {1'b0, out0_valid} + {1'b0, out1_valid} + {1'b0, ram_q_valid} - {1'b0, take};
  assign fetch       = (fetch_ptr != commit_ptr) && (held < 2'd2);

  assign wr_full     = (wr_ptr_next == fetch_ptr);
  assign rd.valid    = out0_valid;
  assign rd.avail    = (tlp_cnt != '0) && out0_valid && (out1_valid || out0.last);
  assign rd.head     = out0;
  assign rd.next     = out1.data;

  always_ff @(posedge clk) begin
    if (write) begin
      mem[wr_ptr] <= wr.word;
    end
  end

  always_ff @(posedge clk) begin
    if (fetch) begin
      ram_q <= mem[fetch_ptr];
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr     <= '0;
      commit_ptr <= '0;
    end
    else if (wr.drop) begin
      wr_ptr <= commit_ptr;
    end
    else if (write) begin
      wr_ptr <= wr_ptr_next;
      if (wr.word.last) begin
        commit_ptr <= wr_ptr_next;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fetch_ptr   <= '0;
      ram_q_valid <= 1'b0;
    end
    else begin
      ram_q_valid <= fetch;
      if (fetch) begin
        fetch_ptr <= fetch_ptr + 1'b1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out0       <= '0;
      out1       <= '0;
      out0_valid <= 1'b0;
      out1_valid <= 1'b0;
    end
    else begin
      unique0 case ({
        take, ram_q_valid
      })
        2'b01: begin
          if (!out0_valid) begin
            out0       <= ram_q;
            out0_valid <= 1'b1;
          end
          else begin
            out1       <= ram_q;
            out1_valid <= 1'b1;
          end
        end
        2'b10: begin
          out0       <= out1;
          out0_valid <= out1_valid;
          out1_valid <= 1'b0;
        end
        2'b11: begin
          out0       <= ram_q;
          out0_valid <= 1'b1;
          out1_valid <= 1'b0;
        end
      endcase
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tlp_cnt <= '0;
    end
    else if (commit && !done) begin
      tlp_cnt <= tlp_cnt + 1'b1;
    end
    else if (done && !commit) begin
      tlp_cnt <= tlp_cnt - 1'b1;
    end
  end

endmodule
