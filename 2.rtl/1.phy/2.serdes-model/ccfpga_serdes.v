`timescale 1ns/100fs

module ccfpga_serdes (
                      clk_ref_i,
                      clk_reg_i,
                      clk_cfg_i,
                      clk_core_tx_i,
                      clk_core_rx_i,
                      clk_core_rx_o,
                      reset_n_i,
                      reset_reg_n_i,
                      reset_core_tx_n_i,
                      reset_core_rx_n_i,
                      testmode_i,
                      scan_enable_i,
                      scan_in_i,
                      scan_out_o,
                      loopback_i,
                      pll_reset_i,
                      clk_core_pll_o,
                      reset_core_pll_n_o,
                      refclk_sel_o,
                      refclk_rterm_o,
                      RX_SERIO_P_B,
                      RX_SERIO_N_B,
                      TX_SERIO_P_B,
                      TX_SERIO_N_B,
                      regfile_we_i,
                      regfile_en_i,
                      regfile_addr_i,
                      regfile_mask_i,
                      regfile_di_i,
                      regfile_do_o,
                      regfile_rdy_o,
                      cfg_en_i,
                      reset_cfg_i,
                      cfgfile_di_i,
                      cfgfile_valid_i,
                      cfgfile_addr_i,
                      tx_reset_i,
                      tx_pcs_reset_i,
                      tx_pma_reset_i,
                      tx_elec_idle_i,
                      tx_detect_rx_i,
                      tx_prbs_sel_i,
                      tx_prbs_force_err_i,
                      tx_powerdown_n_i,
                      tx_data_i,
                      tx_char_is_k_i,
                      tx_polarity_i,
                      tx_8b10b_en_i,
                      tx_8b10b_bypass_i,
                      tx_char_dispmode_i,
                      tx_char_dispval_i,
                      tx_buf_err_o,
                      tx_resetdone_o,
                      rx_detect_done_o,
                      rx_present_o,
                      TERM_SERIO_O,
                      rx_reset_i,
                      rx_pma_reset_i,
                      rx_eqa_reset_i,
                      rx_cdr_reset_i,
                      rx_pcs_reset_i,
                      rx_buf_reset_i,
                      rx_prbs_sel_i,
                      rx_prbs_cnt_reset_i,
                      rx_powerdown_n_i,
                      rx_en_ei_detector_i,
                      rx_comma_detect_en_i,
                      rx_slide_i,
                      rx_polarity_i,
                      rx_8b10b_en_i,
                      rx_8b10b_bypass_i,
                      rx_mcomma_align_i,
                      rx_pcomma_align_i,
                      rx_prbs_err_o,
                      rx_data_o,
                      rx_char_is_k_o,
                      rx_char_is_comma_o,
                      rx_not_in_table_o,
                      rx_disp_err_o,
                      rx_buf_err_o,
                      rx_byte_is_aligned_o,
                      rx_byte_realign_o,
                      rx_resetdone_o,
                      rx_ei_en_o
                      );

   parameter TX_BUFFER_ADDR_WIDTH = 5;

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
   parameter  [4:0] RX_AFE_PEAK              = 16;
   parameter  [7:0] RX_CDR_CKP               = {3'b101, 5'b01111};
   parameter  [7:0] RX_CDR_CKI               = {3'b000, 5'b00000};
   parameter [14:0] RX_CDR_LOCK_CFG          = 15'b000_1000_1101_0101;
   parameter  [1:0] RX_CDR_SET_ACC_CONFIG    = 2'b00;
   parameter        RX_CDR_FORCE_LOCK        = 0;
   parameter [14:0] RX_CDR_FREQ_ACC          = 15'h0;
   parameter [15:0] RX_CDR_PHASE_ACC         = 16'h0;
   parameter  [9:0] ALIGN_MCOMMA_VALUE       = 10'b1010000011;
   parameter  [9:0] ALIGN_PCOMMA_VALUE       = 10'b0101111100;
   parameter  [9:0] ALIGN_COMMA_ENABLE       = 10'b1111111111;
   parameter  [1:0] ALIGN_COMMA_WORD         = 2'b00;
   parameter  [1:0] RX_SLIDE_MODE            = 0;
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
   parameter  [1:0] RX_DATAPATH_SEL          = 3;
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
   parameter  [1:0] TX_DATAPATH_SEL          = 3;
   parameter        PLL_EN_ADPLL_CTRL        = 0;
   parameter        PLL_CONFIG_SEL           = 0;
   parameter        PLL_SET_OP_LOCK          = 1;
   parameter        PLL_ENFORCE_LOCK         = 0;
   parameter        PLL_DISABLE_LOCK         = 0;
   parameter        PLL_LOCK_WINDOW          = 1;
   parameter        PLL_FAST_LOCK            = 1;
   parameter        PLL_SYNC_BYPASS          = 0;
   parameter        PLL_PFD_SELECT           = 0;
   parameter        PLL_REF_BYPASS           = 0;
   parameter        PLL_REF_SEL              = 0;
   parameter        PLL_REF_RTERM            = 1;
   parameter  [5:0] PLL_FCNTRL               = 58;
   parameter  [5:0] PLL_MAIN_DIVSEL          = 27;
   parameter  [1:0] PLL_OUT_DIVSEL           = 0;
   parameter  [4:0] PLL_CI                   = 1;
   parameter  [9:0] PLL_CP                   = 60;
   parameter  [3:0] PLL_AO                   = 0;
   parameter  [2:0] PLL_SCAP                 = 0;
   parameter        PLL_SCAP_AUTO_CAL        = 1;
   parameter  [1:0] PLL_FILTER_SHIFT         = 2;
   parameter  [2:0] PLL_SAR_LIMIT            = 2;
   parameter [10:0] PLL_FT                   = 512;
   parameter        PLL_OPEN_LOOP            = 0;
   parameter  [2:0] PLL_BISC_MODE            = 3'b100;
   parameter  [3:0] PLL_BISC_TIMER_MAX       = 15;
   parameter  [4:0] PLL_BISC_CP_MIN          = 4;
   parameter  [4:0] PLL_BISC_CP_MAX          = 18;
   parameter  [4:0] PLL_BISC_CP_START        = 12;
   parameter        PLL_BISC_OPT_DET_IND     = 0;
   parameter        PLL_BISC_PFD_SEL         = 0;
   parameter        PLL_BISC_DLY_DIR         = 0;
   parameter        PLL_BISC_CAL_SIGN        = 0;
   parameter        PLL_BISC_CAL_AUTO        = 1;
   parameter  [4:0] PLL_BISC_DLY_PFD_MON_REF = 0;
   parameter  [4:0] PLL_BISC_DLY_PFD_MON_DIV = 2;
   parameter  [2:0] PLL_BISC_COR_DLY         = 1;

   parameter real   BHV_PLL_LOCK_TIME_NS     = 500.0;
   parameter real   BHV_REF_CLK_MHZ          = 0.0;
   parameter        BHV_RX_PRESENT           = 1;
   parameter real   BHV_RX_DETECT_TIME_NS    = 120.0;
   parameter real   BHV_CDR_KP               = 0.125;
   parameter        BHV_CDR_LOCK_EDGES       = 32;
   parameter        BHV_VERBOSE              = 0;
   parameter integer BHV_RX_PIPE_STAGES      = 9;
   parameter real   BHV_RX_TCO_NS            = 0.1;

   input         clk_ref_i;
   input         clk_reg_i;
   input         clk_cfg_i;
   input         clk_core_tx_i;
   input         clk_core_rx_i;
   output        clk_core_rx_o;
   input         reset_n_i;
   input         reset_reg_n_i;
   input         reset_core_tx_n_i;
   input         reset_core_rx_n_i;
   input         testmode_i;
   input         scan_enable_i;
   input   [6:0] scan_in_i;
   output  [6:0] scan_out_o;
   input   [2:0] loopback_i;
   input         pll_reset_i;
   output        clk_core_pll_o;
   output        reset_core_pll_n_o;
   output        refclk_sel_o;
   output        refclk_rterm_o;

   input         RX_SERIO_P_B;
   input         RX_SERIO_N_B;
   output        TX_SERIO_P_B;
   output        TX_SERIO_N_B;

   input         regfile_we_i;
   input         regfile_en_i;
   input   [7:0] regfile_addr_i;
   input  [15:0] regfile_mask_i;
   input  [15:0] regfile_di_i;
   output [15:0] regfile_do_o;
   output        regfile_rdy_o;

   input         cfg_en_i;
   input         reset_cfg_i;
   input  [15:0] cfgfile_di_i;
   input         cfgfile_valid_i;
   input   [7:0] cfgfile_addr_i;

   input         tx_reset_i;
   input         tx_pcs_reset_i;
   input         tx_pma_reset_i;
   input         tx_elec_idle_i;
   input         tx_detect_rx_i;
   input   [2:0] tx_prbs_sel_i;
   input         tx_prbs_force_err_i;
   input         tx_powerdown_n_i;
   input  [63:0] tx_data_i;
   input   [7:0] tx_char_is_k_i;
   input         tx_polarity_i;
   input         tx_8b10b_en_i;
   input   [7:0] tx_8b10b_bypass_i;
   input   [7:0] tx_char_dispmode_i;
   input   [7:0] tx_char_dispval_i;
   output        tx_buf_err_o;
   output        tx_resetdone_o;
   output        rx_detect_done_o;
   output        rx_present_o;

   input         rx_reset_i;
   input         rx_pma_reset_i;
   input         rx_eqa_reset_i;
   input         rx_cdr_reset_i;
   input         rx_pcs_reset_i;
   input         rx_buf_reset_i;
   input   [2:0] rx_prbs_sel_i;
   input         rx_prbs_cnt_reset_i;
   input         rx_powerdown_n_i;
   input         rx_en_ei_detector_i;
   input         rx_comma_detect_en_i;
   input         rx_slide_i;
   input         rx_polarity_i;
   input         rx_8b10b_en_i;
   input   [7:0] rx_8b10b_bypass_i;
   input         rx_mcomma_align_i;
   input         rx_pcomma_align_i;
   output        rx_prbs_err_o;
   output [63:0] rx_data_o;
   output  [7:0] rx_char_is_k_o;
   output  [7:0] rx_char_is_comma_o;
   output  [7:0] rx_not_in_table_o;
   output  [7:0] rx_disp_err_o;
   output        rx_buf_err_o;
   output        rx_byte_is_aligned_o;
   output        rx_byte_realign_o;
   output        rx_resetdone_o;
   output        rx_ei_en_o;

   output        TERM_SERIO_O;

`include "ccfpga_serdes_8b10b.vh"
`include "ccfpga_serdes_8b10b_dec.vh"

   localparam PLL_CFG0_ADDR   = 8'h50;
   localparam PLL_CFG1_ADDR   = 8'h51;
   localparam PLL_CFG5_ADDR   = 8'h55;
   localparam PLL_CFG6_ADDR   = 8'h56;
   localparam SERDES_CFG_ADDR = 8'h5C;

   reg [15:0] rf [0:255];
   integer    rf_i;

   reg        serdes_en;
   reg        rx_serdes_auto_init;
   reg        serdes_testmode;

   reg [11:0] pll_op;
   reg [13:0] pll_div;

   reg        regfile_rdy_r;
   reg [15:0] regfile_do_r;
   reg        regfile_en_d;

   wire [7:0]  rf_addr    = cfg_en_i ? cfgfile_addr_i : regfile_addr_i;
   wire [15:0] rf_di      = cfg_en_i ? cfgfile_di_i   : regfile_di_i;
   wire [15:0] rf_mask    = cfg_en_i ? 16'hFFFF       : regfile_mask_i;
   wire        cfg_write  = cfg_en_i & cfgfile_valid_i;
   wire        cfg_rst    = cfg_en_i & reset_cfg_i;
   wire        rf_write   = (regfile_en_i & ~regfile_en_d & ~cfg_en_i & regfile_we_i)
                            | cfg_write;
   wire        rf_read    = regfile_en_i & ~regfile_en_d & ~cfg_en_i & ~regfile_we_i;

   assign regfile_do_o  = regfile_do_r;
   assign regfile_rdy_o = regfile_rdy_r;

   assign refclk_sel_o   = pll_op[10];
   assign refclk_rterm_o = pll_op[11];

   localparam [15:0] PLL_STATUS_LO = 16'h0001;
   localparam [15:0] PLL_STATUS_HI = 16'h0000;

   task rf_reset;
      begin
         for (rf_i = 0; rf_i < 256; rf_i = rf_i + 1)
           rf[rf_i] = 16'h0;
         serdes_en           = 1'b0;
         rx_serdes_auto_init = 1'b0;
         serdes_testmode     = 1'b0;
         pll_op              = {PLL_REF_RTERM[0], PLL_REF_SEL[0], PLL_REF_BYPASS[0],
                                PLL_PFD_SELECT[0], PLL_SYNC_BYPASS[0], PLL_FAST_LOCK[0],
                                PLL_LOCK_WINDOW[0], PLL_DISABLE_LOCK[0], PLL_ENFORCE_LOCK[0],
                                PLL_SET_OP_LOCK[0], PLL_CONFIG_SEL[0], PLL_EN_ADPLL_CTRL[0]};
         pll_div             = {PLL_OUT_DIVSEL, PLL_MAIN_DIVSEL, PLL_FCNTRL};
         rf[PLL_CFG0_ADDR]   = {4'h0, pll_op};
         rf[PLL_CFG1_ADDR]   = {2'h0, pll_div};
         rf[SERDES_CFG_ADDR] = 16'h0;
      end
   endtask

   always @(posedge clk_reg_i or negedge reset_reg_n_i) begin
      if (!reset_reg_n_i) begin
         rf_reset;
         regfile_en_d  <= 1'b0;
         regfile_rdy_r <= 1'b0;
         regfile_do_r  <= 16'h0;
      end
      else begin
         regfile_en_d  <= regfile_en_i;
         regfile_rdy_r <= 1'b0;

         if (cfg_rst)
           rf_reset;
         else begin
            if (rf_write) begin
               rf[rf_addr] <= (rf[rf_addr] & ~rf_mask) | (rf_di & rf_mask);

               case (rf_addr)
                 SERDES_CFG_ADDR :
                   if (cfg_write) begin
                      serdes_en           <= rf_di[0];
                      rx_serdes_auto_init <= rf_di[1];
                      serdes_testmode     <= rf_di[2];
                   end
                 PLL_CFG0_ADDR : begin
                    if (rf_mask[0])  pll_op[0]    <= rf_di[0];
                    if (!rf_di[0] || cfg_write)
                      pll_op[9:1] <= (pll_op[9:1] & ~rf_mask[9:1]) | (rf_di[9:1] & rf_mask[9:1]);
                    if (rf_mask[10]) pll_op[10]   <= rf_di[10];
                    if (rf_mask[11]) pll_op[11]   <= rf_di[11];
                 end
                 PLL_CFG1_ADDR :
                   if (!pll_op[0] || cfg_write)
                     pll_div <= (pll_div & ~rf_mask[13:0]) | (rf_di[13:0] & rf_mask[13:0]);
                 default : ;
               endcase
               regfile_rdy_r <= ~cfg_en_i;
            end
            else if (rf_read) begin
               case (rf_addr)
                 PLL_CFG0_ADDR   : regfile_do_r <= {4'h0, pll_op};
                 PLL_CFG1_ADDR   : regfile_do_r <= {2'h0, pll_div};
                 PLL_CFG5_ADDR   : regfile_do_r <= PLL_STATUS_LO;
                 PLL_CFG6_ADDR   : regfile_do_r <= PLL_STATUS_HI;
                 SERDES_CFG_ADDR : regfile_do_r <= {13'h0, serdes_testmode,
                                                    rx_serdes_auto_init, serdes_en};
                 default         : regfile_do_r <= rf[rf_addr];
               endcase
               regfile_rdy_r <= 1'b1;
            end
         end
      end
   end

   wire [5:0] cfg_main_divsel = pll_div[11:6];
   wire [1:0] cfg_out_divsel  = pll_div[13:12];

   wire integer n1 = (cfg_main_divsel[2] == 1'b0) ? 1 : 2;
   wire integer n2 = (cfg_main_divsel[1:0] == 2'b00) ? 3 :
                     (cfg_main_divsel[1:0] == 2'b01) ? 2 :
                     (cfg_main_divsel[1:0] == 2'b10) ? 4 : 5;
   wire integer n3 = (cfg_main_divsel[4:3] == 2'b00) ? 3 :
                     (cfg_main_divsel[4:3] == 2'b10) ? 4 :
                     (cfg_main_divsel[4:3] == 2'b11) ? 5 : 1;
   wire integer m3 = (cfg_out_divsel == 2'b01) ? 2 :
                     (cfg_out_divsel == 2'b11) ? 4 : 1;

   real    ref_period;
   real    ref_last_edge;
   real    ui;
   real    core_period;

   reg     ref_seen;

   initial begin
      ref_period    = (BHV_REF_CLK_MHZ > 0.0) ? (1000.0 / BHV_REF_CLK_MHZ) : 10.0;
      ref_last_edge = -1.0;
      ref_seen      = (BHV_REF_CLK_MHZ > 0.0);
      ui            = 0.4;
      core_period   = 32.0;
   end

   always @(posedge clk_ref_i) begin
      if (BHV_REF_CLK_MHZ <= 0.0) begin
         if (ref_last_edge >= 0.0) begin
            ref_period = $realtime - ref_last_edge;
            ref_seen   = 1'b1;
         end
         ref_last_edge = $realtime;
      end
   end

   always @(*) begin
      if (ref_seen && (ref_period > 0.0)) begin
         ui          = (ref_period * m3) / (1.0 * n1 * n2 * n3 * 2);
         core_period = ui * 80.0;
      end
   end

   wire pll_enabled = reset_n_i & ~pll_reset_i & serdes_en & pll_op[0];

   reg  pll_locked;
   reg  clk_core_pll_r;

   assign clk_core_pll_o     = clk_core_pll_r;
   assign reset_core_pll_n_o = pll_locked & reset_n_i;

   initial begin
      pll_locked     = 1'b0;
      clk_core_pll_r = 1'b0;
   end

   always @(pll_enabled) begin : pll_lock_seq
      if (!pll_enabled)
        pll_locked = 1'b0;
      else begin
         pll_locked = 1'b0;
         fork
            begin : lock_wait
               #(BHV_PLL_LOCK_TIME_NS);
               if (pll_enabled) begin
                  pll_locked = 1'b1;
                  if (BHV_VERBOSE)
                    $display("[%0t] %m: PLL locked, line rate %.3f Gb/s, core clk %.3f MHz",
                             $time, 1.0 / ui, 1000.0 / core_period);
               end
            end
            begin : lock_abort
               @(pll_enabled);
            end
         join_any
         disable fork;
      end
   end

   always begin : core_clk_gen
      if (pll_locked && (core_period > 0.0)) begin
         #(core_period / 2.0);
         clk_core_pll_r = ~clk_core_pll_r;
      end
      else begin
         clk_core_pll_r = 1'b0;
         @(pll_locked);
      end
   end

   localparam integer RST_PRESC = (1 << RX_RESET_TIMER_PRESC);

   wire tx_core_rst_n = reset_core_pll_n_o & reset_core_tx_n_i & tx_powerdown_n_i
                        & ~tx_reset_i & serdes_en;
   wire rx_core_rst_n = reset_core_pll_n_o & reset_core_rx_n_i & rx_powerdown_n_i
                        & ~rx_reset_i & serdes_en;

   wire tx_pcs_rst_n  = tx_core_rst_n & ~tx_pcs_reset_i;
   wire tx_pma_rst_n  = tx_core_rst_n & ~tx_pma_reset_i;

   wire rx_pcs_rst_n  = rx_core_rst_n & ~rx_pcs_reset_i;
   wire rx_pma_rst_n  = rx_core_rst_n & ~rx_pma_reset_i;
   wire rx_cdr_rst_n  = rx_core_rst_n & ~rx_cdr_reset_i;
   wire rx_buf_rst_n  = rx_core_rst_n & ~rx_buf_reset_i;

   reg        tx_resetdone_r;
   reg [15:0] tx_rst_cnt;

   assign tx_resetdone_o = tx_resetdone_r;

   initial begin
      tx_resetdone_r = 1'b0;
      tx_rst_cnt     = 16'h0;
   end

   always @(posedge clk_core_pll_r or negedge tx_core_rst_n) begin
      if (!tx_core_rst_n) begin
         tx_resetdone_r <= 1'b0;
         tx_rst_cnt     <= 16'h0;
      end
      else if (!tx_pma_rst_n || !tx_pcs_rst_n) begin
         tx_resetdone_r <= 1'b0;
         tx_rst_cnt     <= 16'h0;
      end
      else if (tx_rst_cnt < ((TX_PMA_RESET_TIME + TX_PCS_RESET_TIME + 2) * RST_PRESC))
        tx_rst_cnt <= tx_rst_cnt + 16'd1;
      else
        tx_resetdone_r <= 1'b1;
   end

   wire       rx_cdr_locked;

   reg        rx_resetdone_r;
   reg [15:0] rx_rst_cnt;

   assign rx_resetdone_o = rx_resetdone_r;

   initial begin
      rx_resetdone_r = 1'b0;
      rx_rst_cnt     = 16'h0;
   end

   wire rx_rst_gate = (RX_WAIT_CDR_LOCK != 0) ? rx_cdr_locked : 1'b1;

   always @(posedge clk_core_pll_r or negedge rx_core_rst_n) begin
      if (!rx_core_rst_n) begin
         rx_resetdone_r <= 1'b0;
         rx_rst_cnt     <= 16'h0;
      end
      else if (!rx_pma_rst_n || !rx_pcs_rst_n || !rx_cdr_rst_n || !rx_buf_rst_n) begin
         rx_resetdone_r <= 1'b0;
         rx_rst_cnt     <= 16'h0;
      end
      else if (rx_rst_cnt < ((RX_PMA_RESET_TIME + RX_EQA_RESET_TIME + RX_CDR_RESET_TIME
                              + RX_PCS_RESET_TIME + RX_BUF_RESET_TIME + 5) * RST_PRESC))
        rx_rst_cnt <= rx_rst_cnt + 16'd1;
      else if (rx_rst_gate)
        rx_resetdone_r <= 1'b1;
   end

   function integer dp_bytes;
      input [1:0] sel;
      begin
         dp_bytes = (sel == 2'b00) ? 2 : (sel == 2'b01) ? 4 : 8;
      end
   endfunction

   localparam integer TX_BYTES = (TX_DATAPATH_SEL == 2'b00) ? 2 :
                                 (TX_DATAPATH_SEL == 2'b01) ? 4 : 8;
   localparam integer RX_BYTES = (RX_DATAPATH_SEL == 2'b00) ? 2 :
                                 (RX_DATAPATH_SEL == 2'b01) ? 4 : 8;

   wire       pcs_loopback = loopback_i[1] | loopback_i[2];
   wire       pma_loopback = loopback_i[0] | (TX_PMA_LOOPBACK != 0);

   reg [30:0] tx_prbs_lfsr;
   reg        tx_prbs_bit;

   function [30:0] prbs_next;
      input [30:0] state;
      input [2:0]  sel;
      reg          fb;
      begin
         case (sel)
           3'b001  : fb = state[6]  ^ state[5];
           3'b010  : fb = state[14] ^ state[13];
           3'b011  : fb = state[22] ^ state[17];
           3'b100  : fb = state[30] ^ state[27];
           default : fb = state[6]  ^ state[5];
         endcase
         prbs_next = {state[29:0], fb};
      end
   endfunction

   reg        tx_rd;
   reg [79:0] tx_word;

   reg [79:0] tx_fifo [0:15];
   reg  [4:0] tx_wptr, tx_rptr;
   reg        tx_buf_err_r;
   wire [4:0] tx_fifo_cnt = tx_wptr - tx_rptr;

   assign tx_buf_err_o = tx_buf_err_r;

   integer    tb_i;
   reg [10:0] tb_enc;
   reg  [7:0] tb_byte;
   reg        tb_k;
   reg [79:0] tx_word_v;
   reg        tx_rd_v;

   wire [63:0] tx_src_data     = pcs_loopback ? rx_data_o        : tx_data_i;
   wire  [7:0] tx_src_k        = pcs_loopback ? rx_char_is_k_o   : tx_char_is_k_i;

   initial begin
      tx_rd        = 1'b0;
      tx_word      = 80'h0;
      tx_wptr      = 5'h0;
      tx_rptr      = 5'h0;
      tx_buf_err_r = 1'b0;
      tx_prbs_lfsr = 31'h7FFF_FFFF;
      tx_prbs_bit  = 1'b0;
      for (tb_i = 0; tb_i < 16; tb_i = tb_i + 1)
        tx_fifo[tb_i] = 80'h0;
   end

   always @(posedge clk_core_tx_i or negedge tx_pcs_rst_n) begin
      if (!tx_pcs_rst_n) begin
         tx_rd        <= 1'b0;
         tx_wptr      <= 5'h0;
         tx_buf_err_r <= 1'b0;
      end
      else begin
         tx_buf_err_r <= 1'b0;
         tx_rd_v       = tx_rd;
         tx_word_v     = 80'h0;

         for (tb_i = 0; tb_i < 8; tb_i = tb_i + 1) begin
            if (tb_i < TX_BYTES) begin
               tb_byte = tx_src_data[tb_i*8 +: 8];
               tb_k    = tx_src_k[tb_i];

               if (!tx_8b10b_en_i || tx_8b10b_bypass_i[tb_i]) begin
                  tx_word_v[tb_i*10 +: 10] = {tx_char_dispval_i[tb_i],
                                              tx_char_dispmode_i[tb_i],
                                              tb_byte};
               end
               else begin
                  if (tx_char_dispmode_i[tb_i])
                    tx_rd_v = tx_char_dispval_i[tb_i];
                  tb_enc                    = enc8b10b(tb_byte, tb_k, tx_rd_v);
                  tx_word_v[tb_i*10 +: 10]  = tb_enc[9:0];
                  tx_rd_v                   = tb_enc[10];
               end
            end
         end

         tx_rd <= tx_rd_v;

         if (tx_fifo_cnt < 5'd15) begin
            tx_fifo[tx_wptr[3:0]] <= tx_word_v;
            tx_wptr               <= tx_wptr + 5'd1;
         end
         else begin
            tx_buf_err_r <= 1'b1;
            if (BHV_VERBOSE)
              $display("[%0t] %m: TX elastic buffer overflow", $time);
         end
      end
   end

   localparam integer TX_WORD_BITS_MAX = 80;

   reg [79:0] tx_shift;
   reg  [6:0] tx_bit_idx;
   reg        tx_bit;
   reg        tx_ser_run;
   reg        tx_serio_p_r, tx_serio_n_r;

   wire integer tx_word_bits = TX_BYTES * 10;

   wire tx_fifo_ready = (tx_fifo_cnt >= 5'd2);

   assign TX_SERIO_P_B = tx_serio_p_r;
   assign TX_SERIO_N_B = tx_serio_n_r;
   assign TERM_SERIO_O = 1'b0;

   initial begin
      tx_shift     = 80'h0;
      tx_bit_idx   = 7'd0;
      tx_bit       = 1'b0;
      tx_ser_run   = 1'b0;
      tx_serio_p_r = 1'b0;
      tx_serio_n_r = 1'b0;
   end

   always @(*)
     tx_ser_run = pll_locked & tx_pma_rst_n & tx_resetdone_r;

   always begin : tx_serializer
      if (tx_ser_run && (ui > 0.0)) begin
         #(ui);
         if (tx_bit_idx == 7'd0) begin
            if (tx_fifo_ready || (tx_fifo_cnt != 5'd0)) begin
               tx_shift = tx_fifo[tx_rptr[3:0]];
               tx_rptr  = tx_rptr + 5'd1;
            end
            else begin
               tx_shift     = tx_shift;
               tx_buf_err_r = 1'b1;
            end
         end

         if (tx_prbs_sel_i != 3'b000) begin
            tx_prbs_lfsr = prbs_next(tx_prbs_lfsr, tx_prbs_sel_i);
            tx_prbs_bit  = tx_prbs_lfsr[0] ^ tx_prbs_force_err_i;
            tx_bit       = tx_prbs_bit;
         end
         else
           tx_bit = tx_shift[tx_bit_idx];

         tx_bit_idx = (tx_bit_idx == (tx_word_bits - 1)) ? 7'd0 : tx_bit_idx + 7'd1;

         if (tx_elec_idle_i || !tx_powerdown_n_i) begin
            tx_serio_p_r = 1'b0;
            tx_serio_n_r = 1'b0;
         end
         else begin
            tx_serio_p_r =  tx_bit ^ tx_polarity_i;
            tx_serio_n_r = ~(tx_bit ^ tx_polarity_i);
         end
      end
      else begin
         tx_bit_idx   = 7'd0;
         tx_serio_p_r = 1'b0;
         tx_serio_n_r = 1'b0;
         @(tx_ser_run or pll_locked);
      end
   end

   wire rx_pad_p = pma_loopback ? tx_serio_p_r : RX_SERIO_P_B;
   wire rx_pad_n = pma_loopback ? tx_serio_n_r : RX_SERIO_N_B;

   wire rx_serial_bit = rx_pad_p ^ rx_polarity_i;

   localparam real EI_WINDOW_UI = 20.0;

   reg  rx_ei_filt;
   real rx_ei_deadline;

   assign rx_ei_en_o = rx_en_ei_detector_i & rx_ei_filt;

   initial begin
      rx_ei_filt     = 1'b1;
      rx_ei_deadline = 0.0;
   end

   always @(rx_pad_p or rx_pad_n) begin
      rx_ei_filt     = 1'b0;
      rx_ei_deadline = $realtime + (EI_WINDOW_UI * ui);
   end

   always begin : ei_watchdog
      if (!rx_ei_filt) begin
         if ($realtime >= rx_ei_deadline)
           rx_ei_filt = 1'b1;
         else
           #(rx_ei_deadline - $realtime);
      end
      else
        @(rx_pad_p or rx_pad_n);
   end

   real       rx_last_sample_t;
   real       rx_phase_adj;
   real       rx_err;
   integer    rx_lock_cnt;
   reg        rx_cdr_locked_r;
   reg        rx_sampler_run;

   assign rx_cdr_locked = rx_cdr_locked_r | (RX_CDR_FORCE_LOCK != 0);

   initial begin
      rx_last_sample_t = 0.0;
      rx_phase_adj     = 0.0;
      rx_err           = 0.0;
      rx_lock_cnt      = 0;
      rx_cdr_locked_r  = 1'b0;
      rx_sampler_run   = 1'b0;
   end

   always @(*)
     rx_sampler_run = pll_locked & rx_pma_rst_n & rx_cdr_rst_n & ~rx_ei_filt;

   always @(rx_pad_p or rx_pad_n) begin : cdr_phase_detector
      real edge_t, ideal_t, e;
      if (rx_sampler_run && (ui > 0.0)) begin
         edge_t  = $realtime;
         ideal_t = rx_last_sample_t + (ui / 2.0);
         e       = edge_t - ideal_t;
         while (e >   ui / 2.0) e = e - ui;
         while (e <= -ui / 2.0) e = e + ui;

         rx_err       = e;
         rx_phase_adj = rx_phase_adj + e * BHV_CDR_KP;

         if ((e < ui / 4.0) && (e > -ui / 4.0)) begin
            if (rx_lock_cnt < BHV_CDR_LOCK_EDGES)
              rx_lock_cnt = rx_lock_cnt + 1;
            else if (!rx_cdr_locked_r) begin
               rx_cdr_locked_r = 1'b1;
               if (BHV_VERBOSE)
                 $display("[%0t] %m: RX CDR locked", $time);
            end
         end
         else
           rx_lock_cnt = 0;
      end
   end

   always @(negedge rx_sampler_run) begin
      rx_cdr_locked_r = 1'b0;
      rx_lock_cnt     = 0;
      rx_phase_adj    = 0.0;
   end

   reg  [9:0] rx_shift;
   reg  [6:0] rx_bit_cnt;
   reg  [3:0] rx_sym_cnt;
   reg [79:0] rx_word;
   reg        rx_word_valid;
   reg        rx_aligned_r;
   reg        rx_realign_r;
   reg  [3:0] rx_sym_phase;

   reg        rx_slide_pending;
   reg        rx_realign_tog;
   reg        rx_realign_tog_d;

   integer    rx_bits_seen;

   initial begin
      rx_shift         = 10'h0;
      rx_bit_cnt       = 7'd0;
      rx_sym_cnt       = 4'd0;
      rx_word          = 80'h0;
      rx_word_valid    = 1'b0;
      rx_aligned_r     = 1'b0;
      rx_realign_r     = 1'b0;
      rx_realign_tog   = 1'b0;
      rx_realign_tog_d = 1'b0;
      rx_sym_phase     = 4'd0;
      rx_slide_pending = 1'b0;
      rx_bits_seen     = 0;
   end

   assign rx_byte_is_aligned_o = rx_aligned_r;
   assign rx_byte_realign_o    = rx_realign_r;

   wire [9:0] comma_mask = ALIGN_COMMA_ENABLE;
   wire       comma_align_en = rx_comma_detect_en_i & (rx_mcomma_align_i | rx_pcomma_align_i);

   reg  comma_align_en_d;

   initial comma_align_en_d = 1'b0;

   function integer lane_ok;
      input integer lane;
      begin
         case (ALIGN_COMMA_WORD)
           2'b00   : lane_ok = 1;
           2'b01   : lane_ok = ((lane % 2) == 0);
           default : lane_ok = ((lane % 4) == 0);
         endcase
      end
   endfunction

   reg [30:0] rx_prbs_lfsr;
   reg        rx_prbs_synced;
   reg        rx_prbs_err_r;
   reg [15:0] rx_prbs_err_cnt;
   integer    rx_prbs_good;

   assign rx_prbs_err_o = rx_prbs_err_r;

   initial begin
      rx_prbs_lfsr    = 31'h7FFF_FFFF;
      rx_prbs_synced  = 1'b0;
      rx_prbs_err_r   = 1'b0;
      rx_prbs_err_cnt = 16'h0;
      rx_prbs_good    = 0;
   end

   always begin : rx_sampler
      reg [9:0]  win;
      reg        matched;
      reg        comma_on_boundary;
      real       step;
      if (rx_sampler_run && (ui > 0.0)) begin
         step         = ui + rx_phase_adj;
         if (step < (ui / 8.0)) step = ui / 8.0;
         if (step > (ui * 2.0)) step = ui * 2.0;
         rx_phase_adj = 0.0;
         #(step);
         rx_last_sample_t = $realtime;
         rx_bits_seen     = rx_bits_seen + 1;

         rx_shift = {rx_serial_bit, rx_shift[9:1]};

         if (rx_prbs_sel_i != 3'b000) begin
            if (!rx_prbs_synced) begin
               rx_prbs_lfsr = {rx_prbs_lfsr[29:0], rx_serial_bit};
               rx_prbs_good = rx_prbs_good + 1;
               if (rx_prbs_good > 40) rx_prbs_synced = 1'b1;
            end
            else begin
               rx_prbs_lfsr = prbs_next(rx_prbs_lfsr, rx_prbs_sel_i);
               if (rx_prbs_lfsr[0] !== rx_serial_bit) begin
                  rx_prbs_err_r   = 1'b1;
                  rx_prbs_err_cnt = rx_prbs_err_cnt + 16'd1;
                  rx_prbs_lfsr    = {rx_prbs_lfsr[29:0], rx_serial_bit};
               end
               else
                 rx_prbs_err_r = 1'b0;
            end
            if (rx_prbs_cnt_reset_i) begin
               rx_prbs_err_cnt = 16'h0;
               rx_prbs_err_r   = 1'b0;
            end
         end

         if (comma_align_en && !comma_align_en_d)
           rx_aligned_r = 1'b0;
         comma_align_en_d = comma_align_en;

         win     = rx_shift;
         matched = 1'b0;
         if (comma_align_en && !rx_aligned_r && rx_bits_seen >= 10) begin
            if (rx_mcomma_align_i &&
                ((win & comma_mask) == (ALIGN_MCOMMA_VALUE & comma_mask)))
              matched = 1'b1;
            if (rx_pcomma_align_i &&
                ((win & comma_mask) == (ALIGN_PCOMMA_VALUE & comma_mask)))
              matched = 1'b1;
         end

         if (matched && !rx_aligned_r) begin
            comma_on_boundary = (rx_bit_cnt == 7'd9);
            if (!comma_on_boundary)
              rx_realign_tog = ~rx_realign_tog;
            rx_bit_cnt   = 7'd9;
            rx_sym_cnt   = 4'd0;
            rx_aligned_r = 1'b1;
            if (BHV_VERBOSE)
              $display("[%0t] %m: RX byte alignment acquired", $time);
         end

         if (rx_slide_i && !rx_slide_pending) begin
            rx_slide_pending = 1'b1;
            rx_bit_cnt = (rx_bit_cnt == 7'd0) ? 7'd9 : rx_bit_cnt - 7'd1;
         end
         if (!rx_slide_i)
           rx_slide_pending = 1'b0;

         if (rx_bit_cnt == 7'd9) begin
            rx_word[rx_sym_cnt*10 +: 10] = rx_shift;
            rx_bit_cnt = 7'd0;
            if (rx_sym_cnt == (RX_BYTES - 1)) begin
               rx_sym_cnt    = 4'd0;
               rx_word_valid = ~rx_word_valid;
            end
            else
              rx_sym_cnt = rx_sym_cnt + 4'd1;
         end
         else
           rx_bit_cnt = rx_bit_cnt + 7'd1;
      end
      else begin
         rx_bit_cnt   = 7'd0;
         rx_sym_cnt   = 4'd0;
         rx_bits_seen = 0;
         rx_aligned_r = 1'b0;
         @(rx_sampler_run or pll_locked);
      end
   end

   always @(posedge clk_core_rx_i or negedge rx_pcs_rst_n)
     if (!rx_pcs_rst_n) begin
        rx_realign_tog_d <= rx_realign_tog;
        rx_realign_r     <= 1'b0;
     end
     else begin
        rx_realign_tog_d <= rx_realign_tog;
        rx_realign_r     <= (rx_realign_tog ^ rx_realign_tog_d);
     end

   reg clk_core_rx_r;
   assign clk_core_rx_o = clk_core_rx_r;

   initial clk_core_rx_r = 1'b0;

   always begin : rx_rec_clk_gen
      if (pll_locked && (core_period > 0.0)) begin
         #(core_period / 2.0);
         clk_core_rx_r = ~clk_core_rx_r;
      end
      else begin
         clk_core_rx_r = 1'b0;
         @(pll_locked);
      end
   end

   reg [79:0] rx_fifo [0:15];
   reg  [4:0] rx_wptr, rx_rptr;
   reg        rx_buf_err_r;
   reg        rx_run;
   wire [4:0] rx_fifo_cnt = rx_wptr - rx_rptr;

   assign rx_buf_err_o = rx_buf_err_r;

   integer    rf_j;

   initial begin
      rx_wptr      = 5'h0;
      rx_rptr      = 5'h0;
      rx_buf_err_r = 1'b0;
      rx_run       = 1'b0;
      for (rf_j = 0; rf_j < 16; rf_j = rf_j + 1)
        rx_fifo[rf_j] = 80'h0;
   end

   always @(rx_word_valid) begin
      if (rx_buf_rst_n) begin
         if (rx_fifo_cnt < 5'd15) begin
            rx_fifo[rx_wptr[3:0]] = rx_word;
            rx_wptr               = rx_wptr + 5'd1;
         end
         else begin
            rx_buf_err_r = 1'b1;
            if (BHV_VERBOSE)
              $display("[%0t] %m: RX elastic buffer overflow", $time);
         end
      end
   end

   always @(negedge rx_buf_rst_n) begin
      rx_wptr = 5'h0;
      rx_rptr = 5'h0;
      rx_run  = 1'b0;
   end

   reg [63:0] rx_data_r;
   reg  [7:0] rx_k_r, rx_comma_r, rx_nit_r, rx_disp_r;
   reg        rx_rd;

   integer    rd_i;
   reg [79:0] rd_word;
   reg  [9:0] rd_sym;
   reg  [9:0] rd_ent;
   reg  [1:0] rd_cls;
   reg        rd_rd_v;
   reg [63:0] rd_data_v;
   reg  [7:0] rd_k_v, rd_com_v, rd_nit_v, rd_disp_v;

   initial begin
      rx_data_r  = 64'h0;
      rx_k_r     = 8'h0;
      rx_comma_r = 8'h0;
      rx_nit_r   = 8'h0;
      rx_disp_r  = 8'h0;
      rx_rd      = 1'b0;
   end

   always @(posedge clk_core_rx_i or negedge rx_pcs_rst_n) begin
      if (!rx_pcs_rst_n) begin
         rx_data_r    <= 64'h0;
         rx_k_r       <= 8'h0;
         rx_comma_r   <= 8'h0;
         rx_nit_r     <= 8'h0;
         rx_disp_r    <= 8'h0;
         rx_rd        <= 1'b0;
         rx_rptr      <= 5'h0;
         rx_run       <= 1'b0;
         rx_buf_err_r <= 1'b0;
      end
      else begin
         if (!rx_run) begin
            if (rx_fifo_cnt >= 5'd2) rx_run <= 1'b1;
         end
         else if (rx_fifo_cnt == 5'd0) begin
            rx_buf_err_r <= 1'b1;
            rx_run       <= 1'b0;
         end
         else begin
            rd_word = rx_fifo[rx_rptr[3:0]];
            rx_rptr <= rx_rptr + 5'd1;

            rd_rd_v   = rx_rd;
            rd_data_v = 64'h0;
            rd_k_v    = 8'h0;
            rd_com_v  = 8'h0;
            rd_nit_v  = 8'h0;
            rd_disp_v = 8'h0;

            for (rd_i = 0; rd_i < 8; rd_i = rd_i + 1) begin
               if (rd_i < RX_BYTES) begin
                  rd_sym = rd_word[rd_i*10 +: 10];

                  if (!rx_8b10b_en_i || rx_8b10b_bypass_i[rd_i]) begin
                     rd_data_v[rd_i*8 +: 8] = rd_sym[7:0];
                  end
                  else begin
                     rd_ent = dec_lut[rd_sym];
                     rd_cls = dec_rd [rd_sym];

                     rd_data_v[rd_i*8 +: 8] = rd_ent[7:0];
                     rd_k_v   [rd_i]        = rd_ent[8];
                     rd_nit_v [rd_i]        = ~rd_ent[9];

                     rd_com_v[rd_i] = rd_ent[8] &&
                                      ((rd_ent[7:0] == 8'h3C) ||
                                       (rd_ent[7:0] == 8'hBC) ||
                                       (rd_ent[7:0] == 8'hFC));

                     if ((rd_cls == 2'd1 &&  rd_rd_v) ||
                         (rd_cls == 2'd2 && !rd_rd_v))
                       rd_disp_v[rd_i] = 1'b1;

                     if (rd_cls == 2'd1)      rd_rd_v = 1'b1;
                     else if (rd_cls == 2'd2) rd_rd_v = 1'b0;
                  end
               end
            end

            rx_data_r  <= rd_data_v;
            rx_k_r     <= rd_k_v;
            rx_comma_r <= rd_com_v;
            rx_nit_r   <= rd_nit_v;
            rx_disp_r  <= rd_disp_v;
            rx_rd      <= rd_rd_v;
         end
      end
   end

   reg [63:0] pipe_data [0:15];
   reg  [7:0] pipe_k    [0:15];
   reg  [7:0] pipe_com  [0:15];
   reg  [7:0] pipe_nit  [0:15];
   reg  [7:0] pipe_disp [0:15];

   integer    pp_i;

   initial
     for (pp_i = 0; pp_i < 16; pp_i = pp_i + 1) begin
        pipe_data[pp_i] = 64'h0;  pipe_k   [pp_i] = 8'h0;
        pipe_com [pp_i] = 8'h0;   pipe_nit [pp_i] = 8'h0;
        pipe_disp[pp_i] = 8'h0;
     end

   always @(posedge clk_core_rx_i or negedge rx_pcs_rst_n)
     if (!rx_pcs_rst_n) begin
        for (pp_i = 0; pp_i < 16; pp_i = pp_i + 1) begin
           pipe_data[pp_i] <= 64'h0;  pipe_k   [pp_i] <= 8'h0;
           pipe_com [pp_i] <= 8'h0;   pipe_nit [pp_i] <= 8'h0;
           pipe_disp[pp_i] <= 8'h0;
        end
     end
     else begin
        pipe_data[0] <= rx_data_r;  pipe_k   [0] <= rx_k_r;
        pipe_com [0] <= rx_comma_r; pipe_nit [0] <= rx_nit_r;
        pipe_disp[0] <= rx_disp_r;
        for (pp_i = 1; pp_i < 16; pp_i = pp_i + 1) begin
           pipe_data[pp_i] <= pipe_data[pp_i-1];
           pipe_k   [pp_i] <= pipe_k   [pp_i-1];
           pipe_com [pp_i] <= pipe_com [pp_i-1];
           pipe_nit [pp_i] <= pipe_nit [pp_i-1];
           pipe_disp[pp_i] <= pipe_disp[pp_i-1];
        end
     end

   assign #(BHV_RX_TCO_NS) rx_data_o          = (BHV_RX_PIPE_STAGES == 0) ? rx_data_r
                                                         : pipe_data[BHV_RX_PIPE_STAGES-1];
   assign #(BHV_RX_TCO_NS) rx_char_is_k_o     = (BHV_RX_PIPE_STAGES == 0) ? rx_k_r
                                                         : pipe_k   [BHV_RX_PIPE_STAGES-1];
   assign #(BHV_RX_TCO_NS) rx_char_is_comma_o = (BHV_RX_PIPE_STAGES == 0) ? rx_comma_r
                                                         : pipe_com [BHV_RX_PIPE_STAGES-1];
   assign #(BHV_RX_TCO_NS) rx_not_in_table_o  = (BHV_RX_PIPE_STAGES == 0) ? rx_nit_r
                                                         : pipe_nit [BHV_RX_PIPE_STAGES-1];
   assign #(BHV_RX_TCO_NS) rx_disp_err_o      = (BHV_RX_PIPE_STAGES == 0) ? rx_disp_r
                                                         : pipe_disp[BHV_RX_PIPE_STAGES-1];

   reg rx_detect_done_r;
   reg rx_present_r;

   assign rx_detect_done_o = rx_detect_done_r;
   assign rx_present_o     = rx_present_r;

   initial begin
      rx_detect_done_r = 1'b0;
      rx_present_r     = 1'b0;
   end

   always @(posedge tx_detect_rx_i) begin : rx_detect_seq
      rx_detect_done_r = 1'b0;
      #(BHV_RX_DETECT_TIME_NS);
      if (tx_detect_rx_i) begin
         rx_present_r     = (BHV_RX_PRESENT != 0);
         rx_detect_done_r = 1'b1;
         if (BHV_VERBOSE)
           $display("[%0t] %m: receiver detect done, present=%b", $time, rx_present_r);
      end
   end

   always @(negedge tx_detect_rx_i) begin
      rx_detect_done_r = 1'b0;
      rx_present_r     = 1'b0;
   end

   assign scan_out_o = scan_enable_i ? scan_in_i : 7'h0;

endmodule
