module packet_handler #(
    parameter DATA_BYTES       = 8,
    parameter DATA_WIDTH       = DATA_BYTES * 8,
    parameter PATTERN_WIDTH    = 64
)(
    input wire                     clk,                         // Clock
    input wire                     reset,                       // Asynchronous reset
    input wire    [DATA_WIDTH-1:0] rx_data,                     // Received data bytes
    input wire                     END_lost,                    // Receive buffer is full but no END is detected

    output reg                     SDP_detected,                // SDP detected flag
    output reg                     STP_detected,                // STP detected flag
    output reg                     END_detected,                // END detected flag
    output reg [PATTERN_WIDTH-1:0] data_DLLP,                   // Extracted DLLP
    output reg    [DATA_WIDTH-1:0] data_TL,                     // Data forwarded to Transaction Layer
    output reg              [15:0] sequence_number,             // Sequence number
    output reg              [31:0] lcrc,                        // Extract LCRC when END symbol detected
    output reg                     tlp_valid,                   // TLP valid signal to Transaction Layer
    output reg                     tlp_half                     // Only the lower half of data_TL is TLP data (last word, 64-bit)
);

    // K characters
    localparam  SDP = 8'h5C;
    localparam  STP = 8'hFB;
    localparam _END = 8'hFD;
    localparam  EDB = 8'hFE;

    // SDP/STP can now start at any byte
    // Only support 32 and 64-bit data width
    localparam WIN_WORDS     = 2 + (7 + DATA_BYTES - 1) / DATA_BYTES; // WIN_WORDS = 2 + ceil(7 / DATA_BYTES)
    // STP on the last byte of the oldest word, then we need at least one word for payload
    // 7 = 2 byte sequence number + 4 byte LCRC + 1 byte END
    localparam WIN_BYTES     = WIN_WORDS * DATA_BYTES;
    localparam POS_WIDTH     = $clog2(WIN_BYTES) + 1;
    localparam MAX_TLP_WORDS = (4096 + 16 + 4 + DATA_BYTES - 1) / DATA_BYTES + 1;
    localparam HALF_WORDS    = (DATA_BYTES == 8); //  only possible for 64-bit data width

    // Shift registers to store received data, the oldest word is the base of the window
    reg [DATA_WIDTH - 1 : 0] rx_data_shift [WIN_WORDS - 1 : 0];
    integer i;

    always @ (posedge clk) begin
        rx_data_shift[0] <= rx_data;
        for ( i = 1; i < WIN_WORDS; i = i + 1 ) begin
            rx_data_shift[i] <= rx_data_shift[i - 1];
        end
    end

    wire [WIN_BYTES*8-1:0] win; // flatten out the received window

    genvar w;
    generate
        for ( w = 0; w < WIN_WORDS; w = w + 1 ) begin : window
            assign win[w*DATA_WIDTH +: DATA_WIDTH] = rx_data_shift[WIN_WORDS - 1 - w];
        end
    endgenerate

    reg                 in_tlp; // TLP detected, wait for END
    reg [POS_WIDTH-1:0] q; // window position
    reg [POS_WIDTH-1:0] ptr; // point to the first byte that is not consumed in the last packet detection ... where to start seaching
    reg          [12:0] word_cnt; // words of the current TLP

    // Lowest SDP/STP at or after ptr in the oldest word
    reg                 start_found;
    reg                 start_is_stp;
    reg [POS_WIDTH-1:0] start_pos;
    integer p;

    always @ (*) begin
        start_found  = 1'b0;
        start_is_stp = 1'b0;
        start_pos    = {POS_WIDTH{1'b0}};
        for ( p = DATA_BYTES - 1; p >= 0; p = p - 1 ) begin
            if ( p >= ptr && (win[8*p +: 8] == SDP || win[8*p +: 8] == STP) ) begin // Seach for the lowest SDP/STP at or after ptr in the oldest word
                start_found  = 1'b1;
                start_is_stp = (win[8*p +: 8] == STP);
                start_pos    = p;
            end
        end
    end

    wire [7:0] end_full = win[8*(q + DATA_BYTES + 4) +: 8]; // if the last word is full, END should be here
    wire [7:0] end_half = HALF_WORDS ? win[8*(q + 8) +: 8] : 8'h00; // if the last word is half, END should be here

    wire [31:0] lcrc_full = {win[8*(q + DATA_BYTES) +: 8], win[8*(q + DATA_BYTES + 1) +: 8],
                             win[8*(q + DATA_BYTES + 2) +: 8], win[8*(q + DATA_BYTES + 3) +: 8]}; // if the last word is full, LCRC should be here
    wire [31:0] lcrc_half = {win[8*(q + 4) +: 8], win[8*(q + 5) +: 8], win[8*(q + 6) +: 8], win[8*(q + 7) +: 8]}; // if the last word is half, LCRC should be here

    always @ (posedge clk or posedge reset) begin
        if ( reset ) begin
            SDP_detected      <= 1'b0;
            STP_detected      <= 1'b0;
            END_detected      <= 1'b0;
            data_DLLP         <= {PATTERN_WIDTH{1'b0}};
            data_TL           <= {DATA_WIDTH{1'b0}};
            tlp_valid         <= 1'b0;
            tlp_half          <= 1'b0;
            sequence_number   <= 16'b0;
            lcrc              <= 32'b0;
            in_tlp            <= 1'b0;
            q                 <= {POS_WIDTH{1'b0}};
            ptr               <= {POS_WIDTH{1'b0}};
            word_cnt          <= 13'd0;
        end else begin
            SDP_detected      <= 1'b0;
            STP_detected      <= 1'b0;
            END_detected      <= 1'b0;
            data_DLLP         <= {PATTERN_WIDTH{1'b0}};
            data_TL           <= {DATA_WIDTH{1'b0}};
            tlp_valid         <= 1'b0;
            tlp_half          <= 1'b0;
            sequence_number   <= 16'b0;
            lcrc              <= 32'b0;

            if ( in_tlp ) begin
                word_cnt <= word_cnt + 1'b1;
                if ( HALF_WORDS && end_half == _END ) begin // Half word TLP
                    END_detected <= 1'b1;
                    data_TL      <= {{(DATA_WIDTH/2){1'b0}}, win[8*q +: DATA_WIDTH/2]};
                    tlp_valid    <= 1'b1;
                    tlp_half     <= 1'b1;
                    lcrc         <= lcrc_half;
                    in_tlp       <= 1'b0;
                    ptr          <= q + 9 - DATA_BYTES; // = 4 byte LCRC + 1 byte END + 4 bytes of the last half word - DATA_BYTES
                end else if ( end_full == _END ) begin // Full word TLP
                    END_detected <= 1'b1;
                    data_TL      <= win[8*q +: DATA_WIDTH];
                    tlp_valid    <= 1'b1;
                    lcrc         <= lcrc_full;
                    in_tlp       <= 1'b0;
                    ptr          <= q + 5; // = 4 byte LCRC + 1 byte END + last word - DATA_BYTES
                end else if ( END_lost || word_cnt == MAX_TLP_WORDS ) begin // TLP is too long or END is lost
                    in_tlp       <= 1'b0;
                    ptr          <= {POS_WIDTH{1'b0}};
                end else begin // Extract normal payload
                    data_TL      <= win[8*q +: DATA_WIDTH];
                    tlp_valid    <= 1'b1;
                end
            end else if ( start_found && start_is_stp ) begin // TLP
                STP_detected    <= 1'b1;
                sequence_number <= {win[8*(start_pos + 1) +: 8], win[8*(start_pos + 2) +: 8]};
                data_TL         <= win[8*(start_pos + 3) +: DATA_WIDTH];
                tlp_valid       <= 1'b1;
                in_tlp          <= 1'b1;
                q               <= start_pos + 3;
                word_cnt        <= 13'd1;
            end else if ( start_found ) begin // DLLP
                SDP_detected    <= 1'b1;
                data_DLLP       <= win[8*start_pos +: PATTERN_WIDTH];
                ptr             <= start_pos + 8 - DATA_BYTES; // DLLP is always 8 bytes
            end else begin
                ptr             <= (ptr >= DATA_BYTES) ? ptr - DATA_BYTES : {POS_WIDTH{1'b0}}; // nothing
            end
        end
    end

endmodule
