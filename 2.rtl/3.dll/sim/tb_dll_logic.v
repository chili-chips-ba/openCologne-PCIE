`timescale 1ns/100fs

module tb_dll_logic;

    localparam DATA_BYTES = 8;
    localparam DATA_WIDTH = DATA_BYTES * 8;
    localparam CLK_PERIOD = 10; // ns

    reg                     phy_clk;
    reg                     phy_reset;
    reg                     phy_linkup;

    reg  [DATA_WIDTH-1:0]   phy_rx_data;

    reg  [DATA_WIDTH-1:0]   tl_tx_data;
    reg                     tl_tx_tlp_valid;
    reg                     tl_tx_tlp_first;
    reg                     tl_tx_tlp_last;
    wire                    tl_tx_tlp_ready;

    reg  [7:0]              tl_tx_hdr_credit;
    reg  [11:0]             tl_tx_data_credit;
    reg  [1:0]              tl_tx_update_type;
    reg  [1:0]              tl_tx_packet_type;
    reg                     tl_tx_dllp_valid;

    wire [DATA_WIDTH-1:0]   phy_tx_data;
    wire [DATA_BYTES-1:0]   phy_tx_data_k;

    wire [DATA_WIDTH-1:0]   tl_rx_data;
    wire                    tl_rx_tlp_valid;
    wire                    tl_rx_tlp_first;
    wire                    tl_rx_tlp_last;

    wire [7:0]              tl_rx_hdr_credit;
    wire [11:0]             tl_rx_data_credit;
    wire [1:0]              tl_rx_update_type;
    wire [1:0]              tl_rx_packet_type;
    wire                    tl_rx_dllp_valid;

    integer errors;

    reg [DATA_WIDTH-1:0]    tlp_words [15:0];

    reg                     external_en;
    reg  [DATA_WIDTH-1:0]   external_data;

    reg                     flip_one_bit;

    dll_logic #(
        .DATA_BYTES(DATA_BYTES),
        .NUMBER_OF_VIRTUAL_CHANNELS(1),
        .PATTERN_WIDTH(64)
    ) dut (
        .phy_clk(phy_clk),
        .phy_reset(phy_reset),
        .phy_linkup(phy_linkup),
        .phy_rx_data(phy_rx_data),

        .tl_tx_data(tl_tx_data),
        .tl_tx_tlp_valid(tl_tx_tlp_valid),
        .tl_tx_tlp_first(tl_tx_tlp_first),
        .tl_tx_tlp_last(tl_tx_tlp_last),
        .tl_tx_tlp_ready(tl_tx_tlp_ready),

        .tl_tx_hdr_credit(tl_tx_hdr_credit),
        .tl_tx_data_credit(tl_tx_data_credit),
        .tl_tx_update_type(tl_tx_update_type),
        .tl_tx_packet_type(tl_tx_packet_type),
        .tl_tx_dllp_valid(tl_tx_dllp_valid),

        .phy_tx_data(phy_tx_data),
        .phy_tx_data_k(phy_tx_data_k),

        .tl_rx_data(tl_rx_data),
        .tl_rx_tlp_valid(tl_rx_tlp_valid),
        .tl_rx_tlp_first(tl_rx_tlp_first),
        .tl_rx_tlp_last(tl_rx_tlp_last),

        .tl_rx_hdr_credit(tl_rx_hdr_credit),
        .tl_rx_data_credit(tl_rx_data_credit),
        .tl_rx_update_type(tl_rx_update_type),
        .tl_rx_packet_type(tl_rx_packet_type),
        .tl_rx_dllp_valid(tl_rx_dllp_valid)
    );

    initial phy_clk = 1'b0;
    always #(CLK_PERIOD/2) phy_clk = ~phy_clk;

    // 1. We can inject external data into DLL with external_en and external_data
    // 2. flip one bit flag will flip one bit of received data to corrupt it. lcrc check should fail
    // 3. Normal loopback
    always @(posedge phy_clk or posedge phy_reset) begin
        if (phy_reset) begin
            phy_rx_data <= {DATA_WIDTH{1'b0}};
        end else if (external_en) begin
            phy_rx_data <= external_data;
        end else if (flip_one_bit && phy_tx_data_k[DATA_BYTES-1]) begin
            // only for the last datapath that we have a control charactera the end (END symbol)
            phy_rx_data  <= phy_tx_data ^ 64'h0000_0100_0000_0000; // END | LCRC[7:0] | LCRC[15:8] | LCRC[23:16] | ... -> flip bit 8 of LCRC
            flip_one_bit <= 1'b0;
        end else begin
            phy_rx_data <= phy_tx_data;
        end
    end

    initial begin
        $dumpfile("sim/dll_sim.fst");
        $dumpvars(0, tb_dll_logic);
    end

    // reset all
    task reset_all;
        begin
            phy_reset         = 1'b1;
            phy_linkup        = 1'b0;
            tl_tx_data        = {DATA_WIDTH{1'b0}};
            tl_tx_tlp_valid   = 1'b0;
            tl_tx_tlp_first   = 1'b0;
            tl_tx_tlp_last    = 1'b0;
            tl_tx_hdr_credit  = 8'b0;
            tl_tx_data_credit = 12'b0;
            tl_tx_update_type = 2'b0;
            tl_tx_packet_type = 2'b0;
            tl_tx_dllp_valid  = 1'b0;
            external_en         = 1'b0;
            external_data       = {DATA_WIDTH{1'b0}};
            flip_one_bit  = 1'b0;
            repeat (5) @(posedge phy_clk);
            phy_reset = 1'b0;
            repeat (2) @(posedge phy_clk);
        end
    endtask

    // Wait until DLL is ready to take data from TL again
    // Ready when retry buffer is empty
    task wait_tl_tx_ready;
        integer timeout;
        begin
            timeout = 0;
            while (!tl_tx_tlp_ready && timeout < 2000) begin
                @(posedge phy_clk);
                timeout = timeout + 1;
            end
            if (!tl_tx_tlp_ready) begin
                errors = errors + 1;
                $display("[%0t] ERROR: wait_tl_tx_ready: tl_tx_tlp_ready never asserted (timeout, data in retry buffer was not sent out to the physical layer)", $time);
            end
        end
    endtask

    task DLL_linkup;
        integer timeout;
        begin
            phy_linkup = 1'b1;
            timeout = 0;
            while (!tl_tx_tlp_ready && timeout < 500) begin
                @(posedge phy_clk);
                timeout = timeout + 1;
            end
            if (!tl_tx_tlp_ready) begin
                errors = errors + 1;
                $display("[%0t] ERROR: DLL_linkup: link did not reach DL_ACTIVE (timeout, link never went up and writting into retry buffer is not allowed)", $time);
            end
        end
    endtask

    task send_tlp(input integer n); // n is the number of data words
        integer i;
        integer timeout;
        begin
            timeout = 0;
            // check if retry buffer is empty
            while (!tl_tx_tlp_ready && timeout < 2000) begin
                @(posedge phy_clk);
                timeout = timeout + 1;
            end
            if (!tl_tx_tlp_ready) begin
                errors = errors + 1;
                $display("[%0t] ERROR: send_tlp: retry buffer not empty before send (timeout)", $time);
            end
            #1;
            tl_tx_tlp_valid = 1'b1;
            for (i = 0; i < n; i = i + 1) begin
                tl_tx_data      = tlp_words[i];
                tl_tx_tlp_first = (i == 0);
                tl_tx_tlp_last  = (i == n - 1);
                @(posedge phy_clk);
                #1;
            end
            tl_tx_tlp_valid = 1'b0;
            tl_tx_tlp_first = 1'b0;
            tl_tx_tlp_last  = 1'b0;
            tl_tx_data      = {DATA_WIDTH{1'b0}};
        end
    endtask

    task send_dllp(input [7:0] hdr_credit, input [11:0] data_credit, input [1:0] update_type, input [1:0] packet_type);
        begin
            @(posedge phy_clk);
            #1;
            tl_tx_hdr_credit  = hdr_credit;
            tl_tx_data_credit = data_credit;
            tl_tx_update_type = update_type;
            tl_tx_packet_type = packet_type;
            tl_tx_dllp_valid  = 1'b1;
            @(posedge phy_clk);
            #1;
            tl_tx_dllp_valid = 1'b0;
        end
    endtask

    task check_tlp_rx(input integer n, input integer timeout_limit);
        integer timeout;
        integer i;
        begin
            timeout = 0;
            while (!tl_rx_tlp_valid && timeout < timeout_limit) begin
                @(posedge phy_clk);
                timeout = timeout + 1;
            end
            if (!tl_rx_tlp_valid) begin
                errors = errors + 1;
                $display("[%0t] ERROR: check_tlp_rx: beat0 tl_rx_tlp_valid never asserted (timeout)", $time);
            end else begin
                for (i = 0; i < n; i = i + 1) begin
                    if (i != 0 && !tl_rx_tlp_valid) begin errors = errors + 1; $display("[%0t] ERROR: check_tlp_rx: data word %0d is not valid", $time, i); end
                    if ((i == 0) != tl_rx_tlp_first)   begin errors = errors + 1; $display("[%0t] ERROR: check_tlp_rx: data word %0d is first but not flagged as first word", $time, i); end
                    if ((i == n - 1) != tl_rx_tlp_last) begin errors = errors + 1; $display("[%0t] ERROR: check_tlp_rx: data word %0d is last but not flagged as last word", $time, i); end
                    if (tl_rx_data !== tlp_words[i])   begin errors = errors + 1; $display("[%0t] ERROR: check_tlp_rx: data word %0d mismatch (loopback) expected=%h got=%h", $time, i, tlp_words[i], tl_rx_data); end
                    if (i != n - 1) @(posedge phy_clk);
                end
            end
            @(posedge phy_clk);
        end
    endtask

    task check_dllp_rx(input [7:0] hdr, input [11:0] data, input [1:0] update, input [1:0] packet);
        integer timeout;
        begin
            timeout = 0;
            while (!tl_rx_dllp_valid && timeout < 500) begin
                @(posedge phy_clk);
                timeout = timeout + 1;
            end
            if (!tl_rx_dllp_valid) begin
                errors = errors + 1;
                $display("[%0t] ERROR: check_dllp_rx: dllp valid flag is not asserted (timeout)", $time);
            end else begin
                if (tl_rx_hdr_credit !== hdr) begin
                    errors = errors + 1;
                    $display("[%0t] ERROR: check_dllp_rx: hdr_credit mismatch expected=%0d got=%0d", $time, hdr, tl_rx_hdr_credit);
                end
                if (tl_rx_data_credit !== data) begin
                    errors = errors + 1;
                    $display("[%0t] ERROR: check_dllp_rx: data_credit mismatch expected=%0d got=%0d", $time, data, tl_rx_data_credit);
                end
                if (tl_rx_update_type !== update) begin
                    errors = errors + 1;
                    $display("[%0t] ERROR: check_dllp_rx: update_type mismatch expected=%0d got=%0d", $time, update, tl_rx_update_type);
                end
                if (tl_rx_packet_type !== packet) begin
                    errors = errors + 1;
                    $display("[%0t] ERROR: check_dllp_rx: packet_type mismatch expected=%0d got=%0d", $time, packet, tl_rx_packet_type);
                end
            end
            @(posedge phy_clk);
        end
    endtask

    initial begin
        errors = 0;

        // initialize DLL
        $display("=== Step 1: initialization sequence ===");
        reset_all;
        if (tl_tx_tlp_ready !== 1'b0) begin
            errors = errors + 1;
            $display("[%0t] ERROR: tl_tx_tlp_ready should be low after reset", $time);
        end
        DLL_linkup;

        // Send TLP
        $display("=== Step 2a: TLP 1 (24 bytes payload) ===");
        tlp_words[0] = 64'h0001020304050607;
        tlp_words[1] = 64'h1011121314151617;
        tlp_words[2] = 64'h2021222324252627;
        send_tlp(3);
        check_tlp_rx(3, 500);
        wait_tl_tx_ready; // confirms the ACK for TLP 1 released the retry buffer

        $display("=== Step 2b: TLP 2 (32 bytes payload) ===");
        tlp_words[0] = 64'hA0A1A2A3A4A5A6A7;
        tlp_words[1] = 64'hB0B1B2B3B4B5B6B7;
        tlp_words[2] = 64'hC0C1C2C3C4C5C6C7;
        tlp_words[3] = 64'hD0D1D2D3D4D5D6D7;
        send_tlp(4);
        check_tlp_rx(4, 500);
        wait_tl_tx_ready; // confirms the ACK for TLP 2 released the retry buffer

        $display("=== Step 2c: TLP 3 (48 bytes payload) ===");
        tlp_words[0] = 64'hDEADBEEF12345678;
        tlp_words[1] = 64'hAABBCCDDEEFF0011;
        tlp_words[2] = 64'h2233445566778899;
        tlp_words[3] = 64'h1122334455667788;
        tlp_words[4] = 64'hFFEEDDCCBBAA9988;
        tlp_words[5] = 64'h0102030405060708;
        send_tlp(6);
        check_tlp_rx(6, 500);
        wait_tl_tx_ready; // confirms the ACK for TLP 3 released the retry buffer

        // send error on loopback path
        $display("=== Step 3: send 1 TLP (24 bytes payload), trigger error on loopback path ===");
        tlp_words[0] = 64'h5555AAAA5555AAAA;
        tlp_words[1] = 64'h1234567890ABCDEF;
        tlp_words[2] = 64'hFEDCBA0987654321;
        flip_one_bit = 1'b1; // corrupts this TLP's LCRC once, in flight
        send_tlp(3);
        // The corrupted copy makes the RX schedule a NAK
        // NAK loops back and triggers a retransmission
        check_tlp_rx(3, 2000);
        wait_tl_tx_ready; // confirms the ACK released the retry buffer

        $display("=== Step 4: send + receive UpdateFC-P DLLP ===");
        send_dllp(8'd10, 12'd200, 2'b00, 2'b10);
        check_dllp_rx(8'd10, 12'd200, 2'b00, 2'b10);

        $display("=== SUMMARY: %0d errors ===", errors);
        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED");
        $finish;
    end

endmodule
