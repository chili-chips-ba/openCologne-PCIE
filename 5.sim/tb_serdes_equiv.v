`timescale 1ns/100fs

module tb_serdes_equiv;

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

   reg  clk_ref, clk_reg, clk_cfg;
   reg  reset_n, reset_reg_n;

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

   reg        regfile_we, regfile_en;
   reg  [7:0] regfile_addr;
   reg [15:0] regfile_mask, regfile_di;
   reg        cfg_en, reset_cfg, cfgfile_valid;
   reg [15:0] cfgfile_di;
   reg  [7:0] cfgfile_addr;

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

`ifdef HAVE_VENDOR_SERDES
   wire link_ready = bhv_aligned & ref_aligned;
`else
   wire link_ready = bhv_aligned;
`endif

   function [31:0] xs32;
      input [31:0] s;
      reg   [31:0] v;
      begin
         v = s;
         v = v ^ (v << 13);
         v = v ^ (v >> 17);
         v = v ^ (v << 5);
         xs32 = v;
      end
   endfunction

   wire        bhv_clk_core;
   wire        bhv_reset_core_n;
   wire        bhv_tx_p, bhv_tx_n;
   reg         bhv_rx_p, bhv_rx_n;
   wire        bhv_tx_resetdone, bhv_rx_resetdone;
   wire [63:0] bhv_rx_data;
   wire  [7:0] bhv_rx_k, bhv_rx_comma, bhv_rx_nit, bhv_rx_disp;
   wire        bhv_aligned, bhv_realign, bhv_tx_buf_err, bhv_rx_buf_err;
   wire [15:0] bhv_regfile_do;
   wire        bhv_regfile_rdy;
   wire        bhv_clk_core_rx;

   reg  [63:0] bhv_tx_data;
   reg   [7:0] bhv_tx_k;
   reg         bhv_tx_elec_idle;
   reg         bhv_rx_comma_en, bhv_rx_mcomma, bhv_rx_pcomma;

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
   wire        ref_clk_core;
   wire        ref_reset_core_n;
   wire        ref_tx_p, ref_tx_n;
   reg         ref_rx_p, ref_rx_n;
   wire        ref_tx_resetdone, ref_rx_resetdone;
   wire [63:0] ref_rx_data;
   wire  [7:0] ref_rx_k, ref_rx_comma, ref_rx_nit, ref_rx_disp;
   wire        ref_aligned, ref_realign, ref_tx_buf_err, ref_rx_buf_err;
   wire [15:0] ref_regfile_do;
   wire        ref_regfile_rdy;
   wire        ref_clk_core_rx;

   reg  [63:0] ref_tx_data;
   reg   [7:0] ref_tx_k;
   reg         ref_tx_elec_idle;
   reg         ref_rx_comma_en, ref_rx_mcomma, ref_rx_pcomma;

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

   reg [63:0] exp_data [0:N_PAYLOAD-1];
   reg  [7:0] exp_k    [0:N_PAYLOAD-1];

   integer    gi, gj;
   reg [31:0] gseed;
   reg  [7:0] gbyte;

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

   reg [63:0] bhv_cap_d [0:N_PAYLOAD-1];
   reg  [7:0] bhv_cap_k [0:N_PAYLOAD-1];
   reg  [7:0] bhv_cap_c [0:N_PAYLOAD-1];
   reg  [7:0] bhv_cap_e [0:N_PAYLOAD-1];
   reg  [7:0] bhv_cap_p [0:N_PAYLOAD-1];
   integer    bhv_cap_n;
   reg        bhv_capturing;
   reg        bhv_marker_seen;

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
   reg [63:0] ref_cap_d [0:N_PAYLOAD-1];
   reg  [7:0] ref_cap_k [0:N_PAYLOAD-1];
   reg  [7:0] ref_cap_c [0:N_PAYLOAD-1];
   reg  [7:0] ref_cap_e [0:N_PAYLOAD-1];
   reg  [7:0] ref_cap_p [0:N_PAYLOAD-1];
   integer    ref_cap_n;
   reg        ref_capturing;
   reg        ref_marker_seen;

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

   reg timed_out;

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
      $display("");
      $display("  NOTE: testcase_pipe.v hard-codes a #350 wait between send and");
      $display("        check, so this delta must stay small for that testcase");
      $display("        to pass unmodified against the behavioural model.");
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
      $dumpvars(0, tb_serdes_equiv);
   end
`endif

endmodule
