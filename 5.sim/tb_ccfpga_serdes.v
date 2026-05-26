////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Interessengruppe fuer Mikroelektronik und Eingebettete Systeme (IMES)
// Fachhochschule Dortmund
//
// Development in cooperation with Cologne Chip AG
//
// Filename     : tb_ccfpga_serdes.v
// Author       : Philipp Leduc, S. Hartman (Author of Original Testbench Design)
// Tool         :
// Description  : Testcase for PIPE Interface and SerDes of the Gatemate FPGA.
// Commentary   : Testbench is based on the former Testbench by RacyIC GmbH (tb_ccfpga_serdes.v).
//                The Tesbench has been expanded to test SerDes and the PIPE.
//
//                > To choose between Test, define PIPE or SERDES Macro.
//
//                > For PIPE test define Datapath width through Parameter DATA_BYTES.
//
//                8 > 64 Bit Datapath (PIPE)
//                4 > 32 Bit Datapath (PIPE)
//                2 > 16 Bit Datapath (PIPE)
//                1 >  8 Bit Datapath (PIPE)
//
// Abreviations : [i_] > input,
//                [o_] > output,
//                [_n] > low active
//
// Changelog:
// -------------------------------------------------------------------------------------------------
// Version | Author             | Date       | Changes
// -------------------------------------------------------------------------------------------------
// 1.0     | Hartmann           | 07.08.2015 | black box release (original serdes version)
// -------------------------------------------------------------------------------------------------
// 1.1     | Leduc              | 05.06.2021 | released (PIPE interface version)
// -------------------------------------------------------------------------------------------------
////////////////////////////////////////////////////////////////////////////////////////////////////

`ifdef AMS
 `include "disciplines.vams"
`endif

`timescale 1ns/100fs

module tb_ccfpga_serdes ();

`ifdef PIPE

   // PIPE Parameter

   parameter        DATA_BYTES = 8;
   parameter        DATA_WIDTH = DATA_BYTES*8;

   // Signals

   // PIPE Interface
   wire                  o_PCLK;               // PCLK (user side)
   reg                   i_Reset;              // Async. Reset for Transceiver (Tx/Rx)
   reg            [ 1:0] i_PowerDown;          // Power States (P0 - P2)
   reg                   i_TxDetectRx;         // Receiver Detection (P0) or Loopback (P1)
   reg                   i_TxElecIdle;         // Tx Electrical Idle, Valid Data (P0) or Beacon (P2)
   reg  [DATA_BYTES-1:0] i_TxCompliance;       // Tx negative Disparity LSB (Compliance Pattern)
   //  wire                  i_TxSwing;        // Tx Voltage Swing Level [Optional by Spec]
   reg                   i_RxPolarity;         // Rx Polarity Inversion
   wire                  o_RxValid;            // Symbol Lock and Valid Data on RxData and RxDataK
   wire                  o_PhyStatus;          // Status of several PHY functions (Transition)
   wire                  o_RxElecIdle;         // Rx Detection of Electrical Idle
   wire           [ 2:0] o_RxStatus;           // Receiver Status and Received Data Status
   reg  [DATA_WIDTH-1:0] i_TxData;             // Tx Data
   reg  [DATA_BYTES-1:0] i_TxDataK;            // Tx K Data
   wire [DATA_WIDTH-1:0] o_RxData;             // Rx Data
   wire [DATA_BYTES-1:0] o_RxDataK;            // Rx K Data

   // Support Interface

   wire                  o_tx_buf_error;       // Tx Buffer Error
   wire                  o_clk_core_rx_rec;    // Rx Recovered Clock
   reg                   i_rx_buf_reset;       // Rx Buffer Reset
   wire                  o_rx_buf_err;         // Rx Buffer Error
   wire           [ 3:0] o_fsm_state_pipe;     // State of PIPE FSM
   wire           [ 1:0] o_fsm_state_align;    // State of Align FSM

   wire [DATA_BYTES-1:0] o_RxDataComma;        // Rx Byte Comma Indication
   wire [DATA_BYTES-1:0] o_RxDataDispErr;      // Rx Byte Disparity Error Indication
   wire [DATA_BYTES-1:0] o_RxDataDecErr;       // Rx Byte Decode Error Indication

   // Used by PIPE Logic (SerDes)

   wire        clk_core_tx;
   wire        clk_core_rx_in;   // rx core clock
   wire        clk_core_rx_rec;  // rx recovered clock
   wire        clk_core_pll;

   wire        pll_reset;
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
   wire        rx_powerdown_n;
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

`elsif SERDES

   wire        clk_core_tx;
   wire        clk_core_rx_in;   // rx core clock
   wire        clk_core_rx_rec;  // rx recoverd clock
   wire        clk_core_pll;

   reg         pll_reset          = 1'b0;
   reg         tx_reset           = 1'b0;
   reg         tx_pcs_reset       = 1'b0;
   reg         tx_pma_reset       = 1'b0;

   reg   [2:0] loopback           = 3'b0;

   reg         tx_elec_idle       = 1'b0;
   reg         tx_detect_rx       = 1'b0;
   reg   [2:0] tx_prbs_sel        = 3'b0;
   reg         tx_prbs_force_err  = 1'b0;
   reg         tx_powerdown_n     = 1'b0;
   reg  [63:0] tx_data            = 64'h0;
   reg   [7:0] tx_char_is_k       = 8'h0;
   reg         tx_polarity        = 1'b0;
   reg         tx_8b10b_en        = 1'b0;
   reg   [7:0] tx_8b10b_bypass    = 8'h0;
   reg   [7:0] tx_char_dispmode   = 8'h0;
   reg   [7:0] tx_char_dispval    = 8'h0;

   reg         rx_reset = 1'b0;
   reg         rx_pma_reset       = 1'b0;
   reg         rx_eqa_reset       = 1'b0;
   reg         rx_cdr_reset       = 1'b0;
   reg         rx_pcs_reset       = 1'b0;
   reg         rx_buf_reset       = 1'b0;
   reg   [2:0] rx_prbs_sel        = 3'b0;
   reg         rx_prbs_cnt_reset  = 1'b0;
   reg         rx_powerdown_n     = 1'b0;
   reg         rx_en_ei_detector  = 1'b0;
   reg         rx_comma_detect_en = 1'b0;
   reg         rx_slide           = 1'b0;
   reg         rx_polarity        = 1'b0;
   reg         rx_8b10b_en        = 1'b0;
   reg   [7:0] rx_8b10b_bypass    = 8'h0;
   reg         rx_mcomma_align    = 1'b0;
   reg         rx_pcomma_align    = 1'b0;

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

