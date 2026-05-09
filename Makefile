# MiST VGA — ao486/MiSTer VGA core wrapped for simulation and FPGA hardware
#
# Targets:
#   sim             — build and run Verilator simulation
#   a2gx            — synthesize for Arria II GX development kit (requires Quartus)
#   a2gxhsmc        — synthesize A2GX with PCI/HDMI HSMC pin assignments
#   a5gx            — synthesize for Arria V GX starter kit (requires Quartus)
#   a2gx prog       — program the A2GX board via JTAG
#   a2gx sta        — run A2GX static timing analysis
#   a2gx lint       — Verilator lint check on A2GX wrapper
#   a2gx clean      — remove A2GX build artifacts
#   clean           — remove sim and FPGA build artifacts

FPGA_TARGETS := a2gx a2gxhsmc a5gx
FPGA_COMMANDS := build prog sta lint clean
SELECTED_FPGA := $(firstword $(filter $(FPGA_TARGETS),$(MAKECMDGOALS)))
FPGA_COMMAND_GOALS := $(filter $(FPGA_COMMANDS),$(filter-out $(FPGA_TARGETS),$(MAKECMDGOALS)))
FPGA_COMMAND_EXAMPLE := $(if $(FPGA_COMMAND_GOALS),$(FPGA_COMMAND_GOALS),build)

A2GX_PROJECT_DIR := fpga/a2gx
A2GX_PROJECT := a2gx_mistvga
A2GX_BUILD_DIR := build/a2gx
A2GX_SOF := $(A2GX_BUILD_DIR)/$(A2GX_PROJECT).sof

A2GX_SHARED_RTL_SOURCES = \
	rtl/pci_vga_bridge.sv \
	rtl/a2gx_mistvga_pll.v \
	rtl/a2gx_pci_clk_pll.v \
	rtl/a2gx_i2c_write_wdata.v \
	rtl/a2gx_i2c_controller.v \
	rtl/a2gx_i2c_hdmi_config.v \
	rtl/dac_6bpc_to_8bpc.v \
	rtl/vga.v \
	rtl/dpram_difclk.v

A2GX_RTL_SOURCES = \
	$(A2GX_PROJECT_DIR)/a2gx_mistvga_top.sv \
	$(A2GX_SHARED_RTL_SOURCES)

A2GX_PROJECT_FILES = \
	$(A2GX_PROJECT_DIR)/$(A2GX_PROJECT).qpf \
	$(A2GX_PROJECT_DIR)/$(A2GX_PROJECT).qsf \
	$(A2GX_PROJECT_DIR)/$(A2GX_PROJECT).sdc

A2GX_ROMHEX := $(A2GX_PROJECT_DIR)/boot1.hex

A2GXHSMC_PROJECT_DIR := fpga/a2gxhsmc
A2GXHSMC_PROJECT := a2gxhsmc_mistvga
A2GXHSMC_BUILD_DIR := build/a2gxhsmc
A2GXHSMC_SOF := $(A2GXHSMC_BUILD_DIR)/$(A2GXHSMC_PROJECT).sof

A2GXHSMC_RTL_SOURCES = \
	$(A2GXHSMC_PROJECT_DIR)/a2gx_mistvga_top.sv \
	$(A2GX_SHARED_RTL_SOURCES)

A2GXHSMC_PROJECT_FILES = \
	$(A2GXHSMC_PROJECT_DIR)/$(A2GXHSMC_PROJECT).qpf \
	$(A2GXHSMC_PROJECT_DIR)/$(A2GXHSMC_PROJECT).qsf \
	$(A2GXHSMC_PROJECT_DIR)/$(A2GXHSMC_PROJECT).sdc

A2GXHSMC_ROMHEX := $(A2GXHSMC_PROJECT_DIR)/boot1.hex

A5GX_PROJECT_DIR := fpga/a5gx
A5GX_PROJECT := a5gx_mistvga
A5GX_BUILD_DIR := build/a5gx
A5GX_SOF := $(A5GX_BUILD_DIR)/$(A5GX_PROJECT).sof

A5GX_RTL_SOURCES = \
	$(A5GX_PROJECT_DIR)/a5gx_mistvga_top.sv \
	rtl/a5gx_ssram_pll.v \
	rtl/ascal_1080p.sv \
	rtl/flying_toasters_overlay.sv \
	rtl/flying_toasters_sprite.mem \
	rtl/ascal_ssram_bridge.sv \
	rtl/pci_vga_bridge.sv \
	rtl/dac_6bpc_to_8bpc.v \
	rtl/vga.v \
	rtl/dpram_difclk.v \
	/home/ian/pulled/ao486_MiSTer/sys/ascal.vhd \
	$(A5GX_PROJECT_DIR)/ip/ssram/submodules/memory_ssram.v \
	$(A5GX_PROJECT_DIR)/ip/ssram/submodules/altera_tristate_controller_translator.sv \
	$(A5GX_PROJECT_DIR)/ip/ssram/submodules/altera_merlin_slave_translator.sv \
	$(A5GX_PROJECT_DIR)/ip/ssram/submodules/altera_tristate_controller_aggregator.sv

A5GX_PROJECT_FILES = \
	$(A5GX_PROJECT_DIR)/$(A5GX_PROJECT).qpf \
	$(A5GX_PROJECT_DIR)/$(A5GX_PROJECT).qsf \
	$(A5GX_PROJECT_DIR)/$(A5GX_PROJECT).sdc

A5GX_ROMHEX := $(A5GX_PROJECT_DIR)/boot1.hex

