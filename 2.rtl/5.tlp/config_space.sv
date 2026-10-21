module config_space
  import pcie_pkg::*;
  import tl_pkg::*;
#(
    parameter logic [15:0] VENDOR_ID        = 16'h1234,
    parameter logic [15:0] DEVICE_ID        = 16'h0001,
    parameter logic [ 7:0] REVISION_ID      = 8'h00,
    parameter logic [23:0] CLASS_CODE       = 24'hFF0000,
    parameter logic [15:0] SUBSYS_VENDOR_ID = 16'h1234,
    parameter logic [15:0] SUBSYS_ID        = 16'h0001,
    parameter int          BAR0_SIZE_BITS   = 12,
    parameter logic [ 1:0] ASPM_SUPPORT     = 2'b01,
    parameter logic [ 2:0] L0S_EXIT_LATENCY = 3'b111,
    parameter logic [ 2:0] L1_EXIT_LATENCY  = 3'b111,
    parameter logic [ 2:0] L0S_ACCEPT_LAT   = 3'b111,
    parameter logic [ 2:0] L1_ACCEPT_LAT    = 3'b111,
    parameter logic        SLOT_CLOCK       = 1'b1
) (
    input  logic               clk,
    input  logic               rst_n,
    input  tl_cfg_acc_t        acc,
    output logic        [31:0] rdata,
    input  tl_id_t             id,
    input  tl_sspl_t           sspl,
    input  tl_err_t            err,
    output logic               msg_nonfatal,
    output logic               msg_fatal,
    output tl_cfg_t            cfg
);

  localparam logic [ 7:0] CAP_PM      = 8'h40;
  localparam logic [ 7:0] CAP_PCIE    = 8'h50;
  localparam logic [ 7:0] CAP_ID_PM   = 8'h01;
  localparam logic [ 7:0] CAP_ID_PCIE = 8'h10;
  localparam logic [15:0] PM_CAPS     = 16'h0003;
  localparam logic [15:0] PCIE_CAPS   = 16'h0002;

  localparam logic [ 9:0] R_ID        = 10'h000;
  localparam logic [ 9:0] R_CMD       = 10'h001;
  localparam logic [ 9:0] R_CLASS     = 10'h002;
  localparam logic [ 9:0] R_MISC      = 10'h003;
  localparam logic [ 9:0] R_BAR0      = 10'h004;
  localparam logic [ 9:0] R_SUBSYS    = 10'h00B;
  localparam logic [ 9:0] R_CAP_PTR   = 10'h00D;
  localparam logic [ 9:0] R_INT       = 10'h00F;
  localparam logic [ 9:0] R_PM_CAP    = 10'h010;
  localparam logic [ 9:0] R_PM_CSR    = 10'h011;
  localparam logic [ 9:0] R_PCIE_CAP  = 10'h014;
  localparam logic [ 9:0] R_DEV_CAP   = 10'h015;
  localparam logic [ 9:0] R_DEV_CTL   = 10'h016;
  localparam logic [ 9:0] R_LNK_CAP   = 10'h017;
  localparam logic [ 9:0] R_LNK_CTL   = 10'h018;
  localparam logic [ 9:0] R_LNK_CTL2  = 10'h020;

  localparam logic [31:0] CMD_WMASK   = 32'h0000_0147;
  localparam logic [31:0] CMD_W1C     = 32'hC000_0000;
  localparam logic [31:0] BYTE0_WMASK = 32'h0000_00FF;
  localparam logic [31:0] BAR0_WMASK  = ~((32'd1 << BAR0_SIZE_BITS) - 32'd1);
  localparam logic [31:0] DEV_WMASK   = 32'h0000_78FF;
  localparam logic [31:0] DEV_W1C     = 32'h000E_0000;
  localparam logic [31:0] PM_WMASK    = 32'h0000_0003;
  localparam logic [31:0] LNK_WMASK   = 32'h0000_00CB;
  localparam logic [31:0] LNK2_WMASK  = 32'h0000_1FBF;

  localparam logic [ 1:0] D0          = 2'b00;
  localparam logic [ 1:0] D3HOT       = 2'b11;

  cfg_cmd_dw_t          cmd;
  logic          [31:0] misc;
  logic          [31:0] bar0;
  logic          [31:0] int_reg;
  cfg_pm_dw_t           pm;
  cfg_dev_dw_t          dev;
  cfg_lnk_dw_t          lnk;
  logic          [31:0] lnk2;
  logic          [ 7:0] bus_number;
  logic          [ 4:0] device_number;
  logic          [ 7:0] sspl_value;
  logic          [ 1:0] sspl_scale;

  pcie_dev_cap_t        dev_cap;
  pcie_lnk_cap_t        lnk_cap;
  pcie_lnk_sta_t        lnk_sta;

  logic                 wr_cmd;
  logic                 wr_misc;
  logic                 wr_bar0;
  logic                 wr_int;
  logic                 wr_pm;
  logic                 wr_dev;
  logic                 wr_lnk;
  logic                 wr_lnk2;
  cfg_pm_dw_t           pm_next;

  logic                 send_nonfatal;
  logic                 send_fatal;

  assign cfg.bus_number        = bus_number;
  assign cfg.device_number     = device_number;
  assign cfg.memory_enable     = cmd.command.mem_space && (pm.csr.power_state == D0);
  assign cfg.bus_master_enable = cmd.command.bus_master;
  assign cfg.bar0_base         = bar0;
  assign cfg.max_payload_size  = dev.control.max_payload;

  always_comb begin
    dev_cap                  = '0;
    dev_cap.slot_power_scale = sspl_scale;
    dev_cap.slot_power_value = sspl_value;
    dev_cap.role_based_err   = 1'b1;
    dev_cap.l1_accept_lat    = L1_ACCEPT_LAT;
    dev_cap.l0s_accept_lat   = L0S_ACCEPT_LAT;
  end

  always_comb begin
    lnk_cap              = '0;
    lnk_cap.l1_exit_lat  = L1_EXIT_LATENCY;
    lnk_cap.l0s_exit_lat = L0S_EXIT_LATENCY;
    lnk_cap.aspm_support = ASPM_SUPPORT;
    lnk_cap.max_width    = 6'd1;
    lnk_cap.max_speed    = 4'd1;
  end

  always_comb begin
    lnk_sta            = '0;
    lnk_sta.slot_clock = SLOT_CLOCK;
    lnk_sta.width      = 6'd1;
    lnk_sta.speed      = 4'd1;
  end

  always_comb begin
    rdata = 32'h0000_0000;
    unique0 case (acc.regnum)
      R_ID:       rdata = {DEVICE_ID, VENDOR_ID};
      R_CMD:      rdata = cmd;
      R_CLASS:    rdata = {CLASS_CODE, REVISION_ID};
      R_MISC:     rdata = misc;
      R_BAR0:     rdata = bar0;
      R_SUBSYS:   rdata = {SUBSYS_ID, SUBSYS_VENDOR_ID};
      R_CAP_PTR:  rdata = {24'h00_0000, CAP_PM};
      R_INT:      rdata = int_reg;
      R_PM_CAP:   rdata = {PM_CAPS, CAP_PCIE, CAP_ID_PM};
      R_PM_CSR:   rdata = pm;
      R_PCIE_CAP: rdata = {PCIE_CAPS, 8'h00, CAP_ID_PCIE};
      R_DEV_CAP:  rdata = dev_cap;
      R_DEV_CTL:  rdata = dev;
      R_LNK_CAP:  rdata = lnk_cap;
      R_LNK_CTL:  rdata = lnk;
      R_LNK_CTL2: rdata = lnk2;
    endcase
  end

  assign wr_cmd = acc.write && (acc.regnum == R_CMD);
  assign wr_misc = acc.write && (acc.regnum == R_MISC);
  assign wr_bar0 = acc.write && (acc.regnum == R_BAR0);
  assign wr_int = acc.write && (acc.regnum == R_INT);
  assign wr_pm = acc.write && (acc.regnum == R_PM_CSR);
  assign wr_dev = acc.write && (acc.regnum == R_DEV_CTL);
  assign wr_lnk = acc.write && (acc.regnum == R_LNK_CTL);
  assign wr_lnk2 = acc.write && (acc.regnum == R_LNK_CTL2);
  assign pm_next = cfg_write_merge(pm, acc.wdata, acc.be, PM_WMASK);

  assign send_nonfatal = err.ur && (dev.control.ur_report_en || cmd.command.serr_en) &&
      (dev.control.nonfatal_report_en || cmd.command.serr_en);
  assign send_fatal = (err.malformed || err.overflow) &&
      (dev.control.fatal_report_en || cmd.command.serr_en);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cmd                 <= '0;
      cmd.status.cap_list <= 1'b1;
    end
    else begin
      if (wr_cmd) begin
        cmd <= cfg_write_merge(cmd, acc.wdata, acc.be,
                               CMD_WMASK) & ~cfg_w1c(acc.wdata, acc.be, CMD_W1C);
      end
      if (err.poisoned) begin
        cmd.status.detected_parity_err <= 1'b1;
      end
      if ((send_nonfatal || send_fatal) && cmd.command.serr_en) begin
        cmd.status.signaled_sys_err <= 1'b1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dev                        <= '0;
      dev.control.max_read_req   <= 3'b010;
      dev.control.no_snoop_en    <= 1'b1;
      dev.control.relaxed_ord_en <= 1'b1;
    end
    else begin
      if (wr_dev) begin
        dev <= cfg_write_merge(dev, acc.wdata, acc.be,
                               DEV_WMASK) & ~cfg_w1c(acc.wdata, acc.be, DEV_W1C);
      end
      if (err.ur) begin
        dev.status.nonfatal_detected <= 1'b1;
        dev.status.ur_detected       <= 1'b1;
      end
      if (err.malformed || err.overflow) begin
        dev.status.fatal_detected <= 1'b1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      misc                 <= '0;
      bar0                 <= '0;
      int_reg              <= '0;
      pm                   <= '0;
      pm.csr.no_soft_reset <= 1'b1;
      pm.csr.power_state   <= D0;
      lnk                  <= '0;
      lnk.status           <= lnk_sta;
      lnk2                 <= 32'h0000_0001;
    end
    else begin
      if (wr_misc) begin
        misc <= cfg_write_merge(misc, acc.wdata, acc.be, BYTE0_WMASK);
      end
      if (wr_bar0) begin
        bar0 <= cfg_write_merge(bar0, acc.wdata, acc.be, BAR0_WMASK);
      end
      if (wr_int) begin
        int_reg <= cfg_write_merge(int_reg, acc.wdata, acc.be, BYTE0_WMASK);
      end
      if (wr_pm && (pm_next.csr.power_state == D0 || pm_next.csr.power_state == D3HOT)) begin
        pm <= pm_next;
      end
      if (wr_lnk) begin
        lnk <= cfg_write_merge(lnk, acc.wdata, acc.be, LNK_WMASK);
      end
      if (wr_lnk2) begin
        lnk2 <= cfg_write_merge(lnk2, acc.wdata, acc.be, LNK2_WMASK);
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      msg_nonfatal <= 1'b0;
      msg_fatal    <= 1'b0;
    end
    else begin
      msg_nonfatal <= send_nonfatal;
      msg_fatal    <= send_fatal;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bus_number    <= 8'h00;
      device_number <= 5'h00;
    end
    else if (id.capture) begin
      bus_number    <= id.bus;
      device_number <= id.device;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sspl_value <= 8'h00;
      sspl_scale <= 2'b00;
    end
    else if (sspl.capture) begin
      sspl_value <= sspl.value;
      sspl_scale <= sspl.scale;
    end
  end

endmodule
