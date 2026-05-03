// ao486 VGA wrapped for the Arria II GX development kit.
//
// Uses vga.v (the full ao486/MiSTer VGA core) instead of vga_core
// (Graphics Gremlin text-only core). PCI bus cycles are bridged
// to vga.v's Avalon-like interface via pci_vga_bridge.
//
// Board: Arria II GX Development Kit (DK-DEV-2AGX125N)
// Video: Parallel RGB → IT6613 HDMI transmitter on HSMC
//
`default_nettype none
module a2gx_mistvga_top(
    input                  clkin_top_p,
    input                  cpu_resetn,

    output          [3:0]  user_led,

    output                 enet_gtx_clk,
    output          [3:0]  enet_tx_d,
    output                 enet_tx_en,
    output                 enet_resetn,
    output                 enet_mdc,

    output                 max2_clk,
    output                 max2_csn,
    output          [3:0]  max2_ben,
    output                 max2_oen,
    output                 max2_wen,

    output                 lcd_d_cn,
    output                 lcd_wen,
    output                 lcd_csn,

    output                 pcie_waken,
    output                 pcie_led_x1,
    output                 pcie_led_x4,
    output                 pcie_led_x8,

    output         [11:0]  HDMI_TX_RD,
    output                 HDMI_TX_PCSCL,
    inout                  HDMI_TX_PCSDA,
    output                 HDMI_TX_RST_N,
    input                  HDMI_TX_INT_N,
    output         [11:0]  HDMI_TX_GD,
    output                 HDMI_TX_PCLK,
    output          [3:0]  HDMI_TX_DSD_L,
    output          [3:0]  HDMI_TX_DSD_R,
    output                 HDMI_TX_DCLK,
    output                 HDMI_TX_SCK,
    output                 HDMI_TX_WS,
    output                 HDMI_TX_MCLK,
    output          [3:0]  HDMI_TX_I2S,
    output         [11:0]  HDMI_TX_BD,
    output                 HDMI_TX_DE,
    output                 HDMI_TX_VS,
    output                 HDMI_TX_HS,
    output                 HDMI_TX_SPDIF,

    output                 flash_clk,
    output                 flash_cen,
    output                 flash_oen,
    output                 flash_wen,
    output                 flash_advn,
    output                 flash_resetn,

    output                 sram_clk,
    output                 sram_cen,
    output          [3:0]  sram_bwn,
    output                 sram_gwn,
    output                 sram_bwen,
    output                 sram_oen,
    output                 sram_advn,
    output                 sram_adspn,
    output                 sram_adscn,
    output                 sram_zz,

    inout          [31:0]  lpci_ad,
    inout           [3:0]  lpci_cben,
    inout                  lpci_framen,
    inout                  lpci_irdyn,
    inout                  lpci_trdyn,
    inout                  lpci_devseln,
    inout                  lpci_stopn,
    inout                  lpci_par,
    inout                  lpci_perrn,
    inout                  lpci_serrn,
    inout                  lpci_lockn,
    inout                  lpci_reqn,
    input                  lpci_gntn,
    output                 lpci_intan,
    input                  lpci_idsel,
    input                  lpci_rstn,
    input                  lpci_clk,
    output                 lpci_enablen
);

    // ─── Wires ───

    wire [3:0]  io_address;
    wire        io_read;
    wire [7:0]  io_readdata;
    wire        io_write;
    wire [7:0]  io_writedata;
    wire        io_b_cs;
    wire        io_c_cs;
    wire        io_d_cs;

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
    wire        pci_clk;
    wire        pll_locked;
    wire        pci_config_not_done;
    wire        debug_display_mode;
    wire        scaler_filter_disabled;
    wire [2:0]  led_debug;
    wire        hdmi_config_ready;
    wire        reset_n = cpu_resetn & pll_locked;
    wire        pci_reset_n = lpci_rstn;
    wire        vga_reset_n = reset_n & pci_reset_n;

    // ─── PLL: 100 MHz → 25 MHz pixel clock ───
    // At 25 MHz, vga_ce fires every cycle, matching the standard
    // VGA 25.175 MHz dot clock within monitor tolerance.
    a2gx_mistvga_pll u_vid_pll (
        .areset (),
        .inclk0 (clkin_top_p),
        .c0     (video_clk),
        .locked (pll_locked)
    );
/*
    // GPLGPU-style PCI pass-through PLL for a compensated internal PCI clock.
    a2gx_pci_clk_pll u_pci_pll (
        .areset (~pci_reset_n),
        .inclk0 (lpci_clk),
        .c0     (pci_clk),
        .locked ()
    );
*/
    assign pci_clk = lpci_clk;

    // ─── HDMI transmitter I2C configuration ───
    a2gx_i2c_hdmi_config #(
        .CLK_FREQ    (100000000)
    ) u_hdmi_config (
        .iCLK        (clkin_top_p),
        .iRST_N      (reset_n),
        .I2C_SCLK    (HDMI_TX_PCSCL),
        .I2C_SDAT    (HDMI_TX_PCSDA),
        .HDMI_TX_INT (HDMI_TX_INT_N),
        .READY       (hdmi_config_ready)
    );

    // ─── PCI → Avalon bridge ───
    pci_vga_bridge u_pci_bridge (
        .pci_enable_n       (lpci_enablen),
        .pci_ad             (lpci_ad),
        .pci_cben           (lpci_cben),
        .pci_req_n          (lpci_reqn),
        .pci_gnt_n          (lpci_gntn),
        .pci_inta_n         (lpci_intan),
        .pci_idsel          (lpci_idsel),
        .pci_frame_n        (lpci_framen),
        .pci_irdy_n         (lpci_irdyn),
        .pci_rst_n          (pci_reset_n),
        .pci_clk            (pci_clk),
        .pci_trdy_n         (lpci_trdyn),
        .pci_perr_n         (lpci_perrn),
        .pci_devsel_n       (lpci_devseln),
        .pci_stop_n         (lpci_stopn),
        .pci_serr_n         (lpci_serrn),
        .pci_par            (lpci_par),
        .pci_lock_n         (lpci_lockn),
        .pci_config_not_done(pci_config_not_done),

        .io_address         (io_address),
        .io_read            (io_read),
        .io_readdata        (io_readdata),
        .io_write           (io_write),
        .io_writedata       (io_writedata),
        .io_b_cs            (io_b_cs),
        .io_c_cs            (io_c_cs),
        .io_d_cs            (io_d_cs),

        .mem_address        (mem_address),
        .mem_read           (mem_read),
        .mem_readdata       (mem_readdata),
        .mem_write          (mem_write),
        .mem_writedata      (mem_writedata),

        .debug_display_mode    (debug_display_mode),
        .scaler_filter_disabled(scaler_filter_disabled),
        .led_debug             (led_debug)
    );

    // ─── VGA core (ao486/MiSTer full VGA) ───
    // clk_sys = compensated PCI clock (33 MHz), clk_vga = PLL output (25 MHz)
    vga u_vga (
        .clk_sys        (pci_clk),
        .rst_n          (vga_reset_n),

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

        .irq            (),

        .clk_vga        (video_clk),
        .clock_rate_vga (28'd25000000),

        .vga_ce         (vga_ce),
        .vga_f60        (1'b0),
        .vga_memmode    (),
        .vga_blank_n    (vga_blank_n),
        .vga_off        (),
        .vga_horiz_sync (vga_horiz_sync),
        .vga_vert_sync  (vga_vert_sync),
        .vga_r          (vga_r),
        .vga_g          (vga_g),
        .vga_b          (vga_b),

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

    // ─── HDMI output ───
    // vga.v registers blank_n, r/g/b, and sync on the same clk_vga edge —
    // no additional delay needed.
    assign HDMI_TX_DE = vga_blank_n;
    assign HDMI_TX_RD = {vga_r, 4'b0000};
    assign HDMI_TX_GD = {vga_g, 4'b0000};
    assign HDMI_TX_BD = {vga_b, 4'b0000};
    assign HDMI_TX_HS = vga_horiz_sync;
    assign HDMI_TX_VS = vga_vert_sync;
    assign HDMI_TX_PCLK = video_clk;
    assign HDMI_TX_RST_N = reset_n;

    // ─── Audio (unused) ───
    assign HDMI_TX_DSD_L = 4'b0000;
    assign HDMI_TX_DSD_R = 4'b0000;
    assign HDMI_TX_DCLK = 1'b0;
    assign HDMI_TX_SCK = 1'b0;
    assign HDMI_TX_WS = 1'b0;
    assign HDMI_TX_MCLK = 1'b0;
    assign HDMI_TX_I2S = 4'b0000;
    assign HDMI_TX_SPDIF = 1'b0;

    // ─── Unused peripherals ───
    assign enet_resetn = 1'b0;
    assign enet_gtx_clk = 1'b0;
    assign enet_tx_d = 4'b0000;
    assign enet_tx_en = 1'b0;
    assign enet_mdc = 1'b0;

    assign flash_clk = 1'b0;
    assign flash_cen = 1'b1;
    assign flash_oen = 1'b1;
    assign flash_wen = 1'b1;
    assign flash_advn = 1'b1;
    assign flash_resetn = 1'b0;

    assign sram_clk = 1'b0;
    assign sram_cen = 1'b1;
    assign sram_bwn = 4'hf;
    assign sram_gwn = 1'b1;
    assign sram_bwen = 1'b1;
    assign sram_oen = 1'b1;
    assign sram_advn = 1'b1;
    assign sram_adspn = 1'b1;
    assign sram_adscn = 1'b1;
    assign sram_zz = 1'b1;

    assign max2_clk = 1'b0;
    assign max2_csn = 1'b1;
    assign max2_ben = 4'hf;
    assign max2_oen = 1'b1;
    assign max2_wen = 1'b1;

    assign lcd_d_cn = 1'b0;
    assign lcd_wen = 1'b1;
    assign lcd_csn = 1'b1;

    assign pcie_waken = 1'b1;
    assign pcie_led_x1 = 1'b0;
    assign pcie_led_x4 = 1'b0;
    assign pcie_led_x8 = 1'b0;

    assign user_led = {2'b00, pll_locked, pci_config_not_done};

endmodule
