//==========================================================================
// openCologne-PCIE * PHY block-level testbench: PIPE + SerDes
//--------------------------------------------------------------------------
// Two tests, one compiled per run (run-phy.sh):
//
//   PIPE test (default)  the PIPE layer of gatemate-pipe on the SerDes:
//                        TS1 ordered sets, test data, error detection;
//                        DATA_BYTES = 2 (16-bit) or 8 (64-bit) PIPE
//   TB_PHY_EQUIV         the opensource SerDes BFM alone, looped back, as a
//                        self-check; with HAVE_VENDOR_SERDES also the vendor
//                        model side by side, CROSS_LINK links the two
//
// The PIPE test is based on the testbench of tb_ccfpga_serdes.v and
// testcase_pipe.v from colognechip/gatemate-pipe, see below.
//==========================================================================
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
//                > The PIPE test needs the PIPE macro (run-phy.sh sets it).
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

`ifdef TB_PHY_EQUIV

module tb_phy;

   parameter        CLKPERIOD_REF = 10.0;
   parameter        CLKPERIOD_REG =  8.0;
   parameter        CLKPERIOD_CFG = 40.0;

   parameter real   WIRE_DELAY_NS = 10.0;

   parameter integer N_TRAIN      = 300;
   parameter integer N_PAYLOAD    = 400;
   parameter integer N_TAIL       = 40;

   parameter real   BHV_LOCK_NS   = 500.0;

   parameter  [5:0] PLL_FCNTRL               = 58;
   parameter  [5:0] PLL_MAIN_DIVSEL          = {1'b0,2'b11,1'b0,2'b11};
   parameter  [1:0] PLL_OUT_DIVSEL           = 2'b01;
   parameter  [1:0] RX_DATAPATH_SEL          = 3;
   parameter  [1:0] TX_DATAPATH_SEL          = 3;
   parameter  [9:0] ALIGN_MCOMMA_VALUE       = 10'b1010000011;
   parameter  [9:0] ALIGN_PCOMMA_VALUE       = 10'b0101111100;
   parameter  [9:0] ALIGN_COMMA_ENABLE       = 10'b1111111111;
   parameter  [1:0] ALIGN_COMMA_WORD         = 2'b11;
   parameter        RX_WAIT_CDR_LOCK         = 1;
   parameter        PLL_CONFIG_SEL           = 0;
   parameter        PLL_SET_OP_LOCK          = 1'h0;
   parameter        PLL_LOCK_WINDOW          = 1;
   parameter        PLL_FAST_LOCK            = 1;
   parameter        PLL_REF_RTERM            = 1;
   parameter  [4:0] PLL_CI                   = 5'h3;
   parameter  [9:0] PLL_CP                   = 10'h50;
   parameter        PLL_SCAP_AUTO_CAL        = 1;
   parameter  [1:0] PLL_FILTER_SHIFT         = 2;
   parameter  [2:0] PLL_SAR_LIMIT            = 2;
   parameter [10:0] PLL_FT                   = 512;
   parameter  [2:0] PLL_BISC_MODE            = 3'b100;
   parameter  [3:0] PLL_BISC_TIMER_MAX       = 4'hC;
   parameter  [4:0] PLL_BISC_CP_MIN          = 4;
   parameter  [4:0] PLL_BISC_CP_MAX          = 5'h1E;
   parameter  [4:0] PLL_BISC_CP_START        = 5'h6;
   parameter        PLL_BISC_CAL_SIGN        = 1'h1;
   parameter        PLL_BISC_CAL_AUTO        = 1;
   parameter  [4:0] PLL_BISC_DLY_PFD_MON_DIV = 2;
   parameter  [2:0] PLL_BISC_COR_DLY         = 1;

   logic  clk_ref, clk_reg, clk_cfg;
   logic  reset_n, reset_reg_n;

   initial clk_ref = 1'b1;
   always #(CLKPERIOD_REF/2.0) clk_ref = ~clk_ref;
   initial clk_reg = 1'b1;
   always #(CLKPERIOD_REG/2.0) clk_reg = ~clk_reg;
   initial clk_cfg = 1'b1;
   always #(CLKPERIOD_CFG/2.0) clk_cfg = ~clk_cfg;

   initial begin
      reset_n = 1'b0;
      #(CLKPERIOD_REF*10 + 1) reset_n = 1'b1;
   end
   initial begin
      reset_reg_n = 1'b0;
      #(CLKPERIOD_REG*10 + 1) reset_reg_n = 1'b1;
   end

   logic        regfile_we, regfile_en;
   logic  [7:0] regfile_addr;
   logic [15:0] regfile_mask, regfile_di;
   logic        cfg_en, reset_cfg, cfgfile_valid;
   logic [15:0] cfgfile_di;
   logic  [7:0] cfgfile_addr;

   initial begin
      regfile_we    = 1'b0;  regfile_en   = 1'b0;
      regfile_addr  = 8'h0;  regfile_mask = 16'h0;  regfile_di = 16'h0;
      cfg_en        = 1'b0;  reset_cfg    = 1'b0;   cfgfile_valid = 1'b0;
      cfgfile_di    = 16'h0; cfgfile_addr = 8'h0;
   end

   task writeCfg(input [7:0] addr, input [15:0] data);
      begin
         @(posedge clk_cfg); #1; cfg_en = 1'b1;
         @(posedge clk_cfg); #1;
         @(posedge clk_cfg); #1;
         cfgfile_valid = 1'b1; cfgfile_di = data; cfgfile_addr = addr;
         @(posedge clk_cfg); #1;
         cfgfile_valid = 1'b0; cfgfile_di = 16'h0; cfgfile_addr = 8'h0;
         @(posedge clk_cfg); #1;
         @(posedge clk_cfg); #1; cfg_en = 1'b0;
      end
   endtask

   integer wr_i;
   task writeRegfile(input [7:0] addr, input [15:0] data, input [15:0] mask);
      begin
         @(posedge clk_reg); #1.5;
         regfile_en = 1'b1; regfile_we = 1'b1;
         regfile_addr = addr; regfile_mask = mask; regfile_di = data;
         @(posedge clk_reg); #1.5;
         regfile_en = 1'b0; regfile_we = 1'b0;
         regfile_addr = 8'h0; regfile_mask = 16'h0; regfile_di = 16'h0;
         for (wr_i = 0; wr_i < 40; wr_i = wr_i + 1) begin
            @(posedge clk_reg); #1.5;
         end
      end
   endtask

   localparam [2:0] ST_IDLE    = 3'd0,
                    ST_TRAIN   = 3'd1,
                    ST_MARKER  = 3'd2,
                    ST_PAYLOAD = 3'd3,
                    ST_TAIL    = 3'd4,
                    ST_DONE    = 3'd5;

   localparam [7:0] COMMA  = 8'hBC;
   localparam [7:0] MARKER = 8'h1C;
   localparam [7:0] FILLER = 8'h4A;

   localparam [63:0] TRAIN_D = {FILLER, FILLER, FILLER, FILLER,
                                FILLER, FILLER, FILLER, COMMA};
   localparam  [7:0] TRAIN_K = 8'b0000_0001;

   localparam [63:0] MARK_D  = {8{MARKER}};
   localparam  [7:0] MARK_K  = 8'hFF;

   function [31:0] xs32;
      input [31:0] s;
      logic   [31:0] v;
      begin
         v = s;
         v = v ^ (v << 13);
         v = v ^ (v >> 17);
         v = v ^ (v << 5);
         xs32 = v;
      end
   endfunction

   logic        bhv_clk_core;
   logic        bhv_reset_core_n;
   logic        bhv_tx_p, bhv_tx_n;
   logic         bhv_rx_p, bhv_rx_n;
   logic        bhv_tx_resetdone, bhv_rx_resetdone;
   logic [63:0] bhv_rx_data;
   logic  [7:0] bhv_rx_k, bhv_rx_comma, bhv_rx_nit, bhv_rx_disp;
   logic        bhv_aligned, bhv_realign, bhv_tx_buf_err, bhv_rx_buf_err;
   logic [15:0] bhv_regfile_do;
   logic        bhv_regfile_rdy;
   logic        bhv_clk_core_rx;

   logic  [63:0] bhv_tx_data;
   logic   [7:0] bhv_tx_k;
   logic         bhv_tx_elec_idle;
   logic         bhv_rx_comma_en, bhv_rx_mcomma, bhv_rx_pcomma;

`ifdef CROSS_LINK
   always @(ref_tx_p) bhv_rx_p <= #(WIRE_DELAY_NS) ref_tx_p;
   always @(ref_tx_n) bhv_rx_n <= #(WIRE_DELAY_NS) ref_tx_n;
