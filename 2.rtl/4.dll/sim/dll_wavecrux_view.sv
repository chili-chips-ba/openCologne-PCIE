// WaveCrux view of the DLL's PHY-side streams.
//
// Presents the 64-bit stream in both directions under the names the
// WaveCrux PCIe decoders (wcx-pcie, ferrite.pcie_pipe_w64 / pcie_dll_w64)
// auto-bind to: TxPclk/TxData/TxDataK (DLL -> PHY) and
// RxPclk/RxData/RxDataK (PHY -> DLL). In WaveCrux, Ctrl+Shift+D on
// tb_dll_wavecrux.wavecrux binds all inputs; the prefix drop-down picks
// Tx or Rx.
//
// The testbench has no RX K signal (the DLL does not take one), so RxDataK
// is rebuilt here: the testbench loops phy_tx_data back to phy_rx_data
// through one register, so RxDataK is phy_tx_data_k through the same
// register. Not valid while the testbench drives external_data.
//
// Attached with `bind`, so the testbench itself stays plain Verilog.
// Compile this file after tb_dll_wavecrux.v (Verilator; Icarus does not
// support bind). Build with Verilator -O0, or these copies become trace
// aliases that WaveCrux's signal pickers hide.

module dll_wavecrux_view #(
    parameter DATA_BYTES = 8,
    parameter DATA_WIDTH = DATA_BYTES * 8
) (
    input  wire                  phy_clk,
    input  wire                  phy_reset,
    input  wire [DATA_WIDTH-1:0] phy_tx_data,
    input  wire [DATA_BYTES-1:0] phy_tx_data_k,
    input  wire [DATA_WIDTH-1:0] phy_rx_data
);

    // Only read by the waveform dump
    /* verilator lint_off UNUSEDSIGNAL */
    wire                  pclk    = phy_clk;
    wire                  TxPclk  = phy_clk;  // per-prefix copies: auto-bind looks
    wire                  RxPclk  = phy_clk;  // for <prefix>pclk, not a shared pclk
    wire [DATA_WIDTH-1:0] TxData  = phy_tx_data;
    wire [DATA_BYTES-1:0] TxDataK = phy_tx_data_k;
    wire [DATA_WIDTH-1:0] RxData  = phy_rx_data;
    reg  [DATA_BYTES-1:0] RxDataK;
    /* verilator lint_on UNUSEDSIGNAL */

    always @(posedge phy_clk or posedge phy_reset) begin
        if (phy_reset) begin
            RxDataK <= {DATA_BYTES{1'b0}};
        end else begin
            RxDataK <= phy_tx_data_k;
        end
    end

endmodule

bind tb_dll_wavecrux dll_wavecrux_view #(
    .DATA_BYTES(DATA_BYTES)
) wavecrux (
    .phy_clk      (phy_clk),
    .phy_reset    (phy_reset),
    .phy_tx_data  (phy_tx_data),
    .phy_tx_data_k(phy_tx_data_k),
    .phy_rx_data  (phy_rx_data)
);
