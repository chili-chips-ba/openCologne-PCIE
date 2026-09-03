module tlp_rx_buffer #(
    parameter DATA_BYTES      = 8,
    parameter DATA_WIDTH      = DATA_BYTES * 8,
    parameter BRAM_ADDR_WIDTH = 9,
    parameter DEPTH           = 1 << BRAM_ADDR_WIDTH,
    parameter LFSR_WIDTH      = 32
)(
    input  wire                   clk,
    input  wire                   reset,
    input  wire                   link_active,

    input  wire                   STP_detected,
    input  wire                   END_detected,
    input  wire  [DATA_WIDTH-1:0] data_TL_in,
    input  wire            [15:0] sequence_number,
    input  wire            [31:0] lcrc,
    input  wire                   tlp_valid,

    input  wire            [11:0] NEXT_RCV_SEQ,

    output reg                    nak_scheduled,
    output reg             [11:0] nak_seq_num,
    output reg                    ack_scheduled,
    output reg             [11:0] ack_seq_num,
    output reg                    new_tlp_accepted,
    output reg   [DATA_WIDTH-1:0] rx_data_TL,
    output reg                    rx_tlp_valid,
    output reg                    rx_tlp_first,
    output reg                    rx_tlp_last
);

    // Buffer to store received TLP
    reg [DATA_WIDTH-1:0] rx_buffer [DEPTH-1:0];

    wire [DATA_WIDTH-1:0] data_TL;
    wire                  tlp_en;
    wire                  tlp_first;
    wire                  tlp_last;

    reg [BRAM_ADDR_WIDTH-1:0] write_ptr;
    reg [BRAM_ADDR_WIDTH-1:0] read_ptr;
    reg [BRAM_ADDR_WIDTH-1:0] word_cnt;
    reg [BRAM_ADDR_WIDTH-1:0] read_cnt;
    reg      [DATA_WIDTH-1:0] buffer_data;

    reg [2:0] state;

    localparam [2:0]    IDLE        = 3'b000,
                        STORE_TLP   = 3'b001,
                        DISCARD_TLP = 3'b010,
                        CHECK_CRC   = 3'b011,
                        PRE_WRITE   = 3'b100,
                        WRITE_START = 3'b101,
                        SEND_TLP    = 3'b110;


    // CRC also takes sequence number into account
    // Feed sequence number first
    wire [LFSR_WIDTH-1:0] crc_seq_0;
    wire [LFSR_WIDTH-1:0] crc_seq_1;
    wire crc_en = tlp_valid && (STP_detected || state == STORE_TLP); // enabled when sequence number and TLP available

    reg [LFSR_WIDTH-1:0] crc_state; // store current CRC state;
    reg [LFSR_WIDTH-1:0] lcrc_reg; // store received LCRC for comparison
    reg [11:0] sequence_number_reg; // store sequence number for comparison

    lcrc_byte seq_0 (
        .data_in (sequence_number[7:0]),
        .crc_en  (STP_detected && tlp_valid),
        .crcIn   (crc_state),
        .crcOut  (crc_seq_0)
    );

    lcrc_byte seq_1 (
        .data_in ({4'b0, sequence_number[11:8]}),
        .crc_en  (STP_detected && tlp_valid),
        .crcIn   (crc_seq_0),
        .crcOut  (crc_seq_1)
    );

    wire [LFSR_WIDTH-1:0] crc_tlp_in = STP_detected ? crc_seq_1 : crc_state; // crc after sequence number as crc_In for first tlp word
    wire [DATA_BYTES*LFSR_WIDTH-1:0] lfsr_in;
    wire [DATA_BYTES*LFSR_WIDTH-1:0] lfsr_out;

    assign lfsr_in = {lfsr_out[(DATA_BYTES-1)*LFSR_WIDTH-1:0], crc_tlp_in};

    wire [LFSR_WIDTH-1:0] crc_next = lfsr_out[DATA_BYTES*LFSR_WIDTH-1 -: LFSR_WIDTH];

    genvar i;
    generate
        for (i = 0; i < DATA_BYTES; i = i + 1) begin : crc_bytes
            lcrc_byte crc_b (
                .data_in (data_TL_in[i*8 +: 8]),
                .crc_en  (crc_en),
                .crcIn   (lfsr_in [i*LFSR_WIDTH +: LFSR_WIDTH]),
                .crcOut  (lfsr_out[i*LFSR_WIDTH +: LFSR_WIDTH])
            );
        end
    endgenerate

    // bit complemented and bit-reversed for each byte
    wire [LFSR_WIDTH-1:0] crc_computed;
    genvar l;
    generate
        for (l = 0; l < 8; l = l + 1) begin : compute_lcrc
            assign crc_computed[l] = ~crc_state[7-l];
            assign crc_computed[l+8] = ~crc_state[15-l];
            assign crc_computed[l+16] = ~crc_state[23-l];
            assign crc_computed[l+24] = ~crc_state[31-l];
        end
    endgenerate

    // Write port
    // When STP_detected is detected, data does not only contain sequence number, but also the first word of TLP
    always @(posedge clk) begin
        if ((STP_detected || state == STORE_TLP) && tlp_valid)
            rx_buffer[write_ptr] <= data_TL_in;
    end

    // Read port
    always @(posedge clk) begin
        buffer_data <= rx_buffer[read_ptr];
    end

    //assign data_TL   = (state == SEND_TLP || state == WRITE_START) ? buffer_data : {DATA_WIDTH{1'b0}};
    //assign tlp_en    = (state == SEND_TLP || state == WRITE_START) && (read_cnt < word_cnt);
    //assign tlp_first = (state == SEND_TLP || state == WRITE_START) && (read_cnt == 0);
    //assign tlp_last  = (state == SEND_TLP || state == WRITE_START) && (read_cnt == word_cnt - 1);

    assign data_TL   = (state == SEND_TLP) ? buffer_data : {DATA_WIDTH{1'b0}};
    assign tlp_en    = (state == SEND_TLP) && (read_cnt <= word_cnt);
    assign tlp_first = (state == SEND_TLP) && (read_cnt == 1);
    assign tlp_last  = (state == SEND_TLP) && (read_cnt == word_cnt);

    always @(posedge clk) begin
        if (reset) begin
            rx_data_TL   <= {DATA_WIDTH{1'b0}};
            rx_tlp_valid <= 1'b0;
            rx_tlp_first <= 1'b0;
            rx_tlp_last  <= 1'b0;
        end else begin
            rx_data_TL   <= data_TL;
            rx_tlp_valid <= tlp_en;
            rx_tlp_first <= tlp_first;
            rx_tlp_last  <= tlp_last;
        end
    end

    // FSM
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state               <= IDLE;
            write_ptr           <= 0;
            read_ptr            <= 0;
            read_cnt            <= 0;
            word_cnt            <= 0;
            crc_state           <= {LFSR_WIDTH{1'b1}};
            lcrc_reg            <= {LFSR_WIDTH{1'b0}};
            sequence_number_reg <= 12'b0;
            nak_scheduled       <= 1'b0;
            nak_seq_num         <= 12'b0;
            ack_scheduled       <= 1'b0;
            ack_seq_num         <= 12'b0;
            new_tlp_accepted    <= 1'b0;
        end else begin
            nak_scheduled       <= 1'b0;
            ack_scheduled       <= 1'b0;
            new_tlp_accepted    <= 1'b0;

            case (state)

                IDLE: begin
                    if (STP_detected && link_active) begin // only process TLP when link is active
                        // Check sequence number
                        if (sequence_number[11:0] == NEXT_RCV_SEQ) begin
                            write_ptr           <= 1; // first word has already been written in this cycle
                            word_cnt            <= 1;
                            sequence_number_reg <= sequence_number[11:0];
                            crc_state           <= crc_next;
                            state               <= STORE_TLP;
                        end else if ((NEXT_RCV_SEQ - sequence_number[11:0]) <= 12'd2048) begin
                            // (NEXT_RCV_SEQ - TLP Sequence Number) mod 4096 <= 2048, TLP is a duplicate, an ACK is scheduled.
                            ack_scheduled <= 1'b1;
                            ack_seq_num   <= NEXT_RCV_SEQ - 1'b1;
                            state         <= DISCARD_TLP;
                        end else begin
                            nak_scheduled <= 1'b1;
                            nak_seq_num   <= NEXT_RCV_SEQ;
                            state         <= DISCARD_TLP;
                        end
                    end
                end

                STORE_TLP: begin
                    if (STP_detected) begin // detect STP before END
                        nak_scheduled <= 1'b1;
                        //nak_seq_num <= sequence_number_reg;
                        nak_seq_num   <= NEXT_RCV_SEQ;
                        write_ptr     <= 0;
                        word_cnt      <= 0;
                        crc_state     <= {LFSR_WIDTH{1'b1}};
                        state         <= IDLE;
                    end else begin
                        if (tlp_valid) begin
                            write_ptr <= write_ptr + 1;
                            word_cnt  <= word_cnt + 1;
                            crc_state <= crc_next;
                        end
                        if (END_detected) begin
                            lcrc_reg <= lcrc;
                            state    <= CHECK_CRC;
                        end
                        // TODO: What if END has not been detected and buffer is full
                    end
                end

                DISCARD_TLP: begin
                    state <= IDLE;
                end

                CHECK_CRC: begin
                    if (crc_computed == lcrc_reg) begin
                        ack_scheduled    <= 1'b1; // TODO: issue ACK when AckNak_LATENCY_TIMER exceeds a default value
                        ack_seq_num      <= sequence_number_reg;
                        new_tlp_accepted <= 1'b1;
                        read_ptr         <= 0;
                        state            <= PRE_WRITE;
                    end else begin // crc wrong
                        nak_scheduled <= 1'b1;
                        //nak_seq_num <= sequence_number_reg;
                        nak_seq_num   <= NEXT_RCV_SEQ;
                        write_ptr     <= 0;
                        word_cnt      <= 0;
                        crc_state     <= {LFSR_WIDTH{1'b1}};
                        state         <= IDLE;
                    end
                end

                // buffer data 0 available here
                PRE_WRITE: begin
                    state <= WRITE_START;
                end

                WRITE_START: begin // TODO: Check timing here
                    read_ptr <= 1; // first word has already been read in this cycle
                    read_cnt <= 1;
                    state    <= SEND_TLP;
                end

                SEND_TLP: begin
                    if (read_cnt == word_cnt) begin
                        write_ptr <= 0;
                        word_cnt  <= 0;
                        crc_state <= {LFSR_WIDTH{1'b1}};
                        state     <= IDLE;
                    end else begin
                        read_ptr  <= read_ptr + 1;
                        read_cnt  <= read_cnt + 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
