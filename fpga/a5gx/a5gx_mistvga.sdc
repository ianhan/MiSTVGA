create_clock -name clk_50 -period 20.000 [get_ports clkin_50_top]
create_clock -name clk_100 -period 10.000 [get_ports clkintop_100_p]
create_clock -name pci_clk -period 30.000 [get_ports lpci_clk]
create_clock -name hdmi_refclk -period 8.000 [get_ports refclk2_qr1_p]

create_generated_clock -name ssram_clk_out \
    -source [get_pins -compatibility_mode {u_ssram_pll|altpll_component|auto_generated|generic_pll1~PLL_OUTPUT_COUNTER|divclk}] \
    -divide_by 1 [get_ports sram_clk]

derive_pll_clocks
derive_clock_uncertainty

set ssram_clock_group [get_clocks -nowarn {clk_100 ssram_clk_out *u_ssram_pll*}]

set_clock_groups -asynchronous \
    -group [get_clocks -nowarn {clk_50}] \
    -group $ssram_clock_group \
    -group [get_clocks -nowarn {pci_clk}] \
    -group [get_clocks -nowarn {*txpmalocalclk*}]

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

# SSRAM timing (IS61VPS51236A-200B3, 200 MHz capable; this design drives 100 MHz)
set ssram_ports [get_ports {fsm_a[*] fsm_d[*] sram_adscn sram_bwen sram_bwn[*] sram_cen sram_oen}]

set_output_delay -clock ssram_clk_out -max 1.4 $ssram_ports
set_output_delay -clock ssram_clk_out -min -0.4 $ssram_ports

set_input_delay -clock ssram_clk_out -max 3.1 [get_ports {fsm_d[*]}]
set_input_delay -clock ssram_clk_out -min 1.5 [get_ports {fsm_d[*]}]

# Return data is produced by the SSRAM after an sram_clk edge and consumed on
# the next internal 100 MHz beat.  The internal SSRAM clock has a small positive
# phase shift, so make that one-cycle relationship explicit instead of allowing
# TimeQuest to use the same-cycle shifted edge.
set ssram_core_clock [get_clocks -nowarn {*generic_pll2~PLL_OUTPUT_COUNTER|divclk}]
set_multicycle_path -setup 2 -from [get_ports {fsm_d[*]}] -to $ssram_core_clock
set_multicycle_path -hold 1 -from [get_ports {fsm_d[*]}] -to $ssram_core_clock

# False paths: video outputs (clocked by video PLL, relaxed timing)
#set_false_path -to [get_ports {HDMI_TX_RD[*] HDMI_TX_GD[*] HDMI_TX_BD[*] HDMI_TX_PCLK HDMI_TX_DE HDMI_TX_VS HDMI_TX_HS HDMI_TX_DSD_L[*] HDMI_TX_DSD_R[*] HDMI_TX_DCLK HDMI_TX_SCK HDMI_TX_WS HDMI_TX_MCLK HDMI_TX_I2S[*] HDMI_TX_SPDIF HDMI_TX_PCSCL HDMI_TX_PCSDA user_led[*]}]

# Forwarded SSRAM clock and async/debug pins.
set_false_path -from [get_ports clkintop_100_p] -to [get_ports sram_clk]
set_false_path -from [get_ports {cpu_resetn hdmi_tx_hpd lpci_rstn}]
set_false_path -to [get_ports {user_led[*]}]
