// (C) 2001-2020 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.



  
`timescale 1 ns / 1 ns

			 
module memory_flash_tristate_bridge_pinSharer_0_pin_sharer (
 // ** Clock and Reset Connections
    input  logic clk
   ,input  logic reset

 // ** Arbiter Connections

 // *** Arbiter Grant Interface
   ,output logic ack
   ,input  logic [ 3 - 1 : 0 ] next_grant

// *** Arbiter Request Interface

    ,output logic arb_ext_flash_tcm 
    ,output logic arb_max2_inf_tcm 
    ,output logic arb_ssram_tcm 
		
		     // ** Avalon TC Slave Interfaces




  // Slave Interface tcs2

    ,input  logic tcs2_request 
    ,output logic tcs2_grant   

  //ext_flash.tcm signals
    ,input  logic[ 24 :0 ] tcs2_tcm_address_out
    ,input  logic[ 0 :0 ] tcs2_tcm_read_n_out
    ,input  logic[ 0 :0 ] tcs2_tcm_write_n_out
    ,output logic[ 15 :0 ]  tcs2_tcm_data_in
    ,input  logic[ 15 :0 ]  tcs2_tcm_data_out
    ,input  logic tcs2_tcm_data_outen
    ,input  logic[ 0 :0 ] tcs2_tcm_chipselect_n_out



  // Slave Interface tcs1

    ,input  logic tcs1_request 
    ,output logic tcs1_grant   

  //max2_inf.tcm signals
    ,input  logic[ 0 :0 ] tcs1_tcm_chipselect_n_out
    ,input  logic[ 3 :0 ] tcs1_tcm_byteenable_n_out
    ,input  logic[ 0 :0 ] tcs1_tcm_outputenable_n_out
    ,input  logic[ 0 :0 ] tcs1_tcm_write_n_out
    ,output logic[ 31 :0 ]  tcs1_tcm_data_in
    ,input  logic[ 31 :0 ]  tcs1_tcm_data_out
    ,input  logic tcs1_tcm_data_outen
    ,input  logic[ 19 :0 ] tcs1_tcm_address_out
    ,input  logic[ 0 :0 ] tcs1_tcm_reset_n_out
    ,input  logic[ 0 :0 ] tcs1_tcm_begintransfer_n_out



  // Slave Interface tcs0

    ,input  logic tcs0_request 
    ,output logic tcs0_grant   

  //ssram.tcm signals
    ,input  logic[ 0 :0 ] tcs0_tcm_chipselect_n_out
    ,input  logic[ 3 :0 ] tcs0_tcm_byteenable_n_out
    ,input  logic[ 0 :0 ] tcs0_tcm_outputenable_n_out
    ,input  logic[ 0 :0 ] tcs0_tcm_write_n_out
    ,output logic[ 31 :0 ]  tcs0_tcm_data_in
    ,input  logic[ 31 :0 ]  tcs0_tcm_data_out
    ,input  logic tcs0_tcm_data_outen
    ,input  logic[ 20 :0 ] tcs0_tcm_address_out
    ,input  logic[ 0 :0 ] tcs0_tcm_reset_n_out
    ,input  logic[ 0 :0 ] tcs0_tcm_begintransfer_n_out
		     
		     // ** Avalon TC Master Interface
    ,output logic request
    ,input  logic grant

		     // *** Passthrough Signals
		     
		     
                     // *** Shared Signals
		      	     
    ,output  logic[ 0 :0 ] read_n_to_the_ext_flash
    ,output  logic[ 0 :0 ] adsc_n_to_the_max2_inf
    ,output  logic[ 0 :0 ] select_n_to_the_ext_flash
    ,output  logic[ 0 :0 ] outputenable_n_to_the_max2_inf
    ,output  logic[ 0 :0 ] bwe_n_to_the_ssram
    ,output  logic[ 3 :0 ] bw_n_to_the_max2_inf
    ,output  logic[ 0 :0 ] reset_n_to_the_ssram
    ,output  logic[ 0 :0 ] chipenable1_n_to_the_ssram
    ,output  logic[ 0 :0 ] reset_n_to_the_max2_inf
    ,output  logic[ 0 :0 ] chipenable1_n_to_the_max2_inf
    ,output  logic[ 3 :0 ] bw_n_to_the_ssram
    ,input   logic[ 31  :0 ]  flash_tristate_bridge_data_in
    ,output  logic[ 31  :0 ]  flash_tristate_bridge_data
    ,output  logic flash_tristate_bridge_data_outen
    ,output  logic[ 0 :0 ] outputenable_n_to_the_ssram
    ,output  logic[ 0 :0 ] adsc_n_to_the_ssram
    ,output  logic[ 0 :0 ] bwe_n_to_the_max2_inf
    ,output  logic[ 24 :0 ] flash_tristate_bridge_address
    ,output  logic[ 0 :0 ] write_n_to_the_ext_flash

		     );

   function [3-1:0] getIndex;
      
      input [3-1:0] select;
      
      getIndex = 'h0;
      
      for(int i=0; i < 3; i = i + 1) begin
	 if( select[i] == 1'b1 )
           getIndex = i;
      end
      
   endfunction // getIndex

   logic[ 3 - 1 : 0 ] selected_grant;


   // Request Assignments

    assign arb_ext_flash_tcm = tcs2_request;
    assign arb_max2_inf_tcm = tcs1_request;
    assign arb_ssram_tcm = tcs0_request;
   
   logic [ 3 - 1 : 0 ] concated_incoming_requests;
   
   
   assign 			      concated_incoming_requests = {						    
         tcs2_request 
        ,tcs1_request 
        ,tcs0_request 
				};
   
				       
   assign 			      request = | concated_incoming_requests;
  assign        tcs0_grant = selected_grant[0];
  assign        tcs1_grant = selected_grant[1];
  assign        tcs2_grant = selected_grant[2];

   
    // Perform Grant Selection						  
   always@(posedge clk, posedge reset) begin
     if(reset) begin
	selected_grant<=0;
	ack <= 0;
     end 
     else begin
       if(grant && (concated_incoming_requests[getIndex(selected_grant)] == 0 || selected_grant == 0 )) begin
	  if(~request)
	    selected_grant <= '0;
	  else
	    selected_grant <= next_grant;
	  
          ack<=1;
       end
       else begin
         ack<=0;
         selected_grant <= selected_grant;
       end
     end
   end // always@ (posedge clk, posedge reset)

// Passthrough Signals

  
// Renamed Signals
    assign read_n_to_the_ext_flash = tcs2_tcm_read_n_out ;
    assign write_n_to_the_ext_flash = tcs2_tcm_write_n_out ;
    assign select_n_to_the_ext_flash = tcs2_tcm_chipselect_n_out ;
    assign chipenable1_n_to_the_max2_inf = tcs1_tcm_chipselect_n_out ;
    assign bw_n_to_the_max2_inf = tcs1_tcm_byteenable_n_out ;
    assign outputenable_n_to_the_max2_inf = tcs1_tcm_outputenable_n_out ;
    assign bwe_n_to_the_max2_inf = tcs1_tcm_write_n_out ;
    assign reset_n_to_the_max2_inf = tcs1_tcm_reset_n_out ;
    assign adsc_n_to_the_max2_inf = tcs1_tcm_begintransfer_n_out ;
    assign chipenable1_n_to_the_ssram = tcs0_tcm_chipselect_n_out ;
    assign bw_n_to_the_ssram = tcs0_tcm_byteenable_n_out ;
    assign outputenable_n_to_the_ssram = tcs0_tcm_outputenable_n_out ;
    assign bwe_n_to_the_ssram = tcs0_tcm_write_n_out ;
    assign reset_n_to_the_ssram = tcs0_tcm_reset_n_out ;
    assign adsc_n_to_the_ssram = tcs0_tcm_begintransfer_n_out ;
  
// Shared Signals
  assign tcs0_tcm_data_in = flash_tristate_bridge_data_in[31:0]; 
  assign tcs2_tcm_data_in = flash_tristate_bridge_data_in[15:0]; 
  assign tcs1_tcm_data_in = flash_tristate_bridge_data_in[31:0]; 
  memory_flash_tristate_bridge_pinSharer_0_pin_sharer_multiplexor_3 #(.WIDTH(1) )
    flash_tristate_bridge_data_outen_mux (
                              {
                                tcs2_grant
                               ,tcs1_grant
                               ,tcs0_grant
                              }
                              ,tcs2_tcm_data_outen
                              ,tcs1_tcm_data_outen
                              ,tcs0_tcm_data_outen
                              , flash_tristate_bridge_data_outen
                             );
  memory_flash_tristate_bridge_pinSharer_0_pin_sharer_multiplexor_3 #(.WIDTH(32) )
    flash_tristate_bridge_data_mux (
                              {
                                tcs2_grant
                               ,tcs1_grant
                               ,tcs0_grant
                              }
                              ,{16'h0,tcs2_tcm_data_out}
                              ,tcs1_tcm_data_out
                              ,tcs0_tcm_data_out
                              , flash_tristate_bridge_data
                             );
  memory_flash_tristate_bridge_pinSharer_0_pin_sharer_multiplexor_3 #(.WIDTH(25) )
    flash_tristate_bridge_address_mux (
                              {
                                tcs2_grant
                               ,tcs1_grant
                               ,tcs0_grant
                              }
                              ,tcs2_tcm_address_out
                              ,{5'h0,tcs1_tcm_address_out}
                              ,{4'h0,tcs0_tcm_address_out}
                              , flash_tristate_bridge_address
                             );
  
endmodule   
					    

  
module memory_flash_tristate_bridge_pinSharer_0_pin_sharer_multiplexor_3
  #( parameter WIDTH      = 8
    ) (
    input logic  [ 3 -1 : 0]                       SelectVector,
    input logic  [ WIDTH - 1 : 0 ]                Input_2,
    input logic  [ WIDTH - 1 : 0 ]                Input_1,
    input logic  [ WIDTH - 1 : 0 ]                Input_0,
    output logic [ WIDTH - 1 : 0 ]                OutputSignal
       );


function [3-1:0] getIndex;
      
    input [3-1:0] select;
   
    getIndex = 'h0;
    
    for(int i=0; i < 3; i = i + 1) begin
      if( select[i] == 1'b1 )
        getIndex = i;
    end
			      				
endfunction
								 
   always @* begin
     case(getIndex(SelectVector))
       default: OutputSignal = Input_0;
       0 : OutputSignal = Input_0;									   
       1 : OutputSignal = Input_1;									   
       2 : OutputSignal = Input_2;									   
     endcase
   end
   
endmodule


