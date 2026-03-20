create_clock -name pci_clk -period 30.000 [get_ports lpci_clk]
create_clock -name clk_100 -period 10.000 [get_ports clkin_top_p]

derive_pll_clocks
derive_clock_uncertainty

# PCI domain (external clock + compensated PCI PLL) and video PLL clock
# are asynchronous.
set_clock_groups -asynchronous \
    -group [get_clocks {pci_clk}] \
    -group [get_clocks {u_vid_pll|altpll_component|auto_generated|pll1|clk[*]}]

# vga.v internal CDC: rst_n synchronizer (clk_sys → clk_vga)
set_max_delay -from [get_registers {u_vga|rst_n_xfer_pipe[*]}] \
              -to   [get_registers {u_vga|vga_rst_n_reg}] 10.000

# PCI input/output delays (PCI 33 MHz specification)
# Inputs from the initiator are timed to the external PCI clock but
# captured by the compensated internal PCI PLL clock.
set_input_delay -clock pci_clk -max 11.0 [get_ports {lpci_ad[*] lpci_cben[*] lpci_framen lpci_irdyn lpci_idsel lpci_par}]
set_input_delay -clock pci_clk -min 2.0 [get_ports {lpci_ad[*] lpci_cben[*] lpci_framen lpci_irdyn lpci_idsel lpci_par}]

set_output_delay -clock pci_clk -max 7.0 [get_ports {lpci_ad[*] lpci_reqn lpci_trdyn lpci_devseln lpci_stopn lpci_par lpci_perrn lpci_serrn lpci_lockn lpci_enablen lpci_intan}]
set_output_delay -clock pci_clk -min 0.0 [get_ports {lpci_ad[*] lpci_reqn lpci_trdyn lpci_devseln lpci_stopn lpci_par lpci_perrn lpci_serrn lpci_lockn lpci_enablen lpci_intan}]

# False paths: video outputs (clocked by video PLL, relaxed timing)
#set_false_path -to [get_ports {HDMI_TX_RD[*] HDMI_TX_GD[*] HDMI_TX_BD[*] HDMI_TX_PCLK HDMI_TX_DE HDMI_TX_VS HDMI_TX_HS HDMI_TX_DSD_L[*] HDMI_TX_DSD_R[*] HDMI_TX_DCLK HDMI_TX_SCK HDMI_TX_WS HDMI_TX_MCLK HDMI_TX_I2S[*] HDMI_TX_SPDIF HDMI_TX_PCSCL HDMI_TX_PCSDA user_led[*]}]

# False paths: unused peripheral tie-offs
set_false_path -to [get_ports {enet_gtx_clk enet_tx_d[*] enet_tx_en enet_resetn enet_mdc flash_clk flash_cen flash_oen flash_wen flash_advn flash_resetn sram_clk sram_cen sram_bwn[*] sram_gwn sram_bwen sram_oen sram_advn sram_adspn sram_adscn sram_zz max2_clk max2_csn max2_ben[*] max2_oen max2_wen lcd_d_cn lcd_wen lcd_csn pcie_waken pcie_led_x1 pcie_led_x4 pcie_led_x8}]

# False paths: async and untimed inputs
set_false_path -from [get_ports {cpu_resetn HDMI_TX_INT_N HDMI_TX_RST_N HDMI_TX_PCSDA lpci_rstn lpci_gntn}]
