// Separate sending InitFC logic
module send_DLLP #
(
    parameter DATA_BYTES = 8,
    parameter DATA_WIDTH = DATA_BYTES * 8,
    parameter PATTERN_WIDTH = 64
)
(
    input  wire                         clk,
    input  wire                         reset,

    input  wire                   [2:0] virtual_channel,
    input  wire                   [7:0] hdr_credit,
    input  wire                  [11:0] data_credit,
    input  wire                   [1:0] update_type,
    input  wire                   [1:0] packet_type,

    input  wire                  [11:0] nack_sequence_number, // Sequence number for NAK/ACK DLLP
    input  wire                         ack_trigger, // Asserted in the same cycle as packet_avail, deasserted when DLLP is sent
    input  wire                         nak_trigger, // 

    input  wire                         packet_avail, // DLLP available and free to send, deasserted when DLLP is sent

    input  wire                         initfc1_en, // Sending InitFC1 sequence
    input  wire                         initfc2_en, // Sending InitFC2 sequence

    output reg                          dllp_initfc1_sent,
    output reg                          dllp_initfc2_sent,
    output reg                          dllp_sent,
    output reg         [DATA_WIDTH-1:0] txdata,
    output reg         [DATA_BYTES-1:0] txdatak
);

    localparam  SDP = 8'h5C;
    localparam _END = 8'hFD;
    localparam NUMBER_OF_STEPS = PATTERN_WIDTH / DATA_WIDTH - 1;
    localparam INITFC_NUMBER_OF_STEPS = (PATTERN_WIDTH * 3) / DATA_WIDTH - 1; // Send all three InitFC at a time

    wire  [7:0] dllp_type;
    wire [31:0] data;
    wire  [7:0] data1;
    wire  [7:0] data2;
    wire  [7:0] data3;
    wire [PATTERN_WIDTH-1:0] DLLP;
    wire [PATTERN_WIDTH/8-1:0] DLLP_k;
    wire [PATTERN_WIDTH*3-1:0] DLLP_initfc1;
    wire [PATTERN_WIDTH*3/8-1:0] DLLP_initfc1_k;
    wire [PATTERN_WIDTH*3-1:0] DLLP_initfc2;
    wire [PATTERN_WIDTH*3/8-1:0] DLLP_initfc2_k;
    wire [15:0] calc_crc;

    reg  [$clog2(NUMBER_OF_STEPS) : 0] step;
    reg  [$clog2(INITFC_NUMBER_OF_STEPS) : 0] initfc_step;

    always @ (posedge clk or posedge reset) begin
        if ( reset ) begin
            txdata  <= {DATA_WIDTH{1'b0}};
            txdatak <= {DATA_BYTES{1'b0}};
            step    <= 0;
            initfc_step <= 0;
            dllp_sent <= 1'b0;
            dllp_initfc1_sent <= 1'b0;
            dllp_initfc2_sent <= 1'b0;
        end else begin
            dllp_sent <= 1'b0;
            dllp_initfc1_sent <= 1'b0;
            dllp_initfc2_sent <= 1'b0;


            if (packet_avail) begin
                if ( step != NUMBER_OF_STEPS ) begin
                    txdata  <= DLLP[DATA_WIDTH * step +: DATA_WIDTH];
                    txdatak <= DLLP_k[DATA_BYTES * step +: DATA_BYTES];
                    step    <= step + 1;
                    initfc_step <= 0;
                end else if ( step == NUMBER_OF_STEPS ) begin
                    txdata  <= DLLP[DATA_WIDTH * step +: DATA_WIDTH];
                    txdatak <= DLLP_k[DATA_BYTES * step +: DATA_BYTES];
                    dllp_sent <= 1'b1;
                    step    <= 0;
                    initfc_step <= 0;
                end
            end else if (initfc1_en) begin
                if ( initfc_step != INITFC_NUMBER_OF_STEPS ) begin
                    txdata  <= DLLP_initfc1[DATA_WIDTH * initfc_step +: DATA_WIDTH];
                    txdatak <= DLLP_initfc1_k[DATA_BYTES * initfc_step +: DATA_BYTES];
                    initfc_step <= initfc_step + 1;
                    step    <= 0;
                end else if ( initfc_step == INITFC_NUMBER_OF_STEPS ) begin
                    txdata  <= DLLP_initfc1[DATA_WIDTH * initfc_step +: DATA_WIDTH];
                    txdatak <= DLLP_initfc1_k[DATA_BYTES * initfc_step +: DATA_BYTES];
                    dllp_initfc1_sent <= 1'b1;
                    initfc_step <= 0;
                    step    <= 0;
                end
            end else if (initfc2_en) begin
                if ( initfc_step != INITFC_NUMBER_OF_STEPS ) begin
                    txdata  <= DLLP_initfc2[DATA_WIDTH * initfc_step +: DATA_WIDTH];
                    txdatak <= DLLP_initfc2_k[DATA_BYTES * initfc_step +: DATA_BYTES];
                    initfc_step <= initfc_step + 1;
                    step    <= 0;
                end else if ( initfc_step == INITFC_NUMBER_OF_STEPS ) begin
                    txdata  <= DLLP_initfc2[DATA_WIDTH * initfc_step +: DATA_WIDTH];
                    txdatak <= DLLP_initfc2_k[DATA_BYTES * initfc_step +: DATA_BYTES];
                    dllp_initfc2_sent <= 1'b1;
                    initfc_step <= 0;
                    step    <= 0;
                end
            end else begin
                txdata  <= {DATA_WIDTH{1'b0}};
                txdatak <= {DATA_BYTES{1'b0}};
                step    <= 0;
                initfc_step <= 0;
            end
        end
    end

    crc_gen crc_inst (
        .clk(clk),
        .reset(reset),
        .crc_en(1'b1),
        .data_in(data[31:0]),

        .calc_crc(calc_crc)
    );

    assign dllp_type = ack_trigger ? 8'b0000_0000 :
                       nak_trigger ? 8'b0001_0000 :
                                    {packet_type, update_type, 1'b0, virtual_channel};
    assign data1 = {2'b0, hdr_credit[7:2]};
    assign data2 = {hdr_credit[1:0], 2'b0, data_credit[11:8]};
    assign data3 = {data_credit[7:0]};
    assign data  = (ack_trigger | nak_trigger) ? {nack_sequence_number[7:0], 4'b0, nack_sequence_number[11:8], 8'b0, dllp_type} 
                                                : {data3, data2, data1, dllp_type};
    assign DLLP  = {_END, calc_crc, data, SDP};
    assign DLLP_k = {1'b1, 6'b0, 1'b1};
    assign DLLP_initfc1 = {_END, 8'hbc, 8'h35, 8'hf0, 8'h03, 8'h08, 8'h40, SDP,
                           _END, 8'hf6, 8'hb1, 8'h01, 8'h00, 8'h08, 8'h50, SDP,
                           _END, 8'h92, 8'hd8, 8'h00, 8'h00, 8'h00, 8'h60, SDP};
    assign DLLP_initfc1_k = {1'b1, 6'b0, 1'b1, 1'b1, 6'b0, 1'b1, 1'b1, 6'b0, 1'b1};
    assign DLLP_initfc2 = {_END, 8'hc3, 8'h4f, 8'hf0, 8'h03, 8'h08, 8'hc0, SDP,
                           _END, 8'h89, 8'hcb, 8'h01, 8'h00, 8'h08, 8'hd0, SDP,
                           _END, 8'hed, 8'ha2, 8'h00, 8'h00, 8'h00, 8'he0, SDP};
    assign DLLP_initfc2_k = {1'b1, 6'b0, 1'b1, 1'b1, 6'b0, 1'b1, 1'b1, 6'b0, 1'b1};

endmodule