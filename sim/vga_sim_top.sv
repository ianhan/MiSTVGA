// VGA simulation top for Verilator
// Wraps the ao486-derived vga.v with simulation-friendly ports.
`default_nettype none

module vga_sim_top (
    input  wire        clk_sys,
    input  wire        clk_vga,
    input  wire        rst_n,

    // IO bus
    input  wire [3:0]  io_address,
    input  wire        io_read,
    output wire [7:0]  io_readdata,
    input  wire        io_write,
    input  wire [7:0]  io_writedata,
    input  wire        io_b_cs,
    input  wire        io_c_cs,
    input  wire        io_d_cs,

    // Memory bus
    input  wire [16:0] mem_address,
    input  wire        mem_read,
    output wire [7:0]  mem_readdata,
    input  wire        mem_write,
    input  wire [7:0]  mem_writedata,

    // VGA clock rate
    input  wire [27:0] clock_rate_vga,

    // VGA outputs
    output wire        vga_ce,
    output wire        vga_blank_n,
    output wire        vga_horiz_sync,
    output wire        vga_vert_sync,
    output wire [7:0]  vga_r,
    output wire [7:0]  vga_g,
    output wire [7:0]  vga_b,

    // Status
    output wire        irq
);

    vga u_vga (
        .clk_sys        (clk_sys),
        .rst_n          (rst_n),

        .io_address     (io_address),
        .io_read        (io_read),
        .io_readdata    (io_readdata),
        .io_write       (io_write),
        .io_writedata   (io_writedata),
        .io_b_cs        (io_b_cs),
        .io_c_cs        (io_c_cs),
        .io_d_cs        (io_d_cs),

        .mem_address    (mem_address),
        .mem_read       (mem_read),
        .mem_readdata   (mem_readdata),
        .mem_write      (mem_write),
        .mem_writedata  (mem_writedata),

        .irq            (irq),

        .clk_vga        (clk_vga),
        .clock_rate_vga (clock_rate_vga),

        .vga_ce         (vga_ce),
        .vga_f60        (1'b0),
        .vga_blank_n    (vga_blank_n),
        .vga_off        (),
        .vga_horiz_sync (vga_horiz_sync),
        .vga_vert_sync  (vga_vert_sync),
        .vga_r          (vga_r),
        .vga_g          (vga_g),
        .vga_b          (vga_b),

        .vga_memmode    (),
        .vga_pal_d      (),
        .vga_pal_a      (),
        .vga_pal_we     (),
        .vga_border_color(),
        .vga_start_addr (),
        .vga_wr_seg     (),
        .vga_rd_seg     (),
        .vga_width      (),
        .vga_stride     (),
        .vga_height     (),
        .vga_flags      (),

        .vga_lores      (1'b0),
        .vga_border     (1'b1)
    );

endmodule
