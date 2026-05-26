////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Interessengruppe fuer Mikroelektronik und Eingebettete Systeme (IMES)
// Fachhochschule Dortmund
//
// Development in cooperation with Cologne Chip AG
//
// Filename     : ccfpga_pipe_logic.v
// Author       : Philipp Leduc
// Tool         :
// Description  : PIPE Interface Logic for SerDes Block of Gatemate FPGA.
// Commentary   : Development according to PIPE Specification Version 2.0 by Intel.
//                DATA_BYTES has to match 1 (8-Bit), 2 (16-Bit) 4 (32-Bit) or 8 (64-Bit).
//                Use of the PIPE Interface requires specific Config-Fields to be set (see Doc).
//                Tx Compliance:
//                The use of the Tx Comliance Port differs from the description in the intel spec.
//                Port width is equal to number of bytes, which can be set individually. In case of
//                16-Bit PIPE Interface the Tx Compliance port has a width of 2-Bit. The upper Bit
//                can be tied to Zero and the lower Bit can be used as stated in the intel spec.
//
// Abreviations : [i_] > input (port)
//                [o_] > output (port)
//                [s_] > signal
//                [_n] > low active
//
// Changelog:
// -------------------------------------------------------------------------------------------------
// Version | Author             | Date       | Changes
// -------------------------------------------------------------------------------------------------
// 1.0     | Leduc              | 05.06.2021 | released
// -------------------------------------------------------------------------------------------------
// 1.1     | Leduc              | 12.07.2021 | Connected PIPE FSM to Core Clock.
// -------------------------------------------------------------------------------------------------
////////////////////////////////////////////////////////////////////////////////////////////////////

//`resetall
`timescale 1ns/10ps
//`default_nettype none

