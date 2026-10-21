`timescale 1ns/100fs

module tb_dll_phy;

   localparam DATA_BYTES = 8;
   localparam DATA_WIDTH = DATA_BYTES * 8;

   localparam real CLKPERIOD_REF   = 10.0;
   localparam real CLKPERIOD_REG   =  8.0;
   localparam real CLKPERIOD_CFG   = 40.0;
   localparam real WIRE_DELAY_NS   = 10.0;
   localparam real GLITCH_DELAY_NS = 176.0;
   localparam real GLITCH_PULSE_NS = 0.8;
   localparam real GLITCH_GAP_NS   = 3.2;
   localparam      GLITCH_PULSES   = 16;

   localparam EP = 0;
   localparam RC = 1;

   localparam [7:0] PAD         = 8'hF7;
   localparam [7:0] RC_LINK_NUM = 8'h00;
   localparam [7:0] RC_LANE_NUM = 8'h00;

   localparam [4:0] DETECT_QUIET                    = 5'b00000,
                    DETECT_ACTIVE                   = 5'b00001,
                    POLLING_ACTIVE                  = 5'b00010,
                    POLLING_CONFIG                  = 5'b00011,
                    CONFIG_LINKWIDTH_START          = 5'b00100,
                    CONFIG_LINKWIDTH_ACCEPT         = 5'b00101,
                    CONFIG_LANENUM_ACCEPT           = 5'b00111,
                    CONFIG_COMPLETE                 = 5'b01000,
                    CONFIG_IDLE                     = 5'b01001,
                    L0                              = 5'b01010,
                    RECOVERY_RCVRLOCK               = 5'b01011,
                    PRE_CONFIG_LINKWIDTH_START      = 5'b01100,
                    CONFIG_LINKWIDTH_START_LINKNUM  = 5'b10010,
                    CONFIG_LINKWIDTH_ACCEPT_LANENUM = 5'b10011,
                    RECOVERY_RCVRCFG                = 5'b10100,
                    RECOVERY_IDLE                   = 5'b10101,
                    PRE_DETECT_ACTIVE               = 5'b11010,
                    PRE_DETECT_QUIET                = 5'b11011,
                    PRE_POLLING_CONFIG              = 5'b11100,
                    PRE_CONFIG_LINKWIDTH_START_CNT  = 5'b11101;

   function [8*32-1:0] ltssm_name(input [4:0] s);
      case (s)
         DETECT_QUIET                    : ltssm_name = "Detect.Quiet";
         DETECT_ACTIVE                   : ltssm_name = "Detect.Active";
         POLLING_ACTIVE                  : ltssm_name = "Polling.Active";
         POLLING_CONFIG                  : ltssm_name = "Polling.Configuration";
         CONFIG_LINKWIDTH_START_LINKNUM  : ltssm_name = "Config.Linkwidth.Start (link#)";
         CONFIG_LINKWIDTH_START          : ltssm_name = "Config.Linkwidth.Start";
         CONFIG_LINKWIDTH_ACCEPT_LANENUM : ltssm_name = "Config.Linkwidth.Accept (lane#)";
         CONFIG_LINKWIDTH_ACCEPT         : ltssm_name = "Config.Linkwidth.Accept";
         CONFIG_LANENUM_ACCEPT           : ltssm_name = "Config.Lanenum.Accept";
         CONFIG_COMPLETE                 : ltssm_name = "Config.Complete";
         CONFIG_IDLE                     : ltssm_name = "Config.Idle";
         L0                              : ltssm_name = "L0";
         RECOVERY_RCVRLOCK               : ltssm_name = "Recovery.RcvrLock";
         RECOVERY_RCVRCFG                : ltssm_name = "Recovery.RcvrCfg";
         RECOVERY_IDLE                   : ltssm_name = "Recovery.Idle";
         default                         : ltssm_name = "";
      endcase
   endfunction

   logic clk_ref, clk_reg, clk_cfg;
   logic reset_n;

   initial clk_ref = 1'b1;
   always #(CLKPERIOD_REF/2.0) clk_ref = ~clk_ref;
   initial clk_reg = 1'b1;
   always #(CLKPERIOD_REG/2.0) clk_reg = ~clk_reg;
   initial clk_cfg = 1'b1;
   always #(CLKPERIOD_CFG/2.0) clk_cfg = ~clk_cfg;

   initial begin
      reset_n = 1'b0;
      #(CLKPERIOD_REF*20 + 1) reset_n = 1'b1;
   end

   logic ep_tx_p, ep_tx_n, rc_tx_p, rc_tx_n;
   logic  ep2rc_p, ep2rc_n, rc2ep_p, rc2ep_n;
   logic  serial_glitch;

   always @(ep_tx_p) ep2rc_p <= #(WIRE_DELAY_NS) ep_tx_p;
   always @(ep_tx_n) ep2rc_n <= #(WIRE_DELAY_NS) ep_tx_n;
   always @(rc_tx_p) rc2ep_p <= #(WIRE_DELAY_NS) rc_tx_p;
   always @(rc_tx_n) rc2ep_n <= #(WIRE_DELAY_NS) rc_tx_n;

   logic                  pclk        [0:1];
   logic                  link_up     [0:1];
   logic            [4:0] ltssm       [0:1];
   logic                  serdes_rdy  [0:1];
   logic                  rx_valid    [0:1];
   logic [DATA_BYTES-1:0] disp_err    [0:1];
   logic [DATA_BYTES-1:0] dec_err     [0:1];
   logic                  tx_buf_err  [0:1];

   logic  [DATA_WIDTH-1:0] tx_data     [0:1];
   logic                   tx_valid    [0:1];
   logic                   tx_first    [0:1];
   logic                   tx_last     [0:1];
   logic                   tx_half     [0:1];
   logic                  tx_ready    [0:1];
   logic             [7:0] tx_hdr      [0:1];
   logic            [11:0] tx_dcr      [0:1];
   logic             [1:0] tx_upd      [0:1];
   logic             [1:0] tx_pkt      [0:1];
   logic                   tx_dllp     [0:1];

   logic [DATA_WIDTH-1:0] rx_data     [0:1];
   logic                  rx_tvalid   [0:1];
   logic                  rx_first    [0:1];
   logic                  rx_last     [0:1];
   logic            [7:0] rx_hdr      [0:1];
   logic           [11:0] rx_dcr      [0:1];
   logic            [1:0] rx_upd      [0:1];
   logic            [1:0] rx_pkt      [0:1];
   logic                  rx_dllp     [0:1];

   pcie_stack #(.DATA_BYTES(DATA_BYTES)) ep (
      .clk_ref           ( clk_ref        ),
      .clk_reg           ( clk_reg        ),
      .clk_cfg           ( clk_cfg        ),
      .reset_n           ( reset_n        ),
      .o_PCLK            ( pclk[EP]       ),
      .o_LinkUp          ( link_up[EP]    ),
      .o_ltssm_state     ( ltssm[EP]      ),
      .o_serdes_ready    ( serdes_rdy[EP] ),
      .o_RxValid         ( rx_valid[EP]   ),
      .o_RxDataDispErr   ( disp_err[EP]   ),
      .o_RxDataDecErr    ( dec_err[EP]    ),
      .o_tx_buf_err      ( tx_buf_err[EP] ),
      .tl_tx_data        ( tx_data[EP]    ),
      .tl_tx_tlp_valid   ( tx_valid[EP]   ),
      .tl_tx_tlp_first   ( tx_first[EP]   ),
      .tl_tx_tlp_last    ( tx_last[EP]    ),
      .tl_tx_tlp_last_half ( tx_half[EP]  ),
      .tl_tx_tlp_ready   ( tx_ready[EP]   ),
      .tl_tx_hdr_credit  ( tx_hdr[EP]     ),
      .tl_tx_data_credit ( tx_dcr[EP]     ),
      .tl_tx_update_type ( tx_upd[EP]     ),
      .tl_tx_packet_type ( tx_pkt[EP]     ),
      .tl_tx_dllp_valid  ( tx_dllp[EP]    ),
      .tl_rx_data        ( rx_data[EP]    ),
      .tl_rx_tlp_valid   ( rx_tvalid[EP]  ),
      .tl_rx_tlp_first   ( rx_first[EP]   ),
      .tl_rx_tlp_last    ( rx_last[EP]    ),
      .tl_rx_hdr_credit  ( rx_hdr[EP]     ),
      .tl_rx_data_credit ( rx_dcr[EP]     ),
      .tl_rx_update_type ( rx_upd[EP]     ),
      .tl_rx_packet_type ( rx_pkt[EP]     ),
      .tl_rx_dllp_valid  ( rx_dllp[EP]    ),
      .RX_SERIO_P        ( rc2ep_p        ),
      .RX_SERIO_N        ( rc2ep_n        ),
      .TX_SERIO_P        ( ep_tx_p        ),
      .TX_SERIO_N        ( ep_tx_n        )
   );

   pcie_stack #(.DATA_BYTES(DATA_BYTES)) rc (
      .clk_ref           ( clk_ref        ),
      .clk_reg           ( clk_reg        ),
      .clk_cfg           ( clk_cfg        ),
      .reset_n           ( reset_n        ),
      .o_PCLK            ( pclk[RC]       ),
      .o_LinkUp          ( link_up[RC]    ),
      .o_ltssm_state     ( ltssm[RC]      ),
      .o_serdes_ready    ( serdes_rdy[RC] ),
      .o_RxValid         ( rx_valid[RC]   ),
      .o_RxDataDispErr   ( disp_err[RC]   ),
      .o_RxDataDecErr    ( dec_err[RC]    ),
      .o_tx_buf_err      ( tx_buf_err[RC] ),
      .tl_tx_data        ( tx_data[RC]    ),
      .tl_tx_tlp_valid   ( tx_valid[RC]   ),
      .tl_tx_tlp_first   ( tx_first[RC]   ),
      .tl_tx_tlp_last    ( tx_last[RC]    ),
      .tl_tx_tlp_last_half ( tx_half[RC]  ),
      .tl_tx_tlp_ready   ( tx_ready[RC]   ),
      .tl_tx_hdr_credit  ( tx_hdr[RC]     ),
      .tl_tx_data_credit ( tx_dcr[RC]     ),
      .tl_tx_update_type ( tx_upd[RC]     ),
      .tl_tx_packet_type ( tx_pkt[RC]     ),
      .tl_tx_dllp_valid  ( tx_dllp[RC]    ),
      .tl_rx_data        ( rx_data[RC]    ),
      .tl_rx_tlp_valid   ( rx_tvalid[RC]  ),
      .tl_rx_tlp_first   ( rx_first[RC]   ),
      .tl_rx_tlp_last    ( rx_last[RC]    ),
      .tl_rx_hdr_credit  ( rx_hdr[RC]     ),
      .tl_rx_data_credit ( rx_dcr[RC]     ),
      .tl_rx_update_type ( rx_upd[RC]     ),
      .tl_rx_packet_type ( rx_pkt[RC]     ),
      .tl_rx_dllp_valid  ( rx_dllp[RC]    ),
      .RX_SERIO_P        ( ep2rc_p ^ serial_glitch ),
      .RX_SERIO_N        ( ep2rc_n ^ serial_glitch ),
      .TX_SERIO_P        ( rc_tx_p        ),
      .TX_SERIO_N        ( rc_tx_n        )
   );

   logic rc_training;
   assign rc_training = (ltssm[RC] == DETECT_QUIET)                    ||
                        (ltssm[RC] == DETECT_ACTIVE)                   ||
                        (ltssm[RC] == PRE_DETECT_QUIET)                ||
                        (ltssm[RC] == PRE_DETECT_ACTIVE)               ||
                        (ltssm[RC] == POLLING_ACTIVE)                  ||
                        (ltssm[RC] == PRE_POLLING_CONFIG)              ||
                        (ltssm[RC] == POLLING_CONFIG);
   logic rc_link_phase;
   assign rc_link_phase = (ltssm[RC] == PRE_CONFIG_LINKWIDTH_START)      ||
                        (ltssm[RC] == CONFIG_LINKWIDTH_START_LINKNUM)  ||
                        (ltssm[RC] == PRE_CONFIG_LINKWIDTH_START_CNT)  ||
                        (ltssm[RC] == CONFIG_LINKWIDTH_START);

   logic [7:0] rc_link;
   assign rc_link = rc_training                  ? PAD : RC_LINK_NUM;
   logic [7:0] rc_lane;
   assign rc_lane = (rc_training || rc_link_phase) ? PAD : RC_LANE_NUM;

   always @(rc_link) force rc.mac.expected_Link = rc_link;
   always @(rc_lane) force rc.mac.expected_Lane = rc_lane;

   always @(ltssm[RC])
      if (ltssm[RC] == CONFIG_LINKWIDTH_ACCEPT || ltssm[RC] == CONFIG_LANENUM_ACCEPT)
         force rc.mac.TS2_pattern_en = 1'b1;
      else
         release rc.mac.TS2_pattern_en;

   always @(ltssm[RC])
      if (ltssm[RC] == CONFIG_LANENUM_ACCEPT)
         force rc.mac.TS1_pattern_en = 1'b1;
      else
         release rc.mac.TS1_pattern_en;

`ifndef SCRAMBLE
   initial begin
      force ep.mac.scrambler_en   = 1'b0;
      force ep.mac.descrambler_en = 1'b0;
      force rc.mac.scrambler_en   = 1'b0;
      force rc.mac.descrambler_en = 1'b0;
   end
