// Separate sending InitFC logic
module virtual_channel_tx #
(
    parameter DATA_BYTES = 8,
    parameter DATA_WIDTH = DATA_BYTES * 8,
    parameter PATTERN_WIDTH = 64
)
(
    input  wire                         clk,
    input  wire                         reset,
    input  wire                         link_inactive,

    input  wire                   [2:0] virtual_channel,
    input  wire                   [7:0] hdr_credit,
    input  wire                  [11:0] data_credit,
    input  wire                   [1:0] update_type,
    input  wire                   [1:0] packet_type,
    input  wire                         packet_avail, //pulse

    input  wire                         initfc1_en, // Sending InitFC1 sequence
    input  wire                         initfc2_en, // Sending InitFC2 sequence
    //input  wire                  [11:0] nack_sequence_number, // Sequence number for NAK/ACK DLLP

    input  wire                         tlp_valid,
    input  wire                         tlp_first,
    input  wire                         tlp_last,
    input  wire        [DATA_WIDTH-1:0] tlp_data,

    input  wire                         release_flag,
    input  wire                         retransmit_flag,
    input  wire                  [11:0] retransmit_seq_num, // not used

    input  wire                         nak_trigger, //pulse
    input  wire                         ack_trigger, //pulse
    input  wire                  [11:0] nak_sequence_number,
    input  wire                  [11:0] ack_sequence_number,

    output reg                          dllp_initfc1_sent,
    output reg                          dllp_initfc2_sent,

    output reg                          retry_buffer_empty,
    output reg                          retry_buffer_full,
    //output reg                          dllp_sent,
    //output reg                          tlp_sent,
    output reg         [DATA_WIDTH-1:0] tx_data,
    output reg         [DATA_BYTES-1:0] tx_data_k
);

    wire dllp_sent;
    wire tlp_scheduled;

    reg ack_sending;
    reg nak_sending;
    reg dllp_sending;
    reg tlp_sending;

    reg  [7:0] header_credit;
    reg [11:0] data_credit_reg;
    reg  [1:0] update_type_reg;
    reg  [1:0] packet_type_reg;
    reg        dllp_scheduled;

    reg ack_scheduled;
    reg nak_scheduled;
    reg [11:0] nack_sequence_number;

    // Sorted after priority: NAK > ACK > DLLP > TLP
    always @(posedge clk) begin
        if (reset) begin
            ack_sending  <= 1'b0;
            nak_sending  <= 1'b0;
            dllp_sending <= 1'b0;
            tlp_sending  <= 1'b0;
        end else begin
            if (ack_sending  && !ack_scheduled)
                ack_sending  <= 1'b0;
            if (nak_sending  && !nak_scheduled)
                nak_sending  <= 1'b0;
            if (dllp_sending && !(ack_scheduled || nak_scheduled || dllp_scheduled))
                dllp_sending <= 1'b0;
            if (tlp_sending  && !tlp_scheduled)
                tlp_sending  <= 1'b0;

            if (!(dllp_sending || tlp_sending)) begin
                if (nak_scheduled) begin
                    nak_sending  <= 1'b1;
                    dllp_sending <= 1'b1;
                end else if (ack_scheduled) begin
                    ack_sending  <= 1'b1;
                    dllp_sending <= 1'b1;
                end else if (dllp_scheduled) begin
                    dllp_sending <= 1'b1;
                end else if (tlp_scheduled) begin
                    tlp_sending <= 1'b1;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            header_credit   <= 0;
            data_credit_reg <= 0;
            update_type_reg <= 0;
            packet_type_reg <= 0;
            dllp_scheduled  <= 0;
        end else begin
            if (packet_avail) begin
                header_credit   <= hdr_credit;
                data_credit_reg <= data_credit;
                update_type_reg <= update_type;
                packet_type_reg <= packet_type;
                dllp_scheduled  <= 1'b1;
            end else if (dllp_sent) begin
                if (dllp_sending) begin
                    dllp_scheduled <= 1'b0;
                end
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            ack_scheduled <= 1'b0;
            nak_scheduled <= 1'b0;
        end else if (ack_trigger) begin
            ack_scheduled <= 1'b1;
            nack_sequence_number <= ack_sequence_number;
        end else if (nak_trigger) begin
            nak_scheduled <= 1'b1;
            nack_sequence_number <= nak_sequence_number;
        end else if (dllp_sent) begin
            if (ack_sending) begin
                ack_scheduled <= 1'b0;
            end else if (nak_sending) begin
                nak_scheduled <= 1'b0;
            end
        end
    end

    wire initfc1_sent;
    wire initfc2_sent;

    always @(posedge clk) begin
        if (reset) begin
            dllp_initfc1_sent <= 1'b0;
            dllp_initfc2_sent <= 1'b0;
        end else begin
            dllp_initfc1_sent <= initfc1_sent;
            dllp_initfc2_sent <= initfc2_sent;
        end
    end

    wire [DATA_WIDTH-1:0] dllp_tx_data;
    wire [DATA_BYTES-1:0] dllp_tx_data_k;

    send_DLLP #(
        .DATA_BYTES(DATA_BYTES),
        .PATTERN_WIDTH(PATTERN_WIDTH)
    ) send_DLLP_inst (
        .clk(clk),
        .reset(reset),

        .virtual_channel(virtual_channel),
        .hdr_credit(header_credit),
        .data_credit(data_credit_reg),
        .update_type(update_type_reg),
        .packet_type(packet_type_reg),

        .nack_sequence_number(nack_sequence_number),
        .ack_trigger(ack_sending),
        .nak_trigger(nak_sending),

        .packet_avail(dllp_sending),

        .initfc1_en(initfc1_en),
        .initfc2_en(initfc2_en),

        .dllp_initfc1_sent(initfc1_sent),
        .dllp_initfc2_sent(initfc2_sent),
        .dllp_sent(dllp_sent),
        .txdata(dllp_tx_data),
        .txdatak(dllp_tx_data_k)
    );

    reg release_flag_reg;
    reg retransmit_flag_reg;

    always @(posedge clk) begin
        if (reset) begin
            release_flag_reg    <= 1'b0;
            retransmit_flag_reg <= 1'b0;
        end else begin
            release_flag_reg    <= release_flag;
            retransmit_flag_reg <= retransmit_flag;
        end
    end

    wire empty;
    wire full;

    always @(posedge clk) begin
        if (reset) begin
            retry_buffer_empty <= 1'b1;
            retry_buffer_full  <= 1'b0;
        end else begin
            retry_buffer_empty <= empty;
            retry_buffer_full  <= full;
        end
    end

    wire [DATA_WIDTH-1:0] tlp_tx_data;
    wire [DATA_BYTES-1:0] tlp_tx_data_k;

    reg [11:0] current_seq_num;

    always @(posedge clk) begin
        if (reset) begin
            current_seq_num <= 12'b0;
        end else if (link_inactive) begin
            current_seq_num <= 12'b0;
        end else if (empty && tlp_valid && tlp_first) begin
            current_seq_num <= current_seq_num + 1'b1;
        end
    end

    retry_buffer #(
        .DATA_BYTES(DATA_BYTES),
        .BRAM_ADDR_WIDTH(9)
    ) retry_buffer_inst (
        .clk(clk),
        .reset(reset),

        .tlp_valid(tlp_valid),
        .tlp_first(tlp_first),
        .tlp_last(tlp_last),
        .tlp_in_data(tlp_data),

        .current_seq_num(current_seq_num),

        .empty(empty),
        .full(full),

        .release_flag(release_flag_reg),
        .retransmit_flag(retransmit_flag_reg),
        .retransmit_seq_num(), // currently unused because retry buffer has size of one

         // First word of TLP is sent, stay asserting until the last word is sent
        .tlp_sending(tlp_sending),
        // TLP is scheduled to be sent, stay asserting until the last word is sent
        .tlp_scheduled(tlp_scheduled),
        .tlp_out_data(tlp_tx_data),
        .tlp_out_data_k(tlp_tx_data_k)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_data   <= {DATA_WIDTH{1'b0}};
            tx_data_k <= {DATA_BYTES{1'b0}};
        end else if (ack_sending || nak_sending || dllp_sending || initfc1_en || initfc2_en) begin
            tx_data   <= dllp_tx_data;
            tx_data_k <= dllp_tx_data_k;
        end else if (tlp_sending) begin
            tx_data   <= tlp_tx_data;
            tx_data_k <= tlp_tx_data_k;
        end else begin
            tx_data   <= {DATA_WIDTH{1'b0}};
            tx_data_k <= {DATA_BYTES{1'b0}};
        end
    end
endmodule