`else
   always @(bhv_tx_p) bhv_rx_p <= #(WIRE_DELAY_NS) bhv_tx_p;
   always @(bhv_tx_n) bhv_rx_n <= #(WIRE_DELAY_NS) bhv_tx_n;
`endif

   ccfpga_serdes #(
      .PLL_FCNTRL               (PLL_FCNTRL),
      .PLL_MAIN_DIVSEL          (PLL_MAIN_DIVSEL),
      .PLL_OUT_DIVSEL           (PLL_OUT_DIVSEL),
      .RX_DATAPATH_SEL          (RX_DATAPATH_SEL),
      .TX_DATAPATH_SEL          (TX_DATAPATH_SEL),
      .ALIGN_MCOMMA_VALUE       (ALIGN_MCOMMA_VALUE),
      .ALIGN_PCOMMA_VALUE       (ALIGN_PCOMMA_VALUE),
      .ALIGN_COMMA_ENABLE       (ALIGN_COMMA_ENABLE),
      .ALIGN_COMMA_WORD         (ALIGN_COMMA_WORD),
      .RX_WAIT_CDR_LOCK         (RX_WAIT_CDR_LOCK),
      .PLL_CONFIG_SEL           (PLL_CONFIG_SEL),
      .PLL_SET_OP_LOCK          (PLL_SET_OP_LOCK),
      .PLL_LOCK_WINDOW          (PLL_LOCK_WINDOW),
      .PLL_FAST_LOCK            (PLL_FAST_LOCK),
      .PLL_REF_RTERM            (PLL_REF_RTERM),
      .PLL_CI                   (PLL_CI),
      .PLL_CP                   (PLL_CP),
      .PLL_SCAP_AUTO_CAL        (PLL_SCAP_AUTO_CAL),
      .PLL_FILTER_SHIFT         (PLL_FILTER_SHIFT),
      .PLL_SAR_LIMIT            (PLL_SAR_LIMIT),
      .PLL_FT                   (PLL_FT),
      .PLL_BISC_MODE            (PLL_BISC_MODE),
      .PLL_BISC_TIMER_MAX       (PLL_BISC_TIMER_MAX),
      .PLL_BISC_CP_MIN          (PLL_BISC_CP_MIN),
      .PLL_BISC_CP_MAX          (PLL_BISC_CP_MAX),
      .PLL_BISC_CP_START        (PLL_BISC_CP_START),
      .PLL_BISC_CAL_SIGN        (PLL_BISC_CAL_SIGN),
      .PLL_BISC_CAL_AUTO        (PLL_BISC_CAL_AUTO),
      .PLL_BISC_DLY_PFD_MON_DIV (PLL_BISC_DLY_PFD_MON_DIV),
      .PLL_BISC_COR_DLY         (PLL_BISC_COR_DLY),
      .BHV_PLL_LOCK_TIME_NS     (BHV_LOCK_NS)
   ) DUT_BHV (
      .clk_ref_i            (clk_ref),
      .clk_reg_i            (clk_reg),
      .clk_cfg_i            (clk_cfg),
      .clk_core_tx_i        (bhv_clk_core),
      .clk_core_rx_i        (bhv_clk_core),
      .clk_core_rx_o        (bhv_clk_core_rx),
      .reset_n_i            (reset_n),
      .reset_reg_n_i        (reset_reg_n),
      .reset_core_tx_n_i    (bhv_reset_core_n),
      .reset_core_rx_n_i    (bhv_reset_core_n),
      .testmode_i           (1'b0),
      .scan_enable_i        (1'b0),
      .scan_in_i            (7'h0),
      .scan_out_o           (),
      .loopback_i           (3'b000),
      .pll_reset_i          (1'b0),
      .clk_core_pll_o       (bhv_clk_core),
      .reset_core_pll_n_o   (bhv_reset_core_n),
      .refclk_sel_o         (),
      .refclk_rterm_o       (),
      .RX_SERIO_P_B         (bhv_rx_p),
      .RX_SERIO_N_B         (bhv_rx_n),
      .TX_SERIO_P_B         (bhv_tx_p),
      .TX_SERIO_N_B         (bhv_tx_n),
      .regfile_we_i         (regfile_we),
      .regfile_en_i         (regfile_en),
      .regfile_addr_i       (regfile_addr),
      .regfile_mask_i       (regfile_mask),
      .regfile_di_i         (regfile_di),
      .regfile_do_o         (bhv_regfile_do),
      .regfile_rdy_o        (bhv_regfile_rdy),
      .cfg_en_i             (cfg_en),
      .reset_cfg_i          (reset_cfg),
      .cfgfile_di_i         (cfgfile_di),
      .cfgfile_valid_i      (cfgfile_valid),
      .cfgfile_addr_i       (cfgfile_addr),
      .tx_reset_i           (1'b0),
      .tx_pcs_reset_i       (1'b0),
      .tx_pma_reset_i       (1'b0),
      .tx_elec_idle_i       (bhv_tx_elec_idle),
      .tx_detect_rx_i       (1'b0),
      .tx_prbs_sel_i        (3'b000),
      .tx_prbs_force_err_i  (1'b0),
      .tx_powerdown_n_i     (1'b1),
      .tx_data_i            (bhv_tx_data),
      .tx_char_is_k_i       (bhv_tx_k),
      .tx_polarity_i        (1'b0),
      .tx_8b10b_en_i        (1'b1),
      .tx_8b10b_bypass_i    (8'h0),
      .tx_char_dispmode_i   (8'h0),
      .tx_char_dispval_i    (8'h0),
      .tx_buf_err_o         (bhv_tx_buf_err),
      .tx_resetdone_o       (bhv_tx_resetdone),
      .rx_detect_done_o     (),
      .rx_present_o         (),
      .TERM_SERIO_O         (),
      .rx_reset_i           (1'b0),
      .rx_pma_reset_i       (1'b0),
      .rx_eqa_reset_i       (1'b0),
      .rx_cdr_reset_i       (1'b0),
      .rx_pcs_reset_i       (1'b0),
      .rx_buf_reset_i       (1'b0),
      .rx_prbs_sel_i        (3'b000),
      .rx_prbs_cnt_reset_i  (1'b0),
      .rx_powerdown_n_i     (1'b1),
      .rx_en_ei_detector_i  (1'b0),
      .rx_comma_detect_en_i (bhv_rx_comma_en),
      .rx_slide_i           (1'b0),
      .rx_polarity_i        (1'b0),
      .rx_8b10b_en_i        (1'b1),
      .rx_8b10b_bypass_i    (8'h0),
      .rx_mcomma_align_i    (bhv_rx_mcomma),
      .rx_pcomma_align_i    (bhv_rx_pcomma),
      .rx_prbs_err_o        (),
      .rx_data_o            (bhv_rx_data),
      .rx_char_is_k_o       (bhv_rx_k),
      .rx_char_is_comma_o   (bhv_rx_comma),
      .rx_not_in_table_o    (bhv_rx_nit),
      .rx_disp_err_o        (bhv_rx_disp),
      .rx_buf_err_o         (bhv_rx_buf_err),
      .rx_byte_is_aligned_o (bhv_aligned),
      .rx_byte_realign_o    (bhv_realign),
      .rx_resetdone_o       (bhv_rx_resetdone),
      .rx_ei_en_o           ()
   );

`ifdef HAVE_VENDOR_SERDES
   logic        ref_clk_core;
   logic        ref_reset_core_n;
   logic        ref_tx_p, ref_tx_n;
   logic         ref_rx_p, ref_rx_n;
   logic        ref_tx_resetdone, ref_rx_resetdone;
   logic [63:0] ref_rx_data;
   logic  [7:0] ref_rx_k, ref_rx_comma, ref_rx_nit, ref_rx_disp;
   logic        ref_aligned, ref_realign, ref_tx_buf_err, ref_rx_buf_err;
   logic [15:0] ref_regfile_do;
   logic        ref_regfile_rdy;
   logic        ref_clk_core_rx;

   logic  [63:0] ref_tx_data;
   logic   [7:0] ref_tx_k;
   logic         ref_tx_elec_idle;
   logic         ref_rx_comma_en, ref_rx_mcomma, ref_rx_pcomma;

`ifdef CROSS_LINK
   always @(bhv_tx_p) ref_rx_p <= #(WIRE_DELAY_NS) bhv_tx_p;
   always @(bhv_tx_n) ref_rx_n <= #(WIRE_DELAY_NS) bhv_tx_n;
`else
   always @(ref_tx_p) ref_rx_p <= #(WIRE_DELAY_NS) ref_tx_p;
   always @(ref_tx_n) ref_rx_n <= #(WIRE_DELAY_NS) ref_tx_n;
`endif

   ccfpga_serdes_ref #(
      .PLL_FCNTRL               (PLL_FCNTRL),
      .PLL_MAIN_DIVSEL          (PLL_MAIN_DIVSEL),
      .PLL_OUT_DIVSEL           (PLL_OUT_DIVSEL),
      .RX_DATAPATH_SEL          (RX_DATAPATH_SEL),
      .TX_DATAPATH_SEL          (TX_DATAPATH_SEL),
      .ALIGN_MCOMMA_VALUE       (ALIGN_MCOMMA_VALUE),
      .ALIGN_PCOMMA_VALUE       (ALIGN_PCOMMA_VALUE),
      .ALIGN_COMMA_ENABLE       (ALIGN_COMMA_ENABLE),
      .ALIGN_COMMA_WORD         (ALIGN_COMMA_WORD),
      .RX_WAIT_CDR_LOCK         (RX_WAIT_CDR_LOCK),
      .PLL_CONFIG_SEL           (PLL_CONFIG_SEL),
      .PLL_SET_OP_LOCK          (PLL_SET_OP_LOCK),
      .PLL_LOCK_WINDOW          (PLL_LOCK_WINDOW),
      .PLL_FAST_LOCK            (PLL_FAST_LOCK),
      .PLL_REF_RTERM            (PLL_REF_RTERM),
      .PLL_CI                   (PLL_CI),
      .PLL_CP                   (PLL_CP),
      .PLL_SCAP_AUTO_CAL        (PLL_SCAP_AUTO_CAL),
      .PLL_FILTER_SHIFT         (PLL_FILTER_SHIFT),
      .PLL_SAR_LIMIT            (PLL_SAR_LIMIT),
      .PLL_FT                   (PLL_FT),
      .PLL_BISC_MODE            (PLL_BISC_MODE),
      .PLL_BISC_TIMER_MAX       (PLL_BISC_TIMER_MAX),
      .PLL_BISC_CP_MIN          (PLL_BISC_CP_MIN),
      .PLL_BISC_CP_MAX          (PLL_BISC_CP_MAX),
      .PLL_BISC_CP_START        (PLL_BISC_CP_START),
      .PLL_BISC_CAL_SIGN        (PLL_BISC_CAL_SIGN),
      .PLL_BISC_CAL_AUTO        (PLL_BISC_CAL_AUTO),
      .PLL_BISC_DLY_PFD_MON_DIV (PLL_BISC_DLY_PFD_MON_DIV),
      .PLL_BISC_COR_DLY         (PLL_BISC_COR_DLY)
   ) DUT_REF (
      .clk_ref_i            (clk_ref),
      .clk_reg_i            (clk_reg),
      .clk_cfg_i            (clk_cfg),
      .clk_core_tx_i        (ref_clk_core),
      .clk_core_rx_i        (ref_clk_core),
      .clk_core_rx_o        (ref_clk_core_rx),
      .reset_n_i            (reset_n),
      .reset_reg_n_i        (reset_reg_n),
      .reset_core_tx_n_i    (ref_reset_core_n),
      .reset_core_rx_n_i    (ref_reset_core_n),
      .testmode_i           (1'b0),
      .scan_enable_i        (1'b0),
      .scan_in_i            (7'h0),
      .scan_out_o           (),
      .loopback_i           (3'b000),
      .pll_reset_i          (1'b0),
      .clk_core_pll_o       (ref_clk_core),
      .reset_core_pll_n_o   (ref_reset_core_n),
      .refclk_sel_o         (),
      .refclk_rterm_o       (),
      .RX_SERIO_P_B         (ref_rx_p),
      .RX_SERIO_N_B         (ref_rx_n),
      .TX_SERIO_P_B         (ref_tx_p),
      .TX_SERIO_N_B         (ref_tx_n),
      .regfile_we_i         (regfile_we),
      .regfile_en_i         (regfile_en),
      .regfile_addr_i       (regfile_addr),
      .regfile_mask_i       (regfile_mask),
      .regfile_di_i         (regfile_di),
      .regfile_do_o         (ref_regfile_do),
      .regfile_rdy_o        (ref_regfile_rdy),
      .cfg_en_i             (cfg_en),
      .reset_cfg_i          (reset_cfg),
      .cfgfile_di_i         (cfgfile_di),
      .cfgfile_valid_i      (cfgfile_valid),
      .cfgfile_addr_i       (cfgfile_addr),
      .tx_reset_i           (1'b0),
      .tx_pcs_reset_i       (1'b0),
      .tx_pma_reset_i       (1'b0),
      .tx_elec_idle_i       (ref_tx_elec_idle),
      .tx_detect_rx_i       (1'b0),
      .tx_prbs_sel_i        (3'b000),
      .tx_prbs_force_err_i  (1'b0),
      .tx_powerdown_n_i     (1'b1),
      .tx_data_i            (ref_tx_data),
      .tx_char_is_k_i       (ref_tx_k),
      .tx_polarity_i        (1'b0),
      .tx_8b10b_en_i        (1'b1),
      .tx_8b10b_bypass_i    (8'h0),
      .tx_char_dispmode_i   (8'h0),
      .tx_char_dispval_i    (8'h0),
      .tx_buf_err_o         (ref_tx_buf_err),
      .tx_resetdone_o       (ref_tx_resetdone),
      .rx_detect_done_o     (),
      .rx_present_o         (),
      .TERM_SERIO_O         (),
      .rx_reset_i           (1'b0),
      .rx_pma_reset_i       (1'b0),
      .rx_eqa_reset_i       (1'b0),
      .rx_cdr_reset_i       (1'b0),
      .rx_pcs_reset_i       (1'b0),
      .rx_buf_reset_i       (1'b0),
      .rx_prbs_sel_i        (3'b000),
      .rx_prbs_cnt_reset_i  (1'b0),
      .rx_powerdown_n_i     (1'b1),
      .rx_en_ei_detector_i  (1'b0),
      .rx_comma_detect_en_i (ref_rx_comma_en),
      .rx_slide_i           (1'b0),
      .rx_polarity_i        (1'b0),
      .rx_8b10b_en_i        (1'b1),
      .rx_8b10b_bypass_i    (8'h0),
      .rx_mcomma_align_i    (ref_rx_mcomma),
      .rx_pcomma_align_i    (ref_rx_pcomma),
      .rx_prbs_err_o        (),
      .rx_data_o            (ref_rx_data),
      .rx_char_is_k_o       (ref_rx_k),
      .rx_char_is_comma_o   (ref_rx_comma),
      .rx_not_in_table_o    (ref_rx_nit),
      .rx_disp_err_o        (ref_rx_disp),
      .rx_buf_err_o         (ref_rx_buf_err),
      .rx_byte_is_aligned_o (ref_aligned),
      .rx_byte_realign_o    (ref_realign),
      .rx_resetdone_o       (ref_rx_resetdone),
      .rx_ei_en_o           ()
   );
`endif

   logic [63:0] exp_data [0:N_PAYLOAD-1];
   logic  [7:0] exp_k    [0:N_PAYLOAD-1];

   integer    gi, gj;
   logic [31:0] gseed;
   logic  [7:0] gbyte;

   initial begin : build_expected
      gseed = 32'h1234_5678;
      for (gi = 0; gi < N_PAYLOAD; gi = gi + 1) begin
         exp_data[gi] = 64'h0;
         exp_k[gi]    = 8'h0;
         for (gj = 0; gj < 8; gj = gj + 1) begin
            gseed = xs32(gseed);
            if (gseed[31:29] == 3'b000) begin
               case (gseed[2:0])
                 3'd0 : gbyte = 8'h1C;   3'd1 : gbyte = 8'h3C;
                 3'd2 : gbyte = 8'h5C;   3'd3 : gbyte = 8'h7C;
                 3'd4 : gbyte = 8'h9C;   3'd5 : gbyte = 8'hBC;
                 3'd6 : gbyte = 8'hFB;   3'd7 : gbyte = 8'hFD;
               endcase
               exp_k[gi][gj] = 1'b1;
            end
            else begin
               gbyte = gseed[15:8];
               exp_k[gi][gj] = 1'b0;
            end
            exp_data[gi][gj*8 +: 8] = gbyte;
         end
      end
   end

   integer bhv_state, bhv_cnt;
   real    bhv_marker_tx_t, bhv_marker_rx_t;

   initial begin
      bhv_state = ST_IDLE; bhv_cnt = 0;
      bhv_tx_data = 64'h0; bhv_tx_k = 8'h0; bhv_tx_elec_idle = 1'b1;
      bhv_rx_comma_en = 1'b0; bhv_rx_mcomma = 1'b0; bhv_rx_pcomma = 1'b0;
      bhv_marker_tx_t = 0.0; bhv_marker_rx_t = 0.0;
   end
   always @(posedge bhv_clk_core)
     if (bhv_state != ST_IDLE) begin
        bhv_rx_mcomma <= ~bhv_aligned;
        bhv_rx_pcomma <= ~bhv_aligned;
     end

   // both models are aligned: the run starts counting
`ifdef HAVE_VENDOR_SERDES
   logic link_ready;
   assign link_ready = bhv_aligned & ref_aligned;
`else
   logic link_ready;
   assign link_ready = bhv_aligned;
`endif

   always @(posedge bhv_clk_core) begin
      case (bhv_state)
        ST_IDLE : begin
           bhv_tx_data <= 64'h0; bhv_tx_k <= 8'h0;
           if (bhv_tx_resetdone) begin
              bhv_tx_elec_idle <= 1'b0;
              bhv_rx_comma_en  <= 1'b1;
              bhv_rx_mcomma    <= 1'b1;
              bhv_rx_pcomma    <= 1'b1;
              bhv_state        <= ST_TRAIN;
              bhv_cnt          <= 0;
           end
        end
        ST_TRAIN : begin
           bhv_tx_data <= TRAIN_D;
           bhv_tx_k    <= TRAIN_K;
           if (!link_ready) bhv_cnt <= 0;
           else if (bhv_cnt == N_TRAIN-1) begin bhv_state <= ST_MARKER; bhv_cnt <= 0; end
           else bhv_cnt <= bhv_cnt + 1;
        end
        ST_MARKER : begin
           bhv_tx_data <= MARK_D;
           bhv_tx_k    <= MARK_K;
           if (bhv_cnt == 0) bhv_marker_tx_t = $realtime;
           if (bhv_cnt == 1) begin bhv_state <= ST_PAYLOAD; bhv_cnt <= 0; end
           else bhv_cnt <= bhv_cnt + 1;
        end
        ST_PAYLOAD : begin
           bhv_tx_data <= exp_data[bhv_cnt];
           bhv_tx_k    <= exp_k[bhv_cnt];
           if (bhv_cnt == N_PAYLOAD-1) begin bhv_state <= ST_TAIL; bhv_cnt <= 0; end
           else bhv_cnt <= bhv_cnt + 1;
        end
        ST_TAIL : begin
           bhv_tx_data <= {8{COMMA}};
           bhv_tx_k    <= 8'hFF;
           if (bhv_cnt == N_TAIL-1) bhv_state <= ST_DONE;
           else bhv_cnt <= bhv_cnt + 1;
        end
        default : begin
           bhv_tx_data <= {8{COMMA}};
           bhv_tx_k    <= 8'hFF;
        end
      endcase
   end

`ifdef HAVE_VENDOR_SERDES
   integer ref_state, ref_cnt;
   real    ref_marker_tx_t, ref_marker_rx_t;

   initial begin
      ref_state = ST_IDLE; ref_cnt = 0;
      ref_tx_data = 64'h0; ref_tx_k = 8'h0; ref_tx_elec_idle = 1'b1;
      ref_rx_comma_en = 1'b0; ref_rx_mcomma = 1'b0; ref_rx_pcomma = 1'b0;
      ref_marker_tx_t = 0.0; ref_marker_rx_t = 0.0;
   end
   always @(posedge ref_clk_core)
     if (ref_state != ST_IDLE) begin
        ref_rx_mcomma <= ~ref_aligned;
        ref_rx_pcomma <= ~ref_aligned;
     end

   always @(posedge ref_clk_core) begin
      case (ref_state)
        ST_IDLE : begin
           ref_tx_data <= 64'h0; ref_tx_k <= 8'h0;
           if (ref_tx_resetdone) begin
              ref_tx_elec_idle <= 1'b0;
              ref_rx_comma_en  <= 1'b1;
              ref_rx_mcomma    <= 1'b1;
              ref_rx_pcomma    <= 1'b1;
              ref_state        <= ST_TRAIN;
              ref_cnt          <= 0;
           end
        end
        ST_TRAIN : begin
           ref_tx_data <= TRAIN_D;
           ref_tx_k    <= TRAIN_K;
           if (!link_ready) ref_cnt <= 0;
           else if (ref_cnt == N_TRAIN-1) begin ref_state <= ST_MARKER; ref_cnt <= 0; end
           else ref_cnt <= ref_cnt + 1;
        end
        ST_MARKER : begin
           ref_tx_data <= MARK_D;
           ref_tx_k    <= MARK_K;
           if (ref_cnt == 0) ref_marker_tx_t = $realtime;
           if (ref_cnt == 1) begin ref_state <= ST_PAYLOAD; ref_cnt <= 0; end
           else ref_cnt <= ref_cnt + 1;
        end
        ST_PAYLOAD : begin
           ref_tx_data <= exp_data[ref_cnt];
           ref_tx_k    <= exp_k[ref_cnt];
           if (ref_cnt == N_PAYLOAD-1) begin ref_state <= ST_TAIL; ref_cnt <= 0; end
           else ref_cnt <= ref_cnt + 1;
        end
        ST_TAIL : begin
           ref_tx_data <= {8{COMMA}};
           ref_tx_k    <= 8'hFF;
           if (ref_cnt == N_TAIL-1) ref_state <= ST_DONE;
           else ref_cnt <= ref_cnt + 1;
        end
        default : begin
           ref_tx_data <= {8{COMMA}};
           ref_tx_k    <= 8'hFF;
        end
      endcase
   end
`endif

   logic [63:0] bhv_cap_d [0:N_PAYLOAD-1];
   logic  [7:0] bhv_cap_k [0:N_PAYLOAD-1];
   logic  [7:0] bhv_cap_c [0:N_PAYLOAD-1];
   logic  [7:0] bhv_cap_e [0:N_PAYLOAD-1];
   logic  [7:0] bhv_cap_p [0:N_PAYLOAD-1];
   integer    bhv_cap_n;
   logic        bhv_capturing;
   logic        bhv_marker_seen;

   initial begin bhv_cap_n = 0; bhv_capturing = 1'b0; bhv_marker_seen = 1'b0; end

   always @(posedge bhv_clk_core) begin
      if (!bhv_capturing) begin
         if (bhv_aligned && (bhv_rx_data === MARK_D) && (bhv_rx_k === MARK_K)) begin
            if (!bhv_marker_seen) begin
               bhv_marker_seen <= 1'b1;
               bhv_marker_rx_t  = $realtime;
               $display("[%0t] BHV: marker word received, payload capture armed", $time);
            end
         end
         else if (bhv_marker_seen) begin
            bhv_capturing        <= 1'b1;
            bhv_cap_d[0]         <= bhv_rx_data;
            bhv_cap_k[0]         <= bhv_rx_k;
            bhv_cap_c[0]         <= bhv_rx_comma;
            bhv_cap_e[0]         <= bhv_rx_nit;
            bhv_cap_p[0]         <= bhv_rx_disp;
            bhv_cap_n            <= 1;
         end
      end
      else if (bhv_cap_n < N_PAYLOAD) begin
         bhv_cap_d[bhv_cap_n] <= bhv_rx_data;
         bhv_cap_k[bhv_cap_n] <= bhv_rx_k;
         bhv_cap_c[bhv_cap_n] <= bhv_rx_comma;
         bhv_cap_e[bhv_cap_n] <= bhv_rx_nit;
         bhv_cap_p[bhv_cap_n] <= bhv_rx_disp;
         bhv_cap_n            <= bhv_cap_n + 1;
      end
   end

   initial begin : bhv_progress
      @(posedge bhv_tx_resetdone);
      $display("[%0t] BHV: tx_resetdone asserted", $time);
      @(posedge bhv_aligned);
      $display("[%0t] BHV: rx_byte_is_aligned asserted", $time);
   end

`ifdef HAVE_VENDOR_SERDES
   logic [63:0] ref_cap_d [0:N_PAYLOAD-1];
   logic  [7:0] ref_cap_k [0:N_PAYLOAD-1];
   logic  [7:0] ref_cap_c [0:N_PAYLOAD-1];
   logic  [7:0] ref_cap_e [0:N_PAYLOAD-1];
   logic  [7:0] ref_cap_p [0:N_PAYLOAD-1];
   integer    ref_cap_n;
   logic        ref_capturing;
   logic        ref_marker_seen;

   initial begin ref_cap_n = 0; ref_capturing = 1'b0; ref_marker_seen = 1'b0; end

   always @(posedge ref_clk_core) begin
      if (!ref_capturing) begin
         if (ref_aligned && (ref_rx_data === MARK_D) && (ref_rx_k === MARK_K)) begin
            if (!ref_marker_seen) begin
               ref_marker_seen <= 1'b1;
               ref_marker_rx_t  = $realtime;
               $display("[%0t] REF: marker word received, payload capture armed", $time);
            end
         end
         else if (ref_marker_seen) begin
            ref_capturing        <= 1'b1;
            ref_cap_d[0]         <= ref_rx_data;
            ref_cap_k[0]         <= ref_rx_k;
            ref_cap_c[0]         <= ref_rx_comma;
            ref_cap_e[0]         <= ref_rx_nit;
            ref_cap_p[0]         <= ref_rx_disp;
            ref_cap_n            <= 1;
         end
      end
      else if (ref_cap_n < N_PAYLOAD) begin
         ref_cap_d[ref_cap_n] <= ref_rx_data;
         ref_cap_k[ref_cap_n] <= ref_rx_k;
         ref_cap_c[ref_cap_n] <= ref_rx_comma;
         ref_cap_e[ref_cap_n] <= ref_rx_nit;
         ref_cap_p[ref_cap_n] <= ref_rx_disp;
         ref_cap_n            <= ref_cap_n + 1;
      end
   end

   initial begin : ref_progress
      @(posedge ref_tx_resetdone);
      $display("[%0t] REF: tx_resetdone asserted", $time);
      @(posedge ref_aligned);
      $display("[%0t] REF: rx_byte_is_aligned asserted", $time);
   end
`endif

   integer errors_bhv_exp, errors_ref_exp, errors_bhv_ref;
   integer checks;
   integer ci;

   logic timed_out;

   integer trace_i;
   initial begin : bringup_trace
      for (trace_i = 0; trace_i < 40; trace_i = trace_i + 1) begin
         #25_000;
`ifdef HAVE_VENDOR_SERDES
         if ((bhv_cap_n < N_PAYLOAD) || (ref_cap_n < N_PAYLOAD))
           $display("[%0t] trace BHV: pll_rst_n=%b txdone=%b rxdone=%b align=%b st=%0d cap=%0d | REF: pll_rst_n=%b txdone=%b rxdone=%b align=%b st=%0d cap=%0d",
                    $time,
                    bhv_reset_core_n, bhv_tx_resetdone, bhv_rx_resetdone,
                    bhv_aligned, bhv_state, bhv_cap_n,
                    ref_reset_core_n, ref_tx_resetdone, ref_rx_resetdone,
                    ref_aligned, ref_state, ref_cap_n);
`else
         if (bhv_cap_n < N_PAYLOAD)
           $display("[%0t] trace BHV: pll_rst_n=%b txdone=%b rxdone=%b align=%b st=%0d cap=%0d",
                    $time, bhv_reset_core_n, bhv_tx_resetdone, bhv_rx_resetdone,
                    bhv_aligned, bhv_state, bhv_cap_n);
         $display("        BHV cdr_locked=%b rst_cnt=%0d ei_filt=%b ui=%.4f",
                  DUT_BHV.rx_cdr_locked, DUT_BHV.rx_rst_cnt, DUT_BHV.rx_ei_filt, DUT_BHV.ui);
`endif
      end
   end

   task rule_off;
      begin
         $display("-------------------------------------------------------------");
      end
   endtask

   initial begin : main
      errors_bhv_exp = 0; errors_ref_exp = 0; errors_bhv_ref = 0; checks = 0;

      $display("");
      $display("=============================================================");
      $display("  GateMate SerDes model equivalence test");
`ifdef HAVE_VENDOR_SERDES
      $display("  mode: BHV vs vendor REF vs EXPECTED");
`else
      $display("  mode: BHV vs EXPECTED only (vendor model not compiled in)");
`endif
      $display("=============================================================");

      #500;
      writeCfg(8'h5C, 16'h0001);
      #100;
      writeRegfile(8'h50, 16'h0002, 16'h0007);
      writeRegfile(8'h50, 16'h0003, 16'h0003);

      timed_out = 1'b0;
      fork : wait_or_timeout
         begin
            wait (bhv_cap_n == N_PAYLOAD);
`ifdef HAVE_VENDOR_SERDES
            wait (ref_cap_n == N_PAYLOAD);
`endif
         end
         begin
            #2_000_000;
            timed_out = 1'b1;
         end
      join_any
      disable wait_or_timeout;

      if (timed_out) begin
         $display("ERROR: watchdog expired before both models delivered %0d words",
                  N_PAYLOAD);
         $display("       BHV captured %0d", bhv_cap_n);
`ifdef HAVE_VENDOR_SERDES
         $display("       REF captured %0d", ref_cap_n);
`endif
         errors_bhv_exp = errors_bhv_exp + 1;
      end

      #1000;

      $display("");
      rule_off;
      $display("  CHECK 1 : behavioural model vs expected payload");
      rule_off;
      for (ci = 0; ci < N_PAYLOAD; ci = ci + 1) begin
         checks = checks + 1;
         if ((bhv_cap_d[ci] !== exp_data[ci]) || (bhv_cap_k[ci] !== exp_k[ci]) ||
             (bhv_cap_e[ci] !== 8'h00)        || (bhv_cap_p[ci] !== 8'h00)) begin
            if (errors_bhv_exp < 10)
              $display("  MISMATCH word %0d: got d=%h k=%h nit=%h disp=%h  exp d=%h k=%h",
                       ci, bhv_cap_d[ci], bhv_cap_k[ci], bhv_cap_e[ci], bhv_cap_p[ci],
                       exp_data[ci], exp_k[ci]);
            errors_bhv_exp = errors_bhv_exp + 1;
         end
      end
      $display("  %0d words checked, %0d mismatches", N_PAYLOAD, errors_bhv_exp);

`ifdef HAVE_VENDOR_SERDES
      $display("");
      rule_off;
      $display("  CHECK 2 : vendor model vs expected payload");
      rule_off;
      for (ci = 0; ci < N_PAYLOAD; ci = ci + 1) begin
         if ((ref_cap_d[ci] !== exp_data[ci]) || (ref_cap_k[ci] !== exp_k[ci]) ||
             (ref_cap_e[ci] !== 8'h00)        || (ref_cap_p[ci] !== 8'h00)) begin
            if (errors_ref_exp < 10)
              $display("  MISMATCH word %0d: got d=%h k=%h nit=%h disp=%h  exp d=%h k=%h",
                       ci, ref_cap_d[ci], ref_cap_k[ci], ref_cap_e[ci], ref_cap_p[ci],
                       exp_data[ci], exp_k[ci]);
            errors_ref_exp = errors_ref_exp + 1;
         end
      end
      $display("  %0d words checked, %0d mismatches", N_PAYLOAD, errors_ref_exp);

      $display("");
      rule_off;
      $display("  CHECK 3 : behavioural model vs vendor model (EQUIVALENCE)");
      rule_off;
      for (ci = 0; ci < N_PAYLOAD; ci = ci + 1) begin
         if ((bhv_cap_d[ci] !== ref_cap_d[ci]) || (bhv_cap_k[ci] !== ref_cap_k[ci]) ||
             (bhv_cap_c[ci] !== ref_cap_c[ci]) || (bhv_cap_e[ci] !== ref_cap_e[ci]) ||
             (bhv_cap_p[ci] !== ref_cap_p[ci])) begin
            if (errors_bhv_ref < 10)
              $display("  DIVERGENCE word %0d:\n    BHV d=%h k=%h com=%h nit=%h disp=%h\n    REF d=%h k=%h com=%h nit=%h disp=%h",
                       ci,
                       bhv_cap_d[ci], bhv_cap_k[ci], bhv_cap_c[ci], bhv_cap_e[ci], bhv_cap_p[ci],
                       ref_cap_d[ci], ref_cap_k[ci], ref_cap_c[ci], ref_cap_e[ci], ref_cap_p[ci]);
            errors_bhv_ref = errors_bhv_ref + 1;
         end
      end
      $display("  %0d words compared, %0d divergences", N_PAYLOAD, errors_bhv_ref);
`endif

      $display("");
      rule_off;
      $display("  LATENCY (TX parallel word in -> same word out at RX)");
      rule_off;
      $display("  BHV : marker tx @ %.1f ns, rx @ %.1f ns  ==>  %.1f ns",
               bhv_marker_tx_t, bhv_marker_rx_t, bhv_marker_rx_t - bhv_marker_tx_t);
`ifdef HAVE_VENDOR_SERDES
      $display("  REF : marker tx @ %.1f ns, rx @ %.1f ns  ==>  %.1f ns",
               ref_marker_tx_t, ref_marker_rx_t, ref_marker_rx_t - ref_marker_tx_t);
      $display("  delta (BHV - REF) = %.1f ns",
               (bhv_marker_rx_t - bhv_marker_tx_t) - (ref_marker_rx_t - ref_marker_tx_t));
`endif

      $display("");
      $display("=============================================================");
      if ((errors_bhv_exp == 0) && (errors_ref_exp == 0) && (errors_bhv_ref == 0)) begin
         $display("  RESULT: PASSED");
`ifdef HAVE_VENDOR_SERDES
         $display("  The behavioural model is stream-equivalent to the vendor");
         $display("  model over %0d words of mixed data and control traffic.", N_PAYLOAD);
`endif
      end
      else begin
         $display("  RESULT: FAILED");
         $display("    BHV vs EXPECTED : %0d", errors_bhv_exp);
`ifdef HAVE_VENDOR_SERDES
         $display("    REF vs EXPECTED : %0d", errors_ref_exp);
         $display("    BHV vs REF      : %0d", errors_bhv_ref);
`endif
      end
      $display("=============================================================");
      $display("");
      $finish;
   end

`ifdef DUMP
   initial begin
      $dumpfile("sim/equiv.fst");
      $dumpvars(0, tb_phy);
   end
`endif

endmodule

`else

module tb_phy ();

`ifdef PIPE

   // PIPE Parameter

   parameter        DATA_BYTES = 8;
   parameter        DATA_WIDTH = DATA_BYTES*8;

   // Signals

   // PIPE Interface
   logic                  o_PCLK;               // PCLK (user side)
   logic                   i_Reset;              // Async. Reset for Transceiver (Tx/Rx)
   logic            [ 1:0] i_PowerDown;          // Power States (P0 - P2)
   logic                   i_TxDetectRx;         // Receiver Detection (P0) or Loopback (P1)
   logic                   i_TxElecIdle;         // Tx Electrical Idle, Valid Data (P0) or Beacon (P2)
   logic  [DATA_BYTES-1:0] i_TxCompliance;       // Tx negative Disparity LSB (Compliance Pattern)
   //  wire                  i_TxSwing;        // Tx Voltage Swing Level [Optional by Spec]
   logic                   i_RxPolarity;         // Rx Polarity Inversion
   logic                  o_RxValid;            // Symbol Lock and Valid Data on RxData and RxDataK
   logic                  o_PhyStatus;          // Status of several PHY functions (Transition)
   logic                  o_RxElecIdle;         // Rx Detection of Electrical Idle
   logic           [ 2:0] o_RxStatus;           // Receiver Status and Received Data Status
   logic  [DATA_WIDTH-1:0] i_TxData;             // Tx Data
   logic  [DATA_BYTES-1:0] i_TxDataK;            // Tx K Data
   logic [DATA_WIDTH-1:0] o_RxData;             // Rx Data
   logic [DATA_BYTES-1:0] o_RxDataK;            // Rx K Data

   // Support Interface

   logic                  o_tx_buf_error;       // Tx Buffer Error
   logic                  o_clk_core_rx_rec;    // Rx Recovered Clock
   logic                   i_rx_buf_reset;       // Rx Buffer Reset
   logic                  o_rx_buf_err;         // Rx Buffer Error
   logic           [ 3:0] o_fsm_state_pipe;     // State of PIPE FSM
   logic           [ 1:0] o_fsm_state_align;    // State of Align FSM

   logic [DATA_BYTES-1:0] o_RxDataComma;        // Rx Byte Comma Indication
   logic [DATA_BYTES-1:0] o_RxDataDispErr;      // Rx Byte Disparity Error Indication
   logic [DATA_BYTES-1:0] o_RxDataDecErr;       // Rx Byte Decode Error Indication

   // Used by PIPE Logic (SerDes)

   logic        clk_core_tx;
   logic        clk_core_rx_rec;  // rx recovered clock
   logic        clk_core_pll;

   logic        pll_reset;
   logic        tx_reset;
   logic        tx_pcs_reset;
   logic        tx_pma_reset;

   logic  [2:0] loopback;

   logic        tx_elec_idle;
   logic        tx_detect_rx;
   logic  [2:0] tx_prbs_sel;
   logic        tx_prbs_force_err;
   logic        tx_powerdown_n;
   logic [63:0] tx_data;
   logic  [7:0] tx_char_is_k;
   logic        tx_polarity;
   logic        tx_8b10b_en;
   logic  [7:0] tx_8b10b_bypass;
   logic  [7:0] tx_char_dispmode;
   logic  [7:0] tx_char_dispval;

   logic        rx_reset;
   logic        rx_pma_reset;
   logic        rx_eqa_reset;
   logic        rx_cdr_reset;
   logic        rx_pcs_reset;
   logic        rx_buf_reset;
   logic  [2:0] rx_prbs_sel;
   logic        rx_prbs_cnt_reset;
   logic        rx_powerdown_n;
   logic        rx_en_ei_detector;
   logic        rx_comma_detect_en;
   logic        rx_slide;
   logic        rx_polarity;
   logic        rx_8b10b_en;
   logic  [7:0] rx_8b10b_bypass;
   logic        rx_mcomma_align;
   logic        rx_pcomma_align;

   logic        tx_buf_err;
   logic        tx_resetdone;
   logic        rx_detect_done;
   logic        rx_present;
   logic        rx_prbs_err;
   logic [63:0] rx_data;
   logic  [7:0] rx_char_is_k;
   logic  [7:0] rx_char_is_comma;
   logic  [7:0] rx_not_in_table;
   logic  [7:0] rx_disp_err;
   logic        rx_buf_err;
   logic        rx_byte_is_aligned;
   logic        rx_byte_realign;
   logic        rx_resetdone;
   logic        rx_ei_en;

`endif

   // Not available through FPGA Fabric 

   logic         clk_ref;
   logic         clk_reg;
   logic         clk_cfg;

   logic         reset_n;
   logic         reset_reg_n;
   logic        reset_core_pll_n;
   logic        reset_core_tx_n;
   logic        reset_core_rx_n;

   logic         testmode      = 1'b0;
   logic         scan_enable   = 1'b0;

   logic         cfg_en        = 1'b0;
   logic         reset_cfg     = 1'b0;
   logic  [15:0] cfgfile_di;
   logic         cfgfile_valid = 1'b0;
   logic   [7:0] cfgfile_addr;

   // Register Interface

   logic         regfile_we;
   logic         regfile_en    = 1'b0;
   logic   [7:0] regfile_addr;
   logic  [15:0] regfile_mask;
   logic  [15:0] regfile_di;
   logic [15:0] regfile_do;
   logic        regfile_rdy;

   // Analog

   `ifdef AMS
      electrical  TERM_SERIO;
      electrical  RX_SERIO_P;
      electrical  RX_SERIO_N;
      electrical  TX_SERIO_P;
      electrical  TX_SERIO_N;
   `else
      logic        TERM_SERIO;
      logic         RX_SERIO_P; 
      logic         RX_SERIO_N; 
      logic        TX_SERIO_P;
      logic        TX_SERIO_N;
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

   parameter  [5:0] PLL_FCNTRL               = 6'h1A;                   // (Default = 58 = T:20d)
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
      .clk_core_rx_i         ( clk_core_tx        ),
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
      .o_tx_clk             ( clk_core_tx        ),
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
      .o_clk_core_tx        (                    ),
      .o_clk_core_rx        (                    ),
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
      logic [31:0] pll_status;
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
      logic   [7:0] unit;
      logic  [15:0] pllDiv;
      logic  [31:0] status;
      logic  [31:0] bisc_result;
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



initial begin
    $dumpfile("sim/vlog_sim.vcd");
    $dumpvars(0, tb_phy);
end

// Include Testcases

`ifdef PIPE
// ---- testcase (formerly testcase_pipe.v)
////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Interessengruppe fuer Mikroelektronik und Eingebettete Systeme (IMES)
// Fachhochschule Dortmund
//
// Development in cooperation with Cologne Chip AG
//
// Filename     : testcase_pipe.v
// Author       : Philipp Leduc
// Tool         :
// Description  : Testcase for PIPE Interface of the Gatemate FPGA.
// Commentary   : The testcase is meant for usage with the modified SerDes Testbench.
//                Abreviations: [i_] > input,
//                              [o_] > output,
//                              [_n] > low active
//
// Changelog:
// -------------------------------------------------------------------------------------------------
// Version | Author             | Date       | Changes
// -------------------------------------------------------------------------------------------------
// 1.0     | Leduc              | 05.06.2021 | released
// -------------------------------------------------------------------------------------------------
////////////////////////////////////////////////////////////////////////////////////////////////////


// Connect Tx and Rx Line (incl. Delay)

//always @(TX_SERIO_P) RX_SERIO_P <= #10 TX_SERIO_P;
//always @(TX_SERIO_N) RX_SERIO_N <= #10 TX_SERIO_N;

logic S_FAULT_INJECTION  = 1'b0;

always @(TX_SERIO_P) begin

 if ( S_FAULT_INJECTION == 1'b1 )
    RX_SERIO_P <= #10 ~TX_SERIO_P;
 else 
    RX_SERIO_P <= #10 TX_SERIO_P;

 end // always

always @(TX_SERIO_N) begin

 if ( S_FAULT_INJECTION == 1'b1 )
    RX_SERIO_N <= #10 ~TX_SERIO_N;
 else 
    RX_SERIO_N <= #10 TX_SERIO_N;

 end // always

// Connect ADPLL Core Clock to Tx/Rx Datapath (happens now inside PIPE logic)
//assign clk_core_tx     = clk_core_pll;
//assign clk_core_rx_in  = clk_core_pll;

// Reset Connection (not Fabric)

assign reset_core_tx_n = reset_core_pll_n;
assign reset_core_rx_n = reset_core_pll_n;

// Variables
//reg  [2:0] alignment       = 3'b0;
//reg [63:0] recv_data       = 64'h0;
//reg [15:0] rterm_status    = 16'h0;
//reg        align_done_flag = 1'b0;
logic        transmission_start_flag = 1'b0;

logic         status_flag_1 = 1'b0;    // Status flags for simulation
logic         status_flag_2 = 1'b0;
logic         status_flag_3 = 1'b0;
logic         init_status_flag_done = 1'b0;
logic         s_fault_flag_for_rx = 1'b0;

integer i;
integer j;
integer k;
integer comma_pos;

// Testdata Arrays
logic [ 7:0] testdata     [39:0];
logic        testdata_k   [39:0];
logic        testdata_com [39:0];


// Functions and Tasks

task generate_data ();
  integer i;
  integer j;
  integer start_pos;
  integer pos_k;

  begin

    // fill array with data
    for ( i = 0; i < 40; i = i + 1 ) begin
        testdata[i] = $urandom%255;
        testdata_k[i] = 1'b0;
        testdata_com[i] =1 'b0;
    end

    // implement control bytes
    start_pos = $urandom%4;

    for ( j = start_pos; j < 39; j = j + 4 ) begin
        pos_k = $urandom%11;

        testdata[j] = setControlByte(pos_k);

        testdata_k[j] = 1'b1;

        // Check for COM Symbol
        if      ( testdata[j] == 8'hBC )
            testdata_com [j] = 1'b1;
        else if ( testdata[j] == 8'h3C )
            testdata_com [j] = 1'b1;
        else if ( testdata[j] == 8'hFC )
            testdata_com [j] = 1'b1;
        else
            testdata_com [j] =1'b0;
    end
  end
endtask

function [7:0] setControlByte(input integer pos);
   begin
    setControlByte = ( pos == 0 ) ?
                8'h1C :
                ( pos == 1 ) ?
                8'h3C :
                ( pos == 2 ) ?
                8'h5C :
                ( pos == 3 ) ?
                8'h7C :
                ( pos == 4 ) ?
                8'h9C :
                ( pos == 5 ) ?
                8'hBC :
                ( pos == 6 ) ?
                8'hDC :
                ( pos == 7 ) ?
                8'hFC :
                ( pos == 8 ) ?
                8'hF7 :
                ( pos == 9 ) ?
                8'hFB :
                ( pos == 10 ) ?
                8'hFD :
                8'hFE;
   end
endfunction 

integer                lat_pclk;
logic [DATA_WIDTH-1:0] lat_word;

task find_latency (input integer bytes);
    begin
    lat_word = (bytes == 2) ? {testdata[0], testdata[1]}
                            : {testdata[7], testdata[6], testdata[5], testdata[4],
                               testdata[3], testdata[2], testdata[1], testdata[0]};
    lat_pclk = 0;
    while ((o_RxData !== lat_word) && (lat_pclk < 200)) begin
        @(posedge o_PCLK); #1;
        lat_pclk = lat_pclk + 1;
    end
    if (o_RxData !== lat_word) begin
        $display("ERROR: test data did not come back within 200 PCLK cycles.");
        errors = errors + 1;
        finalize;
    end
    $display("INFO: test data comes back %0d PCLK cycles after send_testdata.", lat_pclk);
    end
endtask

task send_testdata (input integer bytes); 
    integer k;
  //  integer i;
    begin

    if ( bytes == 2) begin  // PIPE 16-Bit

        for ( k = 0; k < 40; k = k + 2 ) begin
       //     i = k + 1;
            @(posedge o_PCLK); #1;
            i_TxData   = {testdata[k], testdata[k+1]}; 
            i_TxDataK  = {testdata_k[k], testdata_k[k+1]};
        end
    end
    else begin // PIPE 64-Bit
        for ( k = 0; k < 40; k = k + 8 ) begin
            //i = k + 1;
            @(posedge o_PCLK); #1;
            i_TxData   = { testdata[k+7],testdata[k+6],testdata[k+5],testdata[k+4],
                           testdata[k+3],testdata[k+2],testdata[k+1],testdata[k]}; 
            i_TxDataK  = { testdata_k[k+7],testdata_k[k+6],testdata_k[k+5],testdata_k[k+4],
                           testdata_k[k+3],testdata_k[k+2],testdata_k[k+1],testdata_k[k]};
        end
    end

    @(posedge o_PCLK); #1;
    i_TxData             =  {DATA_WIDTH{1'b0}};
    i_TxDataK            =  {DATA_BYTES{1'b0}};
  end
endtask

task send_TS1_OS (input integer bytes);
    integer k;
    integer j;
    begin

    if ( bytes == 2) begin  // PIPE 16-Bit
        for ( k = 0; k < 1023; k = k + 1 ) begin // Create TS1 Ordered Set
            @(posedge o_PCLK); #1;

            i_TxData   = 16'h01BC; // TS1 first two bytes
            i_TxDataK  = 2'b01;

            for ( j = 0; j < 15; j = j + 1 ) begin 
                #8;
                i_TxData   = 16'h23CA;
                i_TxDataK  = 8'b00;
            end
        end
    end
    else begin // PIPE 64-Bit
        for ( k = 0; k < 1024; k = k + 1 ) begin // Create TS1 Ordered Set
            @(posedge o_PCLK); #1;

            i_TxData   = 64'h0802_0100_012A_01BC; // TS1 first part
            i_TxDataK  = 8'b0000_0001;
            #32;
            i_TxData   = 64'h162B_F45F_238A_0103; // TS1 second part
            i_TxDataK  = 8'b00_00_00_00;
            end
    end
   // i_TxData   = 64'h0000_0000_0000_0000; 
   // i_TxDataK  = 8'b0000_0000;
end
endtask

task check_testdata (input integer bytes);
    integer k;
    logic [15:0] testdata_16;
    logic  [1:0] testdata_k_16;
    logic  [1:0] testdata_com_16;
    logic [63:0] testdata_64;
    logic  [7:0] testdata_k_64;
    logic  [7:0] testdata_com_64;
  //  integer i;
    begin

    $display("---------------------------------------------");
    $display("  Beginning to check Data against Testdata   ");
    $display("---------------------------------------------");

    if ( bytes == 2) begin  // PIPE 16-Bit



        for ( k = 0; k < 40; k = k + 2 ) begin
            @(posedge o_PCLK); #1;

            testdata_16 = {testdata[k], testdata[k+1]};

            testdata_k_16 = {testdata_k[k], testdata_k[k+1]};

            testdata_com_16 = {testdata_com[k], testdata_com[k+1]};

            // Check RxData
            if ( o_RxData != testdata_16 ) begin

                checks_done = checks_done + 1;
                $display("ERROR: Received Data does not match Test Data.");
                $display("     o_RxData : %h", o_RxData);
                $display("     Testdata : %h", testdata_16);
                errors = errors + 1;
                finalize;
                end
            else begin
                checks_done = checks_done + 1;
                $display("     o_RxData : %h", o_RxData);
                $display("     Testdata : %h", testdata_16);
                $display("");
            end

            // Check RxDataK
            if ( o_RxDataK != testdata_k_16 ) begin

                checks_done = checks_done + 1;
                $display("ERROR: Received K Data does not match Test Data.");
                $display("    o_RxDataK : %b", o_RxDataK);
                $display("     Testdata : %b", testdata_k_16);
                errors = errors + 1;
                finalize;
                end
            else begin
                checks_done = checks_done + 1;
                $display("    o_RxDataK : %b", o_RxDataK);
                $display("     Testdata : %b", testdata_k_16);
                $display("");
            end

            // Check o_RxDataComma
            if ( o_RxDataComma != testdata_com_16 ) begin

                checks_done = checks_done + 1;
                $display("ERROR: Received COM Data does not match Test Data.");
                $display("o_RxDataComma : %b", o_RxDataComma);
                $display("     Testdata : %b", testdata_com_16);
                errors = errors + 1;
                finalize;
                end
            else begin
                checks_done = checks_done + 1;
                $display("o_RxDataComma : %b", o_RxDataComma);
                $display("     Testdata : %b", testdata_com_16);
                $display("---------------------------------------------");
            end
        end // for loop
    end // if

    else begin // PIPE 64-Bit

        for ( k = 0; k < 40; k = k + 8 ) begin
            @(posedge o_PCLK); #1;

            testdata_64 = { testdata[k+7],testdata[k+6],testdata[k+5],
                            testdata[k+4],testdata[k+3],testdata[k+2],
                            testdata[k+1],testdata[k] };

            testdata_k_64 = { testdata_k[k+7],testdata_k[k+6],testdata_k[k+5],
                              testdata_k[k+4],testdata_k[k+3],testdata_k[k+2],
                              testdata_k[k+1],testdata_k[k] };

            testdata_com_64 = { testdata_com[k+7],testdata_com[k+6],testdata_com[k+5],
                                testdata_com[k+4],testdata_com[k+3],testdata_com[k+2],
                                testdata_com[k+1],testdata_com[k] };

            // Check RxData
            if ( o_RxData != testdata_64 ) begin
                checks_done = checks_done + 1;
                $display("ERROR: Received Data does not match Test Data.");
                $display("     o_RxData : %h", o_RxData);
                $display("     Testdata : %h", testdata_64);
                errors = errors + 1;
                finalize;
                end
            else begin
                checks_done = checks_done + 1;
                $display("     o_RxData : %h", o_RxData);
                $display("     Testdata : %h", testdata_64);
                $display("");
            end

            // Check RxDataK
            if ( o_RxDataK != testdata_k_64) begin
                checks_done = checks_done + 1;
                $display("ERROR: Received K Data does not match Test Data.");
                $display("    o_RxDataK : %b", o_RxDataK);
                $display("     Testdata : %b", testdata_k_64);
                errors = errors + 1;
                finalize;
                end
            else begin
                checks_done = checks_done + 1;
                $display("    o_RxDataK : %b", o_RxDataK);
                $display("     Testdata : %b", testdata_k_64);
                $display("");
            end

            // Check o_RxDataComma
            if ( o_RxDataComma != testdata_com_64) begin
                checks_done = checks_done + 1;
                $display("ERROR: Received COM Data does not match Test Data.");
                $display("o_RxDataComma : %b", o_RxDataComma);
                $display("     Testdata : %b", testdata_com_64);
                errors = errors + 1;
                finalize;
                end
            else begin
                checks_done = checks_done + 1;
                $display("o_RxDataComma : %b", o_RxDataComma);
                $display("     Testdata : %b", testdata_com_64);
                $display("---------------------------------------------");
                $display("");
            end
        end // for loop
    end // else

    $display("INFO: Task check_testdata completed without Errors.");
    $display("");

    end // task
endtask 


task force_transm_err (input integer bit_error_cnt);
    integer i;
    begin
        for (i = 0; i < bit_error_cnt ; i = i + 1) begin
            s_fault_flag_for_rx <= #10 1'b1;
            S_FAULT_INJECTION <= 1'b1;
            #0.4;
            S_FAULT_INJECTION <= 1'b0;
            s_fault_flag_for_rx <= #10 1'b0;
            #4.5;
        end
  end // task
endtask 

task check_err_detect (input integer checks, bytes);
    integer k;
    integer i;
    integer j;
    integer m;

    logic [1:0] v_rx_not_in_table;
    logic [1:0] v_rx_disp_err;

    begin

    $display("---------------------------------------------------");
    $display("  Beginning to check Error Detection and RxStatus  ");
    $display("---------------------------------------------------");

    if ( bytes == 2) begin  // PIPE 16-Bit

        ////////////////////////////////////////////////////////////////////////////////////

        // Included Delay Time
        #466;

        @(posedge o_PCLK);

        for ( k = 0; k < checks; k = k + 1 ) begin

            for  ( m = 1; m < 8; m = m + 2) begin

            v_rx_not_in_table = rx_not_in_table[m -: 2];
            v_rx_disp_err     = rx_disp_err[m -: 2];


            @(posedge o_PCLK); #1;

                    // Check 8b/10b Error
                    if ( o_RxDataDecErr !=  v_rx_not_in_table) begin
                        checks_done = checks_done + 1;
                        $display("ERROR: 8b/10b Error of SerDes and PIPE do not match.");
                        $display(" o_RxDataDecErr : %b", o_RxDataDecErr);
                        $display("rx_not_in_table : %b", v_rx_not_in_table);
                        errors = errors + 1;
                        finalize;
                        end
                    else begin
                        checks_done = checks_done + 1;
                        $display(" o_RxDataDecErr : %b", o_RxDataDecErr);
                        $display("rx_not_in_table : %b", v_rx_not_in_table);
                        $display("");
                    end

                    // Check Disparity Error
                    if ( o_RxDataDispErr != v_rx_disp_err) begin

                        checks_done = checks_done + 1;
                        $display("ERROR: Disparity Error of SerDes and PIPE do not match.");
                        $display("o_RxDataDispErr : %b", o_RxDataDispErr);
                        $display("    rx_disp_err : %b", v_rx_disp_err);
                        errors = errors + 1;
                        finalize;
                        end
                    else begin
                        checks_done = checks_done + 1;
                        $display("o_RxDataDispErr : %b", o_RxDataDispErr);
                        $display("    rx_disp_err : %b", v_rx_disp_err);
                        $display("");
                    end

                    // Check RxStatus and RxData (8b/10b)
                    if ( |o_RxDataDecErr == 1'b1 ) begin

                        if (o_RxStatus != 3'b100 ) begin
                            checks_done = checks_done + 1;
                            $display("ERROR: RxStatus does not match Error Detection.");
                            $display("     o_RxStatus : %b", o_RxStatus);
                            $display("      Should be : 100");
                            errors = errors + 1;
                            finalize;
                            end
                        else begin
                            checks_done = checks_done + 1;
                            $display("     o_RxStatus : %b", o_RxStatus);
                            $display("");
                            end

                            // Check EDB Symbol Insertion
                            j = 7;
                            for (i = 0; i < 2; i = i + 1) begin
                                if ( o_RxDataDecErr[i] == 1'b1 ) begin
                                    if ( o_RxData[j -: 8] != 8'hFE ) begin
                                        checks_done = checks_done + 1;
                                        $display("ERROR: EDB Symbol not inserted for 8b/10b Error.");
                                        $display("       o_RxData : %h", o_RxData);
                                        $display(" o_RxDataDecErr : %b", o_RxDataDecErr);
                                        errors = errors + 1;
                                        finalize;
                                        end
                                    else begin
                                        checks_done = checks_done + 1;
                                        $display("---------------------------------------------");
                                        $display(" INFO: EDB Symbol inserted for 8b/10b Error. ");
                                        $display("---------------------------------------------");
                                        $display("");
                                        $display("   o_RxData[%0d:%0d]: %h",j,j-7,o_RxData[j -: 8]);
                                        $display("");
                                        $display("---------------------------------------------");
                                        end
                                end
                                j = j + 8;
                            end
                        end

                    else if ( |o_RxDataDispErr == 1'b1) begin

                        if (o_RxStatus != 3'b111 ) begin
                            checks_done = checks_done + 1;
                            $display("ERROR: RxStatus does not match Error Detection.");
                            $display("     o_RxStatus : %b", o_RxStatus);
                            $display("      Should be : 111");
                            errors = errors + 1;
                            finalize;
                            end
                        else begin
                            checks_done = checks_done + 1;
                            $display("     o_RxStatus : %b", o_RxStatus);
                            $display("---------------------------------------------");
                            end
                        end

                    else if (|o_RxDataDispErr == 1'b0 && |o_RxDataDecErr == 1'b0) begin

                        if (o_RxStatus != 3'b000 ) begin
                            checks_done = checks_done + 1;
                            $display("ERROR: RxStatus does not match Error Detection.");
                            $display("     o_RxStatus : %b", o_RxStatus);
                            $display("      Should be : 000");
                            errors = errors + 1;
                            finalize;
                            end
                        else begin
                            checks_done = checks_done + 1;
                            $display("     o_RxStatus : %b", o_RxStatus);
                            $display("---------------------------------------------");
                            end
                        end

                    else begin
                            $display("ERROR: RxStatus is unknown.");
                        end

                end // for loop (m)


            end // for loop

        end  // if

        ////////////////////////////////////////////////////////////////////////////////////

    else begin // PIPE 64-Bit

        // Included Delay Time
        #450;

        for ( k = 0; k < checks; k = k + 1 ) begin
            @(posedge o_PCLK); #1;

            // Check 8b/10b Error
            if ( o_RxDataDecErr !=  rx_not_in_table) begin
                checks_done = checks_done + 1;
                $display("ERROR: 8b/10b Error of SerDes and PIPE do not match.");
                $display(" o_RxDataDecErr : %b", o_RxDataDecErr);
                $display("rx_not_in_table : %b", rx_not_in_table);
                errors = errors + 1;
                finalize;
                end
            else begin
                checks_done = checks_done + 1;
                $display(" o_RxDataDecErr : %b", o_RxDataDecErr);
                $display("rx_not_in_table : %b", rx_not_in_table);
                $display("");
            end

            // Check Disparity Error
            if ( o_RxDataDispErr != rx_disp_err ) begin

                checks_done = checks_done + 1;
                $display("ERROR: Disparity Error of SerDes and PIPE do not match.");
                $display("o_RxDataDispErr : %b", o_RxDataDispErr);
                $display("    rx_disp_err : %b", rx_disp_err);
                errors = errors + 1;
                finalize;
                end
            else begin
                checks_done = checks_done + 1;
                $display("o_RxDataDispErr : %b", o_RxDataDispErr);
                $display("    rx_disp_err : %b", rx_disp_err);
                $display("");
            end

            // Check RxStatus and RxData (8b/10b)
            if ( |o_RxDataDecErr == 1'b1 ) begin

                if (o_RxStatus != 3'b100 ) begin
                    checks_done = checks_done + 1;
                    $display("ERROR: RxStatus does not match Error Detection.");
                    $display("     o_RxStatus : %b", o_RxStatus);
                    $display("      Should be : 100");
                    errors = errors + 1;
                    finalize;
                    end
                else begin
                    checks_done = checks_done + 1;
                    $display("     o_RxStatus : %b", o_RxStatus);
                    $display("");
                    end

                    // Check EDB Symbol Insertion
                    j = 7;
                    for (i = 0; i < 8; i = i + 1) begin
                        if ( o_RxDataDecErr[i] == 1'b1 ) begin
                            if ( o_RxData[j -: 8] != 8'hFE ) begin
                                checks_done = checks_done + 1;
                                $display("ERROR: EDB Symbol not inserted for 8b/10b Error.");
                                $display("       o_RxData : %h", o_RxData);
                                $display(" o_RxDataDecErr : %b", o_RxDataDecErr);
                                errors = errors + 1;
                                finalize;
                                end
                            else begin
                                checks_done = checks_done + 1;
                                $display("---------------------------------------------");
                                $display(" INFO: EDB Symbol inserted for 8b/10b Error. ");
                                $display("---------------------------------------------");
                                $display("");
                                $display("   o_RxData[%0d:%0d]: %h",j,j-7,o_RxData[j -: 8]);
                                $display("");
                                $display("---------------------------------------------");
                                end
                        end
                        j = j + 8;
                    end
                end

            else if ( |o_RxDataDispErr == 1'b1) begin

                if (o_RxStatus != 3'b111 ) begin
                    checks_done = checks_done + 1;
                    $display("ERROR: RxStatus does not match Error Detection.");
                    $display("     o_RxStatus : %b", o_RxStatus);
                    $display("      Should be : 111");
                    errors = errors + 1;
                    finalize;
                    end
                else begin
                    checks_done = checks_done + 1;
                    $display("     o_RxStatus : %b", o_RxStatus);
                    $display("---------------------------------------------");
                    end
                end

            else if (|o_RxDataDispErr == 1'b0 && |o_RxDataDecErr == 1'b0) begin

                if (o_RxStatus != 3'b000 ) begin
                    checks_done = checks_done + 1;
                    $display("ERROR: RxStatus does not match Error Detection.");
                    $display("     o_RxStatus : %b", o_RxStatus);
                    $display("      Should be : 000");
                    errors = errors + 1;
                    finalize;
                    end
                else begin
                    checks_done = checks_done + 1;
                    $display("     o_RxStatus : %b", o_RxStatus);
                    $display("---------------------------------------------");
                    end
                end

            else begin
                    $display("ERROR: RxStatus is unknown.");
                end

            end // for loop

        end // else

        $display("");
        $display("INFO: Task check_err_detect completed without Errors.");
        $display("");

  end // task
endtask 


initial
    begin

    $printtimescale(tb_phy);


    i_Reset =  1'b0;  // Low active

    // Reset Values PIPE Control Signals

    i_PowerDown          =  2'b10;
    i_TxDetectRx         =  1'b0;
    i_TxElecIdle         =  1'b1;
    i_TxCompliance       =  {DATA_BYTES{1'b0}};
    i_RxPolarity         =  1'b0;
    i_TxData             =  {DATA_WIDTH{1'b0}};
    i_TxDataK            =  {DATA_BYTES{1'b0}};

    i_rx_buf_reset       =  1'b0;

    #20;

    i_Reset =  1'b1;    // Release Reset

    // Wait for different Resets to be done.

    #500;

    writeCfg(8'h5C, 16'h0001); // Enable Serdes

    #100;

    writeRegfile(8'h50, 16'h0002, 16'h0007);  // Config Sel
    writeRegfile(8'h50, 16'h0003, 16'h0003);  // Config Sel + Adpll Enable

    // Alternative Method
    //startSerIOADPLL(5, 1, 5, 2, 1'b0); // 1,25 GHz -> 2,5Gb/s (PCIe)


    // Wait for PhyStatus 

    #2000;

    #35200; // Lock Time PLL

    if (o_PhyStatus == 1'b1) begin
        checks_done = checks_done + 1;
        $display("ERROR: PhyStatus did not signal sucessive Reset");
        errors = errors + 1;
        finalize;
        end
    else if (o_PhyStatus == 1'b0) begin
        checks_done = checks_done + 1;
        $display("INFO: PhyStatus turned to 0 after Reset");
        end
    else begin
        checks_done = checks_done + 1;
        $display("ERROR: PhyStatus is unknown");
        errors = errors + 1;
        finalize;
    end

status_flag_1 = 1'b1;
    // Start of Powerstate Transition Tests

    // Transit to Powerstate P0 (IDLE)

    @(posedge o_PCLK);

    i_PowerDown          =  2'b00;     // P0
    i_TxDetectRx         =  1'b0;
    i_TxElecIdle         =  1'b1;      // Elec Idle
    i_TxCompliance       =  {DATA_BYTES{1'b0}};
    i_RxPolarity         =  1'b0;
    i_TxData             =  {DATA_WIDTH{1'b0}};
    i_TxDataK            =  {DATA_BYTES{1'b0}};

    #128;

    // Transit to Powerstate P1

    @(posedge o_PCLK);

    i_PowerDown          =  2'b10;     // P1
    i_TxDetectRx         =  1'b0;
    i_TxElecIdle         =  1'b1;      // Elec Idle
    i_TxCompliance       =  {DATA_BYTES{1'b0}};
    i_RxPolarity         =  1'b0;
    i_TxData             =  {DATA_WIDTH{1'b0}};
    i_TxDataK            =  {DATA_BYTES{1'b0}};

    #128;

    // Transit to Powerstate P0 (Normal Transmission)

    @(posedge o_PCLK); 

    i_PowerDown          =  2'b00;     // P0
    i_TxDetectRx         =  1'b0;
    i_TxElecIdle         =  1'b0;      // Elec Idle
    i_TxCompliance       =  {DATA_BYTES{1'b0}};
    i_RxPolarity         =  1'b0;
    i_TxData             =  {DATA_WIDTH{1'b0}};
    i_TxDataK            =  {DATA_BYTES{1'b0}};

    #128;


    // Transit to Powerstate P1

    @(posedge o_PCLK);

    i_PowerDown          =  2'b10;     // P1
    i_TxDetectRx         =  1'b0;
    i_TxElecIdle         =  1'b1;      // Elec Idle
    i_TxCompliance       =  {DATA_BYTES{1'b0}};
    i_RxPolarity         =  1'b0;
    i_TxData             =  {DATA_WIDTH{1'b0}};
    i_TxDataK            =  {DATA_BYTES{1'b0}};

    #256;

    // Transit to Powerstate P0 (Loopback)

    @(posedge o_PCLK);

    i_PowerDown          =  2'b00;     // P0
    i_TxDetectRx         =  1'b1;      // Loopmode
    i_TxElecIdle         =  1'b0;      // Elec Idle
    i_TxCompliance       =  {DATA_BYTES{1'b0}};
    i_RxPolarity         =  1'b0;
    i_TxData             =  {DATA_WIDTH{1'b0}};
    i_TxDataK            =  {DATA_BYTES{1'b0}};

    #128;

    // Transit to Powerstate P1

    @(posedge o_PCLK);

    i_PowerDown          =  2'b10;     // P1
    i_TxDetectRx         =  1'b0;
    i_TxElecIdle         =  1'b1;      // Elec Idle
    i_TxCompliance       =  {DATA_BYTES{1'b0}};
    i_RxPolarity         =  1'b0;
    i_TxData             =  {DATA_WIDTH{1'b0}};
    i_TxDataK            =  {DATA_BYTES{1'b0}};

    #384; 

    // End of Powerstate Transition Tests


    // Transit to Powerstate P0 (Idle)

    //@(posedge o_PCLK);

    i_PowerDown          =  2'b00;     // P0
    i_TxDetectRx         =  1'b0;
    i_TxElecIdle         =  1'b1;      // Elec Idle
    i_TxCompliance       =  {DATA_BYTES{1'b0}};
    i_RxPolarity         =  1'b0;
    i_TxData             =  {DATA_WIDTH{1'b0}};
    i_TxDataK            =  {DATA_BYTES{1'b0}};

    #128;

    // Transit to Powerstate P0 (Normal)

    @(posedge o_PCLK); #1;

    i_PowerDown          =  2'b00;     // P0
    i_TxDetectRx         =  1'b0;
    i_TxElecIdle         =  1'b0;      // Elec Idle
    i_TxCompliance       =  {DATA_BYTES{1'b0}};
    i_RxPolarity         =  1'b0;
    i_TxData             =  {DATA_WIDTH{1'b0}};
    i_TxDataK            =  {DATA_BYTES{1'b0}};

    #128;

    // Send TS1 Ordered Sets for Word Alignment

    //send_TS1_OS(8);
      send_TS1_OS(DATA_BYTES);

    // Normal Transmission Test

    generate_data;
    send_testdata(DATA_BYTES);
    find_latency(DATA_BYTES);

    for (i = 0; i < 100 ; i = i + 1) begin
        generate_data;
        send_testdata(DATA_BYTES);
        repeat (lat_pclk - 1) @(posedge o_PCLK);
        //#534;
        //#16;
        //#64;
        check_testdata(DATA_BYTES);
    end




    // Reset Test ( During Normal Operation )

    @(posedge o_PCLK); 
    i_TxData             =  64'hB59C_A235_FBB5_F6D3;
    i_TxDataK            =  8'b0100_1000;

    #1000;

    i_Reset              =  1'b0;  // Low Active
    i_PowerDown          =  2'b10;
    i_TxDetectRx         =  1'b0;
    i_TxElecIdle         =  1'b1;
    i_TxCompliance       =  {DATA_BYTES{1'b0}};
    i_RxPolarity         =  1'b0;
    i_TxData             =  {DATA_WIDTH{1'b0}};
    i_TxDataK            =  {DATA_BYTES{1'b0}};

    #20;
    i_Reset              =  1'b1;  // Release Reset

    // Wait for end of Reset

    while (o_PhyStatus == 1'b1) begin
        @(posedge o_PCLK); #1;
    end

    #128;

    // Transition to P0 (Normal Transmission)

    @(posedge o_PCLK);

    i_PowerDown          =  2'b00;
    i_TxDetectRx         =  1'b0;
    i_TxElecIdle         =  1'b0;
    i_TxCompliance       =  {DATA_BYTES{1'b0}};
    i_RxPolarity         =  1'b0;
    i_TxData             =  {DATA_WIDTH{1'b0}};
    i_TxDataK            =  {DATA_BYTES{1'b0}};

    // Reestablish Word Alignment

    #155;

    send_TS1_OS(DATA_BYTES);

    #50;

    // Error Detection Test

    @(posedge o_PCLK);

    i_TxData             =  64'hB5B5_B5B5_B5B5_B5B5;
    i_TxDataK            =  8'b0000_0000;

    #212;

    fork
        check_err_detect (50,DATA_BYTES);
        force_transm_err (400);
    join

    #200;

    // Negative Disparity Test

    if (DATA_BYTES == 32'd2) begin

        for (i = 0; i < 4; i = i + 1) begin

        @(posedge o_PCLK);
        i_TxData             =  16'hBCBC;
        i_TxDataK            =  2'b11;
        i_TxCompliance       =  2'b11;
        end

        #500;

        for (i = 0; i < 4; i = i + 1) begin

        @(posedge o_PCLK);
        i_TxData             =  16'hBCBC;
        i_TxDataK            =  2'b11;
        i_TxCompliance       =  2'b01;
        end

    end

    else begin

        @(posedge o_PCLK);
        i_TxData             =  64'hBCBC_BCBC_BCBC_BCBC;
        i_TxDataK            =  8'b1111_1111;
        i_TxCompliance       =  8'b1111_1111;

        #500;

        @(posedge o_PCLK);
        i_TxData             =  64'hBCBC_BCBC_BCBC_BCBC;
        i_TxDataK            =  8'b0101_0101;
        i_TxCompliance       =  8'b0101_0101;

    end

    #300;



    // Loopmode Test


    // Transition to P0 (Loopback)

    @(posedge o_PCLK);

    i_TxData             =  64'hB5B5_B5B5_B5B5_B5B5;
    //i_TxData             =  64'hD1B4_C345_DE_E545;
    i_TxDataK            =  8'b0000_0000;
    i_TxCompliance       =  {DATA_BYTES{1'b0}};

    #1000;

    // Activate Loopback Mode

    @(posedge o_PCLK); 
    i_PowerDown          =  2'b00;
    i_TxDetectRx         =  1'b1;   // Loopback Modus
    i_TxElecIdle         =  1'b0;
    i_TxData             =  {DATA_WIDTH{1'b0}};
    i_TxDataK            =  {DATA_BYTES{1'b0}};
    i_RxPolarity         =  1'b0;

    #1500;

    // Deactivate Loopback Mode

    @(posedge o_PCLK);
    i_PowerDown          =  2'b00;
    i_TxDetectRx         =  1'b0;   // Loopback Modus
    i_TxElecIdle         =  1'b0;
    i_TxData             =  {DATA_WIDTH{1'b0}};
    i_TxDataK            =  {DATA_BYTES{1'b0}};
    i_RxPolarity         =  1'b0;

    #500;
/*
    // Receiver Detection Test

    @(posedge o_PCLK);

    i_PowerDown          =  2'b10;     // P1
    i_TxDetectRx         =  1'b0;
    i_TxElecIdle         =  1'b1;      // Elec Idle
    i_TxCompliance       =  {DATA_BYTES{1'b0}};
    i_RxPolarity         =  1'b0;
    i_TxData             =  {DATA_WIDTH{1'b0}};
    i_TxDataK            =  {DATA_BYTES{1'b0}};

    #256;

    // Start Detection

    @(posedge o_PCLK);
    init_status_flag_done = 1'b1;

    i_PowerDown          =  2'b10;     // P1
    i_TxDetectRx         =  1'b1;
    i_TxElecIdle         =  1'b1;      // Elec Idle
    i_TxCompliance       =  {DATA_BYTES{1'b0}};
    i_RxPolarity         =  1'b0;
    i_TxData             =  {DATA_WIDTH{1'b0}};
    i_TxDataK            =  {DATA_BYTES{1'b0}};
*/
    #30000;

    finalize;

    end // initial


`endif

endmodule

`endif
