`timescale 1ns/100fs

module ccfpga_pipe_wrapper #(
   parameter DATA_BYTES = 8,
   parameter DATA_WIDTH = DATA_BYTES*8
   )
   (
   input wire                   i_Reset_n,      // Asyn. Reset
   input wire             [1:0] i_PowerDown,    // Power states
   input wire                   i_TxDetectRx,   // Receiver Detection (P1)/Loopback (P0)
   input wire                   i_TxElecIdle,   // Electrical Idle
   input wire  [DATA_BYTES-1:0] i_TxCompliance, // Compliance Pattern
   input wire                   i_RxPolarity,   // Received data polarity
   input wire  [DATA_WIDTH-1:0] i_TxData,       // Tx Data
   input wire  [DATA_BYTES-1:0] i_TxDataK,      // Tx K Data
   //input wire                   i_TxSwing,      // Tx Voltage Swing Level [Optional by Spec]

   output wire                  o_PCLK,         // Parallel Interface Clock
   output wire                  o_RxValid,      // Received data is valid
   output wire                  o_PhyStatus,    // Physical Status
   output wire            [2:0] o_RxStatus,     // Receiver Status
   output wire                  o_RxElecIdle,   // Electrical Idle at Receiver
   output wire [DATA_WIDTH-1:0] o_RxData,       // Rx Data
   output wire [DATA_BYTES-1:0] o_RxDataK       // Rx K Data
   );

   // CSS Interface
   wire                  o_tx_clk;             // Tx Core Clock
   wire                  o_tx_buf_err;         // Tx Buffer Error
   wire                  o_clk_core_rx_rec;    // Rx Recovered Clock
   wire                  i_rx_buf_reset;       // Rx Buffer Reset
   wire                  o_rx_buf_err;         // Rx Buffer Error
   wire           [ 3:0] o_fsm_state_pipe;     // State of PIPE FSM
   wire           [ 1:0] o_fsm_state_align;    // State of Align FSM

   assign                i_rx_buf_reset           = 1'b0;

   wire [DATA_BYTES-1:0] o_RxDataComma;        // Rx Byte Comma Indication
   wire [DATA_BYTES-1:0] o_RxDataDispErr;      // Rx Byte Disparity Error Indication
   wire [DATA_BYTES-1:0] o_RxDataDecErr;       // Rx Byte Decode Error Indication

   // Used by PIPE Logic (SerDes)
   (* clkbuf_inhibit *) wire        clk_core_pll;
   wire        clk_core_rx_rec;  // rx recovered clock
   wire        clk_core_tx;
   wire        clk_core_rx_in;   // rx core clock
   wire        pll_reset;

   wire [15:0] regfile_do;
   wire        regfile_rdy;

   wire        tx_reset;
   wire        tx_pcs_reset;
   wire        tx_pma_reset;

   wire  [2:0] loopback;

   wire        tx_elec_idle;
   wire        tx_detect_rx;
   wire  [2:0] tx_prbs_sel;
   wire        tx_prbs_force_err;
   wire        tx_powerdown_n;
   wire [63:0] tx_data;
   wire  [7:0] tx_char_is_k;
   wire        tx_polarity;
   wire        tx_8b10b_en;
   wire  [7:0] tx_8b10b_bypass;
   wire  [7:0] tx_char_dispmode;
   wire  [7:0] tx_char_dispval;
   
   wire        rx_reset;
   wire        rx_pma_reset;
   wire        rx_eqa_reset;
   wire        rx_cdr_reset;
   wire        rx_pcs_reset;
   wire        rx_buf_reset;
   wire  [2:0] rx_prbs_sel;
   wire        rx_prbs_cnt_reset;
   wire        rx_power_down_n;
   wire        rx_en_ei_detector;
   wire        rx_comma_detect_en;
   wire        rx_slide;
   wire        rx_polarity;
   wire        rx_8b10b_en;
   wire  [7:0] rx_8b10b_bypass;
   wire        rx_mcomma_align;
   wire        rx_pcomma_align;

   wire        tx_buf_err;
   wire        tx_resetdone;
   wire        rx_detect_done;
   wire        rx_present;
   wire        rx_prbs_err;
   wire [63:0] rx_data;
   wire  [7:0] rx_char_is_k;
   wire  [7:0] rx_char_is_comma;
   wire  [7:0] rx_not_in_table;
   wire  [7:0] rx_disp_err;
   wire        rx_buf_err;
   wire        rx_byte_is_aligned;
   wire        rx_byte_realign;
   wire        rx_resetdone;
   wire        rx_ei_en;

   // SerDes Config Parameter
   // PLL Parameters. Clock with frequency of 62.5 MHz. Tx clock with the frequency of 31.25 MHz will be generated with a divider in PIPE Logic.
   // 32-Bit Datapath will use the 62.5 MHz clock directly, while 64-Bit Datapath will use the divided clock of 31.25 MHz.
   //parameter  [5:0] PLL_FCNTRL               = 6'h1A;                   // (Default = 58 = T:20d)
   //parameter  [5:0] PLL_MAIN_DIVSEL          = {1'b0,2'b11,1'b0,2'b11}; // (Default = 27)
   //parameter  [1:0] PLL_OUT_DIVSEL           = 2'b01;                   // (Default = 0 = T:1d)
   // Lower frequency for Loopback test
   parameter  [5:0] PLL_FCNTRL               = 6'h1A;                   // (Default = 58 = T:20d)
   parameter  [5:0] PLL_MAIN_DIVSEL          = {1'b0,2'b00,1'b0,2'b01}; // (Default = 27)
   parameter  [1:0] PLL_OUT_DIVSEL           = 2'b11;                   // (Default = 0 = T:1d)

   parameter  [1:0] RX_DATAPATH_SEL          = 2'b11;              // (Default = 3)
   parameter  [1:0] TX_DATAPATH_SEL          = 2'b11;              // (Default = 3)

   parameter  [9:0] ALIGN_MCOMMA_VALUE       = 10'h283; // (Default = 10'b1010000011)
   parameter  [9:0] ALIGN_PCOMMA_VALUE       = 10'h17C; // (Default = 10'b0101111100)
   parameter  [9:0] ALIGN_COMMA_ENABLE       = 10'h3FF; // (Default = 3FF) : Maske
   parameter  [1:0] ALIGN_COMMA_WORD         = 2'h3;          // (Default = 2'b00 : 8 Bit)
   parameter  [1:0] RX_SLIDE_MODE            = 2'b00;   // !!!

   parameter        PLL_CONFIG_SEL           = 1'h1;              // (Default = 1'b0) (spec!)

   parameter        RX_WAIT_CDR_LOCK         = 1'b0;
   parameter        RX_RESET_DONE_GATE       = 1'h0;
   parameter  [4:0] RX_RESET_TIMER_PRESC     = 5'h0;
   parameter  [4:0] RX_PMA_RESET_TIME        = 5'h3;
   parameter  [4:0] RX_EQA_RESET_TIME        = 5'h3;
   parameter  [4:0] RX_CDR_RESET_TIME        = 5'h3;
   parameter  [4:0] RX_PCS_RESET_TIME        = 5'h3;
   parameter  [4:0] RX_BUF_RESET_TIME        = 5'h3;
   parameter  [2:0] RX_RTERM_VCMSEL          = 3'h4;
   parameter        RX_RTERM_PD              = 1'h0;
   parameter  [7:0] RX_EQA_CKP_HF            = 8'hA3;
   parameter  [7:0] RX_EQA_CKP_LF            = 8'hA3;
   parameter [15:0] RX_EQA_CONFIG            = 16'h01C0;
   parameter  [7:0] RX_EQA_CKP_OFFSET        = 8'h01;
   parameter        RX_EN_EQA                = 1'h0;
   parameter  [3:0] RX_EQA_LOCK_CFG          = 4'h0;
   parameter  [4:0] RX_TH_MON1               = 5'h8;
   parameter  [4:0] RX_TH_MON2               = 5'h8;
   parameter  [4:0] RX_TAPW                  = 5'h8;
   parameter  [4:0] RX_AFE_OFFSET            = 5'h8;
   parameter  [2:0] RX_AFE_VCMSEL            = 3'h4;
   parameter  [3:0] RX_AFE_GAIN              = 4'h8;
   parameter  [4:0] RX_AFE_PEAK              = 5'hF; //old: 16
   parameter  [7:0] RX_CDR_CKP               = 8'hF8; // old: {3'b101, 5'b01111};
   parameter  [7:0] RX_CDR_CKI               = 8'h00;
   parameter  [7:0] RX_CDR_LOCK_CFG          = 8'hD5; // old: 15'b000_1000_1101_0101;
   parameter  [1:0] RX_CDR_SET_ACC_CONFIG    = 2'h0;
   parameter        RX_CDR_FORCE_LOCK        = 1'h0;
   parameter [14:0] RX_CDR_FREQ_ACC          = 15'h0;
   parameter [15:0] RX_CDR_PHASE_ACC         = 16'h0000;
   parameter [14:0] RX_EYE_MEAS_CFG          = 15'h00;
   parameter  [5:0] RX_MON_PH_OFFSET         = 6'h0;
   parameter  [3:0] RX_EI_BIAS               = 4'h4;
   parameter  [3:0] RX_EI_BW_SEL             = 4'h4;
   parameter  [9:0] RX_CLKCOR_SEQ_1_0        = 10'h1F7;
   parameter  [9:0] RX_CLKCOR_SEQ_1_1        = 10'h1F7;
   parameter  [9:0] RX_CLKCOR_SEQ_1_2        = 10'h1F7;
   parameter  [9:0] RX_CLKCOR_SEQ_1_3        = 10'h1F7;
   parameter  [5:0] RX_CLKCOR_MIN_LAT        = 6'h20;
   parameter  [5:0] RX_CLKCOR_MAX_LAT        = 6'h27;
   parameter  [2:0] TX_TAIL_CASCODE          = 3'h4;
   parameter  [4:0] TX_BRANCH_EN_PRE         = 5'hF;
   parameter  [5:0] TX_BRANCH_EN_MAIN        = 6'h3F;
   parameter  [4:0] TX_BRANCH_EN_POST        = 5'hF;
   parameter  [6:0] TX_DC_ENABLE             = 7'h3F;
   parameter  [4:0] TX_AMP                   = 5'd30;
   parameter  [4:0] TX_DC_OFFSET             = 5'h8;
   parameter  [4:0] TX_CM_RAISE              = 5'h0;
   parameter  [4:0] TX_CM_THRESHOLD_0        = 5'hE;
   parameter  [4:0] TX_CM_THRESHOLD_1        = 5'h10;
   parameter        TX_CM_REG_EN             = 1'h1;
   parameter  [7:0] TX_CM_REG_KI             = 8'h80;
   parameter  [4:0] TX_PMA_RESET_TIME        = 5'h3;
   parameter  [4:0] TX_PCS_RESET_TIME        = 5'h3;
   parameter  [1:0] TX_PMA_LOOPBACK          = 2'b00;
   parameter        PLL_EN_ADPLL_CTRL        = 1'h1;

   parameter        PLL_SET_OP_LOCK          = 1'h0; // old: 1;
   parameter        PLL_ENFORCE_LOCK         = 1'h0;
   parameter        PLL_DISABLE_LOCK         = 1'h0;
   parameter        PLL_LOCK_WINDOW          = 1'h1;
   parameter        PLL_FAST_LOCK            = 1'h1;
   parameter        PLL_SYNC_BYPASS          = 1'h0;
   parameter        PLL_PFD_SELECT           = 1'h0;
   parameter        PLL_REF_BYPASS           = 1'h0;
   parameter        PLL_REF_SEL              = 1'h1;
   parameter        PLL_REF_RTERM            = 1'h1;
   parameter  [4:0] PLL_CI                   = 5'h3;// 5'h1; //
   parameter  [9:0] PLL_CP                   = 10'h50;// 10'h3C; //
   parameter  [3:0] PLL_AO                   = 4'h0;
   parameter  [2:0] PLL_SCAP                 = 3'h0;
   parameter        PLL_SCAP_AUTO_CAL        = 1'h1;
   parameter  [1:0] PLL_FILTER_SHIFT         = 2'h2;
   parameter  [2:0] PLL_SAR_LIMIT            = 2'h2;
   parameter [10:0] PLL_FT                   = 11'h200;
   parameter        PLL_OPEN_LOOP            = 1'h0;
   parameter  [2:0] PLL_BISC_MODE            = 3'h5; // MODE B, enable
   parameter  [3:0] PLL_BISC_TIMER_MAX       = 4'hC; // old: 15;
   parameter  [4:0] PLL_BISC_CP_MIN          = 5'h6; // 4;
   parameter  [4:0] PLL_BISC_CP_MAX          = 5'h1E; // old: 18;x
   parameter  [4:0] PLL_BISC_CP_START        = 5'h6; // old: 12;
   parameter        PLL_BISC_OPT_DET_IND     = 1'h0;
   parameter        PLL_BISC_PFD_SEL         = 1'h0;
   parameter        PLL_BISC_DLY_DIR         = 1'h0;
   parameter        PLL_BISC_CAL_SIGN        = 1'h1;// old: 0;
   parameter        PLL_BISC_CAL_AUTO        = 1'h1;
   parameter  [4:0] PLL_BISC_DLY_PFD_MON_REF = 5'h0;
   parameter  [4:0] PLL_BISC_DLY_PFD_MON_DIV = 5'h2;
   parameter  [2:0] PLL_BISC_COR_DLY         = 3'h1;

   // SerDes Instantiation
   CC_SERDES #(
      .RX_BUF_RESET_TIME(RX_BUF_RESET_TIME),
      .RX_PCS_RESET_TIME(RX_PCS_RESET_TIME),
      .RX_RESET_TIMER_PRESC(RX_RESET_TIMER_PRESC),
      .RX_RESET_DONE_GATE(RX_RESET_DONE_GATE),
      .RX_CDR_RESET_TIME(RX_CDR_RESET_TIME),
      .RX_EQA_RESET_TIME(RX_EQA_RESET_TIME),
      .RX_PMA_RESET_TIME(RX_PMA_RESET_TIME),
      .RX_WAIT_CDR_LOCK(RX_WAIT_CDR_LOCK), // turn off if loopback enabled
      .RX_CALIB_EN(1'h1),
      .RX_CALIB_OVR(1'h0),
      .RX_CALIB_VAL(4'h0),
      .RX_RTERM_VCMSEL(RX_RTERM_VCMSEL),
      .RX_RTERM_PD(RX_RTERM_PD),
      .RX_EQA_CKP_LF(RX_EQA_CKP_LF),
      .RX_EQA_CKP_HF(RX_EQA_CKP_HF),
      .RX_EQA_CKP_OFFSET(RX_EQA_CKP_OFFSET),
      .RX_EN_EQA(RX_EN_EQA),
      .RX_EQA_LOCK_CFG(RX_EQA_LOCK_CFG),
      .RX_TH_MON1(RX_TH_MON1),
      .RX_EN_EQA_EXT_VALUE(4'h0), // ?
      .RX_TH_MON2(RX_TH_MON2),
      .RX_TAPW(RX_TAPW),
      .RX_AFE_OFFSET(RX_AFE_OFFSET),
      .RX_EQA_CONFIG(RX_EQA_CONFIG),
      .RX_AFE_PEAK(RX_AFE_PEAK),
      .RX_AFE_GAIN(RX_AFE_GAIN),
      .RX_AFE_VCMSEL(RX_AFE_VCMSEL),
      .RX_CDR_CKP(RX_CDR_CKP),
      .RX_CDR_CKI(RX_CDR_CKI),
      .RX_CDR_TRANS_TH(7'h8), // h15? // ?
      .RX_CDR_LOCK_CFG(RX_CDR_LOCK_CFG),
      .RX_CDR_FREQ_ACC(RX_CDR_FREQ_ACC),
      .RX_CDR_PHASE_ACC(RX_CDR_PHASE_ACC),
      .RX_CDR_SET_ACC_CONFIG(RX_CDR_SET_ACC_CONFIG),
      .RX_CDR_FORCE_LOCK(RX_CDR_FORCE_LOCK),
      .RX_ALIGN_MCOMMA_VALUE(ALIGN_MCOMMA_VALUE),
      .RX_MCOMMA_ALIGN_OVR(1'h0),
      .RX_MCOMMA_ALIGN(1'h0),
      .RX_ALIGN_PCOMMA_VALUE(ALIGN_PCOMMA_VALUE),
      .RX_PCOMMA_ALIGN_OVR(1'h0),
      .RX_PCOMMA_ALIGN(1'h0),
      .RX_ALIGN_COMMA_WORD(ALIGN_COMMA_WORD), // 11: 32 bit, 01: 16 bit, 00: 8 bit
      .RX_ALIGN_COMMA_ENABLE(ALIGN_COMMA_ENABLE),
      .RX_SLIDE_MODE(RX_SLIDE_MODE),
      .RX_COMMA_DETECT_EN_OVR(1'h0),
      .RX_COMMA_DETECT_EN(1'h0),
      .RX_SLIDE(2'h0),
      .RX_EYE_MEAS_EN(1'h0),
      .RX_EYE_MEAS_CFG(RX_EYE_MEAS_CFG),
      .RX_MON_PH_OFFSET(RX_MON_PH_OFFSET),
      .RX_EI_BIAS(RX_EI_BIAS),
      .RX_EI_BW_SEL(RX_EI_BW_SEL),
      .RX_EN_EI_DETECTOR_OVR(1'h0),
      .RX_EN_EI_DETECTOR(1'h0),
      .RX_DATA_SEL(1'h0),
      .RX_BUF_BYPASS(1'h0),
      .RX_CLKCOR_USE(1'h0),
      .RX_CLKCOR_MIN_LAT(RX_CLKCOR_MIN_LAT),
      .RX_CLKCOR_MAX_LAT(RX_CLKCOR_MAX_LAT),
      .RX_CLKCOR_SEQ_1_0(RX_CLKCOR_SEQ_1_0),
      .RX_CLKCOR_SEQ_1_1(RX_CLKCOR_SEQ_1_1),
      .RX_CLKCOR_SEQ_1_2(RX_CLKCOR_SEQ_1_2),
      .RX_CLKCOR_SEQ_1_3(RX_CLKCOR_SEQ_1_3),
      .RX_PMA_LOOPBACK(1'h0),
      .RX_PCS_LOOPBACK(1'h0),
      .RX_DATAPATH_SEL(RX_DATAPATH_SEL),
      .RX_PRBS_OVR(1'b0),
      .RX_PRBS_SEL(3'b0),
      .RX_LOOPBACK_OVR(1'h0),
      .RX_PRBS_CNT_RESET(1'h0),
      .RX_POWER_DOWN_OVR(1'h0),
      .RX_POWER_DOWN_N(1'h1),
      .RX_RESET_OVR(1'h0),
      .RX_RESET(1'h0),
      .RX_PMA_RESET_OVR(1'h0),
      .RX_PMA_RESET(1'h0),
      .RX_EQA_RESET_OVR(1'h0),
      .RX_EQA_RESET(1'h0),
      .RX_CDR_RESET_OVR(1'h0),
      .RX_CDR_RESET(1'h0),
      .RX_PCS_RESET_OVR(1'h0),
      .RX_PCS_RESET(1'h0),
      .RX_BUF_RESET_OVR(1'h0),
      .RX_BUF_RESET(1'h0),
      .RX_POLARITY_OVR(1'h0),
      .RX_POLARITY(1'h0),
      .RX_8B10B_EN_OVR(1'h0),
      .RX_8B10B_EN(1'h0),
      .RX_8B10B_BYPASS(8'h0),
      .RX_BYTE_REALIGN(1'h0),
      .TX_SEL_PRE(5'h0),
      .TX_SEL_POST(5'h0),
      .TX_AMP(TX_AMP),
      .TX_BRANCH_EN_PRE(TX_BRANCH_EN_PRE),
      .TX_BRANCH_EN_MAIN(TX_BRANCH_EN_MAIN),
      .TX_BRANCH_EN_POST(TX_BRANCH_EN_POST),
      .TX_TAIL_CASCODE(TX_TAIL_CASCODE),
      .TX_DC_ENABLE(TX_DC_ENABLE),
      .TX_DC_OFFSET(TX_DC_OFFSET), // ? note: set to 8
      .TX_CM_RAISE(TX_CM_RAISE),
      .TX_CM_THRESHOLD_0(TX_CM_THRESHOLD_0),
      .TX_CM_THRESHOLD_1(TX_CM_THRESHOLD_1),
      .TX_SEL_PRE_EI(5'h0),
      .TX_SEL_POST_EI(5'h0),
      .TX_AMP_EI(5'hF),
      .TX_BRANCH_EN_PRE_EI(5'h0),
      .TX_BRANCH_EN_MAIN_EI(6'h3F),
      .TX_BRANCH_EN_POST_EI(5'h0),
      .TX_TAIL_CASCODE_EI(3'h4),
      .TX_DC_ENABLE_EI(7'h3F),
      .TX_DC_OFFSET_EI(5'h0),
      .TX_CM_RAISE_EI(5'h0),
      .TX_CM_THRESHOLD_0_EI(5'hE),
      .TX_CM_THRESHOLD_1_EI(5'h10),
      .TX_SEL_PRE_RXDET(5'h0),
      .TX_SEL_POST_RXDET(5'h0),
      .TX_AMP_RXDET(5'hF),
      .TX_BRANCH_EN_PRE_RXDET(5'h0),
      .TX_BRANCH_EN_MAIN_RXDET(6'h3F),
      .TX_BRANCH_EN_POST_RXDET(5'h0),
      .TX_TAIL_CASCODE_RXDET(3'h4),
      .TX_DC_ENABLE_RXDET(7'h3F),
      .TX_DC_OFFSET_RXDET(5'h0),
      .TX_CM_RAISE_RXDET(5'h0),
      .TX_CM_THRESHOLD_0_RXDET(5'hE),
      .TX_CM_THRESHOLD_1_RXDET(5'h10),
      .TX_CALIB_EN(1'h0),
      .TX_CALIB_OVR(1'h0),
      .TX_CALIB_VAL(4'h0),
      .TX_CM_REG_KI(TX_CM_REG_KI),
      .TX_CM_SAR_EN(1'h0),
      .TX_CM_REG_EN(TX_CM_REG_EN),
      .TX_PMA_RESET_TIME(TX_PMA_RESET_TIME),
      .TX_PCS_RESET_TIME(TX_PCS_RESET_TIME),
      .TX_PCS_RESET_OVR(1'h0),
      .TX_PCS_RESET(1'h0),
      .TX_PMA_RESET_OVR(1'h0),
      .TX_PMA_RESET(1'h0),
      .TX_RESET_OVR(1'h0),
      .TX_RESET(1'h0),
      .TX_PMA_LOOPBACK(TX_PMA_LOOPBACK),
      .TX_PCS_LOOPBACK(1'h0),
      .TX_DATAPATH_SEL(TX_DATAPATH_SEL),
      .TX_PRBS_OVR(1'b0),
      .TX_PRBS_SEL(3'b000),
      .TX_PRBS_FORCE_ERR(1'h0),
      .TX_LOOPBACK_OVR(1'h0),
      .TX_POWER_DOWN_OVR(1'h0),
      .TX_POWER_DOWN_N(1'h1),
      .TX_ELEC_IDLE_OVR(1'h0),
      .TX_ELEC_IDLE(1'h0),
      .TX_DETECT_RX_OVR(1'h0),
      .TX_DETECT_RX(1'h0),
      .TX_POLARITY_OVR(1'h0),
      .TX_POLARITY(1'h0),
      .TX_8B10B_EN_OVR(1'h0),
      .TX_8B10B_EN(1'h0),
      .TX_DATA_OVR(1'h0),
      .TX_DATA_CNT(3'h0),
      .TX_DATA_VALID(1'h0),
      .PLL_EN_ADPLL_CTRL(PLL_EN_ADPLL_CTRL),
      .PLL_CONFIG_SEL(PLL_CONFIG_SEL), // 0: internal, 1: regfile
      .PLL_SET_OP_LOCK(PLL_SET_OP_LOCK),
      .PLL_ENFORCE_LOCK(PLL_ENFORCE_LOCK),
      .PLL_DISABLE_LOCK(PLL_DISABLE_LOCK),
      .PLL_LOCK_WINDOW(PLL_LOCK_WINDOW), // 0: long, 1: short
      .PLL_FAST_LOCK(PLL_FAST_LOCK),
      .PLL_SYNC_BYPASS(PLL_SYNC_BYPASS),
      .PLL_PFD_SELECT(PLL_PFD_SELECT),
      .PLL_REF_BYPASS(PLL_REF_BYPASS),
      .PLL_REF_SEL(PLL_REF_SEL), // 0: single-ended, 1: lvds
      .PLL_REF_RTERM(PLL_REF_RTERM),
      .PLL_FCNTRL(PLL_FCNTRL),
      .PLL_MAIN_DIVSEL(PLL_MAIN_DIVSEL),
      .PLL_OUT_DIVSEL(PLL_OUT_DIVSEL),
      .PLL_CI(PLL_CI),
      .PLL_CP(PLL_CP),
      .PLL_AO(PLL_AO),
      .PLL_SCAP(PLL_SCAP),
      .PLL_FILTER_SHIFT(PLL_FILTER_SHIFT),
      .PLL_SAR_LIMIT(PLL_SAR_LIMIT),
      .PLL_FT(PLL_FT),
      .PLL_OPEN_LOOP(PLL_OPEN_LOOP),
      .PLL_SCAP_AUTO_CAL(PLL_SCAP_AUTO_CAL),
      .PLL_BISC_MODE(PLL_BISC_MODE), // MODE B, enable
      .PLL_BISC_TIMER_MAX(PLL_BISC_TIMER_MAX),
      .PLL_BISC_OPT_DET_IND(PLL_BISC_OPT_DET_IND),
      .PLL_BISC_PFD_SEL(PLL_BISC_PFD_SEL),
      .PLL_BISC_DLY_DIR(PLL_BISC_DLY_DIR),
      .PLL_BISC_COR_DLY(PLL_BISC_COR_DLY),
      .PLL_BISC_CAL_SIGN(PLL_BISC_CAL_SIGN),
      .PLL_BISC_CAL_AUTO(PLL_BISC_CAL_AUTO),
      .PLL_BISC_CP_MIN(PLL_BISC_CP_MIN),
      .PLL_BISC_CP_MAX(PLL_BISC_CP_MAX),
      .PLL_BISC_CP_START(PLL_BISC_CP_START),
      .PLL_BISC_DLY_PFD_MON_REF(PLL_BISC_DLY_PFD_MON_REF),
      .PLL_BISC_DLY_PFD_MON_DIV(PLL_BISC_DLY_PFD_MON_DIV),
      .SERDES_ENABLE(1'h1),
      .SERDES_AUTO_INIT(1'h0),
      .SERDES_TESTMODE(1'h1)
   ) i_cc_serdes (
      // ADPLL
      .RX_CLK_O(clk_core_rx_rec), // CDR CLK
      .PLL_CLK_O(clk_core_pll), // PLL CLK
      // LOOPBACK
      .LOOPBACK_I(loopback),
      // RESET
      .TX_RESET_I(tx_reset),
      .RX_RESET_I(rx_reset),
      .RX_PMA_RESET_I(rx_pma_reset),
      .RX_EQA_RESET_I(rx_eqa_reset),
      .RX_CDR_RESET_I(rx_cdr_reset),
      .RX_PCS_RESET_I(rx_pcs_reset),
      .RX_BUF_RESET_I(rx_buf_reset),
      .TX_PCS_RESET_I(tx_pcs_reset),
      .TX_PMA_RESET_I(tx_pma_reset),
      .PLL_RESET_I(pll_reset),
      .TX_RESET_DONE_O(tx_resetdone),
      .RX_RESET_DONE_O(rx_resetdone),
      // TX
      //.TX_CLK_I(clk_core_pll), // PLL CLK
      .TX_CLK_I(o_tx_clk), // Tx clock from PIPE Logic
      .TX_DATA_I(tx_data),
      .TX_POWER_DOWN_N_I(tx_powerdown_n),
      .TX_POLARITY_I(tx_polarity),
      .TX_PRBS_SEL_I(tx_prbs_sel),
      .TX_PRBS_FORCE_ERR_I(tx_prbs_force_err),
      .TX_8B10B_EN_I(tx_8b10b_en),
      .TX_8B10B_BYPASS_I(tx_8b10b_bypass),
      .TX_CHAR_IS_K_I(tx_char_is_k),
      .TX_CHAR_DISPMODE_I(tx_char_dispmode),
      .TX_CHAR_DISPVAL_I(tx_char_dispval),
      .TX_ELEC_IDLE_I(tx_elec_idle),
      .TX_DETECT_RX_I(tx_detect_rx),
      .TX_BUF_ERR_O(tx_buf_err),
      // RX
      .RX_CLK_I(o_tx_clk), // Tx clock from PIPE Logic
      .RX_POWER_DOWN_N_I(rx_power_down_n),
      .RX_POLARITY_I(rx_polarity),
      .RX_PRBS_SEL_I(rx_prbs_sel),
      .RX_PRBS_CNT_RESET_I(rx_prbs_cnt_reset),
      .RX_PRBS_ERR_O(rx_prbs_err),
      .RX_8B10B_EN_I(rx_8b10b_en),
      .RX_8B10B_BYPASS_I(rx_8b10b_bypass),
      .RX_EN_EI_DETECTOR_I(rx_en_ei_detector),
      .RX_COMMA_DETECT_EN_I(rx_comma_detect_en),
      .RX_SLIDE_I(rx_slide),
      .RX_MCOMMA_ALIGN_I(rx_mcomma_align),
      .RX_PCOMMA_ALIGN_I(rx_pcomma_align),
      .RX_DATA_O(rx_data),
      .RX_NOT_IN_TABLE_O(rx_not_in_table),
      .RX_CHAR_IS_COMMA_O(rx_char_is_comma),
      .RX_CHAR_IS_K_O(rx_char_is_k),
      .RX_DISP_ERR_O(rx_disp_err),
      .TX_DETECT_RX_DONE_O(rx_detect_done),
      .TX_DETECT_RX_PRESENT_O(rx_present),
      .RX_BUF_ERR_O(rx_buf_err),
      .RX_BYTE_IS_ALIGNED_O(rx_byte_is_aligned),
      .RX_BYTE_REALIGN_O(rx_byte_realign),
      .RX_EI_EN_O(rx_ei_en),
      // REGFILE
      .REGFILE_CLK_I(1'h0),
      .REGFILE_WE_I(1'h0),
      .REGFILE_EN_I(1'h0),
      .REGFILE_ADDR_I(8'h0),
      .REGFILE_DI_I(16'h0),
      .REGFILE_MASK_I(16'h0),
      .REGFILE_DO_O(regfile_do),
      .REGFILE_RDY_O(regfile_rdy)
   );

   ccfpga_pipe_logic #(
      .DATA_BYTES ( DATA_BYTES )
   )
   pipe_logic_inst (
      .o_PCLK               ( o_PCLK             ),
      .o_tx_clk             ( o_tx_clk           ),
      .i_Reset              ( i_Reset_n          ),
      .i_PowerDown          ( i_PowerDown        ),
      .i_TxDetectRx         ( i_TxDetectRx       ),
      .i_TxElecIdle         ( i_TxElecIdle       ),
      .i_TxCompliance       ( i_TxCompliance     ),
      //.i_TxSwing          ( i_TxSwing          ),
      .i_RxPolarity         ( i_RxPolarity       ),
      .o_RxValid            ( o_RxValid          ),
      .o_PhyStatus          ( o_PhyStatus        ),
      .o_RxElecIdle         ( o_RxElecIdle       ),
      .o_RxStatus           ( o_RxStatus         ),
      .i_TxData             ( i_TxData           ),
      .i_TxDataK            ( i_TxDataK          ),
      .o_RxData             ( o_RxData           ),
      .o_RxDataK            ( o_RxDataK          ),
      .o_tx_buf_err         ( o_tx_buf_err       ),
      .o_clk_core_rx_rec    ( o_clk_core_rx_rec  ),
      .i_rx_buf_reset       ( i_rx_buf_reset     ),
      .o_rx_buf_err         ( o_rx_buf_err       ),
      .o_fsm_state_pipe     ( o_fsm_state_pipe   ),
      .o_fsm_state_align    ( o_fsm_state_align  ),
      .o_RxDataComma        ( o_RxDataComma      ),
      .o_RxDataDispErr      ( o_RxDataDispErr    ),
      .o_RxDataDecErr       ( o_RxDataDecErr     ),
      .i_clk_core_pll       ( clk_core_pll       ),
      .i_clk_core_rx_rec    ( clk_core_rx_rec    ),
      .o_clk_core_tx        ( clk_core_tx        ),
      .o_clk_core_rx        ( clk_core_rx_in     ),
      .o_pll_reset          ( pll_reset          ),
      .o_tx_reset           ( tx_reset           ),
      .i_tx_reset_done      ( tx_resetdone       ),
      .o_rx_reset           ( rx_reset           ),
      .i_rx_reset_done      ( rx_resetdone       ),
      .o_tx_pcs_reset       ( tx_pcs_reset       ),
      .o_tx_pma_reset       ( tx_pma_reset       ),
      .o_rx_pcs_reset       ( rx_pcs_reset       ),
      .o_rx_pma_reset       ( rx_pma_reset       ),
      .o_rx_cdr_reset       ( rx_cdr_reset       ),
      .o_rx_eqa_reset       ( rx_eqa_reset       ),
      .o_tx_powerdown_n     ( tx_powerdown_n     ),
      .o_rx_powerdown_n     ( rx_power_down_n    ),
      .o_loopback           ( loopback           ),
      .o_rx_prbs_sel        ( rx_prbs_sel        ),
      .o_rx_prbs_cnt_reset  ( rx_prbs_cnt_reset  ),
      .o_tx_prbs_sel        ( tx_prbs_sel        ),
      .o_tx_prbs_force_err  ( tx_prbs_force_err  ),
      .o_rx_buf_reset       ( rx_buf_reset       ),
      .i_rx_buf_err         ( rx_buf_err         ),
      .i_tx_buf_err         ( tx_buf_err         ),
      .o_tx_data            ( tx_data            ),
      .o_tx_char_is_k       ( tx_char_is_k       ),
      .o_tx_char_dispmode   ( tx_char_dispmode   ),
      .o_tx_char_dispval    ( tx_char_dispval    ),
      .o_tx_8b10b_en        ( tx_8b10b_en        ),
      .o_tx_8b10b_bypass    ( tx_8b10b_bypass    ),
      .o_tx_polarity        ( tx_polarity        ),
      .o_tx_elec_idle       ( tx_elec_idle       ),
      .o_tx_detect_rx       ( tx_detect_rx       ),
      .i_rx_detect_done     ( rx_detect_done     ),
      .i_rx_present         ( rx_present         ),
      .i_rx_data            ( rx_data            ),
      .i_rx_char_is_k       ( rx_char_is_k       ),
      .i_rx_char_is_comma   ( rx_char_is_comma   ),
      .i_rx_disp_err        ( rx_disp_err        ),
      .i_rx_not_in_table    ( rx_not_in_table    ),
      .o_rx_8b10b_en        ( rx_8b10b_en        ),
      .o_rx_8b10b_bypass    ( rx_8b10b_bypass    ),
      .i_rx_byte_is_aligned ( rx_byte_is_aligned ),
      .i_rx_byte_realign    ( rx_byte_realign    ),
      .o_rx_mcomma_align    ( rx_mcomma_align    ),
      .o_rx_pcomma_align    ( rx_pcomma_align    ),
      .o_rx_comma_detect_en ( rx_comma_detect_en ),
      .o_rx_slide           ( rx_slide           ),
      .o_rx_polarity        ( rx_polarity        ),
      .o_rx_en_ei_detector  ( rx_en_ei_detector  ),
      .i_rx_ei_en           ( rx_ei_en           )
      );

endmodule
