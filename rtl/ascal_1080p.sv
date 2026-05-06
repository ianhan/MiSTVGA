// Readable SystemVerilog wrapper around the external VHDL ASCAL scaler core.
`default_nettype none

module ascal_1080p (
    input  wire         reset_na,

    input  wire         i_clk,
    input  wire         i_ce,
    input  wire [7:0]   i_r,
    input  wire [7:0]   i_g,
    input  wire [7:0]   i_b,
    input  wire         i_hs,
    input  wire         i_vs,
    input  wire         i_de,

    input  wire         o_clk,
    input  wire         o_ce,
    output wire [7:0]   o_r,
    output wire [7:0]   o_g,
    output wire [7:0]   o_b,
    output wire         o_hs,
    output wire         o_vs,
    output wire         o_de,

    input  wire         avl_clk,
    input  wire         avl_waitrequest,
    input  wire [127:0] avl_readdata,
    input  wire         avl_readdatavalid,
    output wire [7:0]   avl_burstcount,
    output wire [127:0] avl_writedata,
    output wire [18:0]  avl_address,
    output wire         avl_write,
    output wire         avl_read,
    output wire [15:0]  avl_byteenable
);
    localparam [7:0]   SCALER_MASK          = 8'h03;
    localparam [31:0]  FRAMEBUFFER_BASE     = 32'h0000_0000;
    localparam [31:0]  FRAMEBUFFER_SIZE     = 32'h0020_0000;
    localparam int     FRACTION_BITS        = 8;
    localparam int     MAX_OUTPUT_HRES      = 2048;
    localparam int     MAX_INPUT_HRES       = 1024;
    localparam int     AVALON_DATA_WIDTH    = 128;
    localparam int     AVALON_ADDRESS_WIDTH = 19;
    localparam int     AVALON_BURST_BYTES   = 256;

    localparam int     HDMI_HTOTAL          = 2200;
    localparam int     HDMI_HSSTART         = 2008;
    localparam int     HDMI_HSEND           = 2052;
    localparam int     HDMI_HDISP           = 1920;
    localparam int     HDMI_HMIN            = 240;
    localparam int     HDMI_HMAX            = 1679;
    localparam int     HDMI_VTOTAL          = 1125;
    localparam int     HDMI_VSSTART         = 1084;
    localparam int     HDMI_VSEND           = 1089;
    localparam int     HDMI_VDISP           = 1080;
    localparam int     HDMI_VMIN            = 0;
    localparam int     HDMI_VMAX            = 1079;

    localparam [4:0]   SCALE_MODE_BILINEAR  = 5'd0;
    localparam [1:0]   SCALE_FORMAT_16BPP   = 2'd0;
    localparam [5:0]   FRAMEBUFFER_FORMAT   = 6'd4;

    ascal #(
        .MASK(SCALER_MASK),
        .RAMBASE(FRAMEBUFFER_BASE),
        .RAMSIZE(FRAMEBUFFER_SIZE),
        .INTER("true"),
        .HEADER("true"),
        .DOWNSCALE("true"),
        .BYTESWAP("true"),
        .PALETTE("false"),
        .PALETTE2("false"),
        .ADAPTIVE("false"),
        .FRAC(FRACTION_BITS),
        .OHRES(MAX_OUTPUT_HRES),
        .IHRES(MAX_INPUT_HRES),
        .N_DW(AVALON_DATA_WIDTH),
        .N_AW(AVALON_ADDRESS_WIDTH),
        .N_BURST(AVALON_BURST_BYTES)
    ) u_ascal (
        .i_r(i_r),
        .i_g(i_g),
        .i_b(i_b),
        .i_hs(i_hs),
        .i_vs(i_vs),
        .i_fl(1'b0),
        .i_de(i_de),
        .i_ce(i_ce),
        .i_clk(i_clk),

        .o_r(o_r),
        .o_g(o_g),
        .o_b(o_b),
        .o_hs(o_hs),
        .o_vs(o_vs),
        .o_de(o_de),
        .o_vbl(),
        .o_brd(),
        .o_ce(o_ce),
        .o_clk(o_clk),

        .o_border(24'd0),
        .o_fb_ena(1'b0),
        .o_fb_hsize(0),
        .o_fb_vsize(0),
        .o_fb_format(FRAMEBUFFER_FORMAT),
        .o_fb_base(32'd0),
        .o_fb_stride(14'd0),

        .pal1_clk(i_clk),
        .pal1_dw(48'd0),
        .pal1_dr(),
        .pal1_a(7'd0),
        .pal1_wr(1'b0),
        .pal_n(1'b0),
        .pal2_clk(i_clk),
        .pal2_dw(24'd0),
        .pal2_dr(),
        .pal2_a(8'd0),
        .pal2_wr(1'b0),

        .o_lltune(),

        .iauto(1'b1),
        .himin(0),
        .himax(0),
        .vimin(0),
        .vimax(0),
        .i_hdmax(),
        .i_vdmax(),

        .run(1'b1),
        .freeze(1'b0),
        .mode(SCALE_MODE_BILINEAR),
        .bob_deint(1'b0),

        .htotal(HDMI_HTOTAL),
        .hsstart(HDMI_HSSTART),
        .hsend(HDMI_HSEND),
        .hdisp(HDMI_HDISP),
        .hmin(HDMI_HMIN),
        .hmax(HDMI_HMAX),
        .vtotal(HDMI_VTOTAL),
        .vsstart(HDMI_VSSTART),
        .vsend(HDMI_VSEND),
        .vdisp(HDMI_VDISP),
        .vmin(HDMI_VMIN),
        .vmax(HDMI_VMAX),
        .vrr(1'b0),
        .vrrmax(0),
        .swblack(1'b0),
        .format(SCALE_FORMAT_16BPP),

        .poly_clk(i_clk),
        .poly_dw(10'd0),
        .poly_a(12'd0),
        .poly_wr(1'b0),

        .avl_clk(avl_clk),
        .avl_waitrequest(avl_waitrequest),
        .avl_readdata(avl_readdata),
        .avl_readdatavalid(avl_readdatavalid),
        .avl_burstcount(avl_burstcount),
        .avl_writedata(avl_writedata),
        .avl_address(avl_address),
        .avl_write(avl_write),
        .avl_read(avl_read),
        .avl_byteenable(avl_byteenable),

        .reset_na(reset_na)
    );
endmodule

`default_nettype wire
