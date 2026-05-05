// ao486 VGA wrapped for the Stratix IV GX development board.
//
// Uses the board-native ADV7513 HDMI transmitter and PCI on HSMC port B.
// This matches the a2gxhsmc no-scaler video path: PCI VGA core directly to
// parallel RGB HDMI.
`default_nettype none

module sivgx_mistvga_top (
    input  wire        clkin_50,
    input  wire        clkinbot_100_p,
    input  wire        cpu_resetn,

    output wire [15:0] user_led,

    output wire        hdmi_clk,
    output wire [23:0] hdmi_d,
    output wire        hdmi_de,
    output wire        hdmi_hsync,
    output wire [3:0]  hdmi_i2s,
    input  wire        hdmi_intn,
    output wire        hdmi_lrclk,
    output wire        hdmi_mclk,
    output wire        hdmi_scl,
    output wire        hdmi_sclk,
    inout  wire        hdmi_sda,
    output wire        hdmi_spdif,
    output wire        hdmi_vsync,

    output wire        hsmb_rx_led,
    output wire        hsmb_tx_led,

    inout  wire [31:0] lpci_ad,
    inout  wire [3:0]  lpci_cben,
    inout  wire        lpci_framen,
    inout  wire        lpci_irdyn,
    inout  wire        lpci_trdyn,
    inout  wire        lpci_devseln,
    inout  wire        lpci_stopn,
    inout  wire        lpci_par,
    inout  wire        lpci_perrn,
    inout  wire        lpci_serrn,
    inout  wire        lpci_lockn,
    inout  wire        lpci_reqn,
    input  wire        lpci_gntn,
    output wire        lpci_intan,
    input  wire        lpci_idsel,
    input  wire        lpci_rstn,
    input  wire        lpci_clk,
    output wire        lpci_enablen
);

    wire [3:0] io_address;
    wire       io_read;
    wire [7:0] io_readdata;
    wire       io_write;
    wire [7:0] io_writedata;
    wire       io_b_cs;
    wire       io_c_cs;
    wire       io_d_cs;

    wire [16:0] mem_address;
    wire        mem_read;
    wire [7:0]  mem_readdata;
    wire        mem_write;
    wire [7:0]  mem_writedata;

    wire        vga_ce;
    wire        vga_blank_n;
    wire        vga_horiz_sync;
    wire        vga_vert_sync;
    wire [7:0]  vga_r;
    wire [7:0]  vga_g;
    wire [7:0]  vga_b;

    wire        video_clk;
    wire        pll_locked;
    wire        pci_config_not_done;
    wire [2:0]  led_debug;
    wire        hdmi_config_ready;
    wire        reset_n = cpu_resetn & pll_locked;
    wire        pci_clk = lpci_clk;
    wire        pci_reset_n = lpci_rstn;
    wire        vga_reset_n = reset_n & pci_reset_n;

    sivgx_mistvga_pll u_vid_pll (
        .areset (~cpu_resetn),
        .inclk0 (clkinbot_100_p),
        .c0     (video_clk),
        .locked (pll_locked)
    );

    sivgx_i2c_hdmi_config #(
        .CLK_FREQ (50000000)
    ) u_hdmi_config (
        .iCLK        (clkin_50),
        .iRST_N      (reset_n),
        .I2C_SCLK    (hdmi_scl),
        .I2C_SDAT    (hdmi_sda),
        .HDMI_TX_INT (hdmi_intn),
        .READY       (hdmi_config_ready)
    );

    pci_vga_bridge u_pci_bridge (
        .pci_enable_n        (lpci_enablen),
        .pci_ad              (lpci_ad),
        .pci_cben            (lpci_cben),
        .pci_req_n           (lpci_reqn),
        .pci_gnt_n           (lpci_gntn),
        .pci_inta_n          (lpci_intan),
        .pci_idsel           (lpci_idsel),
        .pci_frame_n         (lpci_framen),
        .pci_irdy_n          (lpci_irdyn),
        .pci_rst_n           (pci_reset_n),
        .pci_clk             (pci_clk),
        .pci_trdy_n          (lpci_trdyn),
        .pci_perr_n          (lpci_perrn),
        .pci_devsel_n        (lpci_devseln),
        .pci_stop_n          (lpci_stopn),
        .pci_serr_n          (lpci_serrn),
        .pci_par             (lpci_par),
        .pci_lock_n          (lpci_lockn),
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

        .led_debug           (led_debug)
    );

    vga u_vga (
        .clk_sys         (pci_clk),
        .rst_n           (vga_reset_n),

        .io_address      (io_address),
        .io_read         (io_read),
        .io_readdata     (io_readdata),
        .io_write        (io_write),
        .io_writedata    (io_writedata),
        .io_b_cs         (io_b_cs),
        .io_c_cs         (io_c_cs),
        .io_d_cs         (io_d_cs),

        .mem_address     (mem_address),
        .mem_read        (mem_read),
        .mem_readdata    (mem_readdata),
        .mem_write       (mem_write),
        .mem_writedata   (mem_writedata),

        .irq             (),

        .clk_vga         (video_clk),
        .clock_rate_vga  (28'd25000000),

        .vga_ce          (vga_ce),
        .vga_f60         (1'b0),
        .vga_memmode     (),
        .vga_blank_n     (vga_blank_n),
        .vga_off         (),
        .vga_horiz_sync  (vga_horiz_sync),
        .vga_vert_sync   (vga_vert_sync),
        .vga_r           (vga_r),
        .vga_g           (vga_g),
        .vga_b           (vga_b),

        .vga_pal_d       (),
        .vga_pal_a       (),
        .vga_pal_we      (),
        .vga_start_addr  (),
        .vga_wr_seg      (),
        .vga_rd_seg      (),
        .vga_width       (),
        .vga_stride      (),
        .vga_height      (),
        .vga_flags       (),

        .vga_lores       (1'b1),
        .vga_border      (1'b0)
    );

    assign hdmi_de = vga_blank_n;
    assign hdmi_d = {vga_r, vga_g, vga_b};
    assign hdmi_hsync = vga_horiz_sync;
    assign hdmi_vsync = vga_vert_sync;
    assign hdmi_clk = video_clk;

    assign hdmi_i2s = 4'b0000;
    assign hdmi_lrclk = 1'b0;
    assign hdmi_mclk = 1'b0;
    assign hdmi_sclk = 1'b0;
    assign hdmi_spdif = 1'b0;

    assign hsmb_rx_led = pll_locked;
    assign hsmb_tx_led = ~pci_config_not_done;

    assign user_led = {
        8'h00,
        led_debug,
        hdmi_config_ready,
        pll_locked,
        ~cpu_resetn,
        ~pci_reset_n,
        pci_config_not_done
    };

endmodule

`default_nettype wire
