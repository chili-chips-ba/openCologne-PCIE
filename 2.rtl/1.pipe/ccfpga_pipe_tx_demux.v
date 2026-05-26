////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Interessengruppe fuer Mikroelektronik und Eingebettete Systeme (IMES)
// Fachhochschule Dortmund
//
// Development in cooperation with Cologne Chip AG
//
// Filename     : ccfpga_pipe_demux.v
// Author       : Philipp Leduc
// Tool         :
// Description  : Used in PIPE Logic to demux Tx PIPE (8-,16-Bit) across TX SerDes (64-Bit).
//                Also includes Control Symbols (K Data) and Compliance (running disparity).
//                TX PIPE ---> DEMUX ---> TX SERDES
// Commentary   : Parameter DATA_BYTES refers to Tx PIPE.
// Abreviations : [i_] > input (port)
//                [o_] > output (port)
//                [s_] > signal
//                [_n] > low active
//
//
// Changelog:
// -------------------------------------------------------------------------------------------------
// Version | Author             | Date       | Changes
// -------------------------------------------------------------------------------------------------
// 1.0     | Leduc              | 05.06.2021 | released
// -------------------------------------------------------------------------------------------------
////////////////////////////////////////////////////////////////////////////////////////////////////

module ccfpga_pipe_tx_demux #(
    parameter DATA_BYTES = 4,               // Set to configure width of used datapath (PIPE)
    parameter DATA_WIDTH  = DATA_BYTES*8    // Used to configure bitwidth of datapath
    )
    (
    input  wire                  i_clk,
    input  wire                  i_reset,
    input  wire                  i_enable,
    input  wire [DATA_BYTES-1:0] i_k_data,   // TxK Data (PIPE)
    input  wire [DATA_WIDTH-1:0] i_data,     // Tx  Data (PIPE)
    input  wire [DATA_BYTES-1:0] i_compl,    // Tx  Compliance (PIPE)
    output reg            [63:0] o_data,     // Tx  Data (SerDes)
    output reg            [ 7:0] o_k_data,   // TxK Data (SerDes)
    output reg            [ 7:0] o_dispar    // Tx  Disparity (SerDes)
    );

    localparam MSB_INIT   = DATA_WIDTH-1;    // Used to configure the msb init position
    localparam MSB_INIT_K = DATA_BYTES-1;    // Used to configure the msb k init position


    reg [ 5:0] s_msb;                        // Used for partial vector selection of SerDes Port
    reg [ 2:0] s_msb_k;                      // Used for partial vector selection of SerDes Port


    // clocked demux for data
    always@ (posedge i_clk, posedge i_reset) begin
      if(i_reset == 1'b1) begin
        s_msb  <= MSB_INIT;
      end
      else begin
        if (i_enable == 1'b1) begin
          if (s_msb == 6'd63)
            s_msb <= MSB_INIT;
          else
            s_msb <= s_msb + DATA_WIDTH;
        end
      end
    end

    // clocked demux for k data and disparity (compliance)
    always@ (posedge i_clk, posedge i_reset) begin
      if(i_reset == 1'b1) begin
        s_msb_k   <= MSB_INIT_K;
        end
      else begin
        if (i_enable == 1'b1) begin
          if (s_msb_k == 3'd7)
            s_msb_k <= MSB_INIT_K;
          else
            s_msb_k <= s_msb_k + DATA_BYTES;
        end
      end
    end

    generate
      if(DATA_BYTES == 1) begin // 8-Bit PIPE
        // clocked demux for data
        always@ (posedge i_clk, posedge i_reset) begin
          if(i_reset == 1'b1) begin
            o_data <= {64{1'b0}};
          end
          else begin
            if (i_enable == 1'b1) begin
              case (s_msb)
                6'd7: begin
                  o_data[7:0] <= i_data;
                end
                6'd15: begin
                  o_data[15:8] <= i_data;
                end
                6'd23: begin
                  o_data[23:16] <= i_data;
                end
                6'd31: begin
                  o_data[31:24] <= i_data;
                end
                6'd39: begin
                  o_data[39:32] <= i_data;
                end
                6'd47: begin
                  o_data[47:40] <= i_data;
                end
                6'd55: begin
                  o_data[55:48] <= i_data;
                end
                6'd63: begin
                  o_data[63:56] <= i_data;
                end
              endcase
            end
          end
        end

        // clocked demux for k data and disparity (compliance)
        always@ (posedge i_clk, posedge i_reset) begin
          if(i_reset == 1'b1) begin
            o_dispar  <= {8{1'b0}};
            o_k_data  <= {8{1'b0}};
            end
          else begin
            if (i_enable == 1'b1) begin
              case (s_msb_k)
                3'd0: begin
                  o_k_data[0] <= i_k_data;
                  o_dispar[0] <= i_compl;
                end
                3'd1: begin
                  o_k_data[1] <= i_k_data;
                  o_dispar[1] <= i_compl;
                end
                3'd2: begin
                  o_k_data[2] <= i_k_data;
                  o_dispar[2] <= i_compl;
                end
                3'd3: begin
                  o_k_data[3] <= i_k_data;
                  o_dispar[3] <= i_compl;
                end
                3'd4: begin
                  o_k_data[4] <= i_k_data;
                  o_dispar[4] <= i_compl;
                end
                3'd5: begin
                  o_k_data[5] <= i_k_data;
                  o_dispar[5] <= i_compl;
                end
                3'd6: begin
                  o_k_data[6] <= i_k_data;
                  o_dispar[6] <= i_compl;
                end
                3'd7: begin
                  o_k_data[7] <= i_k_data;
                  o_dispar[7] <= i_compl;
                end
              endcase
            end
          end
        end
      end
      else if (DATA_BYTES == 2) begin // 16-Bit PIPE
        // clocked demux for data
        always@ (posedge i_clk, posedge i_reset) begin
          if(i_reset == 1'b1) begin
            o_data <= {64{1'b0}};
            end
          else begin
            if (i_enable == 1'b1) begin
              case (s_msb)
                6'd15: begin
                  o_data[15:0] <= i_data;
                end
                6'd31: begin
                  o_data[31:16] <= i_data;
                end
                6'd47: begin
                  o_data[47:32] <= i_data;
                end
                6'd63: begin
                  o_data[63:48] <= i_data;
                end
              endcase
            end
          end
        end

        // clocked demux for k data and disparity (compliance)
        always@ (posedge i_clk, posedge i_reset) begin
          if(i_reset == 1'b1) begin
            o_dispar  <= {8{1'b0}};
            o_k_data  <= {8{1'b0}};
            end
          else begin
            if (i_enable == 1'b1) begin
              case (s_msb_k)
                3'd1: begin
                  o_k_data[1:0] <= i_k_data;
                  o_dispar[1:0] <= i_compl;
                end
                3'd3: begin
                  o_k_data[3:2] <= i_k_data;
                  o_dispar[3:2] <= i_compl;
                end
                3'd5: begin
                  o_k_data[5:4] <= i_k_data;
                  o_dispar[5:4] <= i_compl;
                end
                3'd7: begin
                  o_k_data[7:6] <= i_k_data;
                  o_dispar[7:6] <= i_compl;
                end
              endcase
            end
          end
        end
      end
      else begin // 32-Bit PIPE
        // clocked demux for data
        always@ (posedge i_clk, posedge i_reset) begin
          if(i_reset == 1'b1) begin
            o_data <= {64{1'b0}};
            end
          else begin
            if (i_enable == 1'b1) begin
              case (s_msb)
                6'd31: begin
                  o_data[31:0] <= i_data;
                end
                6'd63: begin
                  o_data[63:32] <= i_data;
                end
              endcase
            end
          end
        end

        // clocked demux for k data and disparity (compliance)
        always@ (posedge i_clk, posedge i_reset) begin
          if(i_reset == 1'b1) begin
            o_dispar  <= {8{1'b0}};
            o_k_data  <= {8{1'b0}};
            end
          else begin
            if (i_enable == 1'b1) begin
              case (s_msb_k)
                3'd3: begin
                  o_k_data[3:0] <= i_k_data;
                  o_dispar[3:0] <= i_compl;
                end
                3'd7: begin
                  o_k_data[7:4] <= i_k_data;
                  o_dispar[7:4] <= i_compl;
                end
              endcase
            end
          end
        end
      end
    endgenerate

endmodule