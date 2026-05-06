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


// $Id: //acds/rel/20.1std/ip/merlin/altera_tristate_conduit_bridge/altera_tristate_conduit_bridge.sv.terp#1 $
// $Revision: #1 $
// $Date: 2019/10/06 $
// $Author: psgswbuild $

//Defined Terp Parameters


			    

`timescale 1 ns / 1 ns
  				      
module memory_flash_tristate_bridge_bridge_0 (
     input  logic clk
    ,input  logic reset
    ,input  logic request
    ,output logic grant
    ,input  logic[ 0 :0 ] tcs_bwe_n_to_the_ssram
    ,output  wire [ 0 :0 ] bwe_n_to_the_ssram
    ,input  logic[ 0 :0 ] tcs_adsc_n_to_the_max2_inf
    ,output  wire [ 0 :0 ] adsc_n_to_the_max2_inf
    ,input  logic[ 0 :0 ] tcs_adsc_n_to_the_ssram
    ,output  wire [ 0 :0 ] adsc_n_to_the_ssram
    ,input  logic[ 0 :0 ] tcs_chipenable1_n_to_the_max2_inf
    ,output  wire [ 0 :0 ] chipenable1_n_to_the_max2_inf
    ,input  logic[ 0 :0 ] tcs_reset_n_to_the_ssram
    ,output  wire [ 0 :0 ] reset_n_to_the_ssram
    ,input  logic[ 0 :0 ] tcs_write_n_to_the_ext_flash
    ,output  wire [ 0 :0 ] write_n_to_the_ext_flash
    ,input  logic[ 0 :0 ] tcs_select_n_to_the_ext_flash
    ,output  wire [ 0 :0 ] select_n_to_the_ext_flash
    ,input  logic[ 24 :0 ] tcs_flash_tristate_bridge_address
    ,output  wire [ 24 :0 ] flash_tristate_bridge_address
    ,output logic[ 31 :0 ] tcs_flash_tristate_bridge_data_in
    ,input  logic[ 31 :0 ] tcs_flash_tristate_bridge_data
    ,input  logic tcs_flash_tristate_bridge_data_outen
    ,inout  wire [ 31 :0 ]  flash_tristate_bridge_data
    ,input  logic[ 0 :0 ] tcs_reset_n_to_the_max2_inf
    ,output  wire [ 0 :0 ] reset_n_to_the_max2_inf
    ,input  logic[ 0 :0 ] tcs_outputenable_n_to_the_max2_inf
    ,output  wire [ 0 :0 ] outputenable_n_to_the_max2_inf
    ,input  logic[ 3 :0 ] tcs_bw_n_to_the_ssram
    ,output  wire [ 3 :0 ] bw_n_to_the_ssram
    ,input  logic[ 3 :0 ] tcs_bw_n_to_the_max2_inf
    ,output  wire [ 3 :0 ] bw_n_to_the_max2_inf
    ,input  logic[ 0 :0 ] tcs_bwe_n_to_the_max2_inf
    ,output  wire [ 0 :0 ] bwe_n_to_the_max2_inf
    ,input  logic[ 0 :0 ] tcs_read_n_to_the_ext_flash
    ,output  wire [ 0 :0 ] read_n_to_the_ext_flash
    ,input  logic[ 0 :0 ] tcs_outputenable_n_to_the_ssram
    ,output  wire [ 0 :0 ] outputenable_n_to_the_ssram
    ,input  logic[ 0 :0 ] tcs_chipenable1_n_to_the_ssram
    ,output  wire [ 0 :0 ] chipenable1_n_to_the_ssram
		     
   );
   reg grant_reg;
   assign grant = grant_reg;
   
   always@(posedge clk) begin
      if(reset)
	grant_reg <= 0;
      else
	grant_reg <= request;      
   end
   


 // ** Output Pin bwe_n_to_the_ssram 
 
    reg                       bwe_n_to_the_ssramen_reg;     
  
    always@(posedge clk) begin
	 if( reset ) begin
	   bwe_n_to_the_ssramen_reg <= 'b0;
	 end
	 else begin
	   bwe_n_to_the_ssramen_reg <= 'b1;
	 end
     end		     
   
 
    reg [ 0 : 0 ] bwe_n_to_the_ssram_reg;   

     always@(posedge clk) begin
	 bwe_n_to_the_ssram_reg   <= tcs_bwe_n_to_the_ssram[ 0 : 0 ];
      end
          
 
    assign 	bwe_n_to_the_ssram[ 0 : 0 ] = bwe_n_to_the_ssramen_reg ? bwe_n_to_the_ssram_reg : 'z ;
        


 // ** Output Pin adsc_n_to_the_max2_inf 
 
    reg                       adsc_n_to_the_max2_infen_reg;     
  
    always@(posedge clk) begin
	 if( reset ) begin
	   adsc_n_to_the_max2_infen_reg <= 'b0;
	 end
	 else begin
	   adsc_n_to_the_max2_infen_reg <= 'b1;
	 end
     end		     
   
 
    reg [ 0 : 0 ] adsc_n_to_the_max2_inf_reg;   

     always@(posedge clk) begin
	 adsc_n_to_the_max2_inf_reg   <= tcs_adsc_n_to_the_max2_inf[ 0 : 0 ];
      end
          
 
    assign 	adsc_n_to_the_max2_inf[ 0 : 0 ] = adsc_n_to_the_max2_infen_reg ? adsc_n_to_the_max2_inf_reg : 'z ;
        


 // ** Output Pin adsc_n_to_the_ssram 
 
    reg                       adsc_n_to_the_ssramen_reg;     
  
    always@(posedge clk) begin
	 if( reset ) begin
	   adsc_n_to_the_ssramen_reg <= 'b0;
	 end
	 else begin
	   adsc_n_to_the_ssramen_reg <= 'b1;
	 end
     end		     
   
 
    reg [ 0 : 0 ] adsc_n_to_the_ssram_reg;   

     always@(posedge clk) begin
	 adsc_n_to_the_ssram_reg   <= tcs_adsc_n_to_the_ssram[ 0 : 0 ];
      end
          
 
    assign 	adsc_n_to_the_ssram[ 0 : 0 ] = adsc_n_to_the_ssramen_reg ? adsc_n_to_the_ssram_reg : 'z ;
        


 // ** Output Pin chipenable1_n_to_the_max2_inf 
 
    reg                       chipenable1_n_to_the_max2_infen_reg;     
  
    always@(posedge clk) begin
	 if( reset ) begin
	   chipenable1_n_to_the_max2_infen_reg <= 'b0;
	 end
	 else begin
	   chipenable1_n_to_the_max2_infen_reg <= 'b1;
	 end
     end		     
   
 
    reg [ 0 : 0 ] chipenable1_n_to_the_max2_inf_reg;   

     always@(posedge clk) begin
	 chipenable1_n_to_the_max2_inf_reg   <= tcs_chipenable1_n_to_the_max2_inf[ 0 : 0 ];
      end
          
 
    assign 	chipenable1_n_to_the_max2_inf[ 0 : 0 ] = chipenable1_n_to_the_max2_infen_reg ? chipenable1_n_to_the_max2_inf_reg : 'z ;
        


 // ** Output Pin reset_n_to_the_ssram 
 
    reg                       reset_n_to_the_ssramen_reg;     
  
    always@(posedge clk) begin
	 if( reset ) begin
	   reset_n_to_the_ssramen_reg <= 'b0;
	 end
	 else begin
	   reset_n_to_the_ssramen_reg <= 'b1;
	 end
     end		     
   
 
    reg [ 0 : 0 ] reset_n_to_the_ssram_reg;   

     always@(posedge clk) begin
	 reset_n_to_the_ssram_reg   <= tcs_reset_n_to_the_ssram[ 0 : 0 ];
      end
          
 
    assign 	reset_n_to_the_ssram[ 0 : 0 ] = reset_n_to_the_ssramen_reg ? reset_n_to_the_ssram_reg : 'z ;
        


 // ** Output Pin write_n_to_the_ext_flash 
 
    reg                       write_n_to_the_ext_flashen_reg;     
  
    always@(posedge clk) begin
	 if( reset ) begin
	   write_n_to_the_ext_flashen_reg <= 'b0;
	 end
	 else begin
	   write_n_to_the_ext_flashen_reg <= 'b1;
	 end
     end		     
   
 
    reg [ 0 : 0 ] write_n_to_the_ext_flash_reg;   

     always@(posedge clk) begin
	 write_n_to_the_ext_flash_reg   <= tcs_write_n_to_the_ext_flash[ 0 : 0 ];
      end
          
 
    assign 	write_n_to_the_ext_flash[ 0 : 0 ] = write_n_to_the_ext_flashen_reg ? write_n_to_the_ext_flash_reg : 'z ;
        


 // ** Output Pin select_n_to_the_ext_flash 
 
    reg                       select_n_to_the_ext_flashen_reg;     
  
    always@(posedge clk) begin
	 if( reset ) begin
	   select_n_to_the_ext_flashen_reg <= 'b0;
	 end
	 else begin
	   select_n_to_the_ext_flashen_reg <= 'b1;
	 end
     end		     
   
 
    reg [ 0 : 0 ] select_n_to_the_ext_flash_reg;   

     always@(posedge clk) begin
	 select_n_to_the_ext_flash_reg   <= tcs_select_n_to_the_ext_flash[ 0 : 0 ];
      end
          
 
    assign 	select_n_to_the_ext_flash[ 0 : 0 ] = select_n_to_the_ext_flashen_reg ? select_n_to_the_ext_flash_reg : 'z ;
        


 // ** Output Pin flash_tristate_bridge_address 
 
    reg                       flash_tristate_bridge_addressen_reg;     
  
    always@(posedge clk) begin
	 if( reset ) begin
	   flash_tristate_bridge_addressen_reg <= 'b0;
	 end
	 else begin
	   flash_tristate_bridge_addressen_reg <= 'b1;
	 end
     end		     
   
 
    reg [ 24 : 0 ] flash_tristate_bridge_address_reg;   

     always@(posedge clk) begin
	 flash_tristate_bridge_address_reg   <= tcs_flash_tristate_bridge_address[ 24 : 0 ];
      end
          
 
    assign 	flash_tristate_bridge_address[ 24 : 0 ] = flash_tristate_bridge_addressen_reg ? flash_tristate_bridge_address_reg : 'z ;
        


 // ** Bidirectional Pin flash_tristate_bridge_data 
   
    reg                       flash_tristate_bridge_data_outen_reg;
  
    always@(posedge clk) begin
	 flash_tristate_bridge_data_outen_reg <= tcs_flash_tristate_bridge_data_outen;
     end
  
  
    reg [ 31 : 0 ] flash_tristate_bridge_data_reg;   

     always@(posedge clk) begin
	 flash_tristate_bridge_data_reg   <= tcs_flash_tristate_bridge_data[ 31 : 0 ];
      end
         
  
    assign 	flash_tristate_bridge_data[ 31 : 0 ] = flash_tristate_bridge_data_outen_reg ? flash_tristate_bridge_data_reg : 'z ;
       
  
    reg [ 31 : 0 ] 	flash_tristate_bridge_data_in_reg;
								    
    always@(posedge clk) begin
	 flash_tristate_bridge_data_in_reg <= flash_tristate_bridge_data[ 31 : 0 ];
    end
    
  
    assign      tcs_flash_tristate_bridge_data_in[ 31 : 0 ] = flash_tristate_bridge_data_in_reg[ 31 : 0 ];
        


 // ** Output Pin reset_n_to_the_max2_inf 
 
    reg                       reset_n_to_the_max2_infen_reg;     
  
    always@(posedge clk) begin
	 if( reset ) begin
	   reset_n_to_the_max2_infen_reg <= 'b0;
	 end
	 else begin
	   reset_n_to_the_max2_infen_reg <= 'b1;
	 end
     end		     
   
 
    reg [ 0 : 0 ] reset_n_to_the_max2_inf_reg;   

     always@(posedge clk) begin
	 reset_n_to_the_max2_inf_reg   <= tcs_reset_n_to_the_max2_inf[ 0 : 0 ];
      end
          
 
    assign 	reset_n_to_the_max2_inf[ 0 : 0 ] = reset_n_to_the_max2_infen_reg ? reset_n_to_the_max2_inf_reg : 'z ;
        


 // ** Output Pin outputenable_n_to_the_max2_inf 
 
    reg                       outputenable_n_to_the_max2_infen_reg;     
  
    always@(posedge clk) begin
	 if( reset ) begin
	   outputenable_n_to_the_max2_infen_reg <= 'b0;
	 end
	 else begin
	   outputenable_n_to_the_max2_infen_reg <= 'b1;
	 end
     end		     
   
 
    reg [ 0 : 0 ] outputenable_n_to_the_max2_inf_reg;   

     always@(posedge clk) begin
	 outputenable_n_to_the_max2_inf_reg   <= tcs_outputenable_n_to_the_max2_inf[ 0 : 0 ];
      end
          
 
    assign 	outputenable_n_to_the_max2_inf[ 0 : 0 ] = outputenable_n_to_the_max2_infen_reg ? outputenable_n_to_the_max2_inf_reg : 'z ;
        


 // ** Output Pin bw_n_to_the_ssram 
 
    reg                       bw_n_to_the_ssramen_reg;     
  
    always@(posedge clk) begin
	 if( reset ) begin
	   bw_n_to_the_ssramen_reg <= 'b0;
	 end
	 else begin
	   bw_n_to_the_ssramen_reg <= 'b1;
	 end
     end		     
   
 
    reg [ 3 : 0 ] bw_n_to_the_ssram_reg;   

     always@(posedge clk) begin
	 bw_n_to_the_ssram_reg   <= tcs_bw_n_to_the_ssram[ 3 : 0 ];
      end
          
 
    assign 	bw_n_to_the_ssram[ 3 : 0 ] = bw_n_to_the_ssramen_reg ? bw_n_to_the_ssram_reg : 'z ;
        


 // ** Output Pin bw_n_to_the_max2_inf 
 
    reg                       bw_n_to_the_max2_infen_reg;     
  
    always@(posedge clk) begin
	 if( reset ) begin
	   bw_n_to_the_max2_infen_reg <= 'b0;
	 end
	 else begin
	   bw_n_to_the_max2_infen_reg <= 'b1;
	 end
     end		     
   
 
    reg [ 3 : 0 ] bw_n_to_the_max2_inf_reg;   

     always@(posedge clk) begin
	 bw_n_to_the_max2_inf_reg   <= tcs_bw_n_to_the_max2_inf[ 3 : 0 ];
      end
          
 
    assign 	bw_n_to_the_max2_inf[ 3 : 0 ] = bw_n_to_the_max2_infen_reg ? bw_n_to_the_max2_inf_reg : 'z ;
        


 // ** Output Pin bwe_n_to_the_max2_inf 
 
    reg                       bwe_n_to_the_max2_infen_reg;     
  
    always@(posedge clk) begin
	 if( reset ) begin
	   bwe_n_to_the_max2_infen_reg <= 'b0;
	 end
	 else begin
	   bwe_n_to_the_max2_infen_reg <= 'b1;
	 end
     end		     
   
 
    reg [ 0 : 0 ] bwe_n_to_the_max2_inf_reg;   

     always@(posedge clk) begin
	 bwe_n_to_the_max2_inf_reg   <= tcs_bwe_n_to_the_max2_inf[ 0 : 0 ];
      end
          
 
    assign 	bwe_n_to_the_max2_inf[ 0 : 0 ] = bwe_n_to_the_max2_infen_reg ? bwe_n_to_the_max2_inf_reg : 'z ;
        


 // ** Output Pin read_n_to_the_ext_flash 
 
    reg                       read_n_to_the_ext_flashen_reg;     
  
    always@(posedge clk) begin
	 if( reset ) begin
	   read_n_to_the_ext_flashen_reg <= 'b0;
	 end
	 else begin
	   read_n_to_the_ext_flashen_reg <= 'b1;
	 end
     end		     
   
 
    reg [ 0 : 0 ] read_n_to_the_ext_flash_reg;   

     always@(posedge clk) begin
	 read_n_to_the_ext_flash_reg   <= tcs_read_n_to_the_ext_flash[ 0 : 0 ];
      end
          
 
    assign 	read_n_to_the_ext_flash[ 0 : 0 ] = read_n_to_the_ext_flashen_reg ? read_n_to_the_ext_flash_reg : 'z ;
        


 // ** Output Pin outputenable_n_to_the_ssram 
 
    reg                       outputenable_n_to_the_ssramen_reg;     
  
    always@(posedge clk) begin
	 if( reset ) begin
	   outputenable_n_to_the_ssramen_reg <= 'b0;
	 end
	 else begin
	   outputenable_n_to_the_ssramen_reg <= 'b1;
	 end
     end		     
   
 
    reg [ 0 : 0 ] outputenable_n_to_the_ssram_reg;   

     always@(posedge clk) begin
	 outputenable_n_to_the_ssram_reg   <= tcs_outputenable_n_to_the_ssram[ 0 : 0 ];
      end
          
 
    assign 	outputenable_n_to_the_ssram[ 0 : 0 ] = outputenable_n_to_the_ssramen_reg ? outputenable_n_to_the_ssram_reg : 'z ;
        


 // ** Output Pin chipenable1_n_to_the_ssram 
 
    reg                       chipenable1_n_to_the_ssramen_reg;     
  
    always@(posedge clk) begin
	 if( reset ) begin
	   chipenable1_n_to_the_ssramen_reg <= 'b0;
	 end
	 else begin
	   chipenable1_n_to_the_ssramen_reg <= 'b1;
	 end
     end		     
   
 
    reg [ 0 : 0 ] chipenable1_n_to_the_ssram_reg;   

     always@(posedge clk) begin
	 chipenable1_n_to_the_ssram_reg   <= tcs_chipenable1_n_to_the_ssram[ 0 : 0 ];
      end
          
 
    assign 	chipenable1_n_to_the_ssram[ 0 : 0 ] = chipenable1_n_to_the_ssramen_reg ? chipenable1_n_to_the_ssram_reg : 'z ;
        

endmodule

