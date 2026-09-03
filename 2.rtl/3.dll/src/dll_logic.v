module dll_logic #
(
    parameter DATA_BYTES = 8,
    parameter DATA_WIDTH = DATA_BYTES * 8,
    parameter NUMBER_OF_VIRTUAL_CHANNELS = 1,
    parameter PATTERN_WIDTH = 64
)
(
    input  wire                         phy_clk, // Clock from Physical layer
    input  wire                         phy_reset, // Async reset from Physical layer
    input  wire                         phy_linkup, // Link up flag from Physical layer

    input  wire        [DATA_WIDTH-1:0] phy_rx_data, // Received data extracted in physical layer
    //input  wire        [DATA_BYTES-1:0] phy_rx_data_k, // Received data control flags

    input  wire        [DATA_WIDTH-1:0] tl_tx_data, // Transmitted packet from TL
    //input  wire        [DATA_BYTES-1:0] tl_tx_data_k, // Transmitted packet from TL
    input  wire                         tl_tx_tlp_valid, // TLP TX valid flag
    input  wire                         tl_tx_tlp_first, // TLP TX first batch flag
    input  wire                         tl_tx_tlp_last, // TLP TX last batch flag
    output wire                         tl_tx_tlp_ready, // Retry buffer is empty/full

    input  wire                   [7:0] tl_tx_hdr_credit, // Transmitted DLLP header credit
    input  wire                  [11:0] tl_tx_data_credit, // Transmitted DLLP data credit
    input  wire                   [1:0] tl_tx_update_type, // Transmitted DLLP update type
    input  wire                   [1:0] tl_tx_packet_type, // Transmitted DLLP packet type
    input  wire                         tl_tx_dllp_valid, // DLLP TX valid flag

    output wire        [DATA_WIDTH-1:0] phy_tx_data, // Transmitted data forwarded to physical layer
    output wire        [DATA_BYTES-1:0] phy_tx_data_k, // Transmitted data control flags

    output wire        [DATA_WIDTH-1:0] tl_rx_data, // Received TLP
    //output wire        [DATA_BYTES-1:0] tl_rx_data_k, //Received TLP
    output wire                         tl_rx_tlp_valid, // TLP RX valid flag
    output wire                         tl_rx_tlp_first, // TLP RX first batch flag
    output wire                         tl_rx_tlp_last, // TLP RX last batch flag

    output wire                   [7:0] tl_rx_hdr_credit, // Received header credit
    output wire                  [11:0] tl_rx_data_credit, // Received data credit
    output wire                   [1:0] tl_rx_update_type, // Received update type
    output wire                   [1:0] tl_rx_packet_type, // Received packet type
    output wire                         tl_rx_dllp_valid // DLLP RX valid flag
);

    generate
        genvar i;
        for ( i = 0; i < NUMBER_OF_VIRTUAL_CHANNELS; i = i + 1 ) begin
            virtual_channel #(
                .DATA_BYTES(DATA_BYTES),
                .PATTERN_WIDTH(PATTERN_WIDTH)
            ) vc_inst (
                .clk(phy_clk),
                .reset(phy_reset),
                .linkup(phy_linkup),
                .virtual_channel_number(i[2:0]),

                .tx_hdr_credit(tl_tx_hdr_credit),
                .tx_data_credit(tl_tx_data_credit),
                .tx_update_type(tl_tx_update_type),
                .tx_packet_type(tl_tx_packet_type),
                .tx_dllp_valid(tl_tx_dllp_valid),

                .rx_data(phy_rx_data),
                //.rx_data_k(phy_rx_data_k),

                .tx_tlp_data(tl_tx_data),
                //.tx_data_TL_k(tl_tx_data_k),
                .tx_tlp_valid(tl_tx_tlp_valid),
                .tx_tlp_first(tl_tx_tlp_first),
                .tx_tlp_last(tl_tx_tlp_last),
                .tx_tlp_ready(tl_tx_tlp_ready),

                .tx_data(phy_tx_data),
                .tx_data_k(phy_tx_data_k),

                .rx_hdr_credit(tl_rx_hdr_credit),
                .rx_data_credit(tl_rx_data_credit),
                .rx_update_type(tl_rx_update_type),
                .rx_packet_type(tl_rx_packet_type),
                .rx_dllp_valid(tl_rx_dllp_valid),

                .rx_tlp_data(tl_rx_data),
                //.rx_data_TL_k(tl_rx_data_k),
                .rx_tlp_valid(tl_rx_tlp_valid),
                .rx_tlp_first(tl_rx_tlp_first),
                .rx_tlp_last(tl_rx_tlp_last)
            );
        end
    endgenerate

    // TODO: Add arbiter logic for multiple virtual channels

endmodule
