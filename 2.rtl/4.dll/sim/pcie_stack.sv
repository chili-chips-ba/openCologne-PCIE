`timescale 1ns/100fs

module pcie_stack #(
   parameter DATA_BYTES    = 8,
   parameter DATA_WIDTH    = DATA_BYTES * 8,
   parameter PATTERN_WIDTH = 128
   )
   (
   input  logic                   clk_ref,
   input  logic                   clk_reg,
   input  logic                   clk_cfg,
   input  logic                   reset_n,

   output logic                   o_PCLK,
   output logic                   o_LinkUp,
   output logic             [4:0] o_ltssm_state,
   output logic                   o_serdes_ready,
   output logic                   o_RxValid,
   output logic  [DATA_BYTES-1:0] o_RxDataDispErr,
   output logic  [DATA_BYTES-1:0] o_RxDataDecErr,
   output logic                   o_tx_buf_err,

   input  logic  [DATA_WIDTH-1:0] tl_tx_data,
   input  logic                   tl_tx_tlp_valid,
   input  logic                   tl_tx_tlp_first,
   input  logic                   tl_tx_tlp_last,
   output logic                   tl_tx_tlp_ready,
   input  logic             [7:0] tl_tx_hdr_credit,
   input  logic            [11:0] tl_tx_data_credit,
   input  logic             [1:0] tl_tx_update_type,
   input  logic             [1:0] tl_tx_packet_type,
   input  logic                   tl_tx_dllp_valid,

   output logic  [DATA_WIDTH-1:0] tl_rx_data,
   output logic                   tl_rx_tlp_valid,
   output logic                   tl_rx_tlp_first,
   output logic                   tl_rx_tlp_last,
   output logic             [7:0] tl_rx_hdr_credit,
   output logic            [11:0] tl_rx_data_credit,
   output logic             [1:0] tl_rx_update_type,
   output logic             [1:0] tl_rx_packet_type,
   output logic                   tl_rx_dllp_valid,

   input  logic                   RX_SERIO_P,
   input  logic                   RX_SERIO_N,
   output logic                   TX_SERIO_P,
   output logic                   TX_SERIO_N
   );

   logic   [7:0] pipe_rst_cnt;
   logic        pipe_reset_n;
   assign pipe_reset_n = (pipe_rst_cnt == 8'hFF);

   always @(posedge clk_reg or negedge reset_n) begin
      if (!reset_n)
         pipe_rst_cnt <= 8'd0;
      else if (!pipe_reset_n)
         pipe_rst_cnt <= pipe_rst_cnt + 8'd1;
   end

   logic   [1:0] mac_rst_sync;
   logic        mac_reset_n;
   assign mac_reset_n = mac_rst_sync[1];

   always @(posedge o_PCLK or negedge o_serdes_ready) begin
      if (!o_serdes_ready)
         mac_rst_sync <= 2'b00;
      else
         mac_rst_sync <= {mac_rst_sync[0], 1'b1};
   end

   logic                  phy_rx_valid;
   logic                  phy_status;
   logic            [2:0] phy_rx_status;
   logic                  phy_rx_elec_idle;
   logic [DATA_WIDTH-1:0] phy_rx_data;
   logic [DATA_BYTES-1:0] phy_rx_datak;

   logic            [1:0] mac_power_down;
   logic                  mac_tx_detect_rx;
   logic                  mac_tx_elec_idle;
   logic [DATA_BYTES-1:0] mac_tx_compliance;
   logic                  mac_rx_polarity;
   logic [DATA_WIDTH-1:0] mac_tx_data;
   logic [DATA_BYTES-1:0] mac_tx_datak;
   logic [DATA_WIDTH-1:0] mac_rx_data;
   logic [DATA_BYTES-1:0] mac_rx_datak;

   logic [DATA_WIDTH-1:0] dll_tx_data;
   logic [DATA_BYTES-1:0] dll_tx_datak;

   assign o_RxValid     = phy_rx_valid;
   assign o_ltssm_state = mac.s_fsm_state;

   logic dll_linkup;
   assign dll_linkup = o_LinkUp && (o_ltssm_state == 5'b01010);

   dll_logic #(
      .DATA_BYTES                 ( DATA_BYTES ),
      .NUMBER_OF_VIRTUAL_CHANNELS ( 1          ),
      .PATTERN_WIDTH              ( 64         )
   ) dll (
      .phy_clk           ( o_PCLK            ),
      .phy_reset         ( !mac_reset_n      ),
      .phy_linkup        ( dll_linkup        ),
      .phy_rx_data       ( mac_rx_data       ),

      .tl_tx_data        ( tl_tx_data        ),
      .tl_tx_tlp_valid   ( tl_tx_tlp_valid   ),
      .tl_tx_tlp_first   ( tl_tx_tlp_first   ),
      .tl_tx_tlp_last    ( tl_tx_tlp_last    ),
      .tl_tx_tlp_ready   ( tl_tx_tlp_ready   ),

      .tl_tx_hdr_credit  ( tl_tx_hdr_credit  ),
      .tl_tx_data_credit ( tl_tx_data_credit ),
      .tl_tx_update_type ( tl_tx_update_type ),
      .tl_tx_packet_type ( tl_tx_packet_type ),
      .tl_tx_dllp_valid  ( tl_tx_dllp_valid  ),

      .phy_tx_data       ( dll_tx_data       ),
      .phy_tx_data_k     ( dll_tx_datak      ),

      .tl_rx_data        ( tl_rx_data        ),
      .tl_rx_tlp_valid   ( tl_rx_tlp_valid   ),
      .tl_rx_tlp_first   ( tl_rx_tlp_first   ),
      .tl_rx_tlp_last    ( tl_rx_tlp_last    ),

      .tl_rx_hdr_credit  ( tl_rx_hdr_credit  ),
      .tl_rx_data_credit ( tl_rx_data_credit ),
      .tl_rx_update_type ( tl_rx_update_type ),
      .tl_rx_packet_type ( tl_rx_packet_type ),
      .tl_rx_dllp_valid  ( tl_rx_dllp_valid  )
   );

   ccfpga_LTSSM_logic #(
      .DATA_BYTES     ( DATA_BYTES        ),
      .PATTERN_WIDTH  ( PATTERN_WIDTH     )
   ) mac (
      .i_Reset_n      ( mac_reset_n       ),
      .i_PCLK         ( o_PCLK            ),
      .i_RxValid      ( phy_rx_valid      ),
      .i_PhyStatus    ( phy_status        ),
      .i_RxStatus     ( phy_rx_status     ),
      .i_RxElecIdle   ( phy_rx_elec_idle  ),
      .i_RxData       ( phy_rx_data       ),
      .i_RxDataK      ( phy_rx_datak      ),
      .i_TxData       ( dll_tx_data       ),
      .i_TxDataK      ( dll_tx_datak      ),

      .o_PowerDown    ( mac_power_down    ),
      .o_TxDetectRx   ( mac_tx_detect_rx  ),
      .o_TxElecIdle   ( mac_tx_elec_idle  ),
      .o_TxCompliance ( mac_tx_compliance ),
      .o_RxPolarity   ( mac_rx_polarity   ),
      .o_TxData       ( mac_tx_data       ),
      .o_TxDataK      ( mac_tx_datak      ),
      .o_RxData       ( mac_rx_data       ),
      .o_RxDataK      ( mac_rx_datak      ),
      .o_LinkUp       ( o_LinkUp          )
   );

   phy_model #(
      .DATA_BYTES ( DATA_BYTES )
   ) phy (
      .clk_ref           ( clk_ref           ),
      .clk_reg           ( clk_reg           ),
      .clk_cfg           ( clk_cfg           ),
      .reset_n           ( reset_n           ),

      .o_PCLK            ( o_PCLK            ),
      .i_Reset           ( pipe_reset_n      ),
      .i_PowerDown       ( mac_power_down    ),
      .i_TxDetectRx      ( mac_tx_detect_rx  ),
      .i_TxElecIdle      ( mac_tx_elec_idle  ),
      .i_TxCompliance    ( mac_tx_compliance ),
      .i_RxPolarity      ( mac_rx_polarity   ),
      .i_TxData          ( mac_tx_data       ),
      .i_TxDataK         ( mac_tx_datak      ),

      .o_RxValid         ( phy_rx_valid      ),
      .o_PhyStatus       ( phy_status        ),
      .o_RxElecIdle      ( phy_rx_elec_idle  ),
      .o_RxStatus        ( phy_rx_status     ),
      .o_RxData          ( phy_rx_data       ),
      .o_RxDataK         ( phy_rx_datak      ),

      .o_fsm_state_pipe  (                   ),
      .o_fsm_state_align (                   ),
      .o_RxDataComma     (                   ),
      .o_RxDataDispErr   ( o_RxDataDispErr   ),
      .o_RxDataDecErr    ( o_RxDataDecErr    ),
      .o_tx_buf_err      ( o_tx_buf_err      ),
      .o_rx_buf_err      (                   ),
      .o_serdes_ready    ( o_serdes_ready    ),

      .RX_SERIO_P        ( RX_SERIO_P        ),
      .RX_SERIO_N        ( RX_SERIO_N        ),
      .TX_SERIO_P        ( TX_SERIO_P        ),
      .TX_SERIO_N        ( TX_SERIO_N        )
   );

endmodule
