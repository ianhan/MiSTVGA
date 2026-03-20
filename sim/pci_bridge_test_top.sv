`default_nettype none

module pci_bridge_test_top (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        host_ad_drive,
    input  wire [31:0] host_ad_out,
    output wire [31:0] host_ad_in,

    input  wire [3:0]  host_cben_out,
    input  wire        host_frame_n_out,
    input  wire        host_irdy_n_out,
    input  wire        host_idsel,

    output wire        host_trdy_n_in,
    output wire        host_devsel_n_in,
    output wire        host_stop_n_in,
    output wire        host_par_in,
    output wire        host_par_oe_in,
    output wire        pci_config_not_done,

    output wire [7:0]  io_c_4,
    output wire [7:0]  io_c_5,
    output wire [7:0]  io_c_6,
    output wire [7:0]  mem_18000,
    output wire [7:0]  mem_18001,
    output wire [7:0]  mem_18002,
    output wire [7:0]  mem_18003
);

    tri [31:0] pci_ad;
    tri  [3:0] pci_cben;
    tri        pci_frame_n;
    tri        pci_irdy_n;
    tri        pci_trdy_n;
    tri        pci_devsel_n;
    tri        pci_stop_n;
    tri        pci_perr_n;
    tri        pci_serr_n;
    tri        pci_par;
    tri        pci_inta_n;
    tri        pci_lock_n;

    assign pci_ad = host_ad_drive ? host_ad_out : 32'bz;
    assign host_ad_in = pci_ad;

    assign pci_cben = host_cben_out;
    assign pci_frame_n = host_frame_n_out;
    assign pci_irdy_n = host_irdy_n_out;

    assign host_trdy_n_in = pci_trdy_n;
    assign host_devsel_n_in = pci_devsel_n;
    assign host_stop_n_in = pci_stop_n;
    assign host_par_in = pci_par;

    wire [3:0]  io_address;
    wire        io_read;
    reg  [7:0]  io_readdata;
    wire        io_write;
    wire [7:0]  io_writedata;
    wire        io_b_cs;
    wire        io_c_cs;
    wire        io_d_cs;

    wire [16:0] mem_address;
    wire        mem_read;
    reg  [7:0]  mem_readdata;
    wire        mem_write;
    wire [7:0]  mem_writedata;

    reg [7:0] io_b_space [0:15];
    reg [7:0] io_c_space [0:15];
    reg [7:0] io_d_space [0:15];
    reg [7:0] mem_space [0:131071];

    reg io_b_read_last;
    reg io_c_read_last;
    reg io_d_read_last;
    reg mem_read_last;
    reg [7:0] dac_read_counter;

    wire io_b_read = io_read & io_b_cs;
    wire io_c_read = io_read & io_c_cs;
    wire io_d_read = io_read & io_d_cs;

    wire io_b_read_valid = io_b_read & ~io_b_read_last;
    wire io_c_read_valid = io_c_read & ~io_c_read_last;
    wire io_d_read_valid = io_d_read & ~io_d_read_last;
    wire mem_read_valid = mem_read & ~mem_read_last;

    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            io_b_space[i] = 8'h00;
            io_c_space[i] = 8'h00;
            io_d_space[i] = 8'h00;
        end
        for (i = 0; i < 131072; i = i + 1) begin
            mem_space[i] = 8'h00;
        end
        io_readdata = 8'h00;
        mem_readdata = 8'h00;
        io_b_read_last = 1'b0;
        io_c_read_last = 1'b0;
        io_d_read_last = 1'b0;
        mem_read_last = 1'b0;
        dac_read_counter = 8'h10;
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            io_readdata <= 8'h00;
            mem_readdata <= 8'h00;
            io_b_read_last <= 1'b0;
            io_c_read_last <= 1'b0;
            io_d_read_last <= 1'b0;
            mem_read_last <= 1'b0;
            dac_read_counter <= 8'h10;
        end else begin
            if (io_b_read_last) io_b_read_last <= 1'b0;
            else                io_b_read_last <= io_b_read;

            if (io_c_read_last) io_c_read_last <= 1'b0;
            else                io_c_read_last <= io_c_read;

            if (io_d_read_last) io_d_read_last <= 1'b0;
            else                io_d_read_last <= io_d_read;

            if (mem_read_last) mem_read_last <= 1'b0;
            else               mem_read_last <= mem_read;

            if (io_write) begin
                if (io_b_cs) io_b_space[io_address] <= io_writedata;
                if (io_c_cs) io_c_space[io_address] <= io_writedata;
                if (io_d_cs) io_d_space[io_address] <= io_writedata;
            end

            if (mem_write) begin
                mem_space[mem_address] <= mem_writedata;
            end

            if (io_b_read_valid) begin
                io_readdata <= io_b_space[io_address];
            end else if (io_c_read_valid) begin
                if (io_address == 4'h9) begin
                    io_readdata <= dac_read_counter;
                    dac_read_counter <= dac_read_counter + 8'h01;
                end else begin
                    io_readdata <= io_c_space[io_address];
                end
            end else if (io_d_read_valid) begin
                io_readdata <= io_d_space[io_address];
            end

            if (mem_read_valid) begin
                mem_readdata <= mem_space[mem_address];
            end
        end
    end

    assign io_c_4 = io_c_space[4];
    assign io_c_5 = io_c_space[5];
    assign io_c_6 = io_c_space[6];
    assign mem_18000 = mem_space[17'h18000];
    assign mem_18001 = mem_space[17'h18001];
    assign mem_18002 = mem_space[17'h18002];
    assign mem_18003 = mem_space[17'h18003];

    pci_vga_bridge #(
        .ROM_FILE("../fpga/boot1.hex")
    ) u_bridge (
        .pci_enable_n        (),
        .pci_ad              (pci_ad),
        .pci_cben            (pci_cben),
        .pci_req_n           (),
        .pci_gnt_n           (1'b1),
        .pci_inta_n          (pci_inta_n),
        .pci_idsel           (host_idsel),
        .pci_frame_n         (pci_frame_n),
        .pci_irdy_n          (pci_irdy_n),
        .pci_rst_n           (rst_n),
        .pci_clk             (clk),
        .pci_trdy_n          (pci_trdy_n),
        .pci_perr_n          (pci_perr_n),
        .pci_devsel_n        (pci_devsel_n),
        .pci_stop_n          (pci_stop_n),
        .pci_serr_n          (pci_serr_n),
        .pci_par             (pci_par),
        .pci_lock_n          (pci_lock_n),
        .pci_config_not_done (pci_config_not_done),

        .io_address          (io_address),
        .io_read             (io_read),
        .io_readdata         (io_readdata),
        .io_write            (io_write),
        .io_writedata        (io_writedata),
        .io_b_cs             (io_b_cs),
        .io_c_cs             (io_c_cs),
        .io_d_cs             (io_d_cs),

        .mem_address         (mem_address),
        .mem_read            (mem_read),
        .mem_readdata        (mem_readdata),
        .mem_write           (mem_write),
        .mem_writedata       (mem_writedata),

        .led_debug           ()
    );

    assign host_par_oe_in = u_bridge.pci_par_oe;

endmodule
