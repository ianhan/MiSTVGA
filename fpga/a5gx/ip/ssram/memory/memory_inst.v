	memory u0 (
		.bridge_0_external_interface_address     (<connected-to-bridge_0_external_interface_address>),     //        bridge_0_external_interface.address
		.bridge_0_external_interface_byte_enable (<connected-to-bridge_0_external_interface_byte_enable>), //                                   .byte_enable
		.bridge_0_external_interface_read        (<connected-to-bridge_0_external_interface_read>),        //                                   .read
		.bridge_0_external_interface_write       (<connected-to-bridge_0_external_interface_write>),       //                                   .write
		.bridge_0_external_interface_write_data  (<connected-to-bridge_0_external_interface_write_data>),  //                                   .write_data
		.bridge_0_external_interface_acknowledge (<connected-to-bridge_0_external_interface_acknowledge>), //                                   .acknowledge
		.bridge_0_external_interface_read_data   (<connected-to-bridge_0_external_interface_read_data>),   //                                   .read_data
		.clk_0                                   (<connected-to-clk_0>),                                   //                       clk_0_clk_in.clk
		.reset_n                                 (<connected-to-reset_n>),                                 //                 clk_0_clk_in_reset.reset_n
		.bwe_n_to_the_ssram                      (<connected-to-bwe_n_to_the_ssram>),                      // flash_tristate_bridge_bridge_0_out.bwe_n_to_the_ssram
		.adsc_n_to_the_max2_inf                  (<connected-to-adsc_n_to_the_max2_inf>),                  //                                   .adsc_n_to_the_max2_inf
		.adsc_n_to_the_ssram                     (<connected-to-adsc_n_to_the_ssram>),                     //                                   .adsc_n_to_the_ssram
		.chipenable1_n_to_the_max2_inf           (<connected-to-chipenable1_n_to_the_max2_inf>),           //                                   .chipenable1_n_to_the_max2_inf
		.reset_n_to_the_ssram                    (<connected-to-reset_n_to_the_ssram>),                    //                                   .reset_n_to_the_ssram
		.write_n_to_the_ext_flash                (<connected-to-write_n_to_the_ext_flash>),                //                                   .write_n_to_the_ext_flash
		.select_n_to_the_ext_flash               (<connected-to-select_n_to_the_ext_flash>),               //                                   .select_n_to_the_ext_flash
		.flash_tristate_bridge_address           (<connected-to-flash_tristate_bridge_address>),           //                                   .flash_tristate_bridge_address
		.flash_tristate_bridge_data              (<connected-to-flash_tristate_bridge_data>),              //                                   .flash_tristate_bridge_data
		.reset_n_to_the_max2_inf                 (<connected-to-reset_n_to_the_max2_inf>),                 //                                   .reset_n_to_the_max2_inf
		.outputenable_n_to_the_max2_inf          (<connected-to-outputenable_n_to_the_max2_inf>),          //                                   .outputenable_n_to_the_max2_inf
		.bw_n_to_the_ssram                       (<connected-to-bw_n_to_the_ssram>),                       //                                   .bw_n_to_the_ssram
		.bw_n_to_the_max2_inf                    (<connected-to-bw_n_to_the_max2_inf>),                    //                                   .bw_n_to_the_max2_inf
		.bwe_n_to_the_max2_inf                   (<connected-to-bwe_n_to_the_max2_inf>),                   //                                   .bwe_n_to_the_max2_inf
		.read_n_to_the_ext_flash                 (<connected-to-read_n_to_the_ext_flash>),                 //                                   .read_n_to_the_ext_flash
		.outputenable_n_to_the_ssram             (<connected-to-outputenable_n_to_the_ssram>),             //                                   .outputenable_n_to_the_ssram
		.chipenable1_n_to_the_ssram              (<connected-to-chipenable1_n_to_the_ssram>)               //                                   .chipenable1_n_to_the_ssram
	);

