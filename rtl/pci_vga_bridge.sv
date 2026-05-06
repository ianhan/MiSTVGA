// PCI target bridge for ao486-style VGA module (vga.v)
//
// Decodes PCI I/O and memory cycles and translates them to
// vga.v's Avalon-like bus interface.
//
`default_nettype none

module pci_vga_bridge (
    // PCI bus
    output            pci_enable_n,
    inout      [31:0] pci_ad,
    inout       [3:0] pci_cben,
    output            pci_req_n,
    input             pci_gnt_n,
    inout             pci_inta_n,
    input             pci_idsel,
    inout             pci_frame_n,
    inout             pci_irdy_n,
    input             pci_rst_n,
    input             pci_clk,
    inout             pci_trdy_n,
    inout             pci_perr_n,
    inout             pci_devsel_n,
    inout             pci_stop_n,
    inout             pci_serr_n,
    inout             pci_par,
    inout             pci_lock_n,
    output            pci_config_not_done,

    // vga.v Avalon-like IO bus (active on pci_clk)
    output reg  [3:0] io_address,
    output reg        io_read,
    input       [7:0] io_readdata,
    output reg        io_write,
    output reg  [7:0] io_writedata,
    output reg        io_b_cs,
    output reg        io_c_cs,
    output reg        io_d_cs,

    // vga.v Avalon-like memory bus (active on pci_clk)
    output reg [16:0] mem_address,
    output reg        mem_read,
    input       [7:0] mem_readdata,
    output reg        mem_write,
    output reg  [7:0] mem_writedata,

    output reg        debug_display_mode,
    output reg        scaler_filter_disabled,
    output reg  [2:0] led_debug
);

    parameter DEVICE_ID = 16'h3d00;
    parameter VENDOR_ID = 16'h3d3d;
    parameter DEVICE_CLASS = 24'h030000;
    parameter DEVICE_REV = 8'h01;
    parameter SUBSYSTEM_ID = 16'h0001;
    parameter SUBSYSTEM_VENDOR_ID = 16'hBEBE;
    parameter DEVSEL_TIMING = 2'b00;
    parameter ROM_FILE = "boot1.hex";

    // PCI infrastructure

    assign pci_enable_n = 1'b0;
    assign pci_req_n = 1'b1;

    localparam EN_NONE = 2'd0;
    localparam EN_RD   = 2'd1;
    localparam EN_WR   = 2'd2;
    localparam EN_TR   = 2'd3;

    localparam ST_IDLE          = 5'd0;
    localparam ST_BUSY          = 5'd1;
    localparam ST_CFGREAD       = 5'd2;
    localparam ST_CFGWRITE      = 5'd3;
    localparam ST_IOWRITE       = 5'd4;
    localparam ST_IOWRITE_CONT  = 5'd5;
    localparam ST_IOREAD        = 5'd6;
    localparam ST_IO_WAIT       = 5'd7;
    localparam ST_IO_CAPTURE    = 5'd8;
    localparam ST_MEMWRITE      = 5'd9;
    localparam ST_MEMWRITE_CONT = 5'd10;
    localparam ST_MEMREAD       = 5'd11;
    localparam ST_MEM_WAIT      = 5'd12;
    localparam ST_MEM_CAPTURE   = 5'd13;
    localparam ST_DONE          = 5'd14;
    localparam ST_TURNAROUND    = 5'd15;
    localparam ST_ROMREAD       = 5'd16;
    localparam ST_ROM_WAIT      = 5'd17;
    localparam ST_STOP_WAIT     = 5'd18;

    localparam IOREAD   = 4'b0010;
    localparam IOWRITE  = 4'b0011;
    localparam MEMREAD  = 4'b0110;
    localparam MEMWRITE = 4'b0111;
    localparam CFGREAD  = 4'b1010;
    localparam CFGWRITE = 4'b1011;
    localparam MEMWRITE_INVALIDATE = 4'b1111;

    localparam [15:0] KB_DATA_PORT = 16'h0060;
    localparam [7:0]  KB_LED_CMD   = 8'hED;

    reg [4:0]  state;
    reg [31:0] data;
    reg [31:0] ioaddr;
    reg [1:0]  enable;

    reg        ioen;
    reg        memen;
    reg [7:0]  baseaddr;
    reg [17:0] address;

    reg [31:0] write_data_latched;
    reg [31:0] data_accum;
    reg  [3:0] byte_mask;
    reg  [1:0] current_lane;
    reg [31:0] snoop_ioaddr;
    reg        snoop_transaction_active;
    reg        snoop_iowrite_pending;
    reg        kb_led_update_pending;

    // ROM BAR (PCI config offset 0x30)
    reg [31:0] rom_mem [0:8191];  // 8K x 32 = 32 KB
    initial $readmemh(ROM_FILE, rom_mem);

    reg [16:0] rom_base;    // ROM BAR bits [31:15]
    reg        rom_enable;  // ROM BAR bit [0]
    reg [31:0] rom_rdata;   // registered BRAM read output
    reg        pci_par_out;
    reg        pci_par_oe;

    assign pci_ad = (enable == EN_RD) ? data : 32'bZ;
    assign pci_trdy_n = (enable == EN_NONE) ? 1'bZ : (enable == EN_TR ? 1'b1 : 1'b0);
    assign pci_par = pci_par_oe ? pci_par_out : 1'bZ;

    reg devsel_val;
    reg devsel_oe;
    reg disconnect;
    reg stop_wait_pending;

    assign pci_stop_n = (enable == EN_NONE) ? 1'bZ : (disconnect ? 1'b0 : 1'b1);
    assign pci_inta_n = 1'bZ;
    assign pci_lock_n = 1'bZ;
    assign pci_devsel_n = devsel_oe ? devsel_val : 1'bZ;
    assign pci_config_not_done = ~|baseaddr;

    // Config space

    function automatic [31:0] cfg_read_data_word(input [5:0] cfg_addr);
    begin
        case (cfg_addr)
            6'd0:  cfg_read_data_word = {DEVICE_ID, VENDOR_ID};
            6'd1:  cfg_read_data_word = {5'b0, DEVSEL_TIMING, 9'b0, 14'b0, memen, ioen};
            6'd2:  cfg_read_data_word = {DEVICE_CLASS, DEVICE_REV};
            6'd4:  cfg_read_data_word = {12'b0, baseaddr[7:3], 15'b0};
            6'd11: cfg_read_data_word = {SUBSYSTEM_ID, SUBSYSTEM_VENDOR_ID};
            6'd12: cfg_read_data_word = {rom_base, 14'b0, rom_enable};
            default: cfg_read_data_word = 32'h0000_0000;
        endcase
    end
    endfunction

    // Address decode

    wire cfg_hit = ((pci_cben == CFGREAD || pci_cben == CFGWRITE) &&
                    pci_idsel && pci_ad[1:0] == 2'b00);
    wire mem_hit = memen &&
                    ((pci_cben == MEMREAD || pci_cben == MEMWRITE ||
                      pci_cben == MEMWRITE_INVALIDATE) &&
                    (pci_ad[19:17] == 3'b101));
    wire io_hit = ioen &&
                   ((pci_cben == IOREAD || pci_cben == IOWRITE) &&
                   (pci_ad[15:4] == 12'h03B || pci_ad[15:4] == 12'h03C ||
                    pci_ad[15:4] == 12'h03D));
    wire rom_hit = (pci_cben == MEMREAD) && rom_enable && (pci_ad[31:15] == rom_base);

    function automatic [1:0] first_active_lane(input [3:0] active_mask);
    begin
        if (active_mask[0])      first_active_lane = 2'd0;
        else if (active_mask[1]) first_active_lane = 2'd1;
        else if (active_mask[2]) first_active_lane = 2'd2;
        else                     first_active_lane = 2'd3;
    end
    endfunction

    function automatic [3:0] clear_lane(input [3:0] active_mask, input [1:0] lane);
    begin
        clear_lane = active_mask & ~(4'b0001 << lane);
    end
    endfunction

    function automatic [7:0] lane_write_data(input [31:0] write_word, input [1:0] lane);
    begin
        case (lane)
            2'd0: lane_write_data = write_word[7:0];
            2'd1: lane_write_data = write_word[15:8];
            2'd2: lane_write_data = write_word[23:16];
            default: lane_write_data = write_word[31:24];
        endcase
    end
    endfunction

    function automatic [31:0] lane_address(input [31:0] base_word_addr, input [1:0] lane);
    begin
        lane_address = {base_word_addr[31:2], 2'b00} + {30'd0, lane};
    end
    endfunction

    function automatic [31:0] insert_read_byte(
        input [31:0] read_word,
        input [1:0]  lane,
        input [7:0]  read_byte
    );
    begin
        case (lane)
            2'd0: insert_read_byte = {read_word[31:8], read_byte};
            2'd1: insert_read_byte = {read_word[31:16], read_byte, read_word[7:0]};
            2'd2: insert_read_byte = {read_word[31:24], read_byte, read_word[15:0]};
            default: insert_read_byte = {read_byte, read_word[23:0]};
        endcase
    end
    endfunction

    function automatic pci_read_phase_parity(
        input [31:0] read_word,
        input [3:0]  byte_en_n
    );
    begin
        pci_read_phase_parity = ^{read_word, byte_en_n};
    end
    endfunction

    task automatic issue_io_write(input [1:0] lane, input [31:0] write_word);
        reg [31:0] lane_addr;
    begin
        lane_addr = lane_address(ioaddr, lane);
        io_address <= lane_addr[3:0];
        io_writedata <= lane_write_data(write_word, lane);
        io_b_cs <= (lane_addr[15:4] == 12'h03B);
        io_c_cs <= (lane_addr[15:4] == 12'h03C);
        io_d_cs <= (lane_addr[15:4] == 12'h03D);
        io_write <= 1'b1;
    end
    endtask

    task automatic snoop_keyboard_data_write(input [7:0] write_byte);
    begin
        if (kb_led_update_pending) begin
            debug_display_mode <= write_byte[0];
            scaler_filter_disabled <= write_byte[1];
            kb_led_update_pending <= 1'b0;
        end else begin
            kb_led_update_pending <= (write_byte == KB_LED_CMD);
        end
    end
    endtask

    task automatic snoop_iowrite_data_phase;
        reg [31:0] lane_addr;
    begin
        lane_addr = 32'h0000_0000;
        if (!pci_cben[0]) begin
            lane_addr = lane_address(snoop_ioaddr, 2'd0);
            if (lane_addr[15:0] == KB_DATA_PORT) begin
                snoop_keyboard_data_write(pci_ad[7:0]);
            end
        end
        if (!pci_cben[1]) begin
            lane_addr = lane_address(snoop_ioaddr, 2'd1);
            if (lane_addr[15:0] == KB_DATA_PORT) begin
                snoop_keyboard_data_write(pci_ad[15:8]);
            end
        end
        if (!pci_cben[2]) begin
            lane_addr = lane_address(snoop_ioaddr, 2'd2);
            if (lane_addr[15:0] == KB_DATA_PORT) begin
                snoop_keyboard_data_write(pci_ad[23:16]);
            end
        end
        if (!pci_cben[3]) begin
            lane_addr = lane_address(snoop_ioaddr, 2'd3);
            if (lane_addr[15:0] == KB_DATA_PORT) begin
                snoop_keyboard_data_write(pci_ad[31:24]);
            end
        end
    end
    endtask

    task automatic issue_io_read(input [1:0] lane);
        reg [31:0] lane_addr;
    begin
        lane_addr = lane_address(ioaddr, lane);
        io_address <= lane_addr[3:0];
        io_b_cs <= (lane_addr[15:4] == 12'h03B);
        io_c_cs <= (lane_addr[15:4] == 12'h03C);
        io_d_cs <= (lane_addr[15:4] == 12'h03D);
        io_read <= 1'b1;
    end
    endtask

    task automatic issue_mem_write(input [1:0] lane, input [31:0] write_word);
        reg [31:0] lane_addr;
    begin
        lane_addr = lane_address(ioaddr, lane);
        mem_address <= lane_addr[16:0];
        mem_writedata <= lane_write_data(write_word, lane);
        mem_write <= 1'b1;
    end
    endtask

    task automatic issue_mem_read(input [1:0] lane);
        reg [31:0] lane_addr;
    begin
        lane_addr = lane_address(ioaddr, lane);
        mem_address <= lane_addr[16:0];
        mem_read <= 1'b1;
    end
    endtask

    task automatic begin_transaction_from_bus;
    begin
        led_debug <= 3'b000;
        address <= pci_ad[19:2];
        ioaddr <= pci_ad;
        stop_wait_pending <= 1'b0;

        if (cfg_hit) begin
            devsel_oe <= 1'b1;
            devsel_val <= 1'b0;
            if (pci_cben == CFGREAD) begin
                data <= cfg_read_data_word(pci_ad[7:2]);
                address <= pci_ad[19:2] + 18'd1;
                state <= ST_CFGREAD;
                enable <= EN_RD;
            end else begin
                state <= ST_CFGWRITE;
                enable <= EN_WR;
            end
        end else if (rom_hit) begin
            devsel_oe <= 1'b1;
            devsel_val <= 1'b0;
            state <= ST_ROMREAD;
            enable <= EN_TR;
        end else if (mem_hit) begin
            devsel_oe <= 1'b1;
            devsel_val <= 1'b0;
            state <= (pci_cben == MEMREAD) ? ST_MEMREAD : ST_MEMWRITE;
            enable <= EN_TR;
        end else if (io_hit) begin
            devsel_oe <= 1'b1;
            devsel_val <= 1'b0;
            state <= (pci_cben == IOREAD) ? ST_IOREAD : ST_IOWRITE;
            enable <= EN_TR;
        end else begin
            state <= ST_BUSY;
            enable <= EN_NONE;
        end
    end
    endtask

    // State machine

    always @(posedge pci_clk) begin
        if (~pci_rst_n) begin
            state <= ST_IDLE;
            enable <= EN_NONE;
            data <= 32'h0000_0000;
            ioaddr <= 32'h0000_0000;
            baseaddr <= 8'h00;
            address <= 18'd0;
            devsel_oe <= 1'b0;
            devsel_val <= 1'b1;
            ioen <= 1'b0;
            memen <= 1'b0;
            disconnect <= 1'b0;
            stop_wait_pending <= 1'b0;
            write_data_latched <= 32'h0000_0000;
            data_accum <= 32'h0000_0000;
            byte_mask <= 4'b0000;
            current_lane <= 2'd0;
            debug_display_mode <= 1'b0;
            scaler_filter_disabled <= 1'b0;
            snoop_ioaddr <= 32'h0000_0000;
            snoop_transaction_active <= 1'b0;
            snoop_iowrite_pending <= 1'b0;
            kb_led_update_pending <= 1'b0;
            led_debug <= 3'b000;
            rom_base <= 17'd0;
            rom_enable <= 1'b0;
            rom_rdata <= 32'h0000_0000;
            pci_par_out <= 1'b0;
            pci_par_oe <= 1'b0;

            io_address <= 4'h0;
            io_read <= 1'b0;
            io_write <= 1'b0;
            io_writedata <= 8'h00;
            io_b_cs <= 1'b0;
            io_c_cs <= 1'b0;
            io_d_cs <= 1'b0;
            mem_address <= 17'h00000;
            mem_read <= 1'b0;
            mem_write <= 1'b0;
            mem_writedata <= 8'h00;
        end else begin
            // PAR is driven one clock after the target read beat it covers.
            pci_par_oe <= (enable == EN_RD);
            if (enable == EN_RD) begin
                pci_par_out <= pci_read_phase_parity(data, pci_cben);
            end

            // Passive keyboard snoop.  This observes accepted I/O write data
            // beats without widening io_hit or driving any PCI target signals.
            if (pci_frame_n && pci_irdy_n) begin
                snoop_transaction_active <= 1'b0;
                snoop_iowrite_pending <= 1'b0;
            end else if (!snoop_transaction_active && !pci_frame_n && pci_irdy_n) begin
                snoop_transaction_active <= 1'b1;
                snoop_iowrite_pending <= (pci_cben == IOWRITE);
                if (pci_cben == IOWRITE) begin
                    snoop_ioaddr <= pci_ad;
                end
            end else if (snoop_iowrite_pending && !pci_irdy_n && pci_trdy_n == 1'b0) begin
                snoop_iowrite_data_phase();
                snoop_iowrite_pending <= 1'b0;
            end

            // Default: deassert bridge-facing sideband signals unless the
            // current state explicitly issues a bus cycle.
            io_read <= 1'b0;
            io_write <= 1'b0;
            io_b_cs <= 1'b0;
            io_c_cs <= 1'b0;
            io_d_cs <= 1'b0;
            mem_read <= 1'b0;
            mem_write <= 1'b0;

            case (state)
            ST_IDLE: begin
                enable <= EN_NONE;
                devsel_oe <= 1'b0;
                devsel_val <= 1'b1;
                disconnect <= 1'b0;
                if (~pci_frame_n) begin
                    begin_transaction_from_bus();
                end
            end

            ST_BUSY: begin
                devsel_oe <= 1'b0;
                devsel_val <= 1'b1;
                enable <= EN_NONE;
                if (pci_frame_n) begin
                    state <= ST_IDLE;
                end
            end

            // Config space
            ST_CFGREAD: begin
                enable <= EN_RD;
                if (~pci_irdy_n) begin
                    data <= cfg_read_data_word(address[5:0]);
                    address <= address + 18'd1;
                end
                if (pci_frame_n && ~pci_irdy_n) begin
                    devsel_oe <= 1'b1;
                    devsel_val <= 1'b1;
                    state <= ST_TURNAROUND;
                    enable <= EN_TR;
                end
            end

            ST_CFGWRITE: begin
                enable <= EN_WR;
                if (~pci_irdy_n) begin
                    case (address[5:0])
                        6'd4: baseaddr <= pci_ad[19:12];
                        6'd1: begin
                            ioen <= pci_ad[0];
                            memen <= pci_ad[1];
                        end
                        6'd12: begin
                            rom_base <= pci_ad[31:15];
                            rom_enable <= pci_ad[0];
                        end
                        default: ;
                    endcase
                    address <= address + 18'd1;
                    if (pci_frame_n) begin
                        devsel_oe <= 1'b1;
                        devsel_val <= 1'b1;
                        state <= ST_TURNAROUND;
                        enable <= EN_TR;
                    end
                end
            end

            // I/O write: consume each asserted PCI byte lane in order.
            ST_IOWRITE: begin
                if (~pci_irdy_n) begin
                    write_data_latched <= pci_ad;
                    byte_mask <= clear_lane(~pci_cben, first_active_lane(~pci_cben));
                    current_lane <= first_active_lane(clear_lane(~pci_cben, first_active_lane(~pci_cben)));
                    issue_io_write(first_active_lane(~pci_cben), pci_ad);

                    if (clear_lane(~pci_cben, first_active_lane(~pci_cben)) != 4'b0000) begin
                        enable <= EN_TR;
                        state <= ST_IOWRITE_CONT;
                    end else begin
                        enable <= EN_WR;
                        disconnect <= 1'b1;
                        stop_wait_pending <= ~pci_frame_n;
                        state <= ST_DONE;
                    end
                end
            end

            ST_IOWRITE_CONT: begin
                issue_io_write(current_lane, write_data_latched);
                if (clear_lane(byte_mask, current_lane) != 4'b0000) begin
                    byte_mask <= clear_lane(byte_mask, current_lane);
                    current_lane <= first_active_lane(clear_lane(byte_mask, current_lane));
                    enable <= EN_TR;
                end else begin
                    enable <= EN_WR;
                    disconnect <= 1'b1;
                    stop_wait_pending <= ~pci_frame_n;
                    state <= ST_DONE;
                end
            end

            // I/O read: pulse one byte read at a time so vga.v sees exactly one
            // io_*_read_valid event per lane.
            ST_IOREAD: begin
                if (~pci_irdy_n) begin
                    data_accum <= 32'h0000_0000;
                    byte_mask <= ~pci_cben;
                    current_lane <= first_active_lane(~pci_cben);
                    issue_io_read(first_active_lane(~pci_cben));
                    enable <= EN_TR;
                    state <= ST_IO_WAIT;
                end
            end

            ST_IO_WAIT: begin
                state <= ST_IO_CAPTURE;
            end

            ST_IO_CAPTURE: begin
                if (clear_lane(byte_mask, current_lane) != 4'b0000) begin
                    data_accum <= insert_read_byte(data_accum, current_lane, io_readdata);
                    byte_mask <= clear_lane(byte_mask, current_lane);
                    current_lane <= first_active_lane(clear_lane(byte_mask, current_lane));
                    issue_io_read(first_active_lane(clear_lane(byte_mask, current_lane)));
                    enable <= EN_TR;
                    state <= ST_IO_WAIT;
                end else begin
                    data <= insert_read_byte(data_accum, current_lane, io_readdata);
                    enable <= EN_RD;
                    disconnect <= 1'b1;
                    stop_wait_pending <= ~pci_frame_n;
                    state <= ST_DONE;
                end
            end

            // Memory write: same lane walk as I/O writes.
            ST_MEMWRITE: begin
                if (~pci_irdy_n) begin
                    write_data_latched <= pci_ad;
                    byte_mask <= clear_lane(~pci_cben, first_active_lane(~pci_cben));
                    current_lane <= first_active_lane(clear_lane(~pci_cben, first_active_lane(~pci_cben)));
                    issue_mem_write(first_active_lane(~pci_cben), pci_ad);

                    if (clear_lane(~pci_cben, first_active_lane(~pci_cben)) != 4'b0000) begin
                        enable <= EN_TR;
                        state <= ST_MEMWRITE_CONT;
                    end else begin
                        enable <= EN_WR;
                        disconnect <= 1'b1;
                        stop_wait_pending <= ~pci_frame_n;
                        state <= ST_DONE;
                    end
                end
            end

            ST_MEMWRITE_CONT: begin
                issue_mem_write(current_lane, write_data_latched);
                if (clear_lane(byte_mask, current_lane) != 4'b0000) begin
                    byte_mask <= clear_lane(byte_mask, current_lane);
                    current_lane <= first_active_lane(clear_lane(byte_mask, current_lane));
                    enable <= EN_TR;
                end else begin
                    enable <= EN_WR;
                    disconnect <= 1'b1;
                    stop_wait_pending <= ~pci_frame_n;
                    state <= ST_DONE;
                end
            end

            // Memory read: pulse one byte read at a time so mem_read_valid and
            // the VGA host latches advance once per requested lane.
            ST_MEMREAD: begin
                if (~pci_irdy_n) begin
                    data_accum <= 32'h0000_0000;
                    byte_mask <= ~pci_cben;
                    current_lane <= first_active_lane(~pci_cben);
                    issue_mem_read(first_active_lane(~pci_cben));
                    enable <= EN_TR;
                    state <= ST_MEM_WAIT;
                end
            end

            ST_MEM_WAIT: begin
                state <= ST_MEM_CAPTURE;
            end

            ST_MEM_CAPTURE: begin
                if (clear_lane(byte_mask, current_lane) != 4'b0000) begin
                    data_accum <= insert_read_byte(data_accum, current_lane, mem_readdata);
                    byte_mask <= clear_lane(byte_mask, current_lane);
                    current_lane <= first_active_lane(clear_lane(byte_mask, current_lane));
                    issue_mem_read(first_active_lane(clear_lane(byte_mask, current_lane)));
                    enable <= EN_TR;
                    state <= ST_MEM_WAIT;
                end else begin
                    data <= insert_read_byte(data_accum, current_lane, mem_readdata);
                    enable <= EN_RD;
                    disconnect <= 1'b1;
                    stop_wait_pending <= ~pci_frame_n;
                    state <= ST_DONE;
                end
            end

            // ROM read
            ST_ROMREAD: begin
                if (~pci_irdy_n) begin
                    rom_rdata <= rom_mem[ioaddr[14:2]];
                    state <= ST_ROM_WAIT;
                end
            end

            ST_ROM_WAIT: begin
                data <= rom_rdata;
                enable <= EN_RD;
                disconnect <= 1'b1;
                stop_wait_pending <= ~pci_frame_n;
                state <= ST_DONE;
            end

            // Complete PCI transaction
            ST_DONE: begin
                if (stop_wait_pending && !(pci_frame_n && pci_irdy_n)) begin
                    // The accepted beat used target disconnect while the
                    // initiator still had FRAME# asserted.  Hold STOP# until
                    // the initiator terminates the current transaction.
                    devsel_oe <= 1'b1;
                    devsel_val <= 1'b0;
                    enable <= EN_TR;
                    disconnect <= 1'b1;
                    state <= ST_STOP_WAIT;
                end else if (enable != EN_RD && ~pci_frame_n) begin
                    stop_wait_pending <= 1'b0;
                    disconnect <= 1'b0;
                    begin_transaction_from_bus();
                end else begin
                    stop_wait_pending <= 1'b0;
                    disconnect <= 1'b0;
                    devsel_oe <= 1'b1;
                    devsel_val <= 1'b1;
                    enable <= EN_TR;
                    state <= ST_TURNAROUND;
                end
            end

            ST_STOP_WAIT: begin
                devsel_oe <= 1'b1;
                devsel_val <= 1'b0;
                enable <= EN_TR;
                disconnect <= 1'b1;

                if (pci_frame_n && pci_irdy_n) begin
                    stop_wait_pending <= 1'b0;
                    disconnect <= 1'b0;
                    devsel_val <= 1'b1;
                    state <= ST_TURNAROUND;
                end
            end

            ST_TURNAROUND: begin
                enable <= EN_NONE;
                devsel_oe <= 1'b0;
                devsel_val <= 1'b1;
                disconnect <= 1'b0;
                stop_wait_pending <= 1'b0;
                if (~pci_frame_n) begin
                    begin_transaction_from_bus();
                end else begin
                    state <= ST_IDLE;
                end
            end

            default: begin
                state <= ST_IDLE;
            end
            endcase
        end
    end

endmodule