module ccfpga_pipe_logic #(
   parameter  DATA_BYTES = 8,                   // Width of PIPE Datapath in Bytes
   parameter  DATA_WIDTH = DATA_BYTES*8         // Do not set independet from Bytes
   )
   (
   // -------------- PIPE INTERFACE PORTS -----------------
   // External
   output wire                  o_PCLK,         // PCLK (user side)
   output wire                  o_tx_clk,       // Tx Clock (user side)

   // Command
   input  wire                  i_Reset,        // Async. Reset for Transceiver (Tx/Rx)
   input  wire           [ 1:0] i_PowerDown,    // Power States (P0 - P2)
   input  wire                  i_TxDetectRx,   // Receiver Detection (P0) or Loopback (P1)
   input  wire                  i_TxElecIdle,   // Tx Electrical Idle, Valid Data (P0) or Beacon (P2)
   input  wire [DATA_BYTES-1:0] i_TxCompliance, // Tx negative Disparity LSB (Compliance Pattern)
   //input  wire                  i_TxSwing,    // Tx Voltage Swing Level [Optional by Spec]
   input  wire                  i_RxPolarity,   // Rx Polarity Inversion

   // Status
   output wire                  o_RxValid,      // Symbol Lock and Valid Data on RxData and RxDataK
   output wire                  o_PhyStatus,    // Status of several PHY functions (Transition)
   output wire                  o_RxElecIdle,   // Rx Detection of Electrical Idle
   output wire           [ 2:0] o_RxStatus,     // Receiver Status and Received Data Status

   // Transmit Data
   input  wire [DATA_WIDTH-1:0] i_TxData,       // Tx Data
   input  wire [DATA_BYTES-1:0] i_TxDataK,      // Tx K Data

   // Receive Data
   output wire [DATA_WIDTH-1:0] o_RxData,       // Rx Data
   output wire [DATA_BYTES-1:0] o_RxDataK,      // Rx K Data

   // -------------- CSS INTERFACE PORTS ------------------

   output wire                  o_tx_buf_err,       // Tx Buffer Error
   output wire                  o_clk_core_rx_rec,  // Rx Recovered Clock
   input  wire                  i_rx_buf_reset,     // Rx Buffer Reset
   output wire                  o_rx_buf_err,       // Rx Buffer Error
   output wire            [3:0] o_fsm_state_pipe,   // State of PIPE FSM
   output wire            [1:0] o_fsm_state_align,  // State of Align FSM

   output wire [DATA_BYTES-1:0] o_RxDataComma,        // Rx Byte Comma Indication
   output wire [DATA_BYTES-1:0] o_RxDataDispErr,      // Rx Byte Disparity Error Indication
   output wire [DATA_BYTES-1:0] o_RxDataDecErr,       // Rx Byte Decode Error Indication
   //output wire                  o_TxIdleEntry,        // Tx Electrical Idle Counter Flag

   // -------------- CCAG SERDES PORTS --------------------
   // info: port directions seen from PIPE interface side

   // Clock
   input  wire                  i_clk_core_pll,       // ADPLL
   input  wire                  i_clk_core_rx_rec,    // Recovered Clock from Rx
   output wire                  o_clk_core_tx,        // Transmitter (Tx)
   output wire                  o_clk_core_rx,        // Receiver (Rx)

   // Reset
   output wire                  o_pll_reset,          // ADPLL
   output wire                  o_tx_reset,           // Tx Reset
   input  wire                  i_tx_reset_done,      // Tx Reset Status
   output wire                  o_rx_reset,           // Rx Reset
   input  wire                  i_rx_reset_done,      // Rx Reset Status

   output wire                  o_tx_pcs_reset,       // Tx PCS Reset
   output wire                  o_tx_pma_reset,       // Tx PMA Reset

   output wire                  o_rx_pcs_reset,       // Rx PCS Reset
   output wire                  o_rx_pma_reset,       // Rx PMA Reset
   output wire                  o_rx_cdr_reset,       // Rx CDR Reset
   output wire                  o_rx_eqa_reset,       // Rx DFE Reset

   // Power Control
   output wire                  o_tx_powerdown_n,     // Tx Power Control
   output wire                  o_rx_powerdown_n,     // Rx Power Control

   // Loopback and PRBS
   output wire            [2:0] o_loopback,           // Loopback Control
   output wire            [2:0] o_rx_prbs_sel,        // Rx PRBS Checker Mode
   output wire                  o_rx_prbs_cnt_reset,  // Rx PRBS Error Counter Reset
   output wire            [2:0] o_tx_prbs_sel,        // Tx PRBS Generator Mode
   output wire                  o_tx_prbs_force_err,  // Tx PRBS Error Injection

   // Buffer
   output wire                  o_rx_buf_reset,       // Rx Buffer Reset
   input  wire                  i_rx_buf_err,         // Rx Buffer Error (Over- or Underflow)
   input  wire                  i_tx_buf_err,         // Tx Buffer Error (Over- or Underflow)

   // Tx-Datapath
   output wire           [63:0] o_tx_data,            // Tx Data
   output wire           [ 7:0] o_tx_char_is_k,       // Tx K-Data
   output wire           [ 7:0] o_tx_char_dispmode,   // Tx Disparity Enable
   output wire           [ 7:0] o_tx_char_dispval,    // Tx Disparity Values (0:neg, 1:pos)
   output wire                  o_tx_8b10b_en,        // Tx 8b/10b Decoder Enable
   output wire           [ 7:0] o_tx_8b10b_bypass,    // Tx 8b/10b Decoder Bypass per Bit

   output wire                  o_tx_polarity,        // Tx Polarity Control

   output wire                  o_tx_elec_idle,       // Tx Electrical Idle Control

   output wire                  o_tx_detect_rx,       // Tx Receiver Detection Control
   input  wire                  i_rx_detect_done,     // Tx Receiver Detection Status
   input  wire                  i_rx_present,         // Tx Receiver Detection Response (1: Present)

   // Rx-Datapath
   input  wire           [63:0] i_rx_data,            // Rx Data
   input  wire           [ 7:0] i_rx_char_is_k,       // Rx K Data
   input  wire           [ 7:0] i_rx_char_is_comma,   // Rx COM Data
   input  wire           [ 7:0] i_rx_disp_err,        // Rx Disparity Error
   input  wire           [ 7:0] i_rx_not_in_table,    // Rx Decoding Error
   output wire                  o_rx_8b10b_en,        // Rx 8b/10b Decoder Enable
   output wire           [ 7:0] o_rx_8b10b_bypass,    // Rx 8b/10b Decoder Bypass per Bit

   input  wire                  i_rx_byte_is_aligned, // Rx Byte Alignment Status (Not used atm.)
   input  wire                  i_rx_byte_realign,    // Rx Byte Realignment Status
   output wire                  o_rx_mcomma_align,    // Rx Byte Alignment Control COM (neg. CRD)
   output wire                  o_rx_pcomma_align,    // Rx Byte Alignment Control COM (pos. CRD)
   output wire                  o_rx_comma_detect_en, // Rx Byte Alignment Enable
   output wire                  o_rx_slide,           // Rx Manual Comma Slide

   output wire                  o_rx_polarity,        // Rx Polarity Control

   output wire                  o_rx_en_ei_detector,  // Rx Electrical Idle Detection Enable
   input  wire                  i_rx_ei_en            // Rx Electrical Idle Detection Response
   );

   wire                  s_reset;
   wire                  s_clk;
   wire                  s_tx_clk;
   wire                  s_sel_rx_status;  // Mux Select Signal for RxStatus
   wire            [2:0] s_rx_status_dp;   // RxStatus Signal from Rx Datapath
   wire            [2:0] s_rx_status_fsm;  // RxStatus Signal from FSM (Rx Detection)
   wire                  s_loopback_fsm;
   wire                  s_rx_val_from_fsm;
   wire                  s_tx_idle_flag;

   // Parameters for Word Alignment Counter

   localparam CNT_BITWIDTH =  (DATA_BYTES == 2) ? 32'd6  : 32'd4;
   localparam CNT_NUMBER   =  (DATA_BYTES == 2) ? 32'd38 : 32'd7;

   // Parameters for Tx Idle Counter

   localparam CNT_BITWIDTH_TX =  (DATA_BYTES == 2) ? 32'd4 : 32'd3;
   localparam CNT_NUMBER_TX   =  (DATA_BYTES == 2) ? 32'd9 : 32'd2;

   // Parameters for PLL

   localparam       PLL_MUL                  =  (DATA_BYTES == 1) ? 32'd8 : (DATA_BYTES == 2) ? 32'd4 : (DATA_BYTES == 4) ? 32'd2 : 32'd1;
   //localparam       DIVIDER                  =  (DATA_BYTES == 8) ? 32'd2 : 32'd1;
   localparam       DIVIDER                  =  32'd2;
   localparam       DATAPATH_WIDTH           =  32'd80;
   
   parameter  [5:0] PLL_FCNTRL               = 58;                      // (Default = 58 = T:20d)
   parameter  [5:0] PLL_MAIN_DIVSEL          = {1'b0,2'b11,1'b0,2'b11}; // (Default = 27)
   parameter        N1                       = PLL_MAIN_DIVSEL[2] == 1'b0 ? 32'd1 : 32'd2;
   parameter        N2                       = PLL_MAIN_DIVSEL[1:0] == 2'b00 ? 32'd3 : PLL_MAIN_DIVSEL[1:0] == 2'b01 ? 32'd2 : PLL_MAIN_DIVSEL[1:0] == 2'b10 ? 32'd4 : 32'd5;
   parameter        N3                       = PLL_MAIN_DIVSEL[4:3] == 2'b00 ? 32'd3 : PLL_MAIN_DIVSEL[4:3] == 2'b10 ? 32'd4 : PLL_MAIN_DIVSEL[4:3] == 2'b11 ? 32'd5 : 32'd1;
   parameter  [1:0] PLL_OUT_DIVSEL           = 2'b01;                   // (Default = 0 = T:1d)
   parameter        M3                       = PLL_OUT_DIVSEL == 2'b00 ? 32'd1 : PLL_OUT_DIVSEL == 2'b01 ? 32'd2 : PLL_OUT_DIVSEL == 2'b11 ? 32'd4 : 32'd1;
   parameter        DPC                      = (32'd100 * N1 * N2 * N3 * 32'd2) / (M3 * DATAPATH_WIDTH);
   parameter        OUT_CLK                  = DPC * PLL_MUL;

   // Constant Port Value Assignments

   assign o_tx_reset     = 1'b0;
   assign o_tx_pcs_reset = 1'b0;
   assign o_tx_pma_reset = 1'b0;

   assign o_rx_reset     = 1'b0;
   assign o_rx_pcs_reset = 1'b0;
   assign o_rx_pma_reset = 1'b0;
   assign o_rx_cdr_reset = 1'b0;
   assign o_rx_eqa_reset = 1'b0;

   assign o_tx_8b10b_bypass    = 8'b0000_0000;
   assign o_rx_8b10b_bypass    = 8'b0000_0000;
   assign o_tx_8b10b_en        = 1'b1;
   assign o_rx_8b10b_en        = 1'b1;

   assign o_tx_prbs_sel        = 3'b000;
   assign o_tx_prbs_force_err  = 1'b0;
   assign o_rx_prbs_sel        = 3'b000;
   assign o_rx_prbs_cnt_reset  = 1'b0;

   assign o_rx_slide           = 1'b0;
   assign o_rx_comma_detect_en = 1'b1;

   assign o_tx_polarity        = 1'b0;

   assign o_tx_powerdown_n     = 1'b1;
   assign o_rx_powerdown_n     = 1'b1;

   assign o_rx_en_ei_detector  = 1'h0; // old: 1'b1;

   assign o_tx_char_dispval    = 8'b0000_0000;

   // Clock
   assign o_PCLK            = s_clk;
   assign o_tx_clk          = s_tx_clk;

   assign o_clk_core_tx     = i_clk_core_pll;
   assign o_clk_core_rx     = i_clk_core_pll;
   assign o_clk_core_rx_rec = i_clk_core_rx_rec;


   // Reset Logic
   assign s_reset = ~i_Reset;
   assign o_pll_reset = s_reset;


   // RxStatus Mux
   assign o_RxStatus = s_sel_rx_status ? s_rx_status_fsm : s_rx_status_dp;


   // Loopback
   assign o_loopback [0] = 1'b0;
   assign o_loopback [1] = s_loopback_fsm;
   assign o_loopback [2] = s_loopback_fsm;


   // Rx Valid
   assign o_RxValid = s_rx_val_from_fsm & i_rx_byte_is_aligned;


   // Rx Electrical Idle
   assign o_RxElecIdle = i_rx_ei_en;


   // Buffer Support Signals
   assign o_tx_buf_err   = i_tx_buf_err;
   assign o_rx_buf_reset = i_rx_buf_reset;
   assign o_rx_buf_err   = i_rx_buf_err;

   // Rx Polarity
   assign o_rx_polarity = i_RxPolarity;   // Setting not FSM related atm.


   // FSM PIPE
   ccfpga_pipe_fsm fsm_inst_0 (
      .i_clk               ( s_clk             ),
      .i_reset             ( s_reset           ),
      .o_fsm_state         ( o_fsm_state_pipe  ),
      .i_pw_state          ( i_PowerDown       ),
      .i_tx_elec_idle      ( i_TxElecIdle      ),
      .i_tx_detect_or_loop ( i_TxDetectRx      ),
      .o_phy_status        ( o_PhyStatus       ),
      .o_rx_status         ( s_rx_status_fsm   ),
      .i_reset_done        ( s_reset_done      ),
      .i_rx_detect_done    ( i_rx_detect_done  ),
      .i_rx_detect_val     ( i_rx_present      ),
      .o_rx_detect_start   ( o_tx_detect_rx    ),
      .o_sel_rx_status     ( s_sel_rx_status   ),
      .o_pcs_loopback      ( s_loopback_fsm    ),
      .o_tx_elec_idle      ( o_tx_elec_idle    ),
      .o_counter_reset     ( s_tx_idle_cnt_rst ),
      .i_count_flag        ( s_tx_idle_flag    ),
      .o_enable_align      ( s_enable_align    ) // Activate Word Alignment (FSM)
      );


   // Clock Counter for Tx Idle
   ccfpga_pipe_clk_counter #(
      .BIT_WIDTH ( CNT_BITWIDTH_TX ),
      .CLK_NUMB  ( CNT_NUMBER_TX   )
      )
   clk_count_inst_pipe_fsm (
      .i_clk   ( s_clk             ),
      .i_reset ( s_tx_idle_cnt_rst ),
      .o_flag  ( s_tx_idle_flag    )
      );


   // FSM Word Alignment
   ccfpga_pipe_fsm_word_align fsm_inst_1 (
      .i_clk           ( s_clk                ),
      .i_reset         ( s_reset              ),
      .i_enable        ( s_enable_align       ),
      .o_fsm_state     ( o_fsm_state_align    ),
      .o_rx_valid      ( s_rx_val_from_fsm    ),
      .o_counter_reset ( s_count_reset_align  ),
      .i_count_flag    ( s_count_flag         ),
      .o_mcomma_align  ( o_rx_mcomma_align    ),
      .o_pcomma_align  ( o_rx_pcomma_align    ),
      .i_byte_locked   ( i_rx_byte_is_aligned )
      );


   // Clock Counter for Alignment
   ccfpga_pipe_clk_counter #(
      .BIT_WIDTH ( CNT_BITWIDTH ),
      .CLK_NUMB  ( CNT_NUMBER   )
      )
   clk_count_inst_align (
      .i_clk   ( s_clk               ),
      .i_reset ( s_count_reset_align ),
      .o_flag  ( s_count_flag        )
      );

   // Tx clock generator (Clock Divider)
   ccfpga_pipe_clk_divider #(
      .DIVIDER ( DIVIDER )
   ) clk_div_inst (
      .clk_in  ( i_clk_core_pll ),
      .s_reset ( s_reset        ),
      .clk_out ( s_tx_clk       )
   );

   generate
      if (DATA_BYTES == 8) begin // 64-Bit PIPE

         // Clock
         assign s_clk = s_tx_clk;

         // Reset Logic (excludes PLL)
         //assign s_reset_done = i_rx_reset_done & i_tx_reset_done;
         assign s_reset_done = i_tx_reset_done;


         // Tx Datapath
         assign o_tx_data       =  i_TxData;
         assign o_tx_char_is_k  =  i_TxDataK;


         // Disparity (Enable and Value)
         assign o_tx_char_dispmode = i_TxCompliance;


         // Rx Datapath
         assign o_RxData [ 7: 0] = ( i_rx_not_in_table[0] ) ? 8'hFE : i_rx_data [ 7: 0]; // EDB Symbol (8'hFE)
         assign o_RxData [15: 8] = ( i_rx_not_in_table[1] ) ? 8'hFE : i_rx_data [15: 8];
         assign o_RxData [23:16] = ( i_rx_not_in_table[2] ) ? 8'hFE : i_rx_data [23:16];
         assign o_RxData [31:24] = ( i_rx_not_in_table[3] ) ? 8'hFE : i_rx_data [31:24];
         assign o_RxData [39:32] = ( i_rx_not_in_table[4] ) ? 8'hFE : i_rx_data [39:32];
         assign o_RxData [47:40] = ( i_rx_not_in_table[5] ) ? 8'hFE : i_rx_data [47:40];
         assign o_RxData [55:48] = ( i_rx_not_in_table[6] ) ? 8'hFE : i_rx_data [55:48];
         assign o_RxData [63:56] = ( i_rx_not_in_table[7] ) ? 8'hFE : i_rx_data [63:56];

         assign o_RxDataDecErr  = i_rx_not_in_table;
         assign o_RxDataK       = i_rx_char_is_k;
         assign o_RxDataComma   = i_rx_char_is_comma;
         assign o_RxDataDispErr = i_rx_disp_err;

         assign s_rx_status_dp  = |i_rx_not_in_table ? 3'b100 : ( |i_rx_disp_err ? 3'b111 : 3'b000 );

        end

      else begin // 32-Bit PIPE

         wire [7:0] s_neg_disparity;
         //wire       s_pll_locked;

         // Disparity (Enable and Value)
         assign o_tx_char_dispmode = s_neg_disparity;

         //assign o_tx_char_dispmode = {{8-DATA_BYTES{1'b0}}, s_neg_disparity};
         //assign o_tx_char_dispval  = {{8-DATA_BYTES{1'b0}},~s_neg_disparity};
         //assign o_tx_char_dispval  = ~s_neg_disparity; // Constant value!

         // Reset Logic (includes PLL)
         //assign s_reset_done = s_pll_locked & i_rx_reset_done & i_tx_reset_done;
         //assign s_reset_done = s_pll_locked & i_tx_reset_done;
         assign s_reset_done = i_tx_reset_done;

         /*CC_PLL #(
            .REF_CLK(DPC),       // reference input in MHz
            .OUT_CLK(OUT_CLK),   // pll output frequency in MHz
            .PERF_MD("SPEED"), // LOWPOWER, ECONOMY, SPEED
            .LOW_JITTER(1),      // 0: disable, 1: enable low jitter mode
            .CI_FILTER_CONST(2), // optional CI filter constant
            .CP_FILTER_CONST(4)  // optional CP filter constant
         ) pll_inst (
            .CLK_REF(),
            .CLK_FEEDBACK(1'b0),
            .USR_CLK_REF(i_clk_core_pll),
            .USR_LOCKED_STDY_RST(1'b1),
            .USR_PLL_LOCKED_STDY(),
            .USR_PLL_LOCKED(s_pll_locked),
            .CLK270(),
            .CLK180(),
            .CLK90(),
            .CLK0(s_clk),
            .CLK_REF_OUT()
         );*/
         assign s_clk = i_clk_core_pll;

         // Tx Datapath Demuliplexer
         ccfpga_pipe_tx_demux #(
            .DATA_BYTES ( DATA_BYTES )
            )
         demux_inst_0 (
            .i_clk    ( s_clk           ),
            .i_reset  ( s_reset         ),
            .i_enable ( 1'b1            ),
            .i_k_data ( i_TxDataK       ),    // PIPE
            .i_data   ( i_TxData        ),    // PIPE
            .i_compl  ( i_TxCompliance  ),    // PIPE
            .o_data   ( o_tx_data       ),    // SerDes
            .o_k_data ( o_tx_char_is_k  ),    // SerDes
            .o_dispar ( s_neg_disparity )     // SerDes
            );

         // Rx Datapath Muliplexer
         ccfpga_pipe_rx_mux #(
            .DATA_BYTES ( DATA_BYTES )
            )
         mux_inst_0 (
            .i_clk         ( s_clk              ),
            .i_reset       ( s_reset            ),
            .i_enable      ( 1'b1               ),
            .i_disp_err    ( i_rx_disp_err      ),   // SerDes
            .i_char_is_com ( i_rx_char_is_comma ),   // SerDes
            .i_decode_err  ( i_rx_not_in_table  ),   // SerDes
            .i_data        ( i_rx_data          ),   // SerDes
            .i_k_data      ( i_rx_char_is_k     ),   // SerDes
            .o_data        ( o_RxData           ),   // PIPE
            .o_k_data      ( o_RxDataK          ),   // PIPE
            .o_rx_status   ( s_rx_status_dp     ),   // PIPE
            .o_rx_comma    ( o_RxDataComma      ),   // PIPE
            .o_rx_dec_err  ( o_RxDataDecErr     ),   // PIPE
            .o_rx_disp_err ( o_RxDataDispErr    )    // PIPE
            );
       end

   endgenerate

endmodule