# MiST VGA — ao486/MiSTer VGA core wrapped for simulation and A2GX hardware
#
# Targets:
#   sim       — build and run Verilator simulation
#   a2gx      — synthesize for Arria II GX development kit (requires Quartus)
#   prog      — program the A2GX board via JTAG
#   lint      — Verilator lint check on A2GX wrapper
#   clean     — remove build artifacts

A2GX_PROJECT_DIR = fpga
A2GX_PROJECT = a2gx_mistvga
A2GX_BUILD_DIR = build
A2GX_SOF = $(A2GX_BUILD_DIR)/$(A2GX_PROJECT).sof

A2GX_RTL_SOURCES = \
	rtl/a2gx_mistvga_top.sv \
	rtl/pci_vga_bridge.sv \
	rtl/a2gx_mistvga_pll.v \
	rtl/a2gx_pci_clk_pll.v \
	rtl/a2gx_i2c_write_wdata.v \
	rtl/a2gx_i2c_controller.v \
	rtl/a2gx_i2c_hdmi_config.v \
	rtl/vga.v \
	rtl/dpram_difclk.v

A2GX_PROJECT_FILES = \
	$(A2GX_PROJECT_DIR)/$(A2GX_PROJECT).qpf \
	$(A2GX_PROJECT_DIR)/$(A2GX_PROJECT).qsf \
	$(A2GX_PROJECT_DIR)/$(A2GX_PROJECT).sdc

ROMHEX = $(A2GX_PROJECT_DIR)/boot1.hex

.PHONY: all sim a2gx prog lint sta clean

all: sim

sim:
	$(MAKE) -C sim

a2gx: $(A2GX_SOF)

$(ROMHEX): vgabios/boot1.rom vgabios/patch_rom.py
	python3 vgabios/patch_rom.py vgabios/boot1.rom $(ROMHEX)

$(A2GX_SOF): $(A2GX_PROJECT_FILES) $(A2GX_RTL_SOURCES) $(ROMHEX)
	cd $(A2GX_PROJECT_DIR) && quartus_sh --flow compile $(A2GX_PROJECT)

prog: $(A2GX_SOF)
	quartus_pgm -m jtag -o "p;$(A2GX_SOF)" -c 1

sta:
	cd $(A2GX_PROJECT_DIR) && quartus_sta $(A2GX_PROJECT)

lint:
	$(MAKE) -C sim lint-a2gx

clean:
	$(MAKE) -C sim clean
	rm -rf $(A2GX_BUILD_DIR)
	rm -rf $(A2GX_PROJECT_DIR)/db $(A2GX_PROJECT_DIR)/incremental_db
	rm -rf $(A2GX_PROJECT_DIR)/*.rpt $(A2GX_PROJECT_DIR)/*.summary
	rm -rf $(A2GX_PROJECT_DIR)/*.done $(A2GX_PROJECT_DIR)/*.jdi
	rm -rf $(A2GX_PROJECT_DIR)/*.qws $(A2GX_PROJECT_DIR)/greybox_tmp
