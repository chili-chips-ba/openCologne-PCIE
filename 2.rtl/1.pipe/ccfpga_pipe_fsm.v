////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Interessengruppe fuer Mikroelektronik und Eingebettete Systeme (IMES)
// Fachhochschule Dortmund
//
// Development in cooperation with Cologne Chip AG
//
// Filename     : ccfpga_pipe_fsm.v
// Author       : Philipp Leduc
// Tool         :
// Description  : PIPE FSM to implement behaviour during different Power States.
//                Powerstates P0s and P2 are not supported yet.
// Commentary   : Rx Polarity should only be changed during P0 States.
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

module ccfpga_pipe_fsm (
   input  wire          i_clk,
   input  wire          i_reset,
   output wire    [3:0] o_fsm_state,          // fsm status (CSS)

   input  wire    [1:0] i_pw_state,           // Powerstate
   //input  wire        i_rx_polarity,        // Rx Polarity
   input  wire          i_tx_elec_idle,       // Tx Elec Idle
   input  wire          i_tx_detect_or_loop,  // Tx Receiver Detection/ Loopmode
   output reg           o_phy_status,
   //output wire        o_rx_elec_idle,
   output reg     [2:0] o_rx_status,

   input  wire          i_reset_done,         // Reset Done Indicator (SerDes)
   input  wire          i_rx_detect_done,     // Receiver detection done
   input  wire          i_rx_detect_val,      // Receiver status, 1 if receiver present
   output reg           o_rx_detect_start,    // Start rceiver detection
   output reg           o_sel_rx_status,
   output reg           o_pcs_loopback,       // Loopback Enable
   output reg           o_tx_elec_idle,

   output reg           o_counter_reset,      // Reset Clock Counter
   input  wire          i_count_flag,         // Flag for Count Indication

   output reg           o_enable_align        // Activate Word Alignment (FSM)
   );

   localparam [3:0]  RESET         = 4'b0000,
                     P0_NORMAL     = 4'b0001,
                     P0_LOOP       = 4'b0010,
                     P0_IDLE       = 4'b0011,
                     P1_IDLE       = 4'b0100,
                     P1_DET_START  = 4'b0101,
                     P1_DET_GOOD   = 4'b0110,
                     P1_DET_BAD    = 4'b0111,
                     P1_DET_WAIT   = 4'b1000,
                     P0_PRE_NORMAL = 4'b1001,  // Used for PhyStatus Generation
                     P0_PRE_LOOP   = 4'b1010,  // Used for PhyStatus Generation
                     P0_PRE_IDLE   = 4'b1011,  // Used for PhyStatus Generation
                     P1_SET_IDLE   = 4'b1100,  // Used to wait for Tx Idle
                     P1_PRE_IDLE   = 4'b1101;  // Used for Phystatus Generation
            
   reg [3:0] s_state, s_next_state;

   wire [3:0] s_transit;
   reg        s_rx_polarity;

   assign s_transit   = {i_pw_state, i_tx_elec_idle, i_tx_detect_or_loop};
   assign o_fsm_state = s_state;

   // State Register
   always@(posedge i_clk, posedge i_reset) begin
      if (i_reset == 1'b1)
         s_state <= RESET;
      else
         s_state <= s_next_state;
   end

   // // Transition Logic
    always@(*) begin
      s_next_state = s_state;
      case(s_state)
         RESET : begin
            if ( i_reset_done == 1'b1 )
             s_next_state = P1_IDLE;
            else
             s_next_state = RESET;
            end
         P1_IDLE : begin
            if      ( s_transit == 4'b0010 )
             s_next_state = P0_PRE_IDLE;
            else if ( s_transit == 4'b0001 )
             s_next_state = P0_PRE_LOOP;
            else if ( s_transit == 4'b0000 )
             s_next_state = P0_PRE_NORMAL;
            else if ( s_transit == 4'b1011 )
             s_next_state = P1_DET_START;
            else
             s_next_state = P1_IDLE;
            end
         P0_NORMAL : begin
            if      ( s_transit == 4'b1010 || s_transit == 4'b1011)
             s_next_state = P1_SET_IDLE;
            else if ( s_transit == 4'b0010 )
             s_next_state = P0_IDLE;
            else if ( s_transit == 4'b0001 )
             s_next_state = P0_LOOP;
            else
             s_next_state = P0_NORMAL;
            end
         P0_LOOP: begin
            if      ( s_transit == 4'b1010 || s_transit == 4'b1011)
             s_next_state = P1_SET_IDLE;
            else if ( s_transit == 4'b0010 || s_transit == 4'b0011)
             s_next_state = P0_IDLE;
            else if ( s_transit == 4'b0000 )
             s_next_state = P0_NORMAL;
            else
             s_next_state = P0_LOOP;
            end
         P0_IDLE: begin
            if      ( s_transit == 4'b1010 || s_transit == 4'b1011)
             s_next_state = P1_SET_IDLE;
            else if ( s_transit == 4'b0001 )
             s_next_state = P0_LOOP;
            else if ( s_transit == 4'b0000 )
             s_next_state = P0_NORMAL;
            else
             s_next_state = P0_IDLE;
            end
         P1_DET_START : begin
            if      ( s_transit[0] == 1'b0 )
             s_next_state = P1_IDLE;
            else if ( i_rx_detect_done == 1'b1 && i_rx_detect_val == 1'b1)
             s_next_state = P1_DET_GOOD;
            else if ( i_rx_detect_done == 1'b1 && i_rx_detect_val == 1'b0)
             s_next_state = P1_DET_BAD;
            else
            s_next_state = P1_DET_START;
            end
         P1_DET_GOOD : begin
            if ( s_transit[0] == 1'b0 )
             s_next_state = P1_IDLE;
            else
             s_next_state = P1_DET_WAIT;
            end
         P1_DET_BAD : begin
            if ( s_transit[0] == 1'b0 )
             s_next_state = P1_IDLE;
            else
             s_next_state = P1_DET_WAIT;
            end
         P1_DET_WAIT : begin
            if ( s_transit[0] == 1'b0 )
             s_next_state = P1_IDLE;
            else
             s_next_state = P1_DET_WAIT;
            end
         P0_PRE_NORMAL : begin
            s_next_state = P0_NORMAL;
            end
         P0_PRE_LOOP: begin
            s_next_state = P0_LOOP;
            end
         P0_PRE_IDLE: begin
            s_next_state = P0_IDLE;
            end
         P1_SET_IDLE: begin
            if ( i_count_flag == 1'b1 )
               s_next_state = P1_PRE_IDLE;
            else
               s_next_state = P1_SET_IDLE;
            end
         P1_PRE_IDLE: begin
            s_next_state = P1_IDLE;
            end
      endcase
   end

   // Output Logic
   always@(s_state)
   begin
      // o_rx_polarity   = 0;
      o_enable_align    = 1'b0;
      o_counter_reset   = 1'b1;  // new
      o_tx_elec_idle    = 1'b0;
      o_sel_rx_status   = 1'b0;
      o_phy_status      = 1'b0;
      o_rx_status       = 3'b000;
      o_pcs_loopback    = 1'b0;
      o_rx_detect_start = 1'b0;
      case(s_state)
         RESET : begin
            o_phy_status      = 1'b1;
            o_tx_elec_idle    = 1'b1;
            o_sel_rx_status   = 1'b1;
            end
         P1_IDLE : begin
            o_tx_elec_idle    = 1'b1;
            o_sel_rx_status   = 1'b1;
            end
         P0_NORMAL : begin
            o_enable_align    = 1'b1;
            end
         P0_LOOP: begin
            o_pcs_loopback    = 1'b1;
            o_enable_align    = 1'b1;
            end
         P0_IDLE: begin
            o_tx_elec_idle    = 1'b1;
            o_counter_reset   = 1'b0;
            o_enable_align    = 1'b1;
            end
         P1_DET_START : begin
            o_tx_elec_idle    = 1'b1;
            o_sel_rx_status   = 1'b1;
            o_rx_detect_start = 1'b1;
            end
         P1_DET_GOOD : begin
            o_tx_elec_idle    = 1'b1;
            o_sel_rx_status   = 1'b1;
            o_phy_status      = 1'b1;
            o_rx_status       = 3'b011;
            end
         P1_DET_BAD : begin
            o_tx_elec_idle    = 1'b1;
            o_sel_rx_status   = 1'b1;
            o_phy_status      = 1'b1;
            end
         P1_DET_WAIT : begin
            o_tx_elec_idle    = 1'b1;
            o_sel_rx_status   = 1'b1;
            //o_phy_status      = 1'b1;
            //o_rx_status       = 3'b011;
            end
         P0_PRE_NORMAL : begin
            o_phy_status      = 1'b1;
            end
         P0_PRE_LOOP : begin
            o_phy_status      = 1'b1;
            o_pcs_loopback    = 1'b1;
            end
         P0_PRE_IDLE : begin
            o_counter_reset   = 1'b0;
            o_phy_status      = 1'b1;
            o_tx_elec_idle    = 1'b1;
            end
         P1_SET_IDLE : begin
            o_counter_reset   = 1'b0;
            o_tx_elec_idle    = 1'b1;
            end
         P1_PRE_IDLE : begin
            o_phy_status = 1'b1;
            o_sel_rx_status   = 1'b1;
            o_tx_elec_idle = 1'b1;
            end
      endcase
   end

endmodule