`endif

   genvar g;
   generate
      for (g = 0; g < 2; g = g + 1) begin : trace
         always @(ltssm[g])
            if (ltssm_name(ltssm[g]) != "")
               $display("[%10.1f ns] %s LTSSM : %0s", $realtime, g == EP ? "EP" : "RC", ltssm_name(ltssm[g]));
      end
   endgenerate

   integer sym_err_cnt;
   initial sym_err_cnt = 0;
   always @(posedge pclk[RC])
      if (link_up[RC] && ((|dec_err[RC]) || (|disp_err[RC])))
         sym_err_cnt <= sym_err_cnt + 1;

   localparam [7:0] STP = 8'hFB;
   localparam [7:0] END = 8'hFD;

   function stp_in_word(input [DATA_WIDTH-1:0] d, input [DATA_BYTES-1:0] k);
      integer b;
      begin
         stp_in_word = 1'b0;
         for (b = 0; b < DATA_BYTES; b = b + 1)
            if (k[b] && d[8*b +: 8] == STP)
               stp_in_word = 1'b1;
      end
   endfunction

   integer ep_stp_cnt;
   initial ep_stp_cnt = 0;
   always @(posedge pclk[EP])
      if (stp_in_word(ep.dll_tx_data, ep.dll_tx_datak))
         ep_stp_cnt <= ep_stp_cnt + 1;

   integer rc_stp_cnt;
   initial rc_stp_cnt = 0;
   always @(posedge pclk[RC])
      if (stp_in_word(rc.dll_tx_data, rc.dll_tx_datak))
         rc_stp_cnt <= rc_stp_cnt + 1;

   function [31:0] crc32_byte(input [31:0] c, input [7:0] b);
      integer i;
      begin
         crc32_byte = c ^ {24'd0, b};
         for (i = 0; i < 8; i = i + 1)
            crc32_byte = crc32_byte[0] ? ((crc32_byte >> 1) ^ 32'hEDB88320) : (crc32_byte >> 1);
      end
   endfunction

   integer line_tlps;
   integer line_lcrc_err;
   integer line_tlp_bytes [0:1];
   initial begin
      line_tlps     = 0;
      line_lcrc_err = 0;
   end

   generate
      for (g = 0; g < 2; g = g + 1) begin : line
         logic [7:0]            tlp [0:255];
         integer                cnt;
         logic                  framed;
         logic [DATA_WIDTH-1:0] d;
         logic [DATA_BYTES-1:0] k;
         logic [31:0]           crc;
         integer                b, i;
         initial begin
            cnt    = 0;
            framed = 1'b0;
            line_tlp_bytes[g] = 0;
         end
         always @(posedge pclk[g]) begin
            d = (g == EP) ? ep.dll_tx_data  : rc.dll_tx_data;
            k = (g == EP) ? ep.dll_tx_datak : rc.dll_tx_datak;
            for (b = 0; b < DATA_BYTES; b = b + 1) begin
               if (k[b] && d[8*b +: 8] == STP) begin
                  framed = 1'b1;
                  cnt    = 0;
               end
               else if (framed && k[b] && d[8*b +: 8] == END) begin
                  framed = 1'b0;
                  crc    = 32'hFFFFFFFF;
                  for (i = 0; i < cnt - 4; i = i + 1)
                     crc = crc32_byte(crc, tlp[i]);
                  crc = ~crc;
                  line_tlps         = line_tlps + 1;
                  line_tlp_bytes[g] = cnt - 6;
                  if ({tlp[cnt-1], tlp[cnt-2], tlp[cnt-3], tlp[cnt-4]} !== crc) begin
                     line_lcrc_err = line_lcrc_err + 1;
                     $display("[%10.1f ns] ERROR: %s LCRC %h, expected %h", $realtime, g == EP ? "EP" : "RC",
                              {tlp[cnt-1], tlp[cnt-2], tlp[cnt-3], tlp[cnt-4]}, crc);
                  end
               end
               else if (framed) begin
                  tlp[cnt] = d[8*b +: 8];
                  cnt      = cnt + 1;
               end
            end
         end
      end
   endgenerate

   integer errors;
   logic [DATA_WIDTH-1:0] tlp_words [0:15];

   task tick(input integer s);
      begin
         if (s == EP) @(posedge pclk[EP]);
         else         @(posedge pclk[RC]);
      end
   endtask

   task wait_tx_ready(input integer s);
      integer t;
      begin
         t = 0;
         while (!tx_ready[s] && t < 8000) begin
            tick(s);
            t = t + 1;
         end
         if (!tx_ready[s]) begin
            errors = errors + 1;
            $display("[%10.1f ns] ERROR: %s tl_tx_tlp_ready never asserted", $realtime, s == EP ? "EP" : "RC");
         end
      end
   endtask

   task send_tlp(input integer s, input integer n, input logic half);
      integer i;
      begin
         wait_tx_ready(s);
         #1;
         tx_valid[s] = 1'b1;
         for (i = 0; i < n; i = i + 1) begin
            tx_data[s]  = tlp_words[i];
            tx_first[s] = (i == 0);
            tx_last[s]  = (i == n - 1);
            tx_half[s]  = (i == n - 1) && half;
            tick(s);
            #1;
         end
         tx_valid[s] = 1'b0;
         tx_first[s] = 1'b0;
         tx_last[s]  = 1'b0;
         tx_half[s]  = 1'b0;
         tx_data[s]  = {DATA_WIDTH{1'b0}};
      end
   endtask

   task send_dllp(input integer s, input [7:0] hdr, input [11:0] dcr,
                  input [1:0] upd, input [1:0] pkt);
      begin
         tick(s); #1;
         tx_hdr[s]  = hdr;
         tx_dcr[s]  = dcr;
         tx_upd[s]  = upd;
         tx_pkt[s]  = pkt;
         tx_dllp[s] = 1'b1;
         tick(s); #1;
         tx_dllp[s] = 1'b0;
      end
   endtask

   task check_tlp_rx(input integer s, input integer n, input logic half, input integer limit);
      integer t, i;
      logic [DATA_WIDTH-1:0] m;
      begin
         t = 0;
         while (!rx_tvalid[s] && t < limit) begin
            tick(s);
            t = t + 1;
         end
         if (!rx_tvalid[s]) begin
            errors = errors + 1;
            $display("[%10.1f ns] ERROR: %s no TLP received", $realtime, s == EP ? "EP" : "RC");
         end
         else begin
            for (i = 0; i < n; i = i + 1) begin
               m = (half && i == n - 1) ? {{(DATA_WIDTH/2){1'b0}}, {(DATA_WIDTH/2){1'b1}}}
                                        : {DATA_WIDTH{1'b1}};
               if (i != 0 && !rx_tvalid[s]) begin
                  errors = errors + 1;
                  $display("[%10.1f ns] ERROR: word %0d not valid", $realtime, i);
               end
               if ((i == 0) != rx_first[s]) begin
                  errors = errors + 1;
                  $display("[%10.1f ns] ERROR: word %0d first flag wrong", $realtime, i);
               end
               if ((i == n - 1) != rx_last[s]) begin
                  errors = errors + 1;
                  $display("[%10.1f ns] ERROR: word %0d last flag wrong", $realtime, i);
               end
               if ((rx_data[s] & m) !== (tlp_words[i] & m)) begin
                  errors = errors + 1;
                  $display("[%10.1f ns] ERROR: word %0d expected %h got %h", $realtime, i, tlp_words[i] & m, rx_data[s] & m);
               end
               if (i != n - 1) tick(s);
            end
            $display("[%10.1f ns]   %s received %0d DW, checked", $realtime, s == EP ? "EP" : "RC", half ? 2 * n - 1 : 2 * n);
         end
         tick(s);
      end
   endtask

   task check_dllp_rx(input integer s, input [7:0] hdr, input [11:0] dcr,
                      input [1:0] upd, input [1:0] pkt);
      integer t;
      logic     found;
      begin
         t     = 0;
         found = 1'b0;
         while (!found && t < 4000) begin
            tick(s);
            t = t + 1;
            if (rx_dllp[s] && rx_hdr[s] == hdr && rx_dcr[s] == dcr && rx_upd[s] == upd && rx_pkt[s] == pkt)
               found = 1'b1;
         end
         if (!found) begin
            errors = errors + 1;
            $display("[%10.1f ns] ERROR: %s DLLP hdr=%0d data=%0d not received", $realtime, s == EP ? "EP" : "RC", hdr, dcr);
         end
         else
            $display("[%10.1f ns]   %s received UpdateFC hdr=%0d data=%0d", $realtime, s == EP ? "EP" : "RC", hdr, dcr);
      end
   endtask

   task tlp_once(input integer src, input integer n, input logic half);
      integer dst, stp_at_start, sent, bytes;
      begin
         dst          = (src == EP) ? RC : EP;
         stp_at_start = (src == EP) ? ep_stp_cnt : rc_stp_cnt;
         send_tlp(src, n, half);
         check_tlp_rx(dst, n, half, 4000);
         wait_tx_ready(src);
         repeat (40) tick(src);
         sent  = ((src == EP) ? ep_stp_cnt : rc_stp_cnt) - stp_at_start;
         bytes = half ? 8 * n - 4 : 8 * n;
         if (sent != 1) begin
            errors = errors + 1;
            $display("[%10.1f ns] ERROR: %s sent the TLP %0d times", $realtime, src == EP ? "EP" : "RC", sent);
         end
         if (line_tlp_bytes[src] != bytes) begin
            errors = errors + 1;
            $display("[%10.1f ns] ERROR: %s put %0d TLP bytes on the line, expected %0d", $realtime,
                     src == EP ? "EP" : "RC", line_tlp_bytes[src], bytes);
         end
         if (sent == 1 && line_tlp_bytes[src] == bytes)
            $display("[%10.1f ns]   %s sent it once, %0d TLP bytes on the line", $realtime,
                     src == EP ? "EP" : "RC", bytes);
      end
   endtask

   integer t;
   integer s;
   integer stp_before;

   initial begin
      errors        = 0;
      serial_glitch = 1'b0;
      for (s = 0; s < 2; s = s + 1) begin
         tx_data[s]  = {DATA_WIDTH{1'b0}};
         tx_valid[s] = 1'b0;
         tx_first[s] = 1'b0;
         tx_last[s]  = 1'b0;
         tx_half[s]  = 1'b0;
         tx_hdr[s]   = 8'd0;
         tx_dcr[s]   = 12'd0;
         tx_upd[s]   = 2'd0;
         tx_pkt[s]   = 2'd0;
         tx_dllp[s]  = 1'b0;
      end

      $display("");
      $display("=============================================================");
      $display("  DLL -> MAC -> PIPE -> opensource SerDes BFM");
      $display("  two link partners, serial link at 2.5 Gb/s");
      $display("=============================================================");
      $display("");

      wait (serdes_rdy[EP] && serdes_rdy[RC]);
      $display("[%10.1f ns] PHY  : both SerDes ready", $realtime);

      t = 0;
      while (!(ltssm[EP] == L0 && ltssm[RC] == L0) && t < 100000) begin
         #(CLKPERIOD_REF);
         t = t + 1;
      end
      if (!(ltssm[EP] == L0 && ltssm[RC] == L0)) begin
         errors = errors + 1;
         $display("[%10.1f ns] ERROR: link training did not reach L0 (EP %0s, RC %0s)",
                  $realtime, ltssm_name(ltssm[EP]), ltssm_name(ltssm[RC]));
         $display("  TEST FAILED");
         $finish;
      end
      $display("[%10.1f ns] LINK : both MACs in L0, LinkUp", $realtime);

      $display("=== Step 1: DLL initialisation, InitFC1/InitFC2 across the link ===");
      wait_tx_ready(EP);
      wait_tx_ready(RC);
      if (errors != 0) begin
         $display("  TEST FAILED");
         $finish;
      end
      $display("[%10.1f ns]   both DLLs DL_Active", $realtime);

      $display("=== Step 2: EP -> RC, three TLPs ===");
      tlp_words[0] = 64'h0001020304050607;
      tlp_words[1] = 64'h1011121314151617;
      tlp_words[2] = 64'h2021222324252627;
      send_tlp(EP, 3, 1'b0);
      check_tlp_rx(RC, 3, 1'b0, 4000);

      tlp_words[0] = 64'hA0A1A2A3A4A5A6A7;
      tlp_words[1] = 64'hB0B1B2B3B4B5B6B7;
      tlp_words[2] = 64'hC0C1C2C3C4C5C6C7;
      tlp_words[3] = 64'hD0D1D2D3D4D5D6D7;
      send_tlp(EP, 4, 1'b0);
      check_tlp_rx(RC, 4, 1'b0, 4000);

      tlp_words[0] = 64'hDEADBEEF12345678;
      tlp_words[1] = 64'hAABBCCDDEEFF0011;
      tlp_words[2] = 64'h2233445566778899;
      tlp_words[3] = 64'h1122334455667788;
      tlp_words[4] = 64'hFFEEDDCCBBAA9988;
      tlp_words[5] = 64'h0102030405060708;
      send_tlp(EP, 6, 1'b0);
      check_tlp_rx(RC, 6, 1'b0, 4000);

      $display("=== Step 3: RC -> EP, two TLPs ===");
      tlp_words[0] = 64'hCAFEF00D00000001;
      tlp_words[1] = 64'h0123456789ABCDEF;
      tlp_words[2] = 64'h7766554433221100;
      send_tlp(RC, 3, 1'b0);
      check_tlp_rx(EP, 3, 1'b0, 4000);

      tlp_words[0] = 64'hCAFEF00D00000002;
      tlp_words[1] = 64'h5A5A5A5AA5A5A5A5;
      tlp_words[2] = 64'h0F0F0F0FF0F0F0F0;
      tlp_words[3] = 64'h3C3C3C3CC3C3C3C3;
      send_tlp(RC, 4, 1'b0);
      check_tlp_rx(EP, 4, 1'b0, 4000);

      $display("=== Step 4: TLP corrupted on the EP -> RC wire, expect NAK and replay ===");
      tlp_words[0] = 64'h5555AAAA5555AAAA;
      tlp_words[1] = 64'h1234567890ABCDEF;
      tlp_words[2] = 64'hFEDCBA0987654321;
      stp_before = ep_stp_cnt;
      fork
         send_tlp(EP, 3, 1'b0);
         begin
            @(posedge pclk[EP]);
            while (!stp_in_word(ep.mac_tx_data, ep.mac_tx_datak)) @(posedge pclk[EP]);
            #(GLITCH_DELAY_NS);
            repeat (GLITCH_PULSES) begin
               serial_glitch = 1'b1;
               #(GLITCH_PULSE_NS);
               serial_glitch = 1'b0;
               #(GLITCH_GAP_NS);
            end
         end
      join
      check_tlp_rx(RC, 3, 1'b0, 8000);
      wait_tx_ready(EP);
      $display("[%10.1f ns]   RC 8b/10b decoder flagged %0d symbol beats", $realtime, sym_err_cnt);
      if (ep_stp_cnt - stp_before < 2) begin
         errors = errors + 1;
         $display("[%10.1f ns] ERROR: EP did not replay the TLP", $realtime);
      end
      else
         $display("[%10.1f ns]   EP sent the TLP %0d times, NAK and replay worked", $realtime, ep_stp_cnt - stp_before);

      $display("=== Step 5: UpdateFC-P DLLP, EP -> RC ===");
      send_dllp(EP, 8'd10, 12'd200, 2'b00, 2'b10);
      check_dllp_rx(RC, 8'd10, 12'd200, 2'b00, 2'b10);

      $display("=== Step 6: TLPs with an odd number of DW, the last word half ===");
      tlp_words[0] = 64'h0000000F_01000000;
      tlp_words[1] = 64'hDEADDEAD_12345678;
      tlp_once(EP, 2, 1'b1);
      tlp_words[0] = 64'h00000F01_02000040;
      tlp_words[1] = 64'hA5A5A5A5_0BADF00D;
      tlp_words[2] = 64'hEEEEEEEE_C0FFEE00;
      tlp_once(EP, 3, 1'b1);
      tlp_words[0] = 64'h11111111_22222222;
      tlp_words[1] = 64'h33333333_44444444;
      tlp_words[2] = 64'h55555555_66666666;
      tlp_words[3] = 64'hBAD0BAD0_77777777;
      tlp_once(EP, 4, 1'b1);
      tlp_words[0] = 64'h0000000F_01000001;
      tlp_words[1] = 64'hFFFFFFFF_87654321;
      tlp_once(RC, 2, 1'b1);
      tlp_words[0] = 64'h0102030405060708;
      tlp_words[1] = 64'h090A0B0C0D0E0F10;
      tlp_words[2] = 64'h99999999_11121314;
      tlp_once(RC, 3, 1'b1);
      tlp_words[0] = 64'hA0A1A2A3A4A5A6A7;
      tlp_words[1] = 64'hB0B1B2B3B4B5B6B7;
      tlp_words[2] = 64'hC0C1C2C3C4C5C6C7;
      tlp_once(EP, 3, 1'b0);

      $display("=== Step 7: odd-DW TLP corrupted on the EP -> RC wire, expect NAK and replay ===");
      tlp_words[0] = 64'h5555AAAA5555AAAA;
      tlp_words[1] = 64'h1234567890ABCDEF;
      tlp_words[2] = 64'h77777777_FEDCBA09;
      stp_before = ep_stp_cnt;
      fork
         send_tlp(EP, 3, 1'b1);
         begin
            @(posedge pclk[EP]);
            while (!stp_in_word(ep.mac_tx_data, ep.mac_tx_datak)) @(posedge pclk[EP]);
            #(GLITCH_DELAY_NS);
            repeat (GLITCH_PULSES) begin
               serial_glitch = 1'b1;
               #(GLITCH_PULSE_NS);
               serial_glitch = 1'b0;
               #(GLITCH_GAP_NS);
            end
         end
      join
      check_tlp_rx(RC, 3, 1'b1, 8000);
      wait_tx_ready(EP);
      repeat (40) tick(EP);
      if (ep_stp_cnt - stp_before < 2) begin
         errors = errors + 1;
         $display("[%10.1f ns] ERROR: EP did not replay the TLP", $realtime);
      end
      else
         $display("[%10.1f ns]   EP sent the TLP %0d times, NAK and replay worked", $realtime, ep_stp_cnt - stp_before);

      $display("[%10.1f ns] LINE : %0d TLPs, LCRC checked, %0d wrong", $realtime, line_tlps, line_lcrc_err);
      errors = errors + line_lcrc_err;

      if (ltssm[EP] != L0 || ltssm[RC] != L0) begin
         errors = errors + 1;
         $display("[%10.1f ns] ERROR: link left L0", $realtime);
      end
      if (tx_buf_err[EP] || tx_buf_err[RC]) begin
         errors = errors + 1;
         $display("[%10.1f ns] ERROR: TX elastic buffer error", $realtime);
      end

      $display("");
      $display("=============================================================");
      $display("  SUMMARY: %0d errors", errors);
      if (errors == 0)
         $display("  TEST PASSED");
      else
         $display("  TEST FAILED");
      $display("=============================================================");
      $display("");
      $finish;
   end

   initial begin
      #5_000_000;
      $display("");
      $display("ERROR: global watchdog expired (EP %0s, RC %0s)", ltssm_name(ltssm[EP]), ltssm_name(ltssm[RC]));
      $display("  TEST FAILED");
      $finish;
   end

`ifdef DUMP
   initial begin
      $dumpfile("sim/dll_phy.fst");
      $dumpvars(0, tb_dll_phy);
   end
`endif

endmodule
