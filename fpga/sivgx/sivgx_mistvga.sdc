create_clock -name pci_clk -period 30.000 [get_ports lpci_clk]
create_clock -name clk_50 -period 20.000 [get_ports clkin_50]
create_clock -name clk_100 -period 10.000 [get_ports clkinbot_100_p]
create_generated_clock -name hdmi_i2c_ctrl_clk \
    -source [get_ports clkin_50] \
    -divide_by 5002 \
    [get_registers {u_hdmi_config|mI2C_CTRL_CLK}]

derive_pll_clocks
derive_clock_uncertainty

set_clock_groups -asynchronous \
    -group [get_clocks {pci_clk}] \
    -group [get_clocks {u_vid_pll|altpll_component|auto_generated|pll1|clk[*]}]

set_max_delay -from [get_registers {u_vga|rst_n_xfer_pipe[*]}] \
              -to   [get_registers {u_vga|vga_rst_n_reg}] 10.000

set_input_delay -clock pci_clk -max 11.0 [get_ports {lpci_ad[*] lpci_cben[*] lpci_framen lpci_irdyn lpci_idsel lpci_par}]
set_input_delay -clock pci_clk -min 2.0 [get_ports {lpci_ad[*] lpci_cben[*] lpci_framen lpci_irdyn lpci_idsel lpci_par}]

set_output_delay -clock pci_clk -max 7.0 [get_ports {lpci_reqn lpci_trdyn lpci_devseln lpci_stopn lpci_par lpci_perrn lpci_serrn lpci_lockn lpci_enablen lpci_intan}]
set_output_delay -clock pci_clk -min 0.0 [get_ports {lpci_reqn lpci_trdyn lpci_devseln lpci_stopn lpci_par lpci_perrn lpci_serrn lpci_lockn lpci_enablen lpci_intan}]

set_false_path -from [get_ports {cpu_resetn hdmi_intn hdmi_sda lpci_rstn lpci_gntn}]
