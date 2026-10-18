// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openCologne-PCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
//                   Copyright (C) 2026 Chili.CHIPS
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// 1. Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
// contributors may be used to endorse or promote products derived
// from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
// IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//              https://opensource.org/license/bsd-3-clause
//--------------------------------------------------------------------------
// Description:
//   PRBS-7 loopback test of the GateMate SerDes on the evaluation board.
//   SW3 starts it: three regfile writes bring up the SerDes PLL, then the
//   TX sends PRBS-7 and the RX checks it, through an external loopback.
//   A link that keeps failing for ~300 ms gets an RX reset to re-lock.
//   The eight LEDs (active low) show the progress.
//
//   Reset: CC_USR_RSTN marks the end of configuration (UG1001 7.2) and is
//   the only reset source; each clock gets its own synchronized copy.
//==========================================================================

module serdes_top (
    input  logic       clk_10m,  // 10 MHz board clock
    input  logic       rst_n,    // SW3, active low: starts the test
    output logic [7:0] led       // 8 LEDs, active low
);

  // the SerDes sends PRBS-7 (TX_PRBS_SEL_I); TX_DATA_I gets a defined pattern
  localparam logic [63:0] TX_PAT = 64'hA5A5A5A5_A5A5A5A5;

  localparam logic [15:0] BTN_HOLD = 16'hFFFF;     // ~6.5 ms of SW3 at 10 MHz
  localparam logic [5:0] CFG_WAIT_LAST = 6'd31;    // 32 cycles after each write
  localparam logic [25:0] ERR_LIMIT = 26'h1FFFFFF;  // failing ~300 ms: recover
  localparam logic [25:0] RECOVER_END = 26'h20000FF;  // then 256 cycles of RX reset
  localparam logic [15:0] LOCK_HOLD = 16'hFFFF;     // error-free cycles for "link OK"

  //------------------------------------------------------------------------
  // Reset: end of configuration, synchronized per clock
  //------------------------------------------------------------------------
  logic usr_rstn;
  logic serdes_clk;
  logic [1:0] rst10m_sync;
  logic [1:0] rst_serdes_sync;
  logic rst10m_n;
  logic rst_serdes_n;

  CC_USR_RSTN u_usr_rstn (.USR_RSTN(usr_rstn));

  always_ff @(posedge clk_10m or negedge usr_rstn) begin
    if (!usr_rstn) begin
      rst10m_sync <= '0;
    end
    else begin
      rst10m_sync <= {rst10m_sync[0], 1'b1};
    end
  end
  assign rst10m_n = rst10m_sync[1];

  always_ff @(posedge serdes_clk or negedge usr_rstn) begin
    if (!usr_rstn) begin
      rst_serdes_sync <= '0;
    end
    else begin
      rst_serdes_sync <= {rst_serdes_sync[0], 1'b1};
    end
  end
  assign rst_serdes_n = rst_serdes_sync[1];

  //------------------------------------------------------------------------
  // Heartbeat, SW3 debounce and start latch, SerDes reset
  //------------------------------------------------------------------------
  logic [23:0] hb_cnt;
  logic [15:0] btn_cnt;
  logic        started;
  logic        serdes_rst;

  always_ff @(posedge clk_10m or negedge rst10m_n) begin
    if (!rst10m_n) begin
      hb_cnt     <= '0;
      btn_cnt    <= '0;
      started    <= 1'b0;
      serdes_rst <= 1'b1;
    end
    else begin
      hb_cnt <= hb_cnt + 24'd1;

      // SW3 held low for BTN_HOLD cycles starts the test, for good
      if (!rst_n) begin
        if (btn_cnt == BTN_HOLD) begin
          started <= 1'b1;
        end
        else begin
          btn_cnt <= btn_cnt + 16'd1;
        end
      end
      else begin
        btn_cnt <= '0;
      end

      serdes_rst <= !started;
    end
  end

  //------------------------------------------------------------------------
  // SerDes PLL bring-up: three regfile writes, 32 cycles apart
  //------------------------------------------------------------------------
  typedef enum logic [2:0] {
    CFG_IDLE  = 3'd0,  // wait for SW3
    CFG_WRITE = 3'd1,  // drive address/data, strobe the write
    CFG_END   = 3'd2,  // drop the strobe
    CFG_WAIT  = 3'd3,  // let the write settle
    CFG_NEXT  = 3'd4,  // next register, or done
    CFG_DONE  = 3'd5   // configured, stay here
  } cfg_state_e;

  cfg_state_e        cfg_state;
  logic        [1:0] cfg_idx;
  logic        [5:0] cfg_wait;
  logic              reg_we;
  logic              reg_en;
  logic        [7:0] reg_addr;
  logic       [15:0] reg_data;
  logic        [7:0] cfg_addr;
  logic       [15:0] cfg_data;

  // the three writes; an unused index writes nothing useful
  always_comb begin
    cfg_addr = 8'h00;
    cfg_data = 16'h0000;
    unique0 case (cfg_idx)
      2'd0: begin  // PLL settings
        cfg_addr = 8'h51;
        cfg_data = 16'h16FA;
      end
      2'd1: begin  // SerDes global enable
        cfg_addr = 8'h5C;
        cfg_data = 16'h0001;
      end
      2'd2: begin  // PLL on
        cfg_addr = 8'h50;
        cfg_data = 16'h0C03;
      end
    endcase
  end

  always_ff @(posedge clk_10m or negedge rst10m_n) begin
    if (!rst10m_n) begin
      cfg_state <= CFG_IDLE;
      cfg_idx   <= '0;
      cfg_wait  <= '0;
      reg_we    <= 1'b0;
      reg_en    <= 1'b0;
      reg_addr  <= '0;
      reg_data  <= '0;
    end
    else begin
      unique case (cfg_state)
        CFG_IDLE: begin
          reg_we  <= 1'b0;
          reg_en  <= 1'b0;
          cfg_idx <= '0;
          if (started) begin
            cfg_state <= CFG_WRITE;
          end
        end
        CFG_WRITE: begin
          reg_addr  <= cfg_addr;
          reg_data  <= cfg_data;
          reg_we    <= 1'b1;
          reg_en    <= 1'b1;
          cfg_state <= CFG_END;
        end
        CFG_END: begin
          reg_we    <= 1'b0;
          reg_en    <= 1'b0;
          cfg_wait  <= '0;
          cfg_state <= CFG_WAIT;
        end
        CFG_WAIT: begin
          cfg_wait <= cfg_wait + 6'd1;
          if (cfg_wait == CFG_WAIT_LAST) begin
            cfg_state <= CFG_NEXT;
          end
        end
        CFG_NEXT: begin
          if (cfg_idx < 2'd2) begin
            cfg_idx   <= cfg_idx + 2'd1;
            cfg_state <= CFG_WRITE;
          end
          else begin
            cfg_state <= CFG_DONE;
          end
        end
        CFG_DONE: begin
          cfg_state <= CFG_DONE;
        end
      endcase
    end
  end

  //------------------------------------------------------------------------
  // RX recovery: a link failing for ERR_LIMIT cycles gets an RX reset
  //------------------------------------------------------------------------
  logic        tx_done;
  logic        rx_done;
  logic        rx_prbs_err;
  logic [25:0] err_cnt;
  logic        rx_recover;

  always_ff @(posedge serdes_clk or negedge rst_serdes_n) begin
    if (!rst_serdes_n) begin
      err_cnt    <= '0;
      rx_recover <= 1'b0;
    end
    else if (rx_recover) begin
      // err_cnt runs on past ERR_LIMIT: the RX reset lasts until RECOVER_END
      err_cnt <= err_cnt + 26'd1;
      if (err_cnt == RECOVER_END) begin
        rx_recover <= 1'b0;
        err_cnt    <= '0;
      end
    end
    else if (rx_prbs_err && rx_done) begin
      err_cnt <= err_cnt + 26'd1;
      if (err_cnt == ERR_LIMIT) begin
        rx_recover <= 1'b1;
      end
    end
    else begin
      err_cnt <= '0;
    end
  end

  //------------------------------------------------------------------------
  // GateMate SerDes: PRBS-7 out and back, no 8b/10b
  //------------------------------------------------------------------------
  CC_SERDES #(
      .SERDES_ENABLE   (1),
      .SERDES_AUTO_INIT(0)    // the FSM above configures the PLL
  ) u_serdes (
      // PLL
      .PLL_RESET_I(serdes_rst),
      .PLL_CLK_O  (serdes_clk),

      // regfile, written by the bring-up FSM
      .REGFILE_CLK_I (clk_10m),
      .REGFILE_WE_I  (reg_we),
      .REGFILE_EN_I  (reg_en),
      .REGFILE_ADDR_I(reg_addr),
      .REGFILE_DI_I  (reg_data),
      .REGFILE_MASK_I(16'hFFFF),
      .REGFILE_RDY_O (  /*LINT:OK*/),  // the FSM waits a fixed 32 cycles instead
      .REGFILE_DO_O  (  /*LINT:OK*/),  // write-only

      // TX
      .TX_RESET_I         (serdes_rst),
      .TX_PCS_RESET_I     (1'b0),
      .TX_PMA_RESET_I     (1'b0),
      .TX_CLK_I           (serdes_clk),
      .TX_DATA_I          (TX_PAT),
      .TX_RESET_DONE_O    (tx_done),
      .TX_BUF_ERR_O       (  /*LINT:OK*/),  // no TX buffer status in this test
      .TX_DETECT_RX_DONE_O   (  /*LINT:OK*/),  // receiver detection is off
      .TX_DETECT_RX_PRESENT_O(  /*LINT:OK*/),  // receiver detection is off
      .TX_POWER_DOWN_N_I  (1'b1),
      .TX_POLARITY_I      (1'b0),
      .TX_8B10B_EN_I      (1'b0),
      .TX_ELEC_IDLE_I     (1'b0),
      .TX_DETECT_RX_I     (1'b0),
      .TX_PRBS_SEL_I      (3'b001),    // PRBS-7 generator
      .TX_PRBS_FORCE_ERR_I(1'b0),
      .TX_CHAR_IS_K_I     (8'h00),
      .TX_CHAR_DISPMODE_I (8'h00),
      .TX_CHAR_DISPVAL_I  (8'h00),
      .TX_8B10B_BYPASS_I  (8'h00),

      // RX
      .RX_RESET_I          (serdes_rst | rx_recover),
      .RX_PMA_RESET_I      (1'b0),
      .RX_EQA_RESET_I      (1'b0),
      .RX_CDR_RESET_I      (rx_recover),
      .RX_PCS_RESET_I      (1'b0),
      .RX_BUF_RESET_I      (1'b0),
      .RX_CLK_I            (serdes_clk),
      .RX_CLK_O            (  /*LINT:OK*/),  // RX runs on the PLL clock
      .RX_DATA_O           (  /*LINT:OK*/),  // the PRBS checker reads the data
      .RX_RESET_DONE_O     (rx_done),
      .RX_NOT_IN_TABLE_O   (  /*LINT:OK*/),  // 8b/10b is off
      .RX_CHAR_IS_COMMA_O  (  /*LINT:OK*/),  // 8b/10b is off
      .RX_CHAR_IS_K_O      (  /*LINT:OK*/),  // 8b/10b is off
      .RX_DISP_ERR_O       (  /*LINT:OK*/),  // 8b/10b is off
      .RX_BUF_ERR_O        (  /*LINT:OK*/),  // no RX buffer status in this test
      .RX_BYTE_IS_ALIGNED_O(  /*LINT:OK*/),  // comma alignment is off
      .RX_BYTE_REALIGN_O   (  /*LINT:OK*/),  // comma alignment is off
      .RX_EI_EN_O          (  /*LINT:OK*/),  // electrical-idle detector is off
      .RX_POWER_DOWN_N_I   (1'b1),
      .RX_POLARITY_I       (1'b0),
      .RX_8B10B_EN_I       (1'b0),
      .RX_8B10B_BYPASS_I   (8'h00),
      .RX_PRBS_SEL_I       (3'b001),         // PRBS-7 checker
      .RX_PRBS_CNT_RESET_I (rx_recover),
      .RX_PRBS_ERR_O       (rx_prbs_err),
      .RX_EN_EI_DETECTOR_I (1'b0),
      .RX_COMMA_DETECT_EN_I(1'b0),
      .RX_SLIDE_I          (1'b0),
      .RX_MCOMMA_ALIGN_I   (1'b0),
      .RX_PCOMMA_ALIGN_I   (1'b0),
      .LOOPBACK_I          (3'b000)          // external loopback
  );

  //------------------------------------------------------------------------
  // Link check: LOCK_HOLD error-free cycles in a row mean "link OK"
  //------------------------------------------------------------------------
  logic [26:0] pll_cnt;
  logic [15:0] lock_cnt;
  logic        loopback_ok;

  always_ff @(posedge serdes_clk or negedge rst_serdes_n) begin
    if (!rst_serdes_n) begin
      pll_cnt     <= '0;
      lock_cnt    <= '0;
      loopback_ok <= 1'b0;
    end
    else begin
      pll_cnt <= pll_cnt + 27'd1;
      if (tx_done && rx_done && !rx_prbs_err) begin
        if (lock_cnt == LOCK_HOLD) begin
          loopback_ok <= 1'b1;
        end
        else begin
          lock_cnt <= lock_cnt + 16'd1;
        end
      end
      else begin
        lock_cnt    <= '0;
        loopback_ok <= 1'b0;
      end
    end
  end

  //------------------------------------------------------------------------
  // LEDs, active low
  //------------------------------------------------------------------------
  assign led[0] = !hb_cnt[23];   // heartbeat, 10 MHz domain
  assign led[1] = !started;      // test started
  assign led[2] = !tx_done;      // TX ready
  assign led[3] = !rx_done;      // RX ready
  assign led[4] = !pll_cnt[26];  // heartbeat, SerDes clock
  assign led[5] = !loopback_ok;  // link OK
  assign led[6] = serdes_rst;    // SerDes in reset
  assign led[7] = !rx_prbs_err;  // PRBS error now

endmodule

// -----------------------------------------------------------------------------
// Project:     openCologne-PCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        April 2025
// -----------------------------------------------------------------------------
