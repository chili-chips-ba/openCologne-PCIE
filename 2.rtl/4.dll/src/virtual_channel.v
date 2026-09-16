module virtual_channel #
(
    parameter DATA_BYTES = 8,
    parameter DATA_WIDTH = DATA_BYTES * 8,
    parameter PATTERN_WIDTH = 64
)
(
    input  wire                         clk,
    input  wire                         reset,
    input  wire                         linkup,
    input  wire                   [2:0] virtual_channel_number,
    // Credits data from Transaction Layer
    input  wire                   [7:0] tx_hdr_credit,
    input  wire                  [11:0] tx_data_credit,
    input  wire                   [1:0] tx_update_type,
    input  wire                   [1:0] tx_packet_type,
    input  wire                         tx_dllp_valid,
    // Received data from Physical Layer
    input  wire        [DATA_WIDTH-1:0] rx_data,
    //input  wire        [DATA_BYTES-1:0] rx_data_k,
    // TLP data from Transaction Layer
    input  wire        [DATA_WIDTH-1:0] tx_tlp_data,
    //input  wire        [DATA_BYTES-1:0] tx_data_TL_k,
    input  wire                         tx_tlp_valid,
    input  wire                         tx_tlp_first,
    input  wire                         tx_tlp_last,
    output reg                          tx_tlp_ready, // Ready if retry buffer is empty
    // Transmitted data to Physical Layer
    output reg         [DATA_WIDTH-1:0] tx_data,
    output reg         [DATA_BYTES-1:0] tx_data_k,
    // Extracted credits data
    output reg                    [7:0] rx_hdr_credit,
    output reg                   [11:0] rx_data_credit,
    output reg                    [1:0] rx_update_type,
    output reg                    [1:0] rx_packet_type,
    output reg                          rx_dllp_valid,
    // Received TLP data to Transaction Layer
    output reg         [DATA_WIDTH-1:0] rx_tlp_data,
    //output reg         [DATA_BYTES-1:0] rx_data_TL_k,
    output reg                          rx_tlp_valid,
    output reg                          rx_tlp_first,
    output reg                          rx_tlp_last
);
    // FSM
    wire initfc1_en;
    wire initfc2_en;
    wire [2:0] fsm_state;
    localparam [2:0] DL_INACTIVE = 3'b000;
    localparam [2:0] DL_ACTIVE   = 3'b011;
    wire link_active = (fsm_state == DL_ACTIVE);
    wire link_inactive = (fsm_state == DL_INACTIVE);
    // Tx side
    wire [DATA_WIDTH-1:0] txdata;
    wire [DATA_BYTES-1:0] txdatak;

    wire dllp_initfc1_sent;
    wire dllp_initfc2_sent;
    wire retry_buffer_empty;
    wire retry_buffer_full;

    // Rx side
    wire [PATTERN_WIDTH-1:0] data_DLLP;
    wire [1:0] update_type;
    wire [1:0] packet_type;
    wire [7:0] hdrfc;
    wire [11:0] datafc;
    wire crc_valid;
    wire SDP_detected;

    wire [DATA_WIDTH-1:0] rx_data_TL;
    wire rx_valid_TL;
    wire rx_first_TL;
    wire rx_last_TL;

    wire [DATA_WIDTH-1:0] data_TL;
    wire STP_detected;
    wire END_detected;
    wire [15:0] sequence_number;
    wire [31:0] lcrc;
    wire tlp_valid;

    wire nak_trigger;
    wire [11:0] nak_seq_num;
    wire ack_trigger;
    wire [11:0] ack_seq_num;

    reg [2:0] initfc1_received_flag;
    reg initfc1_seq_received;
    reg [2:0] initfc2_received_flag;
    reg initfc2_seq_received;

    reg ack_received_flag;
    reg nak_received_flag;
    reg [11:0] acknak_seq_num;
    reg [11:0] ACKD_SEQ;
    reg tlp_released_flag;
    reg tlp_retransmit_flag;

    reg NAK_SCHEDULED;
    reg [11:0] NEXT_RCV_SEQ;

    // Parameters
    // Define cycle time based on data width
    // TODO: Look at retry timer again
    localparam CYCLE_TIME     = DATA_BYTES == 8 ? 32 : DATA_BYTES == 4 ? 16 : DATA_BYTES == 2 ? 8 : DATA_BYTES == 1 ? 4 : 0; // in ns
    localparam INIT_CYCLE_CNT = 34000 / CYCLE_TIME; // 34us in terms of cycles
    wire       init_counter_flag;
    reg        initfc1; // TODO: currently not used
    reg        initfc2; // TODO: currently not used

    wire END_lost;

    packet_handler #(
        .DATA_BYTES(DATA_BYTES),
        .PATTERN_WIDTH(PATTERN_WIDTH)
    ) dllp_assembly_inst (
        .clk(clk),
        .reset(reset),
        .rx_data(rx_data),
        .END_lost(END_lost), // tlp_rx_buffer for one TLP is full but no END is detected

        .SDP_detected(SDP_detected),
        .STP_detected(STP_detected),
        .END_detected(END_detected),
        .data_DLLP(data_DLLP),
        .data_TL(data_TL),
        .sequence_number(sequence_number),
        .lcrc(lcrc),
        .tlp_valid(tlp_valid)
    );

    virtual_channel_rx #(
        .DATA_BYTES(DATA_BYTES),
        .PATTERN_WIDTH(PATTERN_WIDTH)
    ) vc_rx (
        .clk(clk),
        .reset(reset),
        .link_active(link_active),
        .link_inactive(link_inactive),

        .DLLP_data(data_DLLP),
        .SDP_detected(SDP_detected),

        .TLP_data(data_TL),
        .STP_detected(STP_detected),
        .END_detected(END_detected),
        .sequence_number(sequence_number),
        .lcrc(lcrc),
        .tlp_valid(tlp_valid),

        .update_type(update_type),
        .packet_type(packet_type),
        .hdrfc(hdrfc),
        .datafc(datafc),
        .crc_valid(crc_valid),

        .rx_tlp_data(rx_data_TL),
        .rx_tlp_valid(rx_valid_TL),
        .rx_tlp_first(rx_first_TL),
        .rx_tlp_last(rx_last_TL),

        // TODO: To virtual_channel_tx
        .nak_trigger(nak_trigger),
        .nak_seq_num(nak_seq_num),
        .ack_trigger(ack_trigger),
        .ack_seq_num(ack_seq_num)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_tlp_data  <= {DATA_WIDTH{1'b0}};
            rx_tlp_first <= 1'b0;
            rx_tlp_last  <= 1'b0;
            rx_tlp_valid <= 1'b0;
        end else begin
            rx_tlp_data  <= rx_data_TL;
            rx_tlp_first <= rx_first_TL;
            rx_tlp_last  <= rx_last_TL;
            rx_tlp_valid <= rx_valid_TL;
        end
    end

    // Received DLLP data is sent to TLP
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_update_type   <= 2'b00;
            rx_packet_type   <= 2'b00;
            rx_dllp_valid    <= 1'b0;
            rx_hdr_credit    <= 8'b0;
            rx_data_credit   <= 12'b0;
        end else begin
            rx_dllp_valid <= 1'b0; 
            if (crc_valid) begin
                rx_update_type   <= update_type;
                rx_packet_type   <= packet_type;
                rx_dllp_valid    <= crc_valid;
                rx_hdr_credit    <= hdrfc;
                rx_data_credit   <= datafc;
            end
        end
    end

    // Init sequence handling
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            initfc1_received_flag <= 3'b000;
            initfc2_received_flag <= 3'b000;
        end else if (fsm_state == DL_INACTIVE) begin
            initfc1_received_flag <= 3'b000;
            initfc2_received_flag <= 3'b000;
        end else if (crc_valid) begin
            if (initfc1_en) begin
                if ({packet_type, update_type} == 4'b0100) begin
                    initfc1_received_flag[0] <= 1'b1;
                end else if ({packet_type, update_type} == 4'b0101) begin
                    initfc1_received_flag[1] <= 1'b1;
                end else if ({packet_type, update_type} == 4'b0110) begin
                    initfc1_received_flag[2] <= 1'b1;
                end
            end else if (initfc2_en) begin
                if ({packet_type, update_type} == 4'b1100) begin
                    initfc2_received_flag[0] <= 1'b1;
                end else if ({packet_type, update_type} == 4'b1101) begin
                    initfc2_received_flag[1] <= 1'b1;
                end else if ({packet_type, update_type} == 4'b1110) begin
                    initfc2_received_flag[2] <= 1'b1;
                end
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            initfc1_seq_received <= 1'b0;
            initfc2_seq_received <= 1'b0;
        end else if (fsm_state == DL_INACTIVE) begin
            initfc1_seq_received <= 1'b0;
            initfc2_seq_received <= 1'b0;
        end else begin
            if (&initfc1_received_flag) begin
                initfc1_seq_received <= 1'b1;
            end
            if (&initfc2_received_flag) begin
                initfc2_seq_received <= 1'b1;
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            initfc1 <= 1'b0;
            initfc2 <= 1'b0;
        end else if (init_counter_flag) begin
            if (initfc1_en) begin
                initfc1 <= 1'b1;
                initfc2 <= 1'b0;
            end else if (initfc2_en) begin
                initfc1 <= 1'b0;
                initfc2 <= 1'b1;
            end else begin
                initfc1 <= 1'b0;
                initfc2 <= 1'b0;
            end
        end
    end

    // Ack and Nak handling
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ack_received_flag <= 1'b0;
            nak_received_flag <= 1'b0;
            acknak_seq_num    <= 12'b0;
        end else if (crc_valid) begin
            ack_received_flag <= 1'b0;
            nak_received_flag <= 1'b0;
            if ({packet_type, update_type} == 4'b0000) begin
                ack_received_flag <= 1'b1;
                acknak_seq_num    <= datafc;
            end else if ({packet_type, update_type} == 4'b0001) begin
                nak_received_flag <= 1'b1;
                acknak_seq_num    <= datafc;
            end
        end else begin
            ack_received_flag <= 1'b0;
            nak_received_flag <= 1'b0;
            acknak_seq_num    <= 12'b0;
        end
    end

    // Release and retransmit handling
    // TODO: To virtual_channel_tx
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ACKD_SEQ <= 12'hFFF;
            tlp_released_flag       <= 1'b0;
            tlp_retransmit_flag     <= 1'b0;
        end else if (link_inactive) begin
            ACKD_SEQ <= 12'hFFF;
            tlp_released_flag       <= 1'b0;
            tlp_retransmit_flag     <= 1'b0;
        end else if (ack_received_flag) begin
            if ((acknak_seq_num - ACKD_SEQ) != 12'b0 && (acknak_seq_num - ACKD_SEQ) <= 12'd2048) begin
                ACKD_SEQ <= acknak_seq_num; // Update acknowledged sequence number
                tlp_released_flag   <= 1'b1;
                tlp_retransmit_flag <= 1'b0;
            end else begin
                tlp_released_flag   <= 1'b0;
                tlp_retransmit_flag <= 1'b0;
            end
            // TODO: What if wrong ACK is received? Should we ignore it or trigger a NAK?
        end else if (nak_received_flag) begin
            tlp_released_flag       <= 1'b0;
            tlp_retransmit_flag     <= 1'b1;
        end else begin
            tlp_released_flag       <= 1'b0;
            tlp_retransmit_flag     <= 1'b0;
        end
    end

    /*always @(posedge clk or posedge reset) begin
        if (reset) begin
            data_TL_reg          <= {DATA_WIDTH{1'b0}};
            STP_detected_reg     <= 1'b0;
            END_detected_reg     <= 1'b0;
            sequence_number_reg  <= 12'b0;
            lcrc_reg             <= 32'b0;
            tlp_valid_reg        <= 1'b0;
        end else begin
            data_TL_reg          <= data_TL;
            STP_detected_reg     <= STP_detected;
            END_detected_reg     <= END_detected;
            sequence_number_reg  <= sequence_number;
            lcrc_reg             <= lcrc;
            tlp_valid_reg        <= tlp_valid;
        end
    end*/

    // TODO: Check timer
    ccfpga_clk_counter #(
        .BIT_WIDTH(14)        // Width of Count Register
    ) init_counter_inst (
        .i_clk(clk),
        .i_reset(reset),
        .max_count(INIT_CYCLE_CNT),
        .o_flag(init_counter_flag)
    );

    virtual_channel_tx #(
        .DATA_BYTES(DATA_BYTES),
        .PATTERN_WIDTH(PATTERN_WIDTH)
    ) vc_tx (
        .clk(clk),
        .reset(reset),
        .link_inactive(link_inactive),

        .virtual_channel(virtual_channel_number),
        .hdr_credit(tx_hdr_credit),
        .data_credit(tx_data_credit),
        .update_type(tx_update_type),
        .packet_type(tx_packet_type),
        .packet_avail(tx_dllp_valid),

        .initfc1_en(initfc1_en),
        .initfc2_en(initfc2_en),
        //.tlp_en(tlp_en),
        .tlp_valid(tx_tlp_valid),
        .tlp_first(tx_tlp_first),
        .tlp_last(tx_tlp_last),
        .tlp_data(tx_tlp_data),

        .release_flag(tlp_released_flag),
        .retransmit_flag(tlp_retransmit_flag),
        .retransmit_seq_num(), // not used

        .nak_trigger(nak_trigger),
        .ack_trigger(ack_trigger),
        .nak_sequence_number(nak_seq_num),
        .ack_sequence_number(ack_seq_num),

        .dllp_initfc1_sent(dllp_initfc1_sent),
        .dllp_initfc2_sent(dllp_initfc2_sent),

        .retry_buffer_empty(retry_buffer_empty),
        .retry_buffer_full(retry_buffer_full),
        //.dllp_sent(dllp_sent),
        //.tlp_sent(tlp_sent),
        .tx_data(txdata),
        .tx_data_k(txdatak)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_tlp_ready <= 1'b0;
        end else begin
            tx_tlp_ready <= retry_buffer_empty && (fsm_state == DL_ACTIVE); // ready when retry buffer is empty and FSM is in active state
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_data   <= {DATA_WIDTH{1'b0}};
            tx_data_k <= {DATA_BYTES{1'b0}};
        end else begin
            tx_data   <= txdata;
            tx_data_k <= txdatak;
        end
    end

    dll_fsm #(
        .DATA_BYTES(DATA_BYTES)
    ) init_fsm (
        .reset(reset),
        .i_clk(clk),
        .i_LinkUp(linkup),
        .i_initfc1_rx_done(initfc1_seq_received),
        .i_initfc1_tx_done(dllp_initfc1_sent),
        .i_initfc2_rx_done(initfc2_seq_received),
        .i_initfc2_tx_done(dllp_initfc2_sent),

        .o_initfc1_en(initfc1_en),
        .o_initfc2_en(initfc2_en),
        .o_fsm_state(fsm_state)
    );

endmodule
