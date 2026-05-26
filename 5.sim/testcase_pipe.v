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

reg S_FAULT_INJECTION  = 1'b0;

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
reg        transmission_start_flag = 1'b0;

reg         status_flag_1 = 1'b0;    // Status flags for simulation
reg         status_flag_2 = 1'b0;
reg         status_flag_3 = 1'b0;
reg         init_status_flag_done = 1'b0;
reg         s_fault_flag_for_rx = 1'b0;

integer i;
integer j;
integer k;
integer comma_pos;

// Testdata Arrays
reg [ 7:0] testdata     [39:0];
reg        testdata_k   [39:0];
reg        testdata_com [39:0];


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
    reg [15:0] testdata_16;
    reg  [1:0] testdata_k_16;
    reg  [1:0] testdata_com_16;
    reg [63:0] testdata_64;
    reg  [7:0] testdata_k_64;
    reg  [7:0] testdata_com_64;
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

    reg [1:0] v_rx_not_in_table;
    reg [1:0] v_rx_disp_err;

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

    $printtimescale(tb_ccfpga_serdes);


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

    for (i = 0; i < 100 ; i = i + 1) begin
        generate_data;
        send_testdata(DATA_BYTES);
        #350;
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