ifeq ($(SELECTED_FPGA),a2gx)
FPGA_PROJECT_DIR := $(A2GX_PROJECT_DIR)
FPGA_PROJECT := $(A2GX_PROJECT)
FPGA_SOF := $(A2GX_SOF)
endif
ifeq ($(SELECTED_FPGA),a2gxhsmc)
FPGA_PROJECT_DIR := $(A2GXHSMC_PROJECT_DIR)
FPGA_PROJECT := $(A2GXHSMC_PROJECT)
FPGA_SOF := $(A2GXHSMC_SOF)
endif
ifeq ($(SELECTED_FPGA),a5gx)
FPGA_PROJECT_DIR := $(A5GX_PROJECT_DIR)
FPGA_PROJECT := $(A5GX_PROJECT)
FPGA_SOF := $(A5GX_SOF)
endif

.PHONY: all sim $(FPGA_TARGETS) build prog lint sta clean clean-a2gx clean-a2gxhsmc clean-a5gx require-fpga

all: sim

sim:
	$(MAKE) -C sim

ifeq ($(FPGA_COMMAND_GOALS),)
$(FPGA_TARGETS): build
else
$(FPGA_TARGETS):
	@:
endif

build: require-fpga $(FPGA_SOF)

require-fpga:
	@if [ -z "$(SELECTED_FPGA)" ]; then \
		echo "Select an FPGA target, for example: make a2gx $(FPGA_COMMAND_EXAMPLE)"; \
		exit 2; \
	fi

$(A2GX_ROMHEX): vgabios/boot1.rom vgabios/patch_rom.py
	python3 vgabios/patch_rom.py vgabios/boot1.rom $(A2GX_ROMHEX)

$(A2GX_SOF): $(A2GX_PROJECT_FILES) $(A2GX_RTL_SOURCES) $(A2GX_ROMHEX)
	cd $(A2GX_PROJECT_DIR) && quartus_sh --flow compile $(A2GX_PROJECT)

$(A2GXHSMC_ROMHEX): vgabios/boot1.rom vgabios/patch_rom.py
	python3 vgabios/patch_rom.py vgabios/boot1.rom $(A2GXHSMC_ROMHEX)

$(A2GXHSMC_SOF): $(A2GXHSMC_PROJECT_FILES) $(A2GXHSMC_RTL_SOURCES) $(A2GXHSMC_ROMHEX)
	cd $(A2GXHSMC_PROJECT_DIR) && quartus_sh --flow compile $(A2GXHSMC_PROJECT)

$(A5GX_ROMHEX): vgabios/boot1.rom vgabios/patch_rom.py
	python3 vgabios/patch_rom.py vgabios/boot1.rom $(A5GX_ROMHEX)

$(A5GX_SOF): $(A5GX_PROJECT_FILES) $(A5GX_RTL_SOURCES) $(A5GX_ROMHEX)
	cd $(A5GX_PROJECT_DIR) && quartus_sh --flow compile $(A5GX_PROJECT)

prog: require-fpga $(FPGA_SOF)
	quartus_pgm -m jtag -o "p;$(FPGA_SOF)" -c 1

sta: require-fpga
	cd $(FPGA_PROJECT_DIR) && quartus_sta $(FPGA_PROJECT)

lint: require-fpga
ifeq ($(SELECTED_FPGA),a5gx)
	@echo "No Verilator lint target for a5gx; Quartus analyzes the mixed VHDL/SystemVerilog project."
else
	$(MAKE) -C sim lint-$(SELECTED_FPGA)
endif

ifeq ($(SELECTED_FPGA),a2gx)
clean: clean-a2gx
else ifeq ($(SELECTED_FPGA),a2gxhsmc)
clean: clean-a2gxhsmc
else ifeq ($(SELECTED_FPGA),a5gx)
clean: clean-a5gx
else
clean:
	$(MAKE) -C sim clean
	$(MAKE) clean-a2gx
	$(MAKE) clean-a2gxhsmc
	$(MAKE) clean-a5gx
	rm -rf build
endif

clean-a2gx:
	rm -rf $(A2GX_BUILD_DIR)
	rm -rf $(A2GX_PROJECT_DIR)/db $(A2GX_PROJECT_DIR)/incremental_db
	rm -rf $(A2GX_PROJECT_DIR)/*.rpt $(A2GX_PROJECT_DIR)/*.summary
	rm -rf $(A2GX_PROJECT_DIR)/*.done $(A2GX_PROJECT_DIR)/*.jdi
	rm -rf $(A2GX_PROJECT_DIR)/*.qws $(A2GX_PROJECT_DIR)/greybox_tmp

clean-a2gxhsmc:
	rm -rf $(A2GXHSMC_BUILD_DIR)
	rm -rf $(A2GXHSMC_PROJECT_DIR)/db $(A2GXHSMC_PROJECT_DIR)/incremental_db
	rm -rf $(A2GXHSMC_PROJECT_DIR)/*.rpt $(A2GXHSMC_PROJECT_DIR)/*.summary
	rm -rf $(A2GXHSMC_PROJECT_DIR)/*.done $(A2GXHSMC_PROJECT_DIR)/*.jdi
	rm -rf $(A2GXHSMC_PROJECT_DIR)/*.qws $(A2GXHSMC_PROJECT_DIR)/greybox_tmp

clean-a5gx:
	rm -rf $(A5GX_BUILD_DIR)
	rm -rf $(A5GX_PROJECT_DIR)/db $(A5GX_PROJECT_DIR)/incremental_db
	rm -rf $(A5GX_PROJECT_DIR)/*.rpt $(A5GX_PROJECT_DIR)/*.summary
	rm -rf $(A5GX_PROJECT_DIR)/*.done $(A5GX_PROJECT_DIR)/*.jdi
	rm -rf $(A5GX_PROJECT_DIR)/*.qws $(A5GX_PROJECT_DIR)/greybox_tmp
