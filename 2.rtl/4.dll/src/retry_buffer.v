module retry_buffer #(
    parameter DATA_BYTES      = 8,
    parameter DATA_WIDTH      = DATA_BYTES * 8,
    parameter BRAM_ADDR_WIDTH = 9,
    parameter DEPTH           = 1 << BRAM_ADDR_WIDTH,
    parameter LFSR_WIDTH      = 32
)(
    input  wire                   clk,
    input  wire                   reset,

    input  wire                   tlp_valid,
    input  wire                   tlp_first,
    input  wire                   tlp_last,
    input  wire  [DATA_WIDTH-1:0] tlp_in_data,

    input  wire            [11:0] current_seq_num, // Sequence number of the TLP being sent

    output wire                   empty,
    output wire                   full,

    input  wire                   release_flag,
    input  wire                   retransmit_flag,
    input  wire            [11:0] retransmit_seq_num, // not used

    input  wire                   tlp_sending,
    output reg                    tlp_scheduled,
    output wire  [DATA_WIDTH-1:0] tlp_out_data,
    output wire  [DATA_BYTES-1:0] tlp_out_data_k
);

    // K characters
    localparam  STP = 8'hFB;
    localparam _END = 8'hFD;

    reg [DATA_WIDTH-1:0] retry_buffer [DEPTH-1:0];

    reg [BRAM_ADDR_WIDTH-1:0] write_ptr;
    reg [BRAM_ADDR_WIDTH-1:0] read_ptr;
    reg [BRAM_ADDR_WIDTH-1:0] word_cnt;
    reg [BRAM_ADDR_WIDTH-1:0] read_cnt;

    reg [2:0] state;

    localparam [2:0]    IDLE        = 3'b000,
                        STORE_TLP   = 3'b001,
                        STORE_CRC   = 3'b010, // not used
                        PRE_WRITE   = 3'b011,
                        WRITE_START = 3'b100,
                        SEND_TLP    = 3'b101,
                        TLP_SENT    = 3'b110;

    assign empty = (state == IDLE);
    assign full  = (state != IDLE);

    assign tlp_out_data = ((state == WRITE_START) || (state == SEND_TLP))
                          ? retry_buffer[read_ptr] : {DATA_WIDTH{1'b0}};

    assign tlp_out_data_k = (state == WRITE_START)
                            ? {{(DATA_BYTES-1){1'b0}}, 1'b1} : (state == SEND_TLP && read_cnt == word_cnt - 1)
                            ? {1'b1, {(DATA_BYTES-1){1'b0}}} : {DATA_BYTES{1'b0}};

    // CRC also takes sequence number into account
    // Feed sequence number first
    wire [LFSR_WIDTH-1:0] crc_seq_0;
    wire [LFSR_WIDTH-1:0] crc_seq_1;
    wire crc_en = tlp_valid && ((state == IDLE && tlp_first) || state == STORE_TLP); // enabled when sequence number and TLP available

    reg [LFSR_WIDTH-1:0] crc_state; // store current CRC state
    reg [LFSR_WIDTH-1:0] lcrc_reg; // stored but not used

    lcrc_byte seq_0 (
        .data_in (current_seq_num[7:0]),
        .crc_en  ((state == IDLE && tlp_first) && tlp_valid),
        .crcIn   (crc_state),
        .crcOut  (crc_seq_0)
    );

    lcrc_byte seq_1 (
        .data_in ({4'b0, current_seq_num[11:8]}),
        .crc_en  ((state == IDLE && tlp_first) && tlp_valid),
        .crcIn   (crc_seq_0),
        .crcOut  (crc_seq_1)
    );

    wire [LFSR_WIDTH-1:0] crc_tlp_in = (state == IDLE && tlp_first) ? crc_seq_1 : crc_state; // crc after sequence number as crc_In for first tlp word
    wire [DATA_BYTES*LFSR_WIDTH-1:0] lfsr_in;
    wire [DATA_BYTES*LFSR_WIDTH-1:0] lfsr_out;

    assign lfsr_in = {lfsr_out[(DATA_BYTES-1)*LFSR_WIDTH-1:0], crc_tlp_in};

    wire [LFSR_WIDTH-1:0] crc_next = lfsr_out[DATA_BYTES*LFSR_WIDTH-1 -: LFSR_WIDTH];

    genvar i;
    generate
        for (i = 0; i < DATA_BYTES; i = i + 1) begin : crc_bytes
            lcrc_byte crc_b (
                .data_in (tlp_in_data[i*8 +: 8]),
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
            assign crc_computed[l]    = ~crc_state[7-l];
            assign crc_computed[l+8]  = ~crc_state[15-l];
            assign crc_computed[l+16] = ~crc_state[23-l];
            assign crc_computed[l+24] = ~crc_state[31-l];
        end
    endgenerate

    // Needed in case the first payload is also the last payload
    // We need crc output in the same cycle as the first payload
    wire [LFSR_WIDTH-1:0] crc_computed_next;
    genvar m;
    generate
        for (m = 0; m < 8; m = m + 1) begin : compute_lcrc_next
            assign crc_computed_next[m]    = ~crc_next[7-m];
            assign crc_computed_next[m+8]  = ~crc_next[15-m];
            assign crc_computed_next[m+16] = ~crc_next[23-m];
            assign crc_computed_next[m+24] = ~crc_next[31-m];
        end
    endgenerate

    // Write port
    generate
        if ( DATA_WIDTH == 64 ) begin : retry_buffer_64
            always @(posedge clk) begin
                if ((state == IDLE && tlp_first) && tlp_valid) begin
                    retry_buffer[0]                  <= {tlp_in_data[39:0], current_seq_num[7:0], {4'b0, current_seq_num[11:8]}, STP};
                    retry_buffer[1][23:0]            <= tlp_in_data[63:40];
                    if (tlp_last) begin
                        retry_buffer[1][55:24]       <= {crc_computed_next[7:0], crc_computed_next[15:8], crc_computed_next[23:16], crc_computed_next[31:24]};
                        retry_buffer[1][63:56]       <= _END;
                    end
                end else if ((state == STORE_TLP && tlp_last) && tlp_valid) begin
                    retry_buffer[write_ptr-1][63:24] <= tlp_in_data[39:0];
                    retry_buffer[write_ptr][23:0]    <= tlp_in_data[63:40];
                    retry_buffer[write_ptr][55:24]   <= {crc_computed_next[7:0], crc_computed_next[15:8], crc_computed_next[23:16], crc_computed_next[31:24]};
                    retry_buffer[write_ptr][63:56]   <= _END;
                end else if (state == STORE_TLP && tlp_valid) begin
                    retry_buffer[write_ptr-1][63:24] <= tlp_in_data[39:0];
                    retry_buffer[write_ptr][23:0]    <= tlp_in_data[63:40];
                end
            end
        end else if (DATA_WIDTH == 32) begin : retry_buffer_32
            always @(posedge clk) begin
                if ((state == IDLE && tlp_first) && tlp_valid) begin
                    retry_buffer[0]                  <= {tlp_in_data[7:0], current_seq_num[7:0], {4'b0, current_seq_num[11:8]}, STP};
                    retry_buffer[1][23:0]            <= tlp_in_data[31:8];
                    if (tlp_last) begin
                        retry_buffer[1][31:24]       <= crc_computed_next[31:24];
                        retry_buffer[2][31:0]        <= {_END, crc_computed_next[7:0], crc_computed_next[15:8], crc_computed_next[23:16]};
                    end
                end else if ((state == STORE_TLP && tlp_last) && tlp_valid) begin
                    retry_buffer[write_ptr-1][31:24] <= tlp_in_data[7:0];
                    retry_buffer[write_ptr][23:0]    <= tlp_in_data[31:8];
                    retry_buffer[write_ptr][31:24]   <= crc_computed_next[31:24];
                    retry_buffer[write_ptr+1][31:0]  <= {_END, crc_computed_next[7:0], crc_computed_next[15:8], crc_computed_next[23:16]};
                end else if (state == STORE_TLP && tlp_valid) begin
                    retry_buffer[write_ptr-1][31:24] <= tlp_in_data[7:0];
                    retry_buffer[write_ptr][23:0]    <= tlp_in_data[31:8];
                end
            end
        end
    endgenerate

    // FSM
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state         <= IDLE;
            write_ptr     <= 0;
            read_ptr      <= 0;
            read_cnt      <= 0;
            word_cnt      <= 0;
            tlp_scheduled <= 1'b0;
            lcrc_reg      <= {LFSR_WIDTH{1'b0}};
            crc_state     <= {LFSR_WIDTH{1'b1}};
        end else begin
            case (state)

                IDLE: begin
                    if (tlp_valid && tlp_first) begin
                        write_ptr <= 2;
                        crc_state <= crc_next;
                        if (tlp_last) begin // First is last
                            read_ptr <= 0;
                            state    <= PRE_WRITE;
                            word_cnt <= (DATA_WIDTH == 32) ? 3 : 2; // 32-bit datapath needs two extra words in total (one already added at the beginning)
                        end else begin
                            state    <= STORE_TLP;
                            word_cnt <= 2;
                        end
                    end
                end
                
                STORE_TLP: begin
                    if (tlp_valid) begin
                        write_ptr <= write_ptr + 1;
                        word_cnt  <= word_cnt + 1;
                        if (tlp_last) begin
                            read_ptr <= 0;
                            state    <= PRE_WRITE;
                            if (DATA_WIDTH == 32) // 32-bit datapath needs two extra words in total (one already added at the beginning)
                                word_cnt <= word_cnt + 1;

                            // Store LCRC
                            lcrc_reg <= crc_computed;
                        end
                        crc_state <= crc_next;
                    end
                end

                PRE_WRITE: begin
                    state <= WRITE_START;
                end

                WRITE_START: begin
                    tlp_scheduled <= 1'b1;

                    // Release the packet
                    if (release_flag) begin
                        tlp_scheduled <= 1'b0;
                        write_ptr     <= 0;
                        word_cnt      <= 0;
                        crc_state     <= {LFSR_WIDTH{1'b1}};
                        state         <= IDLE;
                    // We want to wait for the TLP to be allowed to be sent before moving to next state
                    end else if (tlp_sending) begin
                        read_ptr      <= 1;
                        read_cnt      <= 1;
                        if (word_cnt == 1) begin
                            tlp_scheduled <= 1'b0;
                            state         <= TLP_SENT;
                        end else begin
                            state         <= SEND_TLP;
                        end
                    end
                end

                SEND_TLP: begin
                    if (read_cnt == word_cnt - 1) begin
                        tlp_scheduled <= 1'b0;
                        read_cnt      <= 0;
                        state         <= TLP_SENT;
                    end else begin
                        read_ptr     <= read_ptr + 1;
                        read_cnt     <= read_cnt + 1;
                    end
                end

                TLP_SENT: begin
                    tlp_scheduled <= 1'b0;

                    // Release the packet
                    // Buffer is then empty
                    if (release_flag) begin
                        write_ptr <= 0;
                        word_cnt  <= 0;
                        crc_state <= {LFSR_WIDTH{1'b1}};
                        state     <= IDLE;
                    // Retransmit the packet
                    // TODO: Add a counter for the retransmission
                    end else if (retransmit_flag) begin
                        read_ptr  <= 0;
                        state     <= PRE_WRITE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