`endif

   // Not available through FPGA Fabric 

   reg         clk_ref;
   reg         clk_reg;
   reg         clk_cfg;

   reg         reset_n;
   reg         reset_reg_n;
   wire        reset_core_pll_n;
   wire        reset_core_tx_n;
   wire        reset_core_rx_n;

   reg         testmode      = 1'b0;
   reg         scan_enable   = 1'b0;

   reg         cfg_en        = 1'b0;
   reg         reset_cfg     = 1'b0;
   reg  [15:0] cfgfile_di;
   reg         cfgfile_valid = 1'b0;
   reg   [7:0] cfgfile_addr;

   // Register Interface

   reg         regfile_we;
   reg         regfile_en    = 1'b0;
   reg   [7:0] regfile_addr;
   reg  [15:0] regfile_mask;
   reg  [15:0] regfile_di;
   wire [15:0] regfile_do;
   wire        regfile_rdy;

   // Analog

   `ifdef AMS
      electrical  TERM_SERIO;
      electrical  RX_SERIO_P;
      electrical  RX_SERIO_N;
      electrical  TX_SERIO_P;
      electrical  TX_SERIO_N;
   `else
      wire        TERM_SERIO;
      reg         RX_SERIO_P; 
      reg         RX_SERIO_N; 
      wire        TX_SERIO_P;
      wire        TX_SERIO_N;
   `endif // !`ifdef AMS


   // Tb Variables
   integer          errors      = 0;
   integer          checks_done = 0;

   // Parameters for Self Calibration in task startSerIOADPLL

   parameter        ADPLL_PFDAC_TIMER    = 12;
   parameter        ADPLL_PFDAC_COR_DLY  = 1;
   parameter        ADPLL_PFDAC_CP_MIN   = 6;
   parameter        ADPLL_PFDAC_CP_MAX   = 30;
   parameter        ADPLL_PFDAC_CP_START = 6;
   parameter        ADPLL_PFDAC_CAL_SIGN = 1;
   parameter        ADPLL_PFDAC_AUTO_CAL = 1;

   // SerDes Config Parameter 

   parameter  [5:0] PLL_FCNTRL               = 58;                      // (Default = 58 = T:20d)
   parameter  [5:0] PLL_MAIN_DIVSEL          = {1'b0,2'b11,1'b0,2'b11}; // (Default = 27)
   parameter  [1:0] PLL_OUT_DIVSEL           = 2'b01;                   // (Default = 0 = T:1d)

   parameter  [1:0] RX_DATAPATH_SEL          = 3;              // (Default = 3)
   parameter  [1:0] TX_DATAPATH_SEL          = 3;              // (Default = 3)

   parameter  [9:0] ALIGN_MCOMMA_VALUE       = 10'b1010000011; // (Default = 10'b1010000011)
   parameter  [9:0] ALIGN_PCOMMA_VALUE       = 10'b0101111100; // (Default = 10'b0101111100)
   parameter  [9:0] ALIGN_COMMA_ENABLE       = 10'b1111111111; // (Default = FFF) : Maske
   parameter  [1:0] ALIGN_COMMA_WORD         = 2'b11;          // (Default = 2'b00 : 8 Bit)
   parameter  [1:0] RX_SLIDE_MODE            = 0;

   parameter        PLL_CONFIG_SEL           = 0;              // (Default = 1'b0) (spec!)

   parameter        TX_BUFFER_ADDR_WIDTH     = 5;
   parameter        RX_WAIT_CDR_LOCK         = 1;
   parameter        RX_RESETDONE_GATE        = 0;
   parameter  [4:0] RX_RESET_TIMER_PRESC     = 0;
   parameter  [4:0] RX_PMA_RESET_TIME        = 3;
   parameter  [4:0] RX_EQA_RESET_TIME        = 3;
   parameter  [4:0] RX_CDR_RESET_TIME        = 3;
   parameter  [4:0] RX_PCS_RESET_TIME        = 3;
   parameter  [4:0] RX_BUF_RESET_TIME        = 3;
   parameter        RX_CALIB_OVR             = 0;
   parameter  [3:0] RX_CALIB_VAL             = 0;
   parameter  [2:0] RX_RTERM_VCMSEL          = 4;
   parameter        RX_RTERM_PD              = 0;
   parameter  [7:0] RX_EQA_CKP_HF            = 8'b101_00011;
   parameter  [7:0] RX_EQA_CKP_LF            = 8'b101_00011;
   parameter [15:0] RX_EQA_CONFIG            = 16'h01C0;
   parameter  [7:0] RX_EQA_CKP_OFFSET        = 8'b000_00001;
   parameter        RX_EN_EQA                = 0;
   parameter  [3:0] RX_EQA_LOCK_CFG          = 0;
   parameter        RX_TH_MON1_OVR           = 0;
   parameter        RX_TH_MON2_OVR           = 0;
   parameter        RX_TAPW_OVR              = 0;
   parameter        RX_AFE_OFFSET_OVR        = 0;
   parameter  [4:0] RX_TH_MON1               = 8;
   parameter  [4:0] RX_TH_MON2               = 8;
   parameter  [4:0] RX_TAPW                  = 8;
   parameter  [4:0] RX_AFE_OFFSET            = 8;
   parameter  [2:0] RX_AFE_VCMSEL            = 4;
   parameter  [3:0] RX_AFE_GAIN              = 8;
   parameter  [4:0] RX_AFE_PEAK              = 5'hF;
   parameter  [7:0] RX_CDR_CKP               = 8'hF8;
   parameter  [7:0] RX_CDR_CKI               = {3'b000, 5'b00000};
   parameter  [7:0] RX_CDR_LOCK_CFG          = 8'hD5;
   parameter  [1:0] RX_CDR_SET_ACC_CONFIG    = 2'b00;
   parameter        RX_CDR_FORCE_LOCK        = 0;
   parameter [14:0] RX_CDR_FREQ_ACC          = 15'h0;
   parameter [15:0] RX_CDR_PHASE_ACC         = 16'h0;
   parameter [14:0] RX_EYE_MEAS_CFG          = 0;
   parameter  [5:0] RX_MON_PH_OFFSET         = 0;
   parameter  [3:0] RX_EI_BIAS               = 4;
   parameter  [3:0] RX_EI_BW_SEL             = 4;
   parameter        RX_BUF_BYPASS            = 0;
   parameter        RX_CLKCOR_USE            = 0;
   parameter  [9:0] RX_CLKCOR_SEQ_1_0        = 10'b0111110111;
   parameter  [9:0] RX_CLKCOR_SEQ_1_1        = 10'b0111110111;
   parameter  [9:0] RX_CLKCOR_SEQ_1_2        = 10'b0111110111;
   parameter  [9:0] RX_CLKCOR_SEQ_1_3        = 10'b0111110111;
   parameter  [5:0] RX_CLKCOR_MIN_LAT        = 32;
   parameter  [5:0] RX_CLKCOR_MAX_LAT        = 39;
   parameter  [5:0] RX_DBG_SRAM_DELAY        = 6'b00_01_01;
   parameter  [3:0] RX_DBG_SEL               = 0;
   parameter        RX_DBG_MODE              = 0;
   parameter  [4:0] TX_SEL_PRE               = 0;
   parameter  [4:0] TX_SEL_POST              = 0;
   parameter  [2:0] TX_TAIL_CASCODE          = 3'b100;
   parameter  [4:0] TX_BRANCH_EN_PRE         = 0;
   parameter  [5:0] TX_BRANCH_EN_MAIN        = 6'b111111;
   parameter  [4:0] TX_BRANCH_EN_POST        = 0;
   parameter  [6:0] TX_DC_ENABLE             = 63;
   parameter  [4:0] TX_AMP                   = 15;
   parameter  [4:0] TX_DC_OFFSET             = 0;
   parameter  [4:0] TX_CM_RAISE              = 0;
   parameter  [4:0] TX_CM_THRESHOLD_0        = 14; 
   parameter  [4:0] TX_CM_THRESHOLD_1        = 16; 
   parameter        TX_CALIB_OVR             = 0;
   parameter  [3:0] TX_CALIB_VAL             = 0;
   parameter        TX_CM_REG_EN             = 1;
   parameter  [7:0] TX_CM_REG_KI             = 8'h80;
   parameter  [4:0] TX_PMA_RESET_TIME        = 3;
   parameter  [4:0] TX_PCS_RESET_TIME        = 3;
   parameter        TX_PMA_LOOPBACK          = 0;
   parameter        PLL_EN_ADPLL_CTRL        = 0;

   parameter        PLL_SET_OP_LOCK          = 1'h0;
   parameter        PLL_ENFORCE_LOCK         = 0;
   parameter        PLL_DISABLE_LOCK         = 0;
   parameter        PLL_LOCK_WINDOW          = 1;
   parameter        PLL_FAST_LOCK            = 1;
   parameter        PLL_SYNC_BYPASS          = 0;
   parameter        PLL_PFD_SELECT           = 0;
   parameter        PLL_REF_BYPASS           = 0;
   parameter        PLL_REF_SEL              = 0;
   parameter        PLL_REF_RTERM            = 1;
   parameter  [4:0] PLL_CI                   = 5'h3;
   parameter  [9:0] PLL_CP                   = 10'h50;
   parameter  [3:0] PLL_AO                   = 0;
   parameter  [2:0] PLL_SCAP                 = 0;
   parameter        PLL_SCAP_AUTO_CAL        = 1;
   parameter  [1:0] PLL_FILTER_SHIFT         = 2;
   parameter  [2:0] PLL_SAR_LIMIT            = 2;
   parameter [10:0] PLL_FT                   = 512;
   parameter        PLL_OPEN_LOOP            = 0;
   parameter  [2:0] PLL_BISC_MODE            = 3'b100;
   parameter  [3:0] PLL_BISC_TIMER_MAX       = 4'hC;
   parameter  [4:0] PLL_BISC_CP_MIN          = 4;
   parameter  [4:0] PLL_BISC_CP_MAX          = 5'h1E;
   parameter  [4:0] PLL_BISC_CP_START        = 5'h6;
   parameter        PLL_BISC_OPT_DET_IND     = 0;
   parameter        PLL_BISC_PFD_SEL         = 0;
   parameter        PLL_BISC_DLY_DIR         = 0;
   parameter        PLL_BISC_CAL_SIGN        = 1'h1;
   parameter        PLL_BISC_CAL_AUTO        = 1;
   parameter  [4:0] PLL_BISC_DLY_PFD_MON_REF = 0;
   parameter  [4:0] PLL_BISC_DLY_PFD_MON_DIV = 2;
   parameter  [2:0] PLL_BISC_COR_DLY         = 1;


   // SerDes Instantiation
   ccfpga_serdes #(
      .TX_BUFFER_ADDR_WIDTH     ( TX_BUFFER_ADDR_WIDTH     ),
      .RX_WAIT_CDR_LOCK         ( RX_WAIT_CDR_LOCK         ),
      .RX_RESETDONE_GATE        ( RX_RESETDONE_GATE        ),
      .RX_RESET_TIMER_PRESC     ( RX_RESET_TIMER_PRESC     ),
      .RX_PMA_RESET_TIME        ( RX_PMA_RESET_TIME        ),
      .RX_EQA_RESET_TIME        ( RX_EQA_RESET_TIME        ),
      .RX_CDR_RESET_TIME        ( RX_CDR_RESET_TIME        ),
      .RX_PCS_RESET_TIME        ( RX_PCS_RESET_TIME        ),
      .RX_BUF_RESET_TIME        ( RX_BUF_RESET_TIME        ),
      .RX_CALIB_OVR             ( RX_CALIB_OVR             ),
      .RX_CALIB_VAL             ( RX_CALIB_VAL             ),
      .RX_RTERM_VCMSEL          ( RX_RTERM_VCMSEL          ),
      .RX_RTERM_PD              ( RX_RTERM_PD              ),
      .RX_EQA_CKP_HF            ( RX_EQA_CKP_HF            ),
      .RX_EQA_CKP_LF            ( RX_EQA_CKP_LF            ),
      .RX_EQA_CONFIG            ( RX_EQA_CONFIG            ),
      .RX_EQA_CKP_OFFSET        ( RX_EQA_CKP_OFFSET        ),
      .RX_EN_EQA                ( RX_EN_EQA                ),
      .RX_EQA_LOCK_CFG          ( RX_EQA_LOCK_CFG          ),
      .RX_TH_MON1_OVR           ( RX_TH_MON1_OVR           ),
      .RX_TH_MON2_OVR           ( RX_TH_MON2_OVR           ),
      .RX_TAPW_OVR              ( RX_TAPW_OVR              ),
      .RX_AFE_OFFSET_OVR        ( RX_AFE_OFFSET_OVR        ),
      .RX_TH_MON1               ( RX_TH_MON1               ),
      .RX_TH_MON2               ( RX_TH_MON2               ),
      .RX_TAPW                  ( RX_TAPW                  ),
      .RX_AFE_OFFSET            ( RX_AFE_OFFSET            ),
      .RX_AFE_VCMSEL            ( RX_AFE_VCMSEL            ),
      .RX_AFE_GAIN              ( RX_AFE_GAIN              ),
      .RX_AFE_PEAK              ( RX_AFE_PEAK              ),
      .RX_CDR_CKP               ( RX_CDR_CKP               ),
      .RX_CDR_CKI               ( RX_CDR_CKI               ),
      .RX_CDR_LOCK_CFG          ( RX_CDR_LOCK_CFG          ),
      .RX_CDR_SET_ACC_CONFIG    ( RX_CDR_SET_ACC_CONFIG    ),
      .RX_CDR_FORCE_LOCK        ( RX_CDR_FORCE_LOCK        ),
      .RX_CDR_FREQ_ACC          ( RX_CDR_FREQ_ACC          ),
      .RX_CDR_PHASE_ACC         ( RX_CDR_PHASE_ACC         ),
      .ALIGN_MCOMMA_VALUE       ( ALIGN_MCOMMA_VALUE       ),
      .ALIGN_PCOMMA_VALUE       ( ALIGN_PCOMMA_VALUE       ),
      .ALIGN_COMMA_ENABLE       ( ALIGN_COMMA_ENABLE       ),
      .ALIGN_COMMA_WORD         ( ALIGN_COMMA_WORD         ),
      .RX_SLIDE_MODE            ( RX_SLIDE_MODE            ),
      .RX_EYE_MEAS_CFG          ( RX_EYE_MEAS_CFG          ),
      .RX_MON_PH_OFFSET         ( RX_MON_PH_OFFSET         ),
      .RX_EI_BIAS               ( RX_EI_BIAS               ),
      .RX_EI_BW_SEL             ( RX_EI_BW_SEL             ),
      .RX_BUF_BYPASS            ( RX_BUF_BYPASS            ),
      .RX_CLKCOR_USE            ( RX_CLKCOR_USE            ),
      .RX_CLKCOR_SEQ_1_0        ( RX_CLKCOR_SEQ_1_0        ),
      .RX_CLKCOR_SEQ_1_1        ( RX_CLKCOR_SEQ_1_1        ),
      .RX_CLKCOR_SEQ_1_2        ( RX_CLKCOR_SEQ_1_2        ),
      .RX_CLKCOR_SEQ_1_3        ( RX_CLKCOR_SEQ_1_3        ),
      .RX_CLKCOR_MIN_LAT        ( RX_CLKCOR_MIN_LAT        ),
      .RX_CLKCOR_MAX_LAT        ( RX_CLKCOR_MAX_LAT        ),
      .RX_DATAPATH_SEL          ( RX_DATAPATH_SEL          ),
      .RX_DBG_SRAM_DELAY        ( RX_DBG_SRAM_DELAY        ),
      .RX_DBG_SEL               ( RX_DBG_SEL               ),
      .RX_DBG_MODE              ( RX_DBG_MODE              ),
      .TX_SEL_PRE               ( TX_SEL_PRE               ),
      .TX_SEL_POST              ( TX_SEL_POST              ),
      .TX_TAIL_CASCODE          ( TX_TAIL_CASCODE          ),
      .TX_BRANCH_EN_PRE         ( TX_BRANCH_EN_PRE         ),
      .TX_BRANCH_EN_MAIN        ( TX_BRANCH_EN_MAIN        ),
      .TX_BRANCH_EN_POST        ( TX_BRANCH_EN_POST        ),
      .TX_DC_ENABLE             ( TX_DC_ENABLE             ), 
      .TX_AMP                   ( TX_AMP                   ),
      .TX_DC_OFFSET             ( TX_DC_OFFSET             ),
      .TX_CM_RAISE              ( TX_CM_RAISE              ),
      .TX_CM_THRESHOLD_0        ( TX_CM_THRESHOLD_0        ),
      .TX_CM_THRESHOLD_1        ( TX_CM_THRESHOLD_1        ),
      .TX_CALIB_OVR             ( TX_CALIB_OVR             ),
      .TX_CALIB_VAL             ( TX_CALIB_VAL             ),
      .TX_CM_REG_EN             ( TX_CM_REG_EN             ),
      .TX_CM_REG_KI             ( TX_CM_REG_KI             ),
      .TX_PMA_RESET_TIME        ( TX_PMA_RESET_TIME        ),
      .TX_PCS_RESET_TIME        ( TX_PCS_RESET_TIME        ),
      .TX_PMA_LOOPBACK          ( TX_PMA_LOOPBACK          ),
      .TX_DATAPATH_SEL          ( TX_DATAPATH_SEL          ),
      .PLL_EN_ADPLL_CTRL        ( PLL_EN_ADPLL_CTRL        ),
      .PLL_CONFIG_SEL           ( PLL_CONFIG_SEL           ),
      .PLL_SET_OP_LOCK          ( PLL_SET_OP_LOCK          ),
      .PLL_ENFORCE_LOCK         ( PLL_ENFORCE_LOCK         ),
      .PLL_DISABLE_LOCK         ( PLL_DISABLE_LOCK         ),
      .PLL_LOCK_WINDOW          ( PLL_LOCK_WINDOW          ),
      .PLL_FAST_LOCK            ( PLL_FAST_LOCK            ),
      .PLL_SYNC_BYPASS          ( PLL_SYNC_BYPASS          ),
      .PLL_PFD_SELECT           ( PLL_PFD_SELECT           ),
      .PLL_REF_BYPASS           ( PLL_REF_BYPASS           ),
      .PLL_REF_SEL              ( PLL_REF_SEL              ),
      .PLL_REF_RTERM            ( PLL_REF_RTERM            ),
      .PLL_FCNTRL               ( PLL_FCNTRL               ),
      .PLL_MAIN_DIVSEL          ( PLL_MAIN_DIVSEL          ),
      .PLL_OUT_DIVSEL           ( PLL_OUT_DIVSEL           ),
      .PLL_CI                   ( PLL_CI                   ),
      .PLL_CP                   ( PLL_CP                   ),
      .PLL_AO                   ( PLL_AO                   ),
      .PLL_SCAP                 ( PLL_SCAP                 ),
      .PLL_SCAP_AUTO_CAL        ( PLL_SCAP_AUTO_CAL        ),
      .PLL_FILTER_SHIFT         ( PLL_FILTER_SHIFT         ),
      .PLL_SAR_LIMIT            ( PLL_SAR_LIMIT            ),
      .PLL_FT                   ( PLL_FT                   ),
      .PLL_OPEN_LOOP            ( PLL_OPEN_LOOP            ),
      .PLL_BISC_MODE            ( PLL_BISC_MODE            ),
      .PLL_BISC_TIMER_MAX       ( PLL_BISC_TIMER_MAX       ),
      .PLL_BISC_CP_MIN          ( PLL_BISC_CP_MIN          ),
      .PLL_BISC_CP_MAX          ( PLL_BISC_CP_MAX          ),
      .PLL_BISC_CP_START        ( PLL_BISC_CP_START        ),
      .PLL_BISC_OPT_DET_IND     ( PLL_BISC_OPT_DET_IND     ),
      .PLL_BISC_PFD_SEL         ( PLL_BISC_PFD_SEL         ),
      .PLL_BISC_DLY_DIR         ( PLL_BISC_DLY_DIR         ),
      .PLL_BISC_CAL_SIGN        ( PLL_BISC_CAL_SIGN        ),
      .PLL_BISC_CAL_AUTO        ( PLL_BISC_CAL_AUTO        ),
      .PLL_BISC_DLY_PFD_MON_REF ( PLL_BISC_DLY_PFD_MON_REF ),
      .PLL_BISC_DLY_PFD_MON_DIV ( PLL_BISC_DLY_PFD_MON_DIV ),
      .PLL_BISC_COR_DLY         ( PLL_BISC_COR_DLY         )
      )
     i_ccfpga_serdes (
      .clk_ref_i             ( clk_ref            ),
      .clk_reg_i             ( clk_reg            ),
      .clk_cfg_i             ( clk_cfg            ),
      .clk_core_tx_i         ( clk_core_tx        ),
      .clk_core_rx_i         ( clk_core_rx_in     ),
      .clk_core_rx_o         ( clk_core_rx_rec    ),
      .reset_n_i             ( reset_n            ),
      .reset_reg_n_i         ( reset_reg_n        ),
      .reset_core_tx_n_i     ( reset_core_tx_n    ),
      .reset_core_rx_n_i     ( reset_core_rx_n    ),
      .testmode_i            ( testmode           ),
      .scan_enable_i         ( scan_enable        ),
      .scan_in_i             (                    ),  // floating ports
      .scan_out_o            (                    ),
      .loopback_i            ( loopback           ),
      .pll_reset_i           ( pll_reset          ),
      .clk_core_pll_o        ( clk_core_pll       ),
      .reset_core_pll_n_o    ( reset_core_pll_n   ),
      .refclk_sel_o          (                    ),  // floating ports
      .refclk_rterm_o        (                    ),

      .RX_SERIO_P_B          ( RX_SERIO_P         ),
      .RX_SERIO_N_B          ( RX_SERIO_N         ),
      .TX_SERIO_P_B          ( TX_SERIO_P         ),
      .TX_SERIO_N_B          ( TX_SERIO_N         ),

      .regfile_we_i          ( regfile_we         ),
      .regfile_en_i          ( regfile_en         ),
      .regfile_addr_i        ( regfile_addr       ),
      .regfile_mask_i        ( regfile_mask       ),
      .regfile_di_i          ( regfile_di         ),
      .regfile_do_o          ( regfile_do         ),
      .regfile_rdy_o         ( regfile_rdy        ),

      .cfg_en_i              ( cfg_en             ),
      .reset_cfg_i           ( reset_cfg          ),
      .cfgfile_di_i          ( cfgfile_di         ),
      .cfgfile_valid_i       ( cfgfile_valid      ),
      .cfgfile_addr_i        ( cfgfile_addr       ),

      .tx_reset_i            ( tx_reset           ),
      .tx_pcs_reset_i        ( tx_pcs_reset       ),
      .tx_pma_reset_i        ( tx_pma_reset       ),
      .tx_elec_idle_i        ( tx_elec_idle       ),
      .tx_detect_rx_i        ( tx_detect_rx       ),
      .tx_prbs_sel_i         ( tx_prbs_sel        ),
      .tx_prbs_force_err_i   ( tx_prbs_force_err  ),
      .tx_powerdown_n_i      ( tx_powerdown_n     ),
      .tx_data_i             ( tx_data            ),
      .tx_char_is_k_i        ( tx_char_is_k       ),
      .tx_polarity_i         ( tx_polarity        ),
      .tx_8b10b_en_i         ( tx_8b10b_en        ),
      .tx_8b10b_bypass_i     ( tx_8b10b_bypass    ),
      .tx_char_dispmode_i    ( tx_char_dispmode   ),
      .tx_char_dispval_i     ( tx_char_dispval    ),
      .tx_buf_err_o          ( tx_buf_err         ),
      .tx_resetdone_o        ( tx_resetdone       ),
      .rx_detect_done_o      ( rx_detect_done     ),
      .rx_present_o          ( rx_present         ),

      .TERM_SERIO_O          ( TERM_SERIO         ),

      .rx_reset_i            ( rx_reset           ),
      .rx_pma_reset_i        ( rx_pma_reset       ),
      .rx_eqa_reset_i        ( rx_eqa_reset       ),
      .rx_cdr_reset_i        ( rx_cdr_reset       ),
      .rx_pcs_reset_i        ( rx_pcs_reset       ),
      .rx_buf_reset_i        ( rx_buf_reset       ),
      .rx_prbs_sel_i         ( rx_prbs_sel        ),
      .rx_prbs_cnt_reset_i   ( rx_prbs_cnt_reset  ),
      .rx_powerdown_n_i      ( rx_powerdown_n     ),
      .rx_en_ei_detector_i   ( rx_en_ei_detector  ),
      .rx_comma_detect_en_i  ( rx_comma_detect_en ),
      .rx_slide_i            ( rx_slide           ),
      .rx_polarity_i         ( rx_polarity        ),
      .rx_8b10b_en_i         ( rx_8b10b_en        ),
      .rx_8b10b_bypass_i     ( rx_8b10b_bypass    ),
      .rx_mcomma_align_i     ( rx_mcomma_align    ),
      .rx_pcomma_align_i     ( rx_pcomma_align    ),
      .rx_prbs_err_o         ( rx_prbs_err        ),
      .rx_data_o             ( rx_data            ),
      .rx_char_is_k_o        ( rx_char_is_k       ),
      .rx_char_is_comma_o    ( rx_char_is_comma   ),
      .rx_not_in_table_o     ( rx_not_in_table    ),
      .rx_disp_err_o         ( rx_disp_err        ),
      .rx_buf_err_o          ( rx_buf_err         ),
      .rx_byte_is_aligned_o  ( rx_byte_is_aligned ),
      .rx_byte_realign_o     ( rx_byte_realign    ),
      .rx_resetdone_o        ( rx_resetdone       ),
      .rx_ei_en_o            ( rx_ei_en           )
      );

