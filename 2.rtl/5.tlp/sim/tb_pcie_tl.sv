`timescale 1ns/100fs

module tb_pcie_tl;

    import pcie_pkg::*;

    localparam DATA_BYTES     = 8;
    localparam DATA_WIDTH     = DATA_BYTES * 8;
    localparam CLK_PERIOD     = 10;
    localparam BAR0_SIZE_BITS = 12;
    localparam INIT_PH        = 8;
    localparam INIT_PD        = 32;
    localparam INIT_NPH       = 8;
    localparam INIT_NPD       = 8;
    localparam VENDOR_ID      = 16'h1234;
    localparam DEVICE_ID      = 16'h0001;
    localparam RC_ID          = 16'h0010;
    localparam BAR0           = 32'hF000_0000;

    localparam [1:0] FC_P   = 2'b00,
                     FC_NP  = 2'b01,
                     FC_CPL = 2'b10;

    localparam [1:0] DLLP_INITFC1  = 2'b01,
                     DLLP_UPDATEFC = 2'b10,
                     DLLP_INITFC2  = 2'b11;

    localparam [2:0] DL_INACTIVE = 3'b000,
                     DL_INITFC1  = 3'b001,
                     DL_INITFC2  = 3'b010,
                     DL_ACTIVE   = 3'b011;

    reg                   clk;
    reg                   reset;
    reg                   dl_up;
    reg             [2:0] dl_state;

    wire [DATA_WIDTH-1:0] tl_tx_data;
    wire                  tl_tx_tlp_valid;
    wire                  tl_tx_tlp_first;
    wire                  tl_tx_tlp_last;
    wire                  tl_tx_tlp_half;
    reg                   tl_tx_tlp_ready;

    wire            [7:0] tl_tx_hdr_credit;
    wire           [11:0] tl_tx_data_credit;
    wire            [1:0] tl_tx_update_type;
    wire            [1:0] tl_tx_packet_type;
    wire                  tl_tx_dllp_valid;

    reg  [DATA_WIDTH-1:0] tl_rx_data;
    reg                   tl_rx_tlp_valid;
    reg                   tl_rx_tlp_first;
    reg                   tl_rx_tlp_last;

    reg             [7:0] tl_rx_hdr_credit;
    reg            [11:0] tl_rx_data_credit;
    reg             [1:0] tl_rx_update_type;
    reg             [1:0] tl_rx_packet_type;
    reg                   tl_rx_dllp_valid;

    wire [DATA_WIDTH-1:0] app_rx_data;
    wire                  app_rx_valid;
    wire                  app_rx_last;
    wire            [5:0] app_rx_bar_hit;
    reg                   app_rx_ready;
    reg                   app_rx_mid;
    wire                  app_rx_first;

    reg  [DATA_WIDTH-1:0] app_tx_data;
    reg                   app_tx_valid;
    reg                   app_tx_last;
    reg             [7:0] app_tx_keep;
    wire                  app_tx_ready;

    wire            [7:0] cfg_bus_number;
    wire            [4:0] cfg_device_number;
    wire                  cfg_memory_enable;
    wire                  cfg_bus_master_enable;
    wire            [1:0] cfg_power_state;

    dll_if #(.DATA_BYTES(DATA_BYTES)) dll ();
    axis_if #(.DATA_W(TRN_DATA_W), .USER_W($bits(pcie_tx_tuser_t))) s_axis_tx ();
    axis_if #(.DATA_W(TRN_DATA_W), .USER_W($bits(pcie_rx_tuser_t))) m_axis_rx ();
    trn_if #(.DATA_W(TRN_DATA_W), .REM_W(TRN_REM_W)) trn ();
    cfg_if cfg ();

    pcie_tl #(
        .VENDOR_ID(VENDOR_ID),
        .DEVICE_ID(DEVICE_ID),
        .BAR0_SIZE_BITS(BAR0_SIZE_BITS),
        .INIT_PH(INIT_PH),
        .INIT_PD(INIT_PD),
        .INIT_NPH(INIT_NPH),
        .INIT_NPD(INIT_NPD)
    ) dut (
        .clk(clk),
        .rst_n(!reset),
        .dll(dll),
        .trn(trn),
        .cfg(cfg)
    );

    trn_bridge u_trn_bridge (
        .s_axis_tx(s_axis_tx),
        .m_axis_rx(m_axis_rx),
        .trn(trn),
        .cfg_pcie_link_state(3'b000),
        .clk62m5(clk),
        .core_rst_n(!reset)
    );

    assign tl_tx_data           = dll.tx_data;
    assign tl_tx_tlp_valid      = dll.tx_tlp_valid;
    assign tl_tx_tlp_first      = dll.tx_tlp_first;
    assign tl_tx_tlp_last       = dll.tx_tlp_last;
    assign tl_tx_tlp_half       = dll.tx_tlp_last_half;
    assign dll.tx_tlp_ready     = tl_tx_tlp_ready;

    assign tl_tx_hdr_credit     = dll.tx_hdr_credit;
    assign tl_tx_data_credit    = dll.tx_data_credit;
    assign tl_tx_update_type    = dll.tx_update_type;
    assign tl_tx_packet_type    = dll.tx_packet_type;
    assign tl_tx_dllp_valid     = dll.tx_dllp_valid;

    assign dll.rx_data          = tl_rx_data;
    assign dll.rx_tlp_valid     = tl_rx_tlp_valid;
    assign dll.rx_tlp_first     = tl_rx_tlp_first;
    assign dll.rx_tlp_last      = tl_rx_tlp_last;
    assign dll.rx_hdr_credit    = tl_rx_hdr_credit;
    assign dll.rx_data_credit   = tl_rx_data_credit;
    assign dll.rx_update_type   = tl_rx_update_type;
    assign dll.rx_packet_type   = tl_rx_packet_type;
    assign dll.rx_dllp_valid    = tl_rx_dllp_valid;
    assign dll.dl_state         = dl_state;

    assign app_rx_data          = trn_byte_swap(m_axis_rx.tdata);
    assign app_rx_valid         = m_axis_rx.tvalid;
    assign app_rx_last          = m_axis_rx.tlast;
    assign app_rx_bar_hit       = m_axis_rx.tuser[7:2];
    assign app_rx_first         = !app_rx_mid;
    assign m_axis_rx.tready     = app_rx_ready;

    assign s_axis_tx.tdata      = trn_byte_swap(app_tx_data);
    assign s_axis_tx.tvalid     = app_tx_valid;
    assign s_axis_tx.tlast      = app_tx_last;
    assign s_axis_tx.tkeep      = app_tx_keep;
    assign s_axis_tx.tuser      = '0;
    assign app_tx_ready         = s_axis_tx.tready;

    assign cfg_bus_number        = cfg.bus_number;
    assign cfg_device_number     = cfg.device_number;
    assign cfg_memory_enable     = dut.tl_cfg.memory_enable;
    assign cfg_bus_master_enable = dut.tl_cfg.bus_master_enable;
    assign cfg_power_state       = dut.u_cfg_space.pm.csr.power_state;

    always @(posedge clk) begin
        if (reset) begin
            app_rx_mid <= 1'b0;
        end else if (app_rx_valid && app_rx_ready) begin
            app_rx_mid <= !app_rx_last;
        end
    end

    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    integer errors;

    function [31:0] dw0;
        input [2:0] fmt;
        input [4:0] tlp_type;
        input [2:0] tc;
        input       td;
        input       ep;
        input [1:0] attr;
        input [9:0] len;
        begin
            dw0 = {len[7:0], td, ep, attr, 2'b00, len[9:8], 1'b0, tc, 4'b0000, fmt, tlp_type};
        end
    endfunction

    function [31:0] dw_req;
        input [15:0] rid;
        input  [7:0] tag;
        input  [3:0] lbe;
        input  [3:0] fbe;
        begin
            dw_req = {lbe, fbe, tag, rid[7:0], rid[15:8]};
        end
    endfunction

    function [31:0] dw_addr;
        input [31:0] addr;
        begin
            dw_addr = {addr[7:2], 2'b00, addr[15:8], addr[23:16], addr[31:24]};
        end
    endfunction

    function [31:0] dw_cfg;
        input [7:0] bus;
        input [4:0] dev;
        input [2:0] func;
        input [9:0] regnum;
        begin
            dw_cfg = {regnum[5:0], 2'b00, 4'b0000, regnum[9:6], dev, func, bus};
        end
    endfunction

    reg [DATA_WIDTH-1:0] rx_words [0:63];
    integer              rx_len;

    reg           [31:0] tlp_dw [0:127];
    integer              tlp_ndw;

    task pack_tlp;
        integer i;
        begin
            rx_len = (tlp_ndw + 1) / 2;
            for (i = 0; i < rx_len; i = i + 1) begin
                rx_words[i][31:0]  = tlp_dw[2*i];
                rx_words[i][63:32] = (2*i+1 < tlp_ndw) ? tlp_dw[2*i+1] : 32'h0000_0000;
            end
        end
    endtask

    integer exp_p_hdr;
    integer exp_p_data;
    integer exp_np_hdr;
    integer exp_np_data;
    reg     rx_no_count;

    task count_credits;
        reg  [2:0] f;
        reg  [4:0] t;
        reg [10:0] l;
        integer    c;
        begin
            f = tlp_dw[0][7:5];
            t = tlp_dw[0][4:0];
            l = ({tlp_dw[0][17:16], tlp_dw[0][31:24]} == 10'd0) ? 11'd1024 : {tlp_dw[0][17:16], tlp_dw[0][31:24]};
            c = f[1] ? (l + 3) / 4 : 0;
            if (!rx_no_count) begin
                if ((t == 5'b00000 && f[2:1] == 2'b01) || (t[4:3] == 2'b10 && f[0] && t[2:0] <= 3'd5)) begin
                    exp_p_hdr  = exp_p_hdr + 1;
                    exp_p_data = exp_p_data + c;
                end else if ((t == 5'b00000 || t == 5'b00001) && f[2:1] == 2'b00 ||
                             t == 5'b00010 || t == 5'b00100 || t == 5'b00101 ||
                             t == 5'b01100 || t == 5'b01101 || t == 5'b01110) begin
                    exp_np_hdr  = exp_np_hdr + 1;
                    exp_np_data = exp_np_data + c;
                end
            end
        end
    endtask

    task check_updatefc;
        begin
            check("UpdateFC PH",  upd_hdr[FC_P],   exp_p_hdr % 256);
            check("UpdateFC PD",  upd_data[FC_P],  exp_p_data % 4096);
            check("UpdateFC NPH", upd_hdr[FC_NP],  exp_np_hdr % 256);
            check("UpdateFC NPD", upd_data[FC_NP], exp_np_data % 4096);
            check("UpdateFC Cpl never sent", upd_cnt[FC_CPL], 0);
        end
    endtask

    task rx_send;
        integer i;
        begin
            count_credits;
            pack_tlp;
            @(posedge clk); #1;
            for (i = 0; i < rx_len; i = i + 1) begin
                tl_rx_data      = rx_words[i];
                tl_rx_tlp_valid = 1'b1;
                tl_rx_tlp_first = (i == 0);
                tl_rx_tlp_last  = (i == rx_len - 1);
                @(posedge clk); #1;
            end
            tl_rx_data      = {DATA_WIDTH{1'b0}};
            tl_rx_tlp_valid = 1'b0;
            tl_rx_tlp_first = 1'b0;
            tl_rx_tlp_last  = 1'b0;
        end
    endtask

    task rx_dllp(input [1:0] ptype, input [1:0] utype, input [7:0] hdr, input [11:0] data);
        begin
            @(posedge clk); #1;
            tl_rx_packet_type = ptype;
            tl_rx_update_type = utype;
            tl_rx_hdr_credit  = hdr;
            tl_rx_data_credit = data;
            tl_rx_dllp_valid  = 1'b1;
            @(posedge clk); #1;
            tl_rx_dllp_valid  = 1'b0;
        end
    endtask

    task cfg_rd(input [7:0] bus, input [2:0] func, input [9:0] regnum, input [7:0] tag);
        begin
            tlp_dw[0] = dw0(3'b000, 5'b00100, 3'd0, 1'b0, 1'b0, 2'b00, 10'd1);
            tlp_dw[1] = dw_req(RC_ID, tag, 4'b0000, 4'b1111);
            tlp_dw[2] = dw_cfg(bus, 5'd0, func, regnum);
            tlp_ndw   = 3;
            rx_send;
        end
    endtask

    task cfg_wr(input [7:0] bus, input [2:0] func, input [9:0] regnum, input [3:0] be, input [31:0] data, input [7:0] tag);
        begin
            tlp_dw[0] = dw0(3'b010, 5'b00100, 3'd0, 1'b0, 1'b0, 2'b00, 10'd1);
            tlp_dw[1] = dw_req(RC_ID, tag, 4'b0000, be);
            tlp_dw[2] = dw_cfg(bus, 5'd0, func, regnum);
            tlp_dw[3] = data;
            tlp_ndw   = 4;
            rx_send;
        end
    endtask

    task mem_wr(input [31:0] addr, input integer ndw, input [31:0] seed);
        integer i;
        begin
            tlp_dw[0] = dw0(3'b010, 5'b00000, 3'd0, 1'b0, 1'b0, 2'b00, ndw[9:0]);
            tlp_dw[1] = dw_req(RC_ID, 8'h00, (ndw == 1) ? 4'b0000 : 4'b1111, 4'b1111);
            tlp_dw[2] = dw_addr(addr);
            for (i = 0; i < ndw; i = i + 1) begin
                tlp_dw[3+i] = seed + i * 32'h0101_0101;
            end
            tlp_ndw = 3 + ndw;
            rx_send;
        end
    endtask

    task mem_rd(input [31:0] addr, input integer ndw, input [7:0] tag, input [3:0] fbe, input [3:0] lbe);
        begin
            tlp_dw[0] = dw0(3'b000, 5'b00000, 3'd0, 1'b0, 1'b0, 2'b00, ndw[9:0]);
            tlp_dw[1] = dw_req(RC_ID, tag, lbe, fbe);
            tlp_dw[2] = dw_addr(addr);
            tlp_ndw   = 3;
            rx_send;
        end
    endtask

    task mem_rd64(input [31:0] addr, input integer ndw, input [7:0] tag);
        begin
            tlp_dw[0] = dw0(3'b001, 5'b00000, 3'd0, 1'b0, 1'b0, 2'b00, ndw[9:0]);
            tlp_dw[1] = dw_req(RC_ID, tag, (ndw == 1) ? 4'b0000 : 4'b1111, 4'b1111);
            tlp_dw[2] = 32'h0000_0000;
            tlp_dw[3] = dw_addr(addr);
            tlp_ndw   = 4;
            rx_send;
        end
    endtask

    task msg(input [7:0] code, input [2:0] route, input with_data, input [31:0] data);
        begin
            tlp_dw[0] = dw0(with_data ? 3'b011 : 3'b001, {2'b10, route}, 3'd0, 1'b0, 1'b0, 2'b00, with_data ? 10'd1 : 10'd0);
            tlp_dw[1] = {code, 8'h00, RC_ID[7:0], RC_ID[15:8]};
            tlp_dw[2] = 32'h0000_0000;
            tlp_dw[3] = 32'h0000_0000;
            tlp_dw[4] = data;
            tlp_ndw   = with_data ? 5 : 4;
            rx_send;
        end
    endtask

    reg [DATA_WIDTH-1:0] tx_fifo_words [0:63][0:15];
    integer              tx_fifo_len   [0:63];
    reg                  tx_fifo_half  [0:63];
    integer              tx_wr;
    integer              tx_rd;
    integer              tx_cur;
    reg                  tx_in_tlp;

    always @(posedge clk) begin
        if (reset) begin
            tx_wr     <= 0;
            tx_cur    <= 0;
            tx_in_tlp <= 1'b0;
        end else if (tl_tx_tlp_valid) begin
            if (tl_tx_tlp_first) begin
                tx_fifo_words[tx_wr % 64][0] <= tl_tx_data;
                tx_cur <= 1;
            end else begin
                tx_fifo_words[tx_wr % 64][tx_cur] <= tl_tx_data;
                tx_cur <= tx_cur + 1;
            end
            if (tl_tx_tlp_last) begin
                tx_fifo_len[tx_wr % 64]  <= tl_tx_tlp_first ? 1 : tx_cur + 1;
                tx_fifo_half[tx_wr % 64] <= tl_tx_tlp_half;
                tx_wr <= tx_wr + 1;
            end
        end
    end

    integer ready_cnt;
    integer ack_delay;
    reg     ack_hold;
    reg     tx_busy;

    always @(posedge clk) begin
        if (reset) begin
            tl_tx_tlp_ready <= 1'b0;
            tx_busy         <= 1'b0;
            ready_cnt       <= 0;
        end else begin
            if (tl_tx_tlp_valid && tl_tx_tlp_first) begin
                tx_busy   <= 1'b1;
                ready_cnt <= 0;
            end else if (tx_busy) begin
                ready_cnt <= ready_cnt + 1;
                if (ready_cnt == 2) begin
                    tl_tx_tlp_ready <= 1'b0;
                end
                if (ready_cnt >= ack_delay && !ack_hold) begin
                    tx_busy         <= 1'b0;
                    tl_tx_tlp_ready <= dl_up;
                end
            end else begin
                tl_tx_tlp_ready <= dl_up;
            end
        end
    end

    reg  [7:0] upd_hdr  [0:2];
    reg [11:0] upd_data [0:2];
    integer    upd_cnt  [0:2];
    integer    k;

    always @(posedge clk) begin
        if (reset) begin
            for (k = 0; k < 3; k = k + 1) begin
                upd_hdr[k]  <= 8'd0;
                upd_data[k] <= 12'd0;
                upd_cnt[k]  <= 0;
            end
        end else if (tl_tx_dllp_valid) begin
            if (tl_tx_packet_type != DLLP_UPDATEFC) begin
                errors = errors + 1;
                $display("[%0t] ERROR: TL requested a DLLP that is not UpdateFC (type %b)", $time, tl_tx_packet_type);
            end
            upd_hdr[tl_tx_update_type]  <= tl_tx_hdr_credit;
            upd_data[tl_tx_update_type] <= tl_tx_data_credit;
            upd_cnt[tl_tx_update_type]  <= upd_cnt[tl_tx_update_type] + 1;
        end
    end

    reg [DATA_WIDTH-1:0] app_words [0:63][0:39];
    integer              app_len   [0:63];
    reg            [5:0] app_bar   [0:63];
    reg                  app_fwd   [0:63];
    reg           [31:0] app_hdr0;
    integer              app_wr;
    integer              app_cur;
    reg           [31:0] app_mem   [0:1023];
    reg                  app_auto;

    reg [DATA_WIDTH-1:0] atx_data  [0:255];
    reg                  atx_first [0:255];
    reg                  atx_last  [0:255];
    reg            [7:0] atx_keep  [0:255];
    integer              atx_wr;
    integer              atx_rd;

    always @(posedge clk) begin
        if (reset) begin
            app_wr  <= 0;
            app_cur <= 0;
        end else if (app_rx_valid && app_rx_ready) begin
            if (app_rx_first) begin
                app_words[app_wr % 64][0] <= app_rx_data;
                app_bar[app_wr % 64]      <= app_rx_bar_hit;
                app_fwd[app_wr % 64]      <= m_axis_rx.tuser[1];
                app_hdr0                  <= app_rx_data[31:0];
                app_cur <= 1;
            end else begin
                app_words[app_wr % 64][app_cur] <= app_rx_data;
                app_cur <= app_cur + 1;
            end
            if (app_rx_last) begin
                app_len[app_wr % 64] <= app_rx_first ? 1 : app_cur + 1;
                app_wr <= app_wr + 1;
            end
            if (m_axis_rx.tuser[0] !== 1'b0) begin
                errors = errors + 1;
                $display("[%0t] ERROR: m_axis_rx ecrc_err set", $time);
            end
            if (m_axis_rx.tkeep !== ((app_rx_last && rx_half(app_rx_first ? app_rx_data[31:0] : app_hdr0)) ? 8'h0F : 8'hFF)) begin
                errors = errors + 1;
                $display("[%0t] ERROR: m_axis_rx tkeep %h on a %0s beat", $time, m_axis_rx.tkeep, app_rx_last ? "last" : "middle");
            end
        end
    end

    function rx_half;
        input [31:0] h0;
        integer      n;
        begin
            n = (h0[5] ? 4 : 3) + h0[23] + (h0[6] ? (({h0[17:16], h0[31:24]} == 10'd0) ? 1024 : {h0[17:16], h0[31:24]}) : 0);
            rx_half = n[0];
        end
    endfunction

    function [31:0] word_dw;
        input integer slot;
        input integer idx;
        begin
            word_dw = idx[0] ? app_words[slot][idx/2][63:32] : app_words[slot][idx/2][31:0];
        end
    endfunction

    integer app_seen;
    integer ai;
    integer a_slot;
    reg [31:0] a_dw0;
    reg [31:0] a_dw1;
    reg [31:0] a_addr;
    integer    a_len;
    integer    a_hdr;
    reg [31:0] a_cpl [0:63];
    integer    a_cnt;
    reg [11:0] a_bc;

    always @(posedge clk) begin
        if (reset) begin
            app_seen <= 0;
        end else if (app_auto && app_seen < app_wr) begin
            a_slot = app_seen % 64;
            a_dw0  = word_dw(a_slot, 0);
            a_dw1  = word_dw(a_slot, 1);
            a_hdr  = a_dw0[5] ? 4 : 3;
            a_addr = a_dw0[5] ? word_dw(a_slot, 3) : word_dw(a_slot, 2);
            a_addr = {a_addr[7:0], a_addr[15:8], a_addr[23:16], a_addr[31:24]};
            a_len  = {a_dw0[17:16], a_dw0[31:24]};
            if (a_dw0[4:0] == 5'b00000 && a_dw0[7:6] == 2'b01) begin
                for (ai = 0; ai < a_len; ai = ai + 1) begin
                    app_mem[(a_addr[11:2] + ai) % 1024] = word_dw(a_slot, a_hdr + ai);
                end
            end else if (a_dw0[4:0] == 5'b00000 && a_dw0[7:6] == 2'b00) begin
                a_cpl[0] = dw0(3'b010, 5'b01010, a_dw0[14:12], 1'b0, 1'b0, a_dw0[21:20], a_len[9:0]);
                a_bc     = a_len * 4;
                a_cpl[1] = {a_bc[7:0], 3'b000, 1'b0, a_bc[11:8], cfg_device_number, 3'b000, cfg_bus_number};
                a_cpl[2] = {1'b0, a_addr[6:0], a_dw1[23:16], a_dw1[15:0]};
                for (ai = 0; ai < a_len; ai = ai + 1) begin
                    a_cpl[3+ai] = app_mem[(a_addr[11:2] + ai) % 1024];
                end
                a_cnt = 3 + a_len;
                for (ai = 0; ai < (a_cnt + 1) / 2; ai = ai + 1) begin
                    atx_data[(atx_wr + ai) % 256]  = {(2*ai+1 < a_cnt) ? a_cpl[2*ai+1] : 32'h0, a_cpl[2*ai]};
                    atx_first[(atx_wr + ai) % 256] = (ai == 0);
                    atx_last[(atx_wr + ai) % 256]  = (ai == (a_cnt + 1) / 2 - 1);
                    atx_keep[(atx_wr + ai) % 256]  = (2*ai+1 < a_cnt) ? 8'hFF : 8'h0F;
                end
                atx_wr = atx_wr + (a_cnt + 1) / 2;
            end
            app_seen <= app_seen + 1;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            app_tx_valid <= 1'b0;
            app_tx_last  <= 1'b0;
            app_tx_keep  <= 8'h00;
            app_tx_data  <= {DATA_WIDTH{1'b0}};
            atx_rd       = 0;
        end else begin
            if (app_tx_valid && app_tx_ready) begin
                atx_rd = atx_rd + 1;
            end
            if (atx_rd < atx_wr) begin
                app_tx_valid <= 1'b1;
                app_tx_data  <= atx_data[atx_rd % 256];
                app_tx_last  <= atx_last[atx_rd % 256];
                app_tx_keep  <= atx_keep[atx_rd % 256];
            end else begin
                app_tx_valid <= 1'b0;
                app_tx_last  <= 1'b0;
                app_tx_keep  <= 8'h00;
            end
        end
    end

    always @(posedge clk) begin
        if (!reset && trn.tsrc_rdy && trn.tdst_rdy && dut.u_app_queue.wr_full) begin
            errors = errors + 1;
            $display("[%0t] ERROR: TRN TX word from trn_bridge lost, the TX buffer is full", $time);
        end
        if (!reset && cfg.tx_buf_avail > dut.TX_SLOTS) begin
            errors = errors + 1;
            $display("[%0t] ERROR: tbuf_av %0d above the %0d TX slots", $time, cfg.tx_buf_avail, dut.TX_SLOTS);
        end
        if (!reset && dl_state == DL_ACTIVE && dut.app_q_mid && !trn.tdst_rdy) begin
            errors = errors + 1;
            $display("[%0t] ERROR: TRN TX tdst_rdy low inside a TLP", $time);
        end
    end

    reg [DATA_WIDTH-1:0] t0;
    reg [DATA_WIDTH-1:0] t1;
    reg [DATA_WIDTH-1:0] t2;
    integer              t_len;
    reg                  t_half;

    task tx_wait(input integer limit, output reg got);
        integer t;
        begin
            t = 0;
            while (tx_rd >= tx_wr && t < limit) begin
                @(posedge clk);
                t = t + 1;
            end
            got = (tx_rd < tx_wr);
            if (got) begin
                t0     = tx_fifo_words[tx_rd % 64][0];
                t1     = tx_fifo_words[tx_rd % 64][1];
                t2     = tx_fifo_words[tx_rd % 64][2];
                t_len  = tx_fifo_len[tx_rd % 64];
                t_half = tx_fifo_half[tx_rd % 64];
                tx_rd  = tx_rd + 1;
            end
        end
    endtask

    task expect_cpl(input [7:0] tag, input [2:0] status, input with_data, input [31:0] data,
                    input [11:0] byte_count, input [6:0] lower_addr, input [15:0] completer);
        reg got;
        begin
            tx_wait(2000, got);
            if (!got) begin
                errors = errors + 1;
                $display("[%0t] ERROR: no completion for tag %h", $time, tag);
            end else begin
                if (t0[7:0] != (with_data ? 8'h4A : 8'h0A)) begin
                    errors = errors + 1;
                    $display("[%0t] ERROR: tag %h fmt/type %h", $time, tag, t0[7:0]);
                end
                if (t1[23:16] != tag) begin
                    errors = errors + 1;
                    $display("[%0t] ERROR: tag %h got %h", $time, tag, t1[23:16]);
                end
                if ({t1[7:0], t1[15:8]} != RC_ID) begin
                    errors = errors + 1;
                    $display("[%0t] ERROR: tag %h requester id %h", $time, tag, {t1[7:0], t1[15:8]});
                end
                if (t0[55:53] != status) begin
                    errors = errors + 1;
                    $display("[%0t] ERROR: tag %h status %b expected %b", $time, tag, t0[55:53], status);
                end
                if ({t0[51:48], t0[63:56]} != byte_count) begin
                    errors = errors + 1;
                    $display("[%0t] ERROR: tag %h byte count %0d expected %0d", $time, tag, {t0[51:48], t0[63:56]}, byte_count);
                end
                if (t1[30:24] != lower_addr) begin
                    errors = errors + 1;
                    $display("[%0t] ERROR: tag %h lower address %h expected %h", $time, tag, t1[30:24], lower_addr);
                end
                if ({t0[39:32], t0[47:40]} != completer) begin
                    errors = errors + 1;
                    $display("[%0t] ERROR: tag %h completer id %h expected %h", $time, tag, {t0[39:32], t0[47:40]}, completer);
                end
                if (with_data && t1[63:32] != data) begin
                    errors = errors + 1;
                    $display("[%0t] ERROR: tag %h data %h expected %h", $time, tag, t1[63:32], data);
                end
                if (t_len != 2 || t_half != !with_data) begin
                    errors = errors + 1;
                    $display("[%0t] ERROR: tag %h completion length %0d half %b", $time, tag, t_len, t_half);
                end
            end
        end
    endtask

    task expect_msg(input [7:0] code, input [2:0] route, input [15:0] requester);
        reg got;
        begin
            tx_wait(2000, got);
            if (!got) begin
                errors = errors + 1;
                $display("[%0t] ERROR: no message %h", $time, code);
            end else begin
                if (t0[7:0] != {3'b001, 2'b10, route} || t0[63:56] != code ||
                    {t0[39:32], t0[47:40]} != requester || t_len != 2 || t_half) begin
                    errors = errors + 1;
                    $display("[%0t] ERROR: message %h got %h", $time, code, t0);
                end else begin
                    $display("[%0t]   message %h sent, requester %h", $time, code, requester);
                end
            end
        end
    endtask

    task expect_no_tx(input integer cycles);
        reg got;
        begin
            tx_wait(cycles, got);
            if (got) begin
                errors = errors + 1;
                $display("[%0t] ERROR: unexpected TLP %h", $time, t0);
            end
        end
    endtask

    reg [31:0] rd_val;

    task cfg_read(input [9:0] regnum, output [31:0] value);
        reg got;
        begin
            cfg_rd(8'd3, 3'd0, regnum, 8'h55);
            tx_wait(2000, got);
            if (!got || t0[7:0] != 8'h4A) begin
                errors = errors + 1;
                $display("[%0t] ERROR: config read %h failed", $time, regnum);
                value = 32'hxxxx_xxxx;
            end else begin
                value = t1[63:32];
            end
        end
    endtask

    task cfg_write(input [9:0] regnum, input [3:0] be, input [31:0] data);
        reg got;
        begin
            cfg_wr(8'd3, 3'd0, regnum, be, data, 8'h66);
            tx_wait(2000, got);
            if (!got || t0[7:0] != 8'h0A || t0[55:53] != 3'b000) begin
                errors = errors + 1;
                $display("[%0t] ERROR: config write %h failed", $time, regnum);
            end
        end
    endtask

    task check(input [255:0] what, input [31:0] got, input [31:0] expected);
        begin
            if (got !== expected) begin
                errors = errors + 1;
                $display("[%0t] ERROR: %0s = %h, expected %h", $time, what, got, expected);
            end
        end
    endtask

    task wait_cycles(input integer n);
        begin
            repeat (n) @(posedge clk);
        end
    endtask

    task wait_app(input integer count, input integer limit);
        integer t;
        begin
            t = 0;
            while ((app_wr < count || app_seen < app_wr) && t < limit) begin
                @(posedge clk);
                t = t + 1;
            end
        end
    endtask

    task wait_credit(input is_np, input integer need_data);
        integer lim_h;
        integer lim_d;
        integer con_h;
        integer con_d;
        integer t;
        reg     ok;
        begin
            t  = 0;
            ok = 1'b0;
            while (!ok && t < 20000) begin
                if (is_np) begin
                    lim_h = (upd_cnt[FC_NP] > 0) ? upd_hdr[FC_NP]  : INIT_NPH;
                    lim_d = (upd_cnt[FC_NP] > 0) ? upd_data[FC_NP] : INIT_NPD;
                    con_h = exp_np_hdr  - INIT_NPH;
                    con_d = exp_np_data - INIT_NPD;
                end else begin
                    lim_h = (upd_cnt[FC_P] > 0) ? upd_hdr[FC_P]  : INIT_PH;
                    lim_d = (upd_cnt[FC_P] > 0) ? upd_data[FC_P] : INIT_PD;
                    con_h = exp_p_hdr  - INIT_PH;
                    con_d = exp_p_data - INIT_PD;
                end
                ok = (((lim_h - con_h) % 256 + 256) % 256 >= 1) &&
                     (((lim_d - con_d) % 4096 + 4096) % 4096 >= need_data);
                if (!ok) begin
                    @(posedge clk);
                    t = t + 1;
                end
            end
            if (!ok) begin
                errors = errors + 1;
                $display("[%0t] ERROR: no receive credits advertised by the TL", $time);
            end
        end
    endtask

    always @(posedge clk) begin
        if (stress) begin
            rnd_ready    = xorshift(rnd_ready);
            app_rx_ready <= (rnd_ready % 3) != 0;
        end
    end

    task link_up(input [7:0] cplh, input [11:0] cpld);
        begin
            #1 dl_state = DL_INITFC1;
            rx_dllp(DLLP_INITFC1, FC_P,   8'd32, 12'd256);
            rx_dllp(DLLP_INITFC1, FC_NP,  8'd16, 12'd16);
            rx_dllp(DLLP_INITFC1, FC_CPL, cplh,  cpld);
            wait_cycles(4);
            #1 dl_up = 1'b1;
            dl_state = DL_INITFC2;
            rx_dllp(DLLP_INITFC2, FC_P,   8'd32, 12'd256);
            rx_dllp(DLLP_INITFC2, FC_NP,  8'd16, 12'd16);
            rx_dllp(DLLP_INITFC2, FC_CPL, cplh,  cpld);
            #1 dl_state = DL_ACTIVE;
            wait_cycles(4);
        end
    endtask

    integer n;
    integer m;
    integer seed;
    reg [31:0] rnd_main;
    reg [31:0] rnd_ready;

    function [31:0] xorshift;
        input [31:0] x;
        reg   [31:0] y;
        begin
            y = x ^ (x << 13);
            y = y ^ (y >> 17);
            xorshift = y ^ (y << 5);
        end
    endfunction
    integer op_len;
    integer op_addr;
    integer rd_cnt;
    integer cpl_ok;
    reg     stress;
    reg [31:0] shadow    [0:1023];
    reg [31:0] exp_rd    [0:127][0:7];
    integer    exp_rdlen [0:127];
    integer    exp_rdaddr [0:127];
    integer    rd_done;
    integer    overlap;
    integer    kk;
    integer    bad_dw;

    task collect_reads;
        reg rgot;
        begin
            while (rd_done < rd_cnt) begin
                tx_wait(5000, rgot);
                if (rgot && t0[7:0] == 8'h4A && t1[23:16] == 8'h80 + rd_done && t0[31:24] == exp_rdlen[rd_done]) begin
                    bad_dw = 0;
                    for (kk = 0; kk < exp_rdlen[rd_done]; kk = kk + 1) begin
                        if (((kk + 3) % 2 ? tx_fifo_words[(tx_rd - 1) % 64][(kk + 3) / 2][63:32]
                                          : tx_fifo_words[(tx_rd - 1) % 64][(kk + 3) / 2][31:0]) != exp_rd[rd_done][kk]) begin
                            bad_dw = bad_dw + 1;
                        end
                    end
                    if (bad_dw == 0) cpl_ok = cpl_ok + 1;
                    else $display("[%0t] ERROR: read %0d returned %0d wrong DWs", $time, rd_done, bad_dw);
                end else begin
                    $display("[%0t] ERROR: read %0d completion missing or wrong header %h %h", $time, rd_done, t0, t1);
                end
                rd_done = rd_done + 1;
            end
        end
    endtask
    integer seen_mwr;
    integer seen_cpl;
    integer base_app;
    integer upd_before;
    reg     got;

    initial begin
        errors            = 0;
        reset             = 1'b1;
        dl_up             = 1'b0;
        dl_state          = DL_INACTIVE;
        tl_rx_data        = {DATA_WIDTH{1'b0}};
        tl_rx_tlp_valid   = 1'b0;
        tl_rx_tlp_first   = 1'b0;
        tl_rx_tlp_last    = 1'b0;
        tl_rx_hdr_credit  = 8'd0;
        tl_rx_data_credit = 12'd0;
        tl_rx_update_type = 2'd0;
        tl_rx_packet_type = 2'd0;
        tl_rx_dllp_valid  = 1'b0;
        app_rx_ready      = 1'b1;
        app_auto          = 1'b1;
        ack_delay         = 12;
        ack_hold          = 1'b0;
        tx_rd             = 0;
        atx_wr            = 0;
        rx_no_count       = 1'b0;
        stress            = 1'b0;
        if (!$value$plusargs("seed=%d", seed)) seed = 1;
        rnd_main          = 32'h9E37_79B9 ^ seed;
        rnd_ready         = 32'h85EB_CA6B ^ seed;
        exp_p_hdr         = INIT_PH;
        exp_p_data        = INIT_PD;
        exp_np_hdr        = INIT_NPH;
        exp_np_data       = INIT_NPD;
        for (n = 0; n < 1024; n = n + 1) app_mem[n] = 32'h0;
        repeat (5) @(posedge clk);
        reset = 1'b0;
        repeat (5) @(posedge clk);

        $display("=== Step 1: flow control init and first configuration read ===");
        link_up(8'd0, 12'd0);
        cfg_rd(8'd0, 3'd0, 10'h000, 8'h01);
        expect_cpl(8'h01, 3'b000, 1'b1, {DEVICE_ID, VENDOR_ID}, 12'd4, 7'd0, 16'h0000);

        $display("=== Step 2: bus number capture, BAR0 sizing and assignment ===");
        cfg_wr(8'd3, 3'd0, 10'h004, 4'b1111, 32'hFFFF_FFFF, 8'h02);
        expect_cpl(8'h02, 3'b000, 1'b0, 32'h0, 12'd4, 7'd0, 16'h0300);
        check("cfg_bus_number", cfg_bus_number, 32'd3);
        cfg_read(10'h004, rd_val);
        check("BAR0 size mask", rd_val, 32'hFFFF_F000);
        cfg_write(10'h004, 4'b1111, BAR0);
        cfg_read(10'h004, rd_val);
        check("BAR0", rd_val, BAR0);

        $display("=== Step 3: capability list ===");
        cfg_read(10'h001, rd_val);
        check("Status.CapList", rd_val[20], 1'b1);
        cfg_read(10'h00D, rd_val);
        check("Capabilities Pointer", rd_val[7:0], 8'h40);
        cfg_read(10'h010, rd_val);
        check("PM cap id/next", rd_val[15:0], 16'h5001);
        check("PM version", rd_val[18:16], 3'b011);
        cfg_read(10'h014, rd_val);
        check("PCIe cap id/next", rd_val[15:0], 16'h0010);
        check("PCIe cap version/type", rd_val[23:16], 8'h02);
        cfg_read(10'h015, rd_val);
        check("DevCap MPS", rd_val[2:0], 3'b000);
        check("DevCap RBER", rd_val[15], 1'b1);
        cfg_read(10'h016, rd_val);
        check("DevCtl reset value", rd_val[15:0], 16'h2810);
        cfg_read(10'h017, rd_val);
        check("LinkCap speed/width", rd_val[9:0], 10'h011);
        check("LinkCap ASPM", rd_val[11:10], 2'b01);
        cfg_read(10'h018, rd_val);
        check("LinkSta speed/width", rd_val[25:16], 10'h011);
        cfg_read(10'h040, rd_val);
        check("Extended capability header", rd_val, 32'h0);

        $display("=== Step 4: memory read while Memory Space is disabled ===");
        mem_rd(BAR0 + 32'h10, 1, 8'h04, 4'b1111, 4'b0000);
        expect_cpl(8'h04, 3'b001, 1'b0, 32'h0, 12'd4, 7'h10, 16'h0300);
        cfg_read(10'h016, rd_val);
        check("DevSta after advisory UR", rd_val[19:16], 4'b0000);

        $display("=== Step 5: memory writes and reads through the application ===");
        cfg_write(10'h001, 4'b0011, 32'h0000_0006);
        check("cfg_memory_enable", cfg_memory_enable, 1'b1);
        check("cfg_bus_master_enable", cfg_bus_master_enable, 1'b1);
        base_app = app_wr;
        mem_wr(BAR0 + 32'h10, 1, 32'hDEAD_BEEF);
        wait_app(base_app + 1, 200);
        check("app MWr received", app_wr, base_app + 1);
        check("app BAR hit", app_bar[base_app % 64], 6'b000001);
        check("app MWr not poisoned", app_fwd[base_app % 64], 1'b0);
        check("app memory", app_mem[4], 32'hDEAD_BEEF);
        mem_rd(BAR0 + 32'h10, 1, 8'h05, 4'b1111, 4'b0000);
        tx_wait(2000, got);
        check("CplD from app", got, 1'b1);
        check("CplD fmt/type", t0[7:0], 8'h4A);
        check("CplD tag", t1[23:16], 8'h05);
        check("CplD data", t1[63:32], 32'hDEAD_BEEF);
        check("CplD length", t_len, 2);
        mem_wr(BAR0 + 32'h20, 4, 32'h1122_3344);
        mem_rd(BAR0 + 32'h20, 4, 8'h06, 4'b1111, 4'b1111);
        tx_wait(2000, got);
        check("CplD 4DW", got, 1'b1);
        check("CplD 4DW length field", t0[31:24], 8'd4);
        check("CplD 4DW data0", t1[63:32], 32'h1122_3344);
        check("CplD 4DW data1", t2[31:0], 32'h1223_3445);
        check("CplD 4DW data2", t2[63:32], 32'h1324_3546);
        check("CplD 4DW words/half", {t_len[3:0], t_half}, {4'd4, 1'b1});
        mem_rd64(BAR0 + 32'h10, 1, 8'h07);
        tx_wait(2000, got);
        check("CplD for 64-bit MRd", got, 1'b1);
        check("CplD for 64-bit MRd data", t1[63:32], 32'hDEAD_BEEF);

        $display("=== Step 6: unsupported requests that need a completion ===");
        mem_rd(BAR0 + 32'h1004, 2, 8'h08, 4'b1110, 4'b0011);
        expect_cpl(8'h08, 3'b001, 1'b0, 32'h0, 12'd5, 7'h05, 16'h0300);
        cfg_rd(8'd3, 3'd1, 10'h000, 8'h09);
        expect_cpl(8'h09, 3'b001, 1'b0, 32'h0, 12'd4, 7'd0, 16'h0300);
        tlp_dw[0] = dw0(3'b000, 5'b00101, 3'd0, 1'b0, 1'b0, 2'b00, 10'd1);
        tlp_dw[1] = dw_req(RC_ID, 8'h0A, 4'b0000, 4'b1111);
        tlp_dw[2] = dw_cfg(8'd4, 5'd0, 3'd0, 10'h000);
        tlp_ndw   = 3;
        rx_send;
        expect_cpl(8'h0A, 3'b001, 1'b0, 32'h0, 12'd4, 7'd0, 16'h0300);
        tlp_dw[0] = dw0(3'b000, 5'b00010, 3'd0, 1'b0, 1'b0, 2'b00, 10'd1);
        tlp_dw[1] = dw_req(RC_ID, 8'h0B, 4'b0000, 4'b1111);
        tlp_dw[2] = dw_addr(32'h0000_1000);
        tlp_ndw   = 3;
        rx_send;
        expect_cpl(8'h0B, 3'b001, 1'b0, 32'h0, 12'd4, 7'd0, 16'h0300);
        tlp_dw[0] = dw0(3'b000, 5'b00001, 3'd0, 1'b0, 1'b0, 2'b00, 10'd1);
        tlp_dw[1] = dw_req(RC_ID, 8'h0C, 4'b0000, 4'b1111);
        tlp_dw[2] = dw_addr(BAR0 + 32'h10);
        tlp_ndw   = 3;
        rx_send;
        expect_cpl(8'h0C, 3'b001, 1'b0, 32'h0, 12'd4, 7'h10, 16'h0300);
        tlp_dw[0] = dw0(3'b010, 5'b01100, 3'd0, 1'b0, 1'b0, 2'b00, 10'd1);
        tlp_dw[1] = dw_req(RC_ID, 8'h0D, 4'b0000, 4'b1111);
        tlp_dw[2] = dw_addr(BAR0 + 32'h10);
        tlp_dw[3] = 32'h0000_0001;
        tlp_ndw   = 4;
        rx_send;
        expect_cpl(8'h0D, 3'b001, 1'b0, 32'h0, 12'd4, 7'd0, 16'h0300);
        cfg_read(10'h016, rd_val);
        check("DevSta after advisory URs", rd_val[19:16], 4'b0000);

        $display("=== Step 7: posted unsupported requests and ERR_NONFATAL ===");
        base_app = app_wr;
        mem_wr(BAR0 + 32'h2000, 1, 32'h0BAD_0BAD);
        expect_no_tx(100);
        check("app untouched by MWr miss", app_wr, base_app);
        cfg_read(10'h016, rd_val);
        check("DevSta UR+NonFatal", rd_val[19:16], 4'b1010);
        cfg_write(10'h016, 4'b0001, 32'h0000_000A);
        mem_wr(BAR0 + 32'h2000, 1, 32'h0BAD_0BAD);
        expect_msg(8'h31, 3'b000, 16'h0300);
        cfg_write(10'h016, 4'b0100, 32'h000F_0000);
        cfg_read(10'h016, rd_val);
        check("DevSta cleared", rd_val[19:16], 4'b0000);

        $display("=== Step 8: malformed TLPs and ERR_FATAL ===");
        tlp_dw[0] = dw0(3'b000, 5'b00100, 3'd0, 1'b0, 1'b0, 2'b00, 10'd2);
        tlp_dw[1] = dw_req(RC_ID, 8'h0E, 4'b1111, 4'b1111);
        tlp_dw[2] = dw_cfg(8'd3, 5'd0, 3'd0, 10'h000);
        tlp_ndw   = 3;
        rx_send;
        expect_no_tx(100);
        cfg_read(10'h016, rd_val);
        check("DevSta Fatal", rd_val[19:16], 4'b0100);
        cfg_write(10'h016, 4'b0101, 32'h0004_000E);
        tlp_dw[0] = dw0(3'b010, 5'b00000, 3'd0, 1'b0, 1'b0, 2'b00, 10'd2);
        tlp_dw[1] = dw_req(RC_ID, 8'h00, 4'b1111, 4'b1111);
        tlp_dw[2] = dw_addr(BAR0 + 32'h40);
        tlp_dw[3] = 32'h1111_1111;
        tlp_ndw   = 4;
        rx_send;
        expect_msg(8'h33, 3'b000, 16'h0300);
        tlp_dw[0] = dw0(3'b000, 5'b11011, 3'd0, 1'b0, 1'b0, 2'b00, 10'd1);
        tlp_dw[1] = dw_req(RC_ID, 8'h0F, 4'b0000, 4'b1111);
        tlp_dw[2] = 32'h0;
        tlp_ndw   = 3;
        rx_send;
        expect_msg(8'h33, 3'b000, 16'h0300);
        cfg_write(10'h016, 4'b0101, 32'h0004_0000);

        $display("=== Step 9: messages ===");
        msg(8'h19, 3'b011, 1'b0, 32'h0);
        expect_msg(8'h1B, 3'b101, 16'h0300);
        msg(8'h50, 3'b100, 1'b1, 32'h0000_01FA);
        wait_cycles(20);
        cfg_read(10'h015, rd_val);
        check("Captured Slot Power Limit", rd_val[27:18], 10'h1FA);
        msg(8'h7F, 3'b100, 1'b0, 32'h0);
        msg(8'h00, 3'b011, 1'b0, 32'h0);
        expect_no_tx(100);
        cfg_read(10'h016, rd_val);
        check("DevSta after ignored messages", rd_val[19:16], 4'b0000);
        msg(8'h7E, 3'b100, 1'b0, 32'h0);
        wait_cycles(20);
        cfg_read(10'h016, rd_val);
        check("DevSta after Vendor_Defined Type 0", rd_val[19:16], 4'b1010);
        cfg_write(10'h016, 4'b0100, 32'h000F_0000);

        $display("=== Step 10: poisoned configuration write ===");
        cfg_read(10'h00F, rd_val);
        check("Interrupt Line before", rd_val[7:0], 8'h00);
        tlp_dw[0] = dw0(3'b010, 5'b00100, 3'd0, 1'b0, 1'b1, 2'b00, 10'd1);
        tlp_dw[1] = dw_req(RC_ID, 8'h10, 4'b0000, 4'b0001);
        tlp_dw[2] = dw_cfg(8'd3, 5'd0, 3'd0, 10'h00F);
        tlp_dw[3] = 32'h0000_00AA;
        tlp_ndw   = 4;
        rx_send;
        expect_cpl(8'h10, 3'b001, 1'b0, 32'h0, 12'd4, 7'd0, 16'h0300);
        cfg_read(10'h00F, rd_val);
        check("Interrupt Line not written", rd_val[7:0], 8'h00);
        cfg_read(10'h001, rd_val);
        check("Status.DetectedParityError", rd_val[31], 1'b1);
        cfg_write(10'h001, 4'b1000, 32'h8000_0000);
        cfg_read(10'h001, rd_val);
        check("Status.DetectedParityError cleared", rd_val[31], 1'b0);

        $display("=== Step 11: UpdateFC for received credits ===");
        wait_cycles(20);
        check_updatefc;

        $display("=== Step 12: ordering, non-posted waits for earlier posted ===");
        app_rx_ready <= 1'b0;
        base_app = app_wr;
        mem_wr(BAR0 + 32'h80, 2, 32'h5555_AAAA);
        cfg_rd(8'd3, 3'd0, 10'h000, 8'h11);
        expect_no_tx(200);
        app_rx_ready <= 1'b1;
        expect_cpl(8'h11, 3'b000, 1'b1, {DEVICE_ID, VENDOR_ID}, 12'd4, 7'd0, 16'h0300);
        check("posted delivered before the read completed", app_wr, base_app + 1);

        $display("=== Step 13: ordering, posted passes a blocked non-posted ===");
        app_rx_ready <= 1'b0;
        base_app = app_wr;
        mem_rd(BAR0 + 32'h80, 1, 8'h12, 4'b1111, 4'b0000);
        msg(8'h50, 3'b100, 1'b1, 32'h0000_0123);
        wait_cycles(50);
        check("posted message passed the blocked read", dut.u_cfg_space.sspl_value, 8'h23);
        check("read still waiting for the application", app_wr, base_app);
        app_rx_ready <= 1'b1;
        tx_wait(2000, got);
        check("CplD for the blocked read", t1[63:32], 32'h5555_AAAA);

        $display("=== Step 14: receiver overflow ===");
        app_rx_ready <= 1'b0;
        base_app = app_wr;
        for (n = 0; n < INIT_PH + 1; n = n + 1) begin
            rx_no_count = (n == INIT_PH);
            mem_wr(BAR0 + 32'h100 + n * 8, 2, 32'hC000_0000 + n);
        end
        rx_no_count = 1'b0;
        wait_cycles(20);
        app_rx_ready <= 1'b1;
        wait_app(base_app + INIT_PH, 500);
        wait_cycles(50);
        check("posted TLPs accepted up to the credit limit", app_wr - base_app, INIT_PH);
        cfg_read(10'h016, rd_val);
        check("DevSta Fatal after overflow", rd_val[18], 1'b1);
        cfg_write(10'h016, 4'b0100, 32'h000F_0000);

        $display("=== Step 15: digest and 64-bit address forms ===");
        tlp_dw[0] = dw0(3'b000, 5'b00100, 3'd0, 1'b1, 1'b0, 2'b00, 10'd1);
        tlp_dw[1] = dw_req(RC_ID, 8'h13, 4'b0000, 4'b1111);
        tlp_dw[2] = dw_cfg(8'd3, 5'd0, 3'd0, 10'h000);
        tlp_dw[3] = 32'h1234_5678;
        tlp_ndw   = 4;
        rx_send;
        expect_cpl(8'h13, 3'b000, 1'b1, {DEVICE_ID, VENDOR_ID}, 12'd4, 7'd0, 16'h0300);

        $display("=== Step 16: completion forwarded to the application ===");
        base_app = app_wr;
        tlp_dw[0] = dw0(3'b010, 5'b01010, 3'd0, 1'b0, 1'b0, 2'b00, 10'd1);
        tlp_dw[1] = {8'h04, 8'h00, RC_ID[7:0], RC_ID[15:8]};
        tlp_dw[2] = {8'h00, 8'h21, 8'h00, 8'h03};
        tlp_dw[3] = 32'hCAFE_0001;
        tlp_ndw   = 4;
        rx_send;
        wait_app(base_app + 1, 200);
        check("completion delivered to the application", app_wr, base_app + 1);
        check("completion bar hit", app_bar[base_app % 64], 6'b000000);
        check("completion not poisoned", app_fwd[base_app % 64], 1'b0);
        tlp_dw[0] = dw0(3'b010, 5'b01010, 3'd0, 1'b0, 1'b1, 2'b00, 10'd1);
        tlp_dw[1] = {8'h04, 8'h00, RC_ID[7:0], RC_ID[15:8]};
        tlp_dw[2] = {8'h00, 8'h22, 8'h00, 8'h03};
        tlp_dw[3] = 32'hCAFE_0002;
        tlp_ndw   = 4;
        rx_send;
        wait_app(base_app + 2, 200);
        check("poisoned completion delivered to the application", app_wr, base_app + 2);
        check("poisoned completion err_fwd", app_fwd[(base_app + 1) % 64], 1'b1);
        wait_cycles(5);

        $display("=== Step 17: D3hot disables memory space ===");
        cfg_write(10'h011, 4'b0001, 32'h0000_0003);
        check("cfg_power_state", cfg_power_state, 2'b11);
        mem_rd(BAR0 + 32'h10, 1, 8'h14, 4'b1111, 4'b0000);
        expect_cpl(8'h14, 3'b001, 1'b0, 32'h0, 12'd4, 7'h10, 16'h0300);
        cfg_write(10'h011, 4'b0001, 32'h0000_0002);
        check("D2 write ignored", cfg_power_state, 2'b11);
        cfg_write(10'h011, 4'b0001, 32'h0000_0000);
        check("back in D0", cfg_power_state, 2'b00);

        $display("=== Step 18: application request needs Bus Master Enable ===");
        cfg_write(10'h001, 4'b0011, 32'h0000_0002);
        for (m = 0; m < 5; m = m + 1) begin
            atx_data[atx_wr % 256]      = {dw_req(16'h0300, 8'h00, 4'b0000, 4'b1111), dw0(3'b010, 5'b00000, 3'd0, 1'b0, 1'b0, 2'b00, 10'd1)};
            atx_first[atx_wr % 256]     = 1'b1;
            atx_last[atx_wr % 256]      = 1'b0;
            atx_keep[atx_wr % 256]      = 8'hFF;
            atx_data[(atx_wr+1) % 256]  = {32'h0000_0042 + m, dw_addr(32'h8000_0000 + 4 * m)};
            atx_first[(atx_wr+1) % 256] = 1'b0;
            atx_last[(atx_wr+1) % 256]  = 1'b1;
            atx_keep[(atx_wr+1) % 256]  = 8'hFF;
            atx_wr = atx_wr + 2;
        end
        expect_no_tx(200);
        check("TX buffer full: tbuf_av", cfg.tx_buf_avail, 6'd1);
        check("trn_bridge holds the SOC back", atx_rd < atx_wr, 1'b1);
        cfg_wr(8'd3, 3'd0, 10'h001, 4'b0011, 32'h0000_0006, 8'h15);
        seen_mwr = 0;
        seen_cpl = 0;
        for (n = 0; n < 6; n = n + 1) begin
            tx_wait(2000, got);
            if (got && t0[7:0] == 8'h40 && t1[63:32] == 32'h0000_0042 + seen_mwr) seen_mwr = seen_mwr + 1;
            if (got && t0[7:0] == 8'h0A && t1[23:16] == 8'h15) seen_cpl = seen_cpl + 1;
        end
        check("application MWrs sent in order after BME", seen_mwr, 5);
        check("completion of the Command write", seen_cpl, 1);
        check("TX buffer empty again: tbuf_av", cfg.tx_buf_avail, dut.TX_SLOTS);

        $display("=== Step 19: random traffic with application back-pressure ===");
        for (n = 0; n < 1024; n = n + 1) shadow[n] = app_mem[n];
        cfg_write(10'h001, 4'b0011, 32'h0000_0006);
        tx_rd  = tx_wr;
        rd_cnt = 0;
        cpl_ok = 0;
        stress = 1'b1;
        rd_done = 0;
        for (n = 0; n < 80; n = n + 1) begin
            rnd_main = xorshift(rnd_main);
            op_len   = 1 + rnd_main % 8;
            rnd_main = xorshift(rnd_main);
            op_addr  = 32'h200 + 4 * (rnd_main % 120);
            rnd_main = xorshift(rnd_main);
            if (rnd_main[16]) begin
                overlap = 0;
                for (m = rd_done; m < rd_cnt; m = m + 1) begin
                    if (op_addr < exp_rdaddr[m] + 4 * exp_rdlen[m] && exp_rdaddr[m] < op_addr + 4 * op_len) overlap = 1;
                end
                if (overlap) collect_reads;
                wait_credit(1'b0, (op_len + 3) / 4);
                tlp_dw[0] = dw0(3'b010, 5'b00000, 3'd0, 1'b0, 1'b0, 2'b00, op_len[9:0]);
                tlp_dw[1] = dw_req(RC_ID, 8'h00, (op_len == 1) ? 4'b0000 : 4'b1111, 4'b1111);
                tlp_dw[2] = dw_addr(BAR0 + op_addr);
                for (m = 0; m < op_len; m = m + 1) begin
                    rnd_main = xorshift(rnd_main);
                    tlp_dw[3+m] = rnd_main;
                    shadow[(op_addr / 4 + m) % 1024] = tlp_dw[3+m];
                end
                tlp_ndw = 3 + op_len;
                rx_send;
            end else begin
                wait_credit(1'b1, 0);
                for (m = 0; m < op_len; m = m + 1) begin
                    exp_rd[rd_cnt][m] = shadow[(op_addr / 4 + m) % 1024];
                end
                exp_rdlen[rd_cnt]  = op_len;
                exp_rdaddr[rd_cnt] = op_addr;
                mem_rd(BAR0 + op_addr, op_len, 8'h80 + rd_cnt, 4'b1111, (op_len == 1) ? 4'b0000 : 4'b1111);
                rd_cnt = rd_cnt + 1;
            end
        end
        collect_reads;
        stress = 1'b0;
        app_rx_ready <= 1'b1;
        wait_cycles(50);
        check("random reads completed with the right data", cpl_ok, rd_cnt);
        m = 0;
        for (n = 0; n < 1024; n = n + 1) begin
            if (app_mem[n] !== shadow[n]) m = m + 1;
        end
        check("application memory matches all random writes", m, 0);
        $display("        %0d writes and %0d reads", 80 - rd_cnt, rd_cnt);

        wait_cycles(20);
        check_updatefc;

        $display("=== Step 20: DL_Down resets the TL, finite completion credits ===");
        @(posedge clk);
        #1 dl_up = 1'b0;
        dl_state = DL_INACTIVE;
        wait_cycles(10);
        exp_p_hdr   = INIT_PH;
        exp_p_data  = INIT_PD;
        exp_np_hdr  = INIT_NPH;
        exp_np_data = INIT_NPD;
        check("BAR0 reset by DL_Down", dut.tl_cfg.bar0_base, 32'h0);
        check("bus number reset by DL_Down", cfg_bus_number, 8'd0);
        link_up(8'd2, 12'd2);
        cfg_rd(8'd3, 3'd0, 10'h000, 8'h21);
        cfg_rd(8'd3, 3'd0, 10'h002, 8'h22);
        cfg_rd(8'd3, 3'd0, 10'h003, 8'h23);
        expect_cpl(8'h21, 3'b000, 1'b1, {DEVICE_ID, VENDOR_ID}, 12'd4, 7'd0, 16'h0000);
        expect_cpl(8'h22, 3'b000, 1'b1, 32'hFF00_0000, 12'd4, 7'd0, 16'h0000);
        expect_no_tx(300);
        rx_dllp(DLLP_UPDATEFC, FC_CPL, 8'd3, 12'd3);
        expect_cpl(8'h23, 3'b000, 1'b1, 32'h0000_0000, 12'd4, 7'd0, 16'h0000);
        wait_cycles(20);
        check("UpdateFC NPH after DL_Down", upd_hdr[FC_NP], exp_np_hdr % 256);
        check("UpdateFC NPD after DL_Down", upd_data[FC_NP], exp_np_data % 4096);

        $display("=== Step 21: DL_Down in the middle of a TLP on TRN RX ===");
        @(posedge clk);
        #1 dl_up = 1'b0;
        dl_state = DL_INACTIVE;
        wait_cycles(10);
        link_up(8'd0, 12'd0);
        cfg_wr(8'd3, 3'd0, 10'h004, 4'b1111, BAR0, 8'h31);
        expect_cpl(8'h31, 3'b000, 1'b0, 32'h0, 12'd4, 7'd0, 16'h0300);
        cfg_wr(8'd3, 3'd0, 10'h001, 4'b0011, 32'h0000_0006, 8'h32);
        expect_cpl(8'h32, 3'b000, 1'b0, 32'h0, 12'd4, 7'd0, 16'h0300);
        base_app = app_wr;
        app_rx_ready <= 1'b0;
        mem_wr(BAR0 + 32'h200, 4, 32'h7777_0000);
        wait_cycles(30);
        @(posedge clk);
        #1 dl_up = 1'b0;
        dl_state = DL_INACTIVE;
        wait_cycles(10);
        app_rx_ready <= 1'b1;
        wait_cycles(30);
        link_up(8'd0, 12'd0);
        cfg_wr(8'd3, 3'd0, 10'h004, 4'b1111, BAR0, 8'h33);
        expect_cpl(8'h33, 3'b000, 1'b0, 32'h0, 12'd4, 7'd0, 16'h0300);
        cfg_wr(8'd3, 3'd0, 10'h001, 4'b0011, 32'h0000_0006, 8'h34);
        expect_cpl(8'h34, 3'b000, 1'b0, 32'h0, 12'd4, 7'd0, 16'h0300);
        mem_wr(BAR0 + 32'h300, 2, 32'h1111_2222);
        wait_app(base_app + 2, 300);
        check("SOC TLPs: cut one and next", app_wr - base_app, 2);
        check("cut TLP padded to its length", app_len[base_app % 64], 4);
        check("next TLP whole", app_len[(base_app + 1) % 64], 3);
        check("next TLP data", word_dw((base_app + 1) % 64, 3), 32'h1111_2222);

        wait_cycles(20);
        $display("=== SUMMARY: %0d errors ===", errors);
        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED");
        $finish;
    end

    initial begin
        #2_000_000;
        $display("ERROR: watchdog");
        $display("TEST FAILED");
        $finish;
    end

`ifdef DUMP
    initial begin
        $dumpfile("sim/tb_pcie_tl.fst");
        $dumpvars(0, tb_pcie_tl);
    end
`endif

endmodule
