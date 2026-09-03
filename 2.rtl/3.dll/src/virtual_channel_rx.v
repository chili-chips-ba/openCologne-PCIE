module virtual_channel_rx #
(
    parameter DATA_BYTES = 8,
    parameter DATA_WIDTH = DATA_BYTES * 8,
    parameter PATTERN_WIDTH = 64
)
(
    input  wire                         clk,
    input  wire                         reset,
    input  wire                         link_active,
    input  wire                         link_inactive,

    input  wire     [PATTERN_WIDTH-1:0] DLLP_data,
    input  wire                         SDP_detected,

    input  wire        [DATA_WIDTH-1:0] TLP_data,
    input  wire                         STP_detected,
    input  wire                         END_detected,
    input  wire                  [15:0] sequence_number,
    input  wire                  [31:0] lcrc,
    input  wire                         tlp_valid,

    output reg                    [1:0] update_type,
    output reg                    [1:0] packet_type,
    output reg                    [7:0] hdrfc,
    output reg                   [11:0] datafc,
    output reg                          crc_valid,

    output reg         [DATA_WIDTH-1:0] rx_tlp_data,
    output reg                          rx_tlp_valid,
    output reg                          rx_tlp_first,
    output reg                          rx_tlp_last,

    output reg                          nak_trigger,
    output reg                   [11:0] nak_seq_num,
    output reg                          ack_trigger,
    output reg                   [11:0] ack_seq_num
);

    wire [DATA_WIDTH-1:0] tlp_data_w;
    wire                  tlp_valid_w;
    wire                  tlp_first_w;
    wire                  tlp_last_w;

    // DLLP RX Handler
    wire        DLLP_valid;
    wire [15:0] calc_crc;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            update_type       <= 2'b00;
            packet_type       <= 2'b11;
            hdrfc             <= 8'b0;
            datafc            <= 12'b0;
            crc_valid         <= 1'b0;
        end else begin
            crc_valid <= 1'b0;
            if (SDP_detected) begin
                update_type <= DLLP_data[13:12];
                packet_type <= DLLP_data[15:14];
                hdrfc       <= {DLLP_data[21:16], DLLP_data[31:30]};
                datafc      <= {DLLP_data[27:24], DLLP_data[39:32]};
                crc_valid   <= DLLP_valid;
            end
        end
    end

    crc_gen crc_inst (
        .clk(clk),
        .reset(reset),
        .crc_en(SDP_detected),
        .data_in(DLLP_data[39:8]),

        .calc_crc(calc_crc)
    );

    assign DLLP_valid   = calc_crc == DLLP_data[55:40];


    // TLP RX Handler
    wire nak_scheduled;
    wire [11:0] nak_seq_number;
    wire ack_scheduled;
    wire [11:0] ack_seq_number;
    wire new_tlp_accepted;

    reg  [11:0] NEXT_RCV_SEQ;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            nak_trigger <= 1'b0;
            nak_seq_num <= 12'b0;
            ack_trigger <= 1'b0;
            ack_seq_num <= 12'b0;
        end else begin
            nak_trigger <= nak_scheduled;
            nak_seq_num <= nak_seq_number;
            ack_trigger <= ack_scheduled;
            ack_seq_num <= ack_seq_number;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            NEXT_RCV_SEQ <= 12'b0;
        end else if (link_inactive) begin
            NEXT_RCV_SEQ <= 12'b0;
        end else if (new_tlp_accepted) begin
            NEXT_RCV_SEQ <= NEXT_RCV_SEQ + 1;
        end
    end

    tlp_rx_buffer #(
        .DATA_BYTES(DATA_BYTES),
        .BRAM_ADDR_WIDTH(9)
    ) tlp_rx_buffer_inst (
        .clk(clk),
        .reset(reset),
        .link_active(link_active),

        .STP_detected(STP_detected),
        .END_detected(END_detected),
        .data_TL_in(TLP_data),
        .sequence_number(sequence_number),
        .lcrc(lcrc),
        .tlp_valid(tlp_valid),

        .NEXT_RCV_SEQ(NEXT_RCV_SEQ),

        .nak_scheduled(nak_scheduled),
        .nak_seq_num(nak_seq_number),
        .ack_scheduled(ack_scheduled),
        .ack_seq_num(ack_seq_number),
        .new_tlp_accepted(new_tlp_accepted),

        .rx_data_TL(tlp_data_w),
        .rx_tlp_valid(tlp_valid_w),
        .rx_tlp_first(tlp_first_w),
        .rx_tlp_last(tlp_last_w)
    );

    always @(posedge clk) begin
        if (reset) begin
            rx_tlp_data  <= {DATA_WIDTH{1'b0}};
            rx_tlp_valid <= 1'b0;
            rx_tlp_first <= 1'b0;
            rx_tlp_last  <= 1'b0;
        end else begin
            rx_tlp_data  <= tlp_data_w;
            rx_tlp_valid <= tlp_valid_w;
            rx_tlp_first <= tlp_first_w;
            rx_tlp_last  <= tlp_last_w;
        end
    end

endmodule