`ifdef PIPE

   // PIPE Logic Instantiation
   ccfpga_pipe_logic #(
      .DATA_BYTES ( DATA_BYTES )
   )
   pipe_logic_inst ( 
      .o_PCLK               ( o_PCLK             ),
      .i_Reset              ( i_Reset            ),
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
      .o_tx_buf_err         ( o_tx_buf_error     ),
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
      .o_rx_powerdown_n     ( rx_powerdown_n     ),
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

`endif

   // Clock Generation

   parameter CLKPERIOD_REF = 10.0;  // ADPLL
   parameter CLKPERIOD_REG = 8.0;   // Register
   parameter CLKPERIOD_CFG = 40.0;  // Config

   initial clk_ref = 1'b1;
   always #(CLKPERIOD_REF / 2) clk_ref = ~clk_ref;  // 100 MHz

   initial clk_reg = 1'b1;
   always #(CLKPERIOD_REG / 2) clk_reg = ~clk_reg;  // 125 MHz

   initial clk_cfg = 1'b1;
   always #(CLKPERIOD_CFG / 2) clk_cfg = ~clk_cfg;  // 25 MHz

   // Reset Generation (SerDes and Regfile)

   initial  // ADPLL
     begin
        reset_n = 1'b0;
        #(CLKPERIOD_REF * 10 + 1);
        reset_n = 1'b1;
     end

   initial  // Register
     begin
        reset_reg_n = 1'b0;
        #(CLKPERIOD_REG * 10 + 1);
        reset_reg_n = 1'b1;
     end

   // Testbench Tasks and Functions

   function real round(input real number);
      begin
         round = ( number < 0.0 ) ? $ceil(number - 0.5) : $floor(number + 0.5);
      end
   endfunction // round

   task finalize();
      begin
         $display("");
         if ( checks_done == 0 )
           begin
              $display(" #   #  #   #  #  #  #   #   ###   #   #  #   #");
              $display(" #   #  ##  #  # #   ##  #  #   #  #   #  ##  #");
              $display(" #   #  # # #  ###   # # #  #   #  # # #  # # #");
              $display(" #   #  #  ##  # #   #  ##  #   #  # # #  #  ##");
              $display("  ###   #   #  #  #  #   #   ###   ## ##  #   #");
         //     $display("\nRI_TESTBENCH:WARNING:SIMUNKNOWN: Test result Unknown");
           end
         else if ( errors > 0 )
           begin
              $display(" #####   ###   #  #      #####  #### ");
              $display(" #      #   #  #  #      #      #   #");
              $display(" ###    #####  #  #      ###    #   #");
              $display(" #      #   #  #  #      #      #   #");
              $display(" #      #   #  #  #####  #####  #### ");
         //     $display("\nRI_TESTBENCH:ERROR:SIMFAIL: Test FAILed");
           end
         else
           begin
              $display(" ####    ###    ####  ####  #####  #### ");
              $display(" #   #  #   #  #     #      #      #   #");
              $display(" ####   #####   ###   ###   ###    #   #");
              $display(" #      #   #      #     #  #      #   #");
              $display(" #      #   #  ####  ####   #####  #### ");
         //     $display("\nRI_TESTBENCH:NOTE:SIMPASS: Test PASSed");
           end // else: !if( errors > 0 )
         $finish;
      end
   endtask // finalize

   task writeCfg(input  [7:0] addr,
                 input [15:0] data);
      begin
         @(posedge clk_cfg); #1;
         cfg_en = 1'b1;
         @(posedge clk_cfg); #1;
         @(posedge clk_cfg); #1;
         cfgfile_valid = 1'b1;
         cfgfile_di    = data;
         cfgfile_addr  = addr;
         @(posedge clk_cfg); #1;
         cfgfile_valid = 1'b0;
         cfgfile_di    = 16'h0;
         cfgfile_addr  = 8'h0;
         @(posedge clk_cfg); #1;
         @(posedge clk_cfg); #1;
         cfg_en = 1'b0;
      end
   endtask // writeCfg

   task writeRegfile(input  [7:0] addr,
                     input [15:0] data,
                     input [15:0] mask);
      integer cnt;
      begin
         @(posedge clk_reg); #1.5;
         regfile_en   = 1'b1;
         regfile_we   = 1'b1;
         regfile_addr = addr;
         regfile_mask = mask;
         regfile_di   = data;
         @(posedge clk_reg); #1.5;
         regfile_en   = 1'b0;
         regfile_we   = 1'b0;
         regfile_addr = 8'h0;
         regfile_mask = 16'h0;
         regfile_di   = 16'h0;
         while ( regfile_rdy !== 1'b1 )
           begin
              @(posedge clk_reg); #1.5;
              cnt = cnt + 1;
              if ( cnt == 32 )
                begin
                   checks_done = checks_done + 1;
                   $display("ERROR: Waiting for Register File ready timed out.");
                   errors = errors + 1;
                end
           end // while ( regfile_rdy !== 1'b1 )
      end
   endtask // writeRegfile

   task readRegfile(input   [7:0] addr,
                    output [15:0] data);
      integer cnt;
      begin
         @(posedge clk_reg); #1;
         regfile_en   = 1'b1;
         regfile_we   = 1'b0;
         regfile_addr = addr;
         @(posedge clk_reg); #1;
         regfile_en   = 1'b0;
         regfile_addr = 8'h0;
         cnt = 0;
         while ( regfile_rdy !== 1'b1 )
           begin
              @(posedge clk_reg); #1;
              cnt = cnt + 1;
              if ( cnt == 32 )
                begin
                   checks_done = checks_done + 1;
                   $display("ERROR: Waiting for Register File ready timed out.");
                   errors = errors + 1;
                end
           end // while ( regfile_rdy !== 1'b1 )
         data = regfile_do;
      end
   endtask // readRegfile

   task writeCfgFile(input  [7:0] addr,
                     input [15:0] data);
     begin
        @(posedge clk_cfg); #1;
        cfg_en          = 1'b1;
        cfgfile_valid = 1'b1;
        cfgfile_addr    = addr;
        cfgfile_di      = data;
        @(posedge clk_cfg); #1;
        cfg_en          = 1'b0;
        cfgfile_valid = 1'b0;
        cfgfile_addr    = 1'b0;
        cfgfile_di      = 1'b0;
     end
   endtask // writeCfgFile

   task readSerIOADPLLStatus(output [31:0] status);
      reg [31:0] pll_status;
      begin
         readRegfile(8'h55, pll_status[15:0]);
         readRegfile(8'h56, pll_status[31:16]);
         checks_done = checks_done + 1;
         if ( (^pll_status) === 1'bx )
           begin
              $display("ERROR: SerIO ADPLL status is invalid.");
              errors = errors + 1;
              finalize;
           end
         status = pll_status;
      end
   endtask // readSerIOADPLLStatus

   task startSerIOADPLL(input integer mainDivN1,      // N1 and N2 Names are twisted compared to Spec
                        input integer mainDivN2,
                        input integer mainDivN3,
                        input integer outDiv,
                        input         enableCalib);
      real        dcoFreq;
      real        freq;
      reg   [7:0] unit;
      reg  [15:0] pllDiv;
      reg  [31:0] status;
      reg  [31:0] bisc_result;
      time        start;
      integer     i;
      begin
         $display("INFO: Configuring SerIO ADPLL ...");

         checks_done = checks_done + 1;
         if ( mainDivN1 < 2 || mainDivN1 > 5 )
           begin
              $display("ERROR: Main divider N1 of SerIO ADPLL is limited to 2, 3, 4 or 5.");
              errors = errors + 1;
              finalize;
           end

         checks_done = checks_done + 1;
         if ( mainDivN2 < 1 || mainDivN2 > 2 )
           begin
              $display("ERROR: Main divider N2 of SerIO ADPLL is limited to 1 or 2.");
              errors = errors + 1;
              finalize;
           end

         checks_done = checks_done + 1;
         if ( mainDivN3 < 3 || mainDivN3 > 5 )
           begin
              $display("ERROR: Main divider N3 of SerIO ADPLL is limited to 3, 4 or 5.");
              errors = errors + 1;
              finalize;
           end

         checks_done = checks_done + 1;
         if ( outDiv != 1 && outDiv != 2 && outDiv != 4 )
           begin
              $display("ERROR: Output divider of SerIO ADPLL is limited to 1, 2 or 4.");
              errors = errors + 1;
              finalize;
           end

         dcoFreq = 1000.0 / CLKPERIOD_REF * mainDivN1 * mainDivN2 * mainDivN3;
         freq = dcoFreq / outDiv;
         unit = "M";
         if ( $rtoi(round(freq * 1000.0)) > 1000000 )
           begin
              freq = freq / 1000;
              unit = "G";
           end

         $display("INFO: SerIO ADPLL frequency will be %.3f %cHz.",
                  freq, unit);
         pllDiv = ( ( outDiv == 1 ) ? 16'h0000 :
                    ( outDiv == 2 ) ? 16'h1000 : 16'h3000 );
         if ( mainDivN1 == 5 )
           pllDiv[7:6] = 2'b11;
         else if ( mainDivN1 == 4 )
           pllDiv[7:6] = 2'b10;
         else if ( mainDivN1 == 2 )
           pllDiv[7:6] = 2'b01;

         if ( mainDivN2 == 2 )
           pllDiv[8] = 1'b1;

         if ( mainDivN3 == 5 )
           pllDiv[10:9] = 2'b11;
         else if ( mainDivN3 == 4 )
           pllDiv[10:9] = 2'b10;

         $display("INFO: Checking state of SerIO ADPLL ...");
         readSerIOADPLLStatus(status);
         if ( status[0] == 1'b1 )
           begin
              $display("INFO: Disabling SerIO ADPLL ...");
              writeRegfile(8'h50, 16'h0000, 16'h0001);
              for ( i = 0; i < 100; i = i + 1 )
                begin
                   @(posedge clk_reg); #1;
                end
           end

         $display("INFO: Writing SerIO ADPLL divider settings ...");
         writeRegfile(8'h51, pllDiv, 16'h3FC0);
         if ( enableCalib === 1'b1 )
           begin
              $display("INFO: Stopping ADPLL self-calibration ...");
              writeRegfile(8'h57, 16'h0004, 16'h0007);
              writeRegfile(8'h57,
                           ( ( ADPLL_PFDAC_TIMER    & 16'h000F ) <<  3 ) |
                           ( ( ADPLL_PFDAC_COR_DLY  & 16'h0007 ) << 10 ) |
                           ( ( ADPLL_PFDAC_CAL_SIGN & 16'h0001 ) << 13 ) |
                           ( ( ADPLL_PFDAC_AUTO_CAL & 16'h0001 ) << 14 ),
                           16'hFFF8);
              writeRegfile(16'h58,
                           ( ( ADPLL_PFDAC_CP_MIN   & 16'h001F ) << 0  ) |
                           ( ( ADPLL_PFDAC_CP_MAX   & 16'h001F ) << 5  ) |
                           ( ( ADPLL_PFDAC_CP_START & 16'h001F ) << 10 ),
                           16'hFFFF);
           end // if ( enableCalib === 1'b1 )

         $display("INFO: Starting SerIO ADPLL ...");
         writeRegfile(8'h50, 16'h0002, 16'h0007);  // Config Sel
         writeRegfile(8'h50, 16'h0003, 16'h0003);  // Config Sel + ADPLL Enable

         if ( enableCalib === 1'b1 )
           begin
              $display("INFO: Starting ADPLL self-calibration ...");
              writeRegfile(8'h57, 16'h0004, 16'h0007);
              writeRegfile(8'h57, 16'h0005, 16'h0007);
           end

         $display("INFO: Waiting for SerIO ADPLL to lock ...");
         start = $realtime;
         status = 16'h0;
         while ( status[0] == 1'b0 )
           begin
              for ( i = 0; i < 1000; i = i + 1 )
                begin
                   @(posedge clk_reg); #1;
                end
              readSerIOADPLLStatus(status);
              if ( status[0] == 1'b0 )
                $display("INFO: LCK: %1d   FTO: %1d   FTU: %1d   FT: %4d  SY: %3d  ST: %1d",
                         status[0], status[1], status[2],
                         status[12:3], status[23:16], status[14:13]);
              if ( ( $realtime - start ) > 2000000 && status[0] == 1'b0 )
                begin
                   checks_done = checks_done + 1;
                   $display("ERROR: Waiting for SerIO ADPLL lock timed out.");
                   errors = errors + 1;
                   finalize;
                end
           end // while ( status[0] == 1'b0 )

         if ( enableCalib === 1'b1 )
           begin
              readRegfile(8'h5A, bisc_result[15:0]);
              readRegfile(8'h5B, bisc_result[31:16]);
              if ( (^bisc_result) === 1'bx )
                begin
                   $display("ERROR: SerIO ADPLL BISC result is invalid.");
                   errors = errors + 1;
                   finalize;
                end

              $display("INFO: PFDAC Result: Done: %1d, Counter: %6d, CP: %2d",
                       bisc_result[0], bisc_result[31:16],
                       bisc_result[7:1]);
           end // if ( enableCalib === 1'b1 )

         $display("INFO: SerIO ADPLL locked.");
         $display("INFO: LCK: %1d   FTO: %1d   FTU: %1d   FT: %4d  SY: %3d  ST: %1d",
                  status[0], status[1], status[2],
                  status[12:3], status[23:16], status[14:13]);
      end
   endtask // startSerIOADPLL


`ifdef SERDES

   task resetSerDes();
      integer cnt;
      reg     done;
      begin
         tx_reset = 1'b1;
         cnt = 0;
         done = 1'b0;
         @(posedge clk_core_tx); #1;
         while ( done == 1'b0 )
           begin
              if ( tx_resetdone === 1'b0 )
                done = 1'b1;
              else
                begin
                   checks_done = checks_done + 1;
                   if ( tx_resetdone === 1'bx )
                     begin
                        $display("ERROR: TX Resetdone indicator is invalid.");
                        errors = errors + 1;
                        finalize;
                     end
                   cnt = cnt + 1;
                   if ( cnt == 64 )
                     begin
                        checks_done = checks_done + 1;
                        $display("ERROR: Waiting for TX Resetdone release timed out.");
                        errors = errors + 1;
                        finalize;
                     end
                end // else: !if( tx_resetdone === 1'b0 )
              @(posedge clk_core_tx); #1;
           end // while ( done == 1'b0 )

         tx_reset = 1'b0;
         cnt = 0;
         done = 1'b0;
         while ( done == 1'b0 )
           begin
              if ( tx_resetdone === 1'b1 )
                done = 1'b1;
              else
                begin
                   checks_done = checks_done + 1;
                   if ( tx_resetdone === 1'bx )
                     begin
                        $display("ERROR: TX Resetdone indicator is invalid.");
                        errors = errors + 1;
                        finalize;
                     end
                   cnt = cnt + 1;
                   if ( cnt == 64 )
                     begin
                        checks_done = checks_done + 1;
                        $display("ERROR: Waiting for TX Resetdone set timed out.");
                        errors = errors + 1;
                        finalize;
                     end
                end // else: !if( tx_resetdone === 1'b1 )
              @(posedge clk_core_tx); #1;
           end // while ( done == 1'b0 )

         rx_reset = 1'b1;
         cnt = 0;
         done = 1'b0;
         @(posedge clk_core_rx_in); #1;
         while ( done == 1'b0 )
           begin
              if ( rx_resetdone === 1'b0 )
                done = 1'b1;
              else
                begin
                   checks_done = checks_done + 1;
                   if ( rx_resetdone === 1'bx )
                     begin
                        $display("ERROR: RX Resetdone indicator is invalid.");
                        errors = errors + 1;
                        finalize;
                     end
                   cnt = cnt + 1;
                   if ( cnt == 64 )
                     begin
                        checks_done = checks_done + 1;
                        $display("ERROR: Waiting for RX Resetdone release timed out.");
                        errors = errors + 1;
                        finalize;
                     end
                end // else: !if( rx_resetdone === 1'b0 )
              @(posedge clk_core_rx_in); #1;
           end // while ( done == 1'b0 )

         rx_reset = 1'b0;
         cnt = 0;
         done = 1'b0;
         while ( done == 1'b0 )
           begin
              if ( rx_resetdone === 1'b1 )
                done = 1'b1;
              else
                begin
                   checks_done = checks_done + 1;
                   if ( rx_resetdone === 1'bx )
                     begin
                        $display("ERROR: RX Resetdone indicator is invalid.");
                        errors = errors + 1;
                        finalize;
                     end
                   cnt = cnt + 1;
                   if ( cnt == 128 )
                     begin
                        checks_done = checks_done + 1;
                        $display("ERROR: Waiting for RX Resetdone set timed out.");
                        errors = errors + 1;
                        finalize;
                     end
                end // else: !if( rx_resetdone === 1'b1 )
              @(posedge clk_core_rx_in); #1;
           end // while ( done == 1'b0 )
      end
   endtask // resetSerDes

`endif

initial begin
    $dumpfile("sim/vlog_sim.vcd");
    $dumpvars(0, tb_ccfpga_serdes);
end

// Include Testcases

 `ifdef PIPE
    `include "testcase_pipe.v"
 `elsif SERDES 
    `include "testcase_serdes.v"
 `else
    $display("ERROR: TESTCASE NOT DEFINED")
 `endif

endmodule // tb_ccfpga_serdes