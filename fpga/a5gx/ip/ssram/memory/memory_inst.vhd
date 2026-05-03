	component memory is
		port (
			bridge_0_external_interface_address     : in    std_logic_vector(29 downto 0)  := (others => 'X'); -- address
			bridge_0_external_interface_byte_enable : in    std_logic_vector(15 downto 0)  := (others => 'X'); -- byte_enable
			bridge_0_external_interface_read        : in    std_logic                      := 'X';             -- read
			bridge_0_external_interface_write       : in    std_logic                      := 'X';             -- write
			bridge_0_external_interface_write_data  : in    std_logic_vector(127 downto 0) := (others => 'X'); -- write_data
			bridge_0_external_interface_acknowledge : out   std_logic;                                         -- acknowledge
			bridge_0_external_interface_read_data   : out   std_logic_vector(127 downto 0);                    -- read_data
			clk_0                                   : in    std_logic                      := 'X';             -- clk
			reset_n                                 : in    std_logic                      := 'X';             -- reset_n
			bwe_n_to_the_ssram                      : out   std_logic_vector(0 downto 0);                      -- bwe_n_to_the_ssram
			adsc_n_to_the_max2_inf                  : out   std_logic_vector(0 downto 0);                      -- adsc_n_to_the_max2_inf
			adsc_n_to_the_ssram                     : out   std_logic_vector(0 downto 0);                      -- adsc_n_to_the_ssram
			chipenable1_n_to_the_max2_inf           : out   std_logic_vector(0 downto 0);                      -- chipenable1_n_to_the_max2_inf
			reset_n_to_the_ssram                    : out   std_logic_vector(0 downto 0);                      -- reset_n_to_the_ssram
			write_n_to_the_ext_flash                : out   std_logic_vector(0 downto 0);                      -- write_n_to_the_ext_flash
			select_n_to_the_ext_flash               : out   std_logic_vector(0 downto 0);                      -- select_n_to_the_ext_flash
			flash_tristate_bridge_address           : out   std_logic_vector(24 downto 0);                     -- flash_tristate_bridge_address
			flash_tristate_bridge_data              : inout std_logic_vector(31 downto 0)  := (others => 'X'); -- flash_tristate_bridge_data
			reset_n_to_the_max2_inf                 : out   std_logic_vector(0 downto 0);                      -- reset_n_to_the_max2_inf
			outputenable_n_to_the_max2_inf          : out   std_logic_vector(0 downto 0);                      -- outputenable_n_to_the_max2_inf
			bw_n_to_the_ssram                       : out   std_logic_vector(3 downto 0);                      -- bw_n_to_the_ssram
			bw_n_to_the_max2_inf                    : out   std_logic_vector(3 downto 0);                      -- bw_n_to_the_max2_inf
			bwe_n_to_the_max2_inf                   : out   std_logic_vector(0 downto 0);                      -- bwe_n_to_the_max2_inf
			read_n_to_the_ext_flash                 : out   std_logic_vector(0 downto 0);                      -- read_n_to_the_ext_flash
			outputenable_n_to_the_ssram             : out   std_logic_vector(0 downto 0);                      -- outputenable_n_to_the_ssram
			chipenable1_n_to_the_ssram              : out   std_logic_vector(0 downto 0)                       -- chipenable1_n_to_the_ssram
		);
	end component memory;

	u0 : component memory
		port map (
			bridge_0_external_interface_address     => CONNECTED_TO_bridge_0_external_interface_address,     --        bridge_0_external_interface.address
			bridge_0_external_interface_byte_enable => CONNECTED_TO_bridge_0_external_interface_byte_enable, --                                   .byte_enable
			bridge_0_external_interface_read        => CONNECTED_TO_bridge_0_external_interface_read,        --                                   .read
			bridge_0_external_interface_write       => CONNECTED_TO_bridge_0_external_interface_write,       --                                   .write
			bridge_0_external_interface_write_data  => CONNECTED_TO_bridge_0_external_interface_write_data,  --                                   .write_data
			bridge_0_external_interface_acknowledge => CONNECTED_TO_bridge_0_external_interface_acknowledge, --                                   .acknowledge
			bridge_0_external_interface_read_data   => CONNECTED_TO_bridge_0_external_interface_read_data,   --                                   .read_data
			clk_0                                   => CONNECTED_TO_clk_0,                                   --                       clk_0_clk_in.clk
			reset_n                                 => CONNECTED_TO_reset_n,                                 --                 clk_0_clk_in_reset.reset_n
			bwe_n_to_the_ssram                      => CONNECTED_TO_bwe_n_to_the_ssram,                      -- flash_tristate_bridge_bridge_0_out.bwe_n_to_the_ssram
			adsc_n_to_the_max2_inf                  => CONNECTED_TO_adsc_n_to_the_max2_inf,                  --                                   .adsc_n_to_the_max2_inf
			adsc_n_to_the_ssram                     => CONNECTED_TO_adsc_n_to_the_ssram,                     --                                   .adsc_n_to_the_ssram
			chipenable1_n_to_the_max2_inf           => CONNECTED_TO_chipenable1_n_to_the_max2_inf,           --                                   .chipenable1_n_to_the_max2_inf
			reset_n_to_the_ssram                    => CONNECTED_TO_reset_n_to_the_ssram,                    --                                   .reset_n_to_the_ssram
			write_n_to_the_ext_flash                => CONNECTED_TO_write_n_to_the_ext_flash,                --                                   .write_n_to_the_ext_flash
			select_n_to_the_ext_flash               => CONNECTED_TO_select_n_to_the_ext_flash,               --                                   .select_n_to_the_ext_flash
			flash_tristate_bridge_address           => CONNECTED_TO_flash_tristate_bridge_address,           --                                   .flash_tristate_bridge_address
			flash_tristate_bridge_data              => CONNECTED_TO_flash_tristate_bridge_data,              --                                   .flash_tristate_bridge_data
			reset_n_to_the_max2_inf                 => CONNECTED_TO_reset_n_to_the_max2_inf,                 --                                   .reset_n_to_the_max2_inf
			outputenable_n_to_the_max2_inf          => CONNECTED_TO_outputenable_n_to_the_max2_inf,          --                                   .outputenable_n_to_the_max2_inf
			bw_n_to_the_ssram                       => CONNECTED_TO_bw_n_to_the_ssram,                       --                                   .bw_n_to_the_ssram
			bw_n_to_the_max2_inf                    => CONNECTED_TO_bw_n_to_the_max2_inf,                    --                                   .bw_n_to_the_max2_inf
			bwe_n_to_the_max2_inf                   => CONNECTED_TO_bwe_n_to_the_max2_inf,                   --                                   .bwe_n_to_the_max2_inf
			read_n_to_the_ext_flash                 => CONNECTED_TO_read_n_to_the_ext_flash,                 --                                   .read_n_to_the_ext_flash
			outputenable_n_to_the_ssram             => CONNECTED_TO_outputenable_n_to_the_ssram,             --                                   .outputenable_n_to_the_ssram
			chipenable1_n_to_the_ssram              => CONNECTED_TO_chipenable1_n_to_the_ssram               --                                   .chipenable1_n_to_the_ssram
		);

