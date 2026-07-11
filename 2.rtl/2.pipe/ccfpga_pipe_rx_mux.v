////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Interessengruppe fuer Mikroelektronik und Eingebettete Systeme (IMES)
// Fachhochschule Dortmund
//
// Development in cooperation with Cologne Chip AG
//
// Filename     : ccfpga_pipe_mux.v
// Author       : Philipp Leduc
// Tool         :
// Description  : Used in PIPE Logic to mux Rx SerDes (64-Bit) to Rx PIPE (8-,16-Bit).
//                Also includes Control Symbols (K Data) and Error Detection Logic (e.g. RxStatus).
//                Module also contains the additional Control Support Signals (CSS).
//                RX SERDES ---> MUX ---> RX PIPE
// Commentary   : Parameter DATA_BYTES refers to Rx PIPE. Reset is asynchronous.
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
// 1.01    | Leduc              | 01.08.2021 | changed reset values for s_msb and s_msb_k
// -------------------------------------------------------------------------------------------------
////////////////////////////////////////////////////////////////////////////////////////////////////

module ccfpga_pipe_rx_mux #(
  parameter DATA_BYTES = 4,                 // Set to configure width of used pipe datapath
  parameter DATA_WIDTH = DATA_BYTES*8       // Used to configure bitwidth of datapath
  )
  (
  input  wire                  i_clk,
  input  wire                  i_reset,
  input  wire                  i_enable,

  input  wire           [ 7:0] i_disp_err,     // Disparity Error (SerDes)
  input  wire           [ 7:0] i_char_is_com,  // Byte is COM symbol    (SerDes)
  input  wire           [ 7:0] i_decode_err,   // Decoding Error 8b/10b (SerDes)
  input  wire           [63:0] i_data,         // Rx  Data (SerDes)
  input  wire           [ 7:0] i_k_data,       // RxK Data (SerDes)

  output wire [DATA_WIDTH-1:0] o_data,         // Rx  Data (PIPE)
  output reg  [DATA_BYTES-1:0] o_k_data,       // RxK Data (PIPE)
  output reg             [2:0] o_rx_status,    // Rx Status Signal (PIPE)
  output reg  [DATA_BYTES-1:0] o_rx_comma,     // Rx Comma Signal (CSS)
  output wire [DATA_BYTES-1:0] o_rx_dec_err,   // Rx Decode Error (CSS)
  output wire [DATA_BYTES-1:0] o_rx_disp_err   // Rx Disparity Error (CSS)
  );


  localparam MSB_INIT   = DATA_WIDTH-1;        // Used to configure the msb data init position
  localparam MSB_INIT_K = DATA_BYTES-1;        // Used to configure the msb k data init position

  reg [DATA_WIDTH-1:0] s_data;
  reg [DATA_BYTES-1:0] s_dec_err;
  reg [DATA_BYTES-1:0] s_disp_err;
  wire                 s_dec_err_flag;
  wire                 s_disp_err_flag;
  reg           [ 5:0] s_msb;                 // Used for partial vector selection of SerDes Port
  reg           [ 2:0] s_msb_k;               // Used for partial vector selection of SerDes Port


  assign s_dec_err_flag  = |s_dec_err;
  assign s_disp_err_flag = |s_disp_err;
  assign o_rx_dec_err    = s_dec_err;
  assign o_rx_disp_err   = s_disp_err;


  // clocked mux for data
  always@(posedge i_clk, posedge i_reset) begin
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

  // clocked mux for k data, comma, error signals
  always@ (posedge i_clk, posedge i_reset) begin
      if(i_reset == 1'b1) begin
        s_msb_k    <= MSB_INIT_K;
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
    if (DATA_BYTES == 1) begin // 8-Bit PIPE
      // clocked mux for data
      always@(posedge i_clk, posedge i_reset) begin
          if(i_reset == 1'b1) begin
            s_data <= {DATA_WIDTH{1'b0}};
            end
          else begin
            if (i_enable == 1'b1) begin
              case (s_msb)
                6'd7: begin
                  s_data <= i_data[7:0];
                end
                6'd15: begin
                  s_data <= i_data[15:8];
                end
                6'd23: begin
                  s_data <= i_data[23:16];
                end
                6'd31: begin
                  s_data <= i_data[31:24];
                end
                6'd39: begin
                  s_data <= i_data[39:32];
                end
                6'd47: begin
                  s_data <= i_data[47:40];
                end
                6'd55: begin
                  s_data <= i_data[55:48];
                end
                6'd63: begin
                  s_data <= i_data[63:56];
                end
              endcase
            end
          end
      end

      // clocked mux for k data, comma, error signals
      always@ (posedge i_clk, posedge i_reset) begin
          if(i_reset == 1'b1) begin
            o_k_data   <= {DATA_BYTES{1'b0}};
            o_rx_comma <= {DATA_BYTES{1'b0}};
            s_dec_err  <= {DATA_BYTES{1'b0}};
            s_disp_err <= {DATA_BYTES{1'b0}};
            end
          else begin
            if (i_enable == 1'b1) begin
              case (s_msb_k)
                3'd0: begin
                  o_k_data   <= i_k_data[0];
                  o_rx_comma <= i_char_is_com[0];
                  s_dec_err  <= i_decode_err[0];
                  s_disp_err <= i_disp_err[0];
                end
                3'd1: begin
                  o_k_data   <= i_k_data[1];
                  o_rx_comma <= i_char_is_com[1];
                  s_dec_err  <= i_decode_err[1];
                  s_disp_err <= i_disp_err[1];
                end
                3'd2: begin
                  o_k_data   <= i_k_data[2];
                  o_rx_comma <= i_char_is_com[2];
                  s_dec_err  <= i_decode_err[2];
                  s_disp_err <= i_disp_err[2];
                end
                3'd3: begin
                  o_k_data   <= i_k_data[3];
                  o_rx_comma <= i_char_is_com[3];
                  s_dec_err  <= i_decode_err[3];
                  s_disp_err <= i_disp_err[3];
                end
                3'd4: begin
                  o_k_data   <= i_k_data[4];
                  o_rx_comma <= i_char_is_com[4];
                  s_dec_err  <= i_decode_err[4];
                  s_disp_err <= i_disp_err[4];
                end
                3'd5: begin
                  o_k_data   <= i_k_data[5];
                  o_rx_comma <= i_char_is_com[5];
                  s_dec_err  <= i_decode_err[5];
                  s_disp_err <= i_disp_err[5];
                end
                3'd6: begin
                  o_k_data   <= i_k_data[6];
                  o_rx_comma <= i_char_is_com[6];
                  s_dec_err  <= i_decode_err[6];
                  s_disp_err <= i_disp_err[6];
                end
                3'd7: begin
                  o_k_data   <= i_k_data[7];
                  o_rx_comma <= i_char_is_com[7];
                  s_dec_err  <= i_decode_err[7];
                  s_disp_err <= i_disp_err[7];
                end
              endcase
            end
          end
      end
    end
    else if (DATA_BYTES == 2) begin // 16-Bit PIPE
      // clocked mux for data
      always@(posedge i_clk, posedge i_reset) begin
          if(i_reset == 1'b1) begin
            s_data <= {DATA_WIDTH{1'b0}};
            end
          else begin
            if (i_enable == 1'b1) begin
              case (s_msb)
                6'd15: begin
                  s_data <= i_data[15:0];
                end
                6'd31: begin
                  s_data <= i_data[31:16];
                end
                6'd47: begin
                  s_data <= i_data[47:32];
                end
                6'd63: begin
                  s_data <= i_data[63:48];
                end
              endcase
            end
          end
      end

      // clocked mux for k data, comma, error signals
      always@ (posedge i_clk, posedge i_reset) begin
          if(i_reset == 1'b1) begin
            o_k_data   <= {DATA_BYTES{1'b0}};
            o_rx_comma <= {DATA_BYTES{1'b0}};
            s_dec_err  <= {DATA_BYTES{1'b0}};
            s_disp_err <= {DATA_BYTES{1'b0}};
            end
          else begin
            if (i_enable == 1'b1) begin
              case (s_msb_k)
                3'd1: begin
                  o_k_data   <= i_k_data[1:0];
                  o_rx_comma <= i_char_is_com[1:0];
                  s_dec_err  <= i_decode_err[1:0];
                  s_disp_err <= i_disp_err[1:0];
                end
                3'd3: begin
                  o_k_data   <= i_k_data[3:2];
                  o_rx_comma <= i_char_is_com[3:2];
                  s_dec_err  <= i_decode_err[3:2];
                  s_disp_err <= i_disp_err[3:2];
                end
                3'd5: begin
                  o_k_data   <= i_k_data[5:4];
                  o_rx_comma <= i_char_is_com[5:4];
                  s_dec_err  <= i_decode_err[5:4];
                  s_disp_err <= i_disp_err[5:4];
                end
                3'd7: begin
                  o_k_data   <= i_k_data[7:6];
                  o_rx_comma <= i_char_is_com[7:6];
                  s_dec_err  <= i_decode_err[7:6];
                  s_disp_err <= i_disp_err[7:6];
                end
              endcase
            end
          end
      end
    end
    else begin // 32-Bit PIPE
      // clocked mux for data
      always@(posedge i_clk, posedge i_reset) begin
          if(i_reset == 1'b1) begin
            s_data <= {DATA_WIDTH{1'b0}};
            end
          else begin
            if (i_enable == 1'b1) begin
              case (s_msb)
                6'd31: begin
                  s_data <= i_data[31:0];
                end
                6'd63: begin
                  s_data <= i_data[63:32];
                end
              endcase
            end
          end
      end

      // clocked mux for k data, comma, error signals
      always@ (posedge i_clk, posedge i_reset) begin
          if(i_reset == 1'b1) begin
            o_k_data   <= {DATA_BYTES{1'b0}};
            o_rx_comma <= {DATA_BYTES{1'b0}};
            s_dec_err  <= {DATA_BYTES{1'b0}};
            s_disp_err <= {DATA_BYTES{1'b0}};
            end
          else begin
            if (i_enable == 1'b1) begin
              case (s_msb_k)
                3'd3: begin
                  o_k_data   <= i_k_data[3:0];
                  o_rx_comma <= i_char_is_com[3:0];
                  s_dec_err  <= i_decode_err[3:0];
                  s_disp_err <= i_disp_err[3:0];
                end
                3'd7: begin
                  o_k_data   <= i_k_data[7:4];
                  o_rx_comma <= i_char_is_com[7:4];
                  s_dec_err  <= i_decode_err[7:4];
                  s_disp_err <= i_disp_err[7:4];
                end
              endcase
            end
          end
      end
    end
  endgenerate

  // logic for setting rx status
  always@* begin
    if (s_dec_err_flag == 1'b1)       // 8b/10b error
      o_rx_status = 3'b100;
    else if (s_disp_err_flag == 1'b1) // Disparity error
      o_rx_status = 3'b111;
    else                              // Data OK (rst value)
      o_rx_status = 3'b000;
  end

 // logic for implementing EDB Symbol (8b/10b Error)
  genvar i;

  generate
    for (i = 0; i < DATA_BYTES ; i = i + 1) begin : gen_block_rx_mux
      localparam integer j = i*8 + 7;
      assign o_data [ j -: 8] = ( s_dec_err[i] == 1'b1 ) ? 8'hFE : s_data [ j -: 8];
    end
  endgenerate


endmodule