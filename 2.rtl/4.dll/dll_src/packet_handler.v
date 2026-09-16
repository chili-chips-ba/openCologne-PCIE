module packet_handler #(
    parameter DATA_BYTES       = 8,
    parameter DATA_WIDTH       = DATA_BYTES * 8,
    parameter PATTERN_WIDTH    = 64,
    parameter NUMBER_OF_STEPS  = PATTERN_WIDTH / DATA_WIDTH
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
    output reg                     tlp_valid                    // TLP valid signal to Transaction Layer
);

    // K characters
    localparam  SDP = 8'h5C;
    localparam  STP = 8'hFB;
    localparam _END = 8'hFD;
    localparam  EDB = 8'hFE;

    // Shift registers to store received data for Ordered Set assembly
    reg [DATA_WIDTH - 1 : 0] rx_data_shift [NUMBER_OF_STEPS : 0];
    integer i;

    always @ (posedge clk) begin
        rx_data_shift[0] <= rx_data;
        for ( i = 1; i < NUMBER_OF_STEPS + 1; i = i + 1 ) begin
            rx_data_shift[i] <= rx_data_shift[i - 1];
        end
    end

    // STP and SDP is aligned to the first or the fifth byte of the data word for 64-bit data width
    // and the first byte for narrower data widths
    reg TLP_detected;
    generate
        if ( DATA_WIDTH == 64 ) begin
            reg K_POS; // 0 for byte 0, 1 for byte 4
            always @ (posedge clk or posedge reset) begin
                SDP_detected      <= 1'b0;
                STP_detected      <= 1'b0;
                END_detected      <= 1'b0;
                data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                data_TL           <= {DATA_WIDTH{1'b0}};
                tlp_valid         <= 1'b0;
                sequence_number   <= 16'b0;
                lcrc              <= 32'b0;

                if ( reset ) begin
                    SDP_detected      <= 1'b0;
                    STP_detected      <= 1'b0;
                    END_detected      <= 1'b0;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                    data_TL           <= {DATA_WIDTH{1'b0}};
                    tlp_valid         <= 1'b0;
                    sequence_number   <= 16'b0;
                    lcrc              <= 32'b0;
                    K_POS             <= 1'b0;
                    TLP_detected      <= 1'b0;
                end else if (rx_data_shift[NUMBER_OF_STEPS][7:0] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[63:0]   <= rx_data_shift[NUMBER_OF_STEPS];
                    K_POS             <= 1'b0;
                end else if (rx_data_shift[NUMBER_OF_STEPS][39:32] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[31:0]   <= rx_data_shift[NUMBER_OF_STEPS][63:32];
                    data_DLLP[63:32]  <= rx_data_shift[NUMBER_OF_STEPS - 1][31:0];
                    K_POS             <= 1'b1;
                end else if (rx_data_shift[NUMBER_OF_STEPS][7:0] == STP ) begin
                    STP_detected      <= 1'b1;
                    data_TL           <= {rx_data_shift[NUMBER_OF_STEPS-1][23:0], rx_data_shift[NUMBER_OF_STEPS][63:24]};
                    tlp_valid         <= 1'b1;
                    sequence_number   <= {rx_data_shift[NUMBER_OF_STEPS][15:8], rx_data_shift[NUMBER_OF_STEPS][23:16]};
                    K_POS             <= 1'b0;
                    TLP_detected      <= 1'b1;
                end else if (rx_data_shift[NUMBER_OF_STEPS][39:32] == STP ) begin
                    STP_detected      <= 1'b1;
                    data_TL           <= {rx_data_shift[NUMBER_OF_STEPS-1][55:0], rx_data_shift[NUMBER_OF_STEPS][63:56]};
                    tlp_valid         <= 1'b1;
                    sequence_number   <= {rx_data_shift[NUMBER_OF_STEPS][47:40], rx_data_shift[NUMBER_OF_STEPS][55:48]};
                    K_POS             <= 1'b1;
                    TLP_detected      <= 1'b1;
                end else if (rx_data_shift[NUMBER_OF_STEPS-1][31:24] == _END ) begin
                    END_detected      <= 1'b1;
                    if (K_POS == 1'b0) begin
                        data_TL           <= {{(DATA_WIDTH/2){1'b0}}, rx_data_shift[NUMBER_OF_STEPS][55:24]};
                        tlp_valid         <= 1'b1;
                    end else begin
                        data_TL           <= {DATA_WIDTH{1'b0}};
                        tlp_valid         <= 1'b0;
                    end
                    lcrc              <= {rx_data_shift[NUMBER_OF_STEPS][63:56], rx_data_shift[NUMBER_OF_STEPS-1][7:0], rx_data_shift[NUMBER_OF_STEPS-1][15:8], rx_data_shift[NUMBER_OF_STEPS-1][23:16]};
                    K_POS             <= 1'b0;
                    TLP_detected      <= 1'b0;
                end else if (rx_data_shift[NUMBER_OF_STEPS-1][63:56] == _END ) begin
                    SDP_detected      <= 1'b0;
                    STP_detected      <= 1'b0;
                    END_detected      <= 1'b1;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                    if (K_POS == 1'b1) begin
                        data_TL           <= {{(DATA_WIDTH/2){1'b0}}, rx_data_shift[NUMBER_OF_STEPS-1][23:0], rx_data_shift[NUMBER_OF_STEPS][63:56]};
                        tlp_valid         <= 1'b1;
                    end else begin
                        data_TL           <= {rx_data_shift[NUMBER_OF_STEPS-1][23:0], rx_data_shift[NUMBER_OF_STEPS][63:24]};
                        tlp_valid         <= 1'b1;
                    end
                    lcrc              <= {rx_data_shift[NUMBER_OF_STEPS-1][31:24], rx_data_shift[NUMBER_OF_STEPS-1][39:32], rx_data_shift[NUMBER_OF_STEPS-1][47:40], rx_data_shift[NUMBER_OF_STEPS-1][55:48]};
                    K_POS             <= 1'b0;
                    TLP_detected      <= 1'b0;
                end else if (TLP_detected) begin
                    SDP_detected      <= 1'b0;
                    STP_detected      <= 1'b0;
                    END_detected      <= 1'b0;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                    if (K_POS == 1'b0) begin
                        data_TL           <= {rx_data_shift[NUMBER_OF_STEPS-1][23:0], rx_data_shift[NUMBER_OF_STEPS][63:24]};
                    end else begin
                        data_TL           <= {rx_data_shift[NUMBER_OF_STEPS-1][55:0], rx_data_shift[NUMBER_OF_STEPS][63:56]};
                    end
                    tlp_valid         <= 1'b1;
                    sequence_number   <= 16'b0;
                    lcrc              <= 32'b0;
                end else if (END_lost) begin
                    TLP_detected      <= 1'b0;
                end
            end
        end else if ( DATA_WIDTH == 32 ) begin
            always @ (posedge clk or posedge reset) begin
                SDP_detected      <= 1'b0;
                STP_detected      <= 1'b0;
                END_detected      <= 1'b0;
                data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                data_TL           <= {DATA_WIDTH{1'b0}};
                tlp_valid         <= 1'b0;
                sequence_number   <= 16'b0;
                lcrc              <= 32'b0;

                if ( reset ) begin
                    SDP_detected      <= 1'b0;
                    STP_detected      <= 1'b0;
                    END_detected      <= 1'b0;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                    data_TL           <= {DATA_WIDTH{1'b0}};
                    tlp_valid         <= 1'b0;
                    sequence_number   <= 16'b0;
                    lcrc              <= 32'b0;
                    TLP_detected      <= 1'b0;
                end else if ( rx_data_shift[NUMBER_OF_STEPS][7:0] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[31:0]   <= rx_data_shift[NUMBER_OF_STEPS];
                    data_DLLP[63:32]  <= rx_data_shift[NUMBER_OF_STEPS - 1];
                end else if (rx_data_shift[NUMBER_OF_STEPS][7:0] == STP ) begin
                    STP_detected      <= 1'b1;
                    data_TL           <= {rx_data_shift[NUMBER_OF_STEPS-1][23:0], rx_data_shift[NUMBER_OF_STEPS][31:24]};
                    tlp_valid         <= 1'b1;
                    sequence_number   <= {rx_data_shift[NUMBER_OF_STEPS][15:8], rx_data_shift[NUMBER_OF_STEPS][23:16]};
                    TLP_detected      <= 1'b1;
                end else if (rx_data_shift[NUMBER_OF_STEPS-1][31:24] == _END ) begin
                    END_detected      <= 1'b1;
                    lcrc              <= {rx_data_shift[NUMBER_OF_STEPS-1][23:0], rx_data_shift[NUMBER_OF_STEPS][31:24]};
                    TLP_detected      <= 1'b0;
                end else if (TLP_detected) begin
                    data_TL           <= {rx_data_shift[NUMBER_OF_STEPS-1][23:0], rx_data_shift[NUMBER_OF_STEPS][31:24]};
                    tlp_valid         <= 1'b1;
                end else if (END_lost) begin
                    TLP_detected      <= 1'b0;
                end
            end
        end/* else if ( DATA_WIDTH == 16 ) begin
            always @ (posedge clk or posedge reset) begin
                if ( reset ) begin
                    SDP_detected      <= 1'b0;
                    STP_detected      <= 1'b0;
                    END_detected      <= 1'b0;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                    data_TL           <= {DATA_WIDTH{1'b0}};
                    tlp_valid         <= 1'b0;
                    sequence_number   <= 16'b0;
                    lcrc              <= 32'b0;
                    TLP_detected      <= 1'b0;
                end else if ( rx_data_shift[NUMBER_OF_STEPS][7:0] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    STP_detected      <= 1'b0;
                    END_detected      <= 1'b0;
                    data_DLLP[15:0]   <= rx_data_shift[NUMBER_OF_STEPS];
                    data_DLLP[31:16]  <= rx_data_shift[NUMBER_OF_STEPS - 1];
                    data_DLLP[47:32]  <= rx_data_shift[NUMBER_OF_STEPS - 2];
                    data_DLLP[63:48]  <= rx_data_shift[NUMBER_OF_STEPS - 3];
                    data_TL           <= {DATA_WIDTH{1'b0}};
                    tlp_valid         <= 1'b0;
                    sequence_number   <= 16'b0;
                    lcrc              <= 32'b0;
                    TLP_detected      <= 1'b0;
                end else if (rx_data_shift[NUMBER_OF_STEPS][7:0] == STP ) begin
                    SDP_detected      <= 1'b0;
                    STP_detected      <= 1'b1;
                    END_detected      <= 1'b0;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                    data_TL           <= {rx_data_shift[NUMBER_OF_STEPS-2][7:0], rx_data_shift[NUMBER_OF_STEPS-1][15:8]};
                    tlp_valid         <= 1'b1;
                    sequence_number   <= {rx_data_shift[NUMBER_OF_STEPS-1][7:0], rx_data_shift[NUMBER_OF_STEPS][15:8]};
                    lcrc              <= 32'b0;
                    TLP_detected      <= 1'b0;
                end else if (rx_data_shift[NUMBER_OF_STEPS-2][15:8] == _END ) begin
                    SDP_detected      <= 1'b0;
                    STP_detected      <= 1'b0;
                    END_detected      <= 1'b1;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                    data_TL           <= {DATA_WIDTH{1'b0}};
                    tlp_valid         <= 1'b0;
                    sequence_number   <= 16'b0;
                    lcrc              <= {rx_data_shift[NUMBER_OF_STEPS-1][7:0], rx_data_shift[NUMBER_OF_STEPS][15:8], rx_data_shift[NUMBER_OF_STEPS][7:0], rx_data_shift[NUMBER_OF_STEPS-1][15:8]};
                    TLP_detected      <= 1'b0;
                end else if (TLP_detected) begin
                    SDP_detected      <= 1'b0;
                    STP_detected      <= 1'b0;
                    END_detected      <= 1'b0;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                    data_TL           <= {rx_data_shift[NUMBER_OF_STEPS-2][7:0], rx_data_shift[NUMBER_OF_STEPS-1][15:8]};
                    tlp_valid         <= 1'b1;
                    sequence_number   <= 16'b0;
                    lcrc              <= 32'b0;
                    TLP_detected      <= TLP_detected;
                end else begin
                    SDP_detected      <= 1'b0;
                    STP_detected      <= 1'b0;
                    END_detected      <= 1'b0;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                    data_TL           <= {DATA_WIDTH{1'b0}};
                    tlp_valid         <= 1'b0;
                    sequence_number   <= 16'b0;
                    lcrc              <= 32'b0;
                    TLP_detected      <= 1'b0;
                end
            end
        end else begin // 8-Bit data width
            always @ (posedge clk or posedge reset) begin
                if ( reset ) begin
                    SDP_detected      <= 1'b0;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                end else if ( rx_data_shift[NUMBER_OF_STEPS][7:0] == SDP ) begin
                    SDP_detected      <= 1'b1;
                    data_DLLP[7:0]    <= rx_data_shift[NUMBER_OF_STEPS];
                    data_DLLP[15:8]   <= rx_data_shift[NUMBER_OF_STEPS - 1];
                    data_DLLP[23:16]  <= rx_data_shift[NUMBER_OF_STEPS - 2];
                    data_DLLP[31:24]  <= rx_data_shift[NUMBER_OF_STEPS - 3];
                    data_DLLP[39:32]  <= rx_data_shift[NUMBER_OF_STEPS - 4];
                    data_DLLP[47:40]  <= rx_data_shift[NUMBER_OF_STEPS - 5];
                    data_DLLP[55:48]  <= rx_data_shift[NUMBER_OF_STEPS - 6];
                    data_DLLP[63:56]  <= rx_data_shift[NUMBER_OF_STEPS - 7];
                end else begin
                    SDP_detected      <= 1'b0;
                    data_DLLP         <= {PATTERN_WIDTH{1'b0}};
                end
            end
        end*/
    endgenerate

endmodule