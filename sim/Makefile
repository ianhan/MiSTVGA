# MiST VGA Simulation Makefile (Verilator)

JOBS ?= 8
TRACE ?= 0

SIM_DIR  := $(CURDIR)
RTL_DIR  := $(SIM_DIR)/../rtl
BUILD_DIR := $(SIM_DIR)/obj_dir
TARGET   := $(SIM_DIR)/vga_sim
BRIDGE_BUILD_DIR := $(SIM_DIR)/obj_dir_bridge
BRIDGE_TARGET := $(SIM_DIR)/pci_bridge_sim

RTL_SOURCES := \
	$(RTL_DIR)/dac_6bpc_to_8bpc.v \
	$(RTL_DIR)/vga.v \
	$(RTL_DIR)/dpram_difclk.v \
	$(SIM_DIR)/vga_sim_top.sv

CPP_SOURCES := \
	$(SIM_DIR)/main.cpp

SDL_CFLAGS := $(shell pkg-config --cflags sdl2 2>/dev/null || echo "-I/usr/include/SDL2")

VERILATOR_FLAGS := \
	--cc \
	--exe \
	--build \
	-j $(JOBS) \
	-Wall \
	-Wno-WIDTHTRUNC \
	-Wno-WIDTHEXPAND \
	-Wno-CASEINCOMPLETE \
	-Wno-UNUSEDSIGNAL \
	-Wno-UNUSEDPARAM \
	-Wno-UNOPTFLAT \
	-Wno-BLKSEQ \
	-Wno-INITIALDLY \
	-Wno-LATCH \
	-Wno-MULTIDRIVEN \
	-Wno-GENUNNAMED \
	-Wno-PINCONNECTEMPTY \
	--top-module vga_sim_top \
	-Mdir $(BUILD_DIR) \
	-o $(TARGET) \
	-CFLAGS "-I$(SIM_DIR) $(SDL_CFLAGS)"

BRIDGE_RTL_SOURCES := \
	$(RTL_DIR)/pci_vga_bridge.sv \
	$(SIM_DIR)/pci_bridge_test_top.sv

BRIDGE_CPP_SOURCES := \
	$(SIM_DIR)/pci_bridge_main.cpp

BRIDGE_VERILATOR_FLAGS := \
	--cc \
	--exe \
	--build \
	-j $(JOBS) \
	-Wall \
	-Wno-WIDTHTRUNC \
	-Wno-WIDTHEXPAND \
	-Wno-CASEINCOMPLETE \
	-Wno-UNUSEDSIGNAL \
	-Wno-UNUSEDPARAM \
	-Wno-UNOPTFLAT \
	-Wno-BLKSEQ \
	-Wno-INITIALDLY \
	-Wno-LATCH \
	-Wno-MULTIDRIVEN \
	-Wno-GENUNNAMED \
	-Wno-PINCONNECTEMPTY \
	--top-module pci_bridge_test_top \
	-Mdir $(BRIDGE_BUILD_DIR) \
	-o $(BRIDGE_TARGET) \
	-CFLAGS "-I$(SIM_DIR)"

ifeq ($(TRACE),1)
VERILATOR_FLAGS += --trace -CFLAGS -DTRACE
endif

all: $(TARGET)

$(TARGET): $(RTL_SOURCES) $(CPP_SOURCES) $(SIM_DIR)/font8x16.h
	verilator $(VERILATOR_FLAGS) $(RTL_SOURCES) $(CPP_SOURCES)

$(BRIDGE_TARGET): $(BRIDGE_RTL_SOURCES) $(BRIDGE_CPP_SOURCES)
	verilator $(BRIDGE_VERILATOR_FLAGS) $(BRIDGE_RTL_SOURCES) $(BRIDGE_CPP_SOURCES)

run: $(TARGET)
	$(TARGET)

bridge-run: $(BRIDGE_TARGET)
	$(BRIDGE_TARGET)

trace: TRACE=1
trace: clean $(TARGET)
	$(TARGET)
	@echo "VCD trace: vga_sim.vcd"

clean:
	rm -rf $(BUILD_DIR) $(BRIDGE_BUILD_DIR) $(TARGET) $(BRIDGE_TARGET) vga_sim.vcd

# Lint the a2gx hardware wrapper (no C++, just syntax/elaboration check)
A2GX_SOURCES := \
	$(RTL_DIR)/dac_6bpc_to_8bpc.v \
	$(RTL_DIR)/vga.v \
	$(RTL_DIR)/dpram_difclk.v \
	$(RTL_DIR)/pci_vga_bridge.sv \
	$(RTL_DIR)/a2gx_mistvga_top.sv

lint-a2gx:
	verilator --lint-only -Wall \
		-Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-CASEINCOMPLETE \
		-Wno-UNUSEDSIGNAL -Wno-UNUSEDPARAM -Wno-UNOPTFLAT \
		-Wno-BLKSEQ -Wno-INITIALDLY -Wno-LATCH -Wno-MULTIDRIVEN \
		-Wno-GENUNNAMED -Wno-PINCONNECTEMPTY -Wno-DECLFILENAME \
		--top-module a2gx_mistvga_top \
		$(A2GX_SOURCES) $(SIM_DIR)/a2gx_stubs.v

.PHONY: all run bridge-run trace clean lint-a2gx
