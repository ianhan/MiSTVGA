
module memory (
	bridge_0_external_interface_address,
	bridge_0_external_interface_byte_enable,
	bridge_0_external_interface_read,
	bridge_0_external_interface_write,
	bridge_0_external_interface_write_data,
	bridge_0_external_interface_acknowledge,
	bridge_0_external_interface_read_data,
	clk_0,
	reset_n,
	bwe_n_to_the_ssram,
	adsc_n_to_the_max2_inf,
	adsc_n_to_the_ssram,
	chipenable1_n_to_the_max2_inf,
	reset_n_to_the_ssram,
	write_n_to_the_ext_flash,
	select_n_to_the_ext_flash,
	flash_tristate_bridge_address,
	flash_tristate_bridge_data,
	reset_n_to_the_max2_inf,
	outputenable_n_to_the_max2_inf,
	bw_n_to_the_ssram,
	bw_n_to_the_max2_inf,
	bwe_n_to_the_max2_inf,
	read_n_to_the_ext_flash,
	outputenable_n_to_the_ssram,
	chipenable1_n_to_the_ssram);	

	input	[29:0]	bridge_0_external_interface_address;
	input	[15:0]	bridge_0_external_interface_byte_enable;
	input		bridge_0_external_interface_read;
	input		bridge_0_external_interface_write;
	input	[127:0]	bridge_0_external_interface_write_data;
	output		bridge_0_external_interface_acknowledge;
	output	[127:0]	bridge_0_external_interface_read_data;
	input		clk_0;
	input		reset_n;
	output	[0:0]	bwe_n_to_the_ssram;
	output	[0:0]	adsc_n_to_the_max2_inf;
	output	[0:0]	adsc_n_to_the_ssram;
	output	[0:0]	chipenable1_n_to_the_max2_inf;
	output	[0:0]	reset_n_to_the_ssram;
	output	[0:0]	write_n_to_the_ext_flash;
	output	[0:0]	select_n_to_the_ext_flash;
	output	[24:0]	flash_tristate_bridge_address;
	inout	[31:0]	flash_tristate_bridge_data;
	output	[0:0]	reset_n_to_the_max2_inf;
	output	[0:0]	outputenable_n_to_the_max2_inf;
	output	[3:0]	bw_n_to_the_ssram;
	output	[3:0]	bw_n_to_the_max2_inf;
	output	[0:0]	bwe_n_to_the_max2_inf;
	output	[0:0]	read_n_to_the_ext_flash;
	output	[0:0]	outputenable_n_to_the_ssram;
	output	[0:0]	chipenable1_n_to_the_ssram;
endmodule
