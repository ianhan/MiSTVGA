// ao486 VGA wrapped for the Arria V GX Starter Kit.
//
// Video path:
//   PCI VGA core -> ASCAL fixed 1920x1080 output -> Arria V HDMI TX PHY
//
`default_nettype none

module a5gx_mistvga_top (
    input  wire        refclk2_qr1_p,
    input  wire        clkin_50_top,
    input  wire        clkintop_100_p,
    input  wire        cpu_resetn,

    output wire [3:0]  user_led,

    output wire        hdmi_tx_oen,
    input  wire        hdmi_tx_hpd,
    output wire [2:0]  hdmi_tx_p,
    output wire        hdmi_tx_clkout_p,

    output wire [26:0] fsm_a,
    inout  wire [31:0] fsm_d,
    output wire        sram_clk,
    output wire        sram_cen,
    output wire [3:0]  sram_bwn,
    output wire        sram_gwn,
    output wire        sram_bwen,
    output wire        sram_oen,
    output wire        sram_advn,
    output wire        sram_adspn,
    output wire        sram_adscn,
    output wire        sram_zz,
    output wire        sram_mode,
    inout  wire [3:0]  sram_dqp,

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
    localparam int SCALER_ADDR_WIDTH = 19;

    reg [20:0] por_cnt = 21'd0;
    always_ff @(posedge clkin_50_top or negedge cpu_resetn) begin
        if (!cpu_resetn) begin
            por_cnt <= 21'd0;
        end else if (!por_cnt[20]) begin
            por_cnt <= por_cnt + 21'd1;
        end
    end

    wire board_reset_n = cpu_resetn & por_cnt[20];
    wire pci_clk = lpci_clk;
    wire pci_reset_n = lpci_rstn;
    wire vga_reset_n = board_reset_n & pci_reset_n;

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

    wire        pci_config_not_done;
    wire [2:0]  led_debug;

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

        .clk_vga         (clkin_50_top),
        .clock_rate_vga  (28'd50000000),

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
        .vga_border      (1'b1)
    );

    wire        pixel_clk;
    wire        hdmi_pll_locked;
    wire        scaler_hs;
    wire        scaler_vs;
    wire        scaler_de;
    wire [7:0]  scaler_r;
    wire [7:0]  scaler_g;
    wire [7:0]  scaler_b;

    wire [SCALER_ADDR_WIDTH-1:0] avl_address;
    wire [7:0]                   avl_burstcount;
    wire [127:0]                 avl_writedata;
    wire [127:0]                 avl_readdata;
    wire [15:0]                  avl_byteenable;
    wire                         avl_write;
    wire                         avl_read;
    wire                         avl_waitrequest;
    wire                         avl_readdatavalid;

    wire         ssram_clk_0deg;
    wire         scaler_mem_clk;
    wire         ssram_pll_locked;
    wire         scaler_reset_n = board_reset_n & ssram_pll_locked;

    a5gx_ssram_pll u_ssram_pll (
        .areset (~board_reset_n),
        .inclk0 (clkintop_100_p),
        .c0     (ssram_clk_0deg),
        .c1     (scaler_mem_clk),
        .locked (ssram_pll_locked)
    );

    wire [29:0] scaler_memory_address =
        30'h1000_0000 + {{(30-SCALER_ADDR_WIDTH-4){1'b0}}, avl_address, 4'b0000};

    wire [24:0] memory_fsm_address;
    wire [0:0]  memory_sram_bwe_n;
    wire [0:0]  memory_sram_adsc_n;
    wire [3:0]  memory_sram_bw_n;
    wire [0:0]  memory_sram_outputenable_n;
    wire [0:0]  memory_sram_chipenable1_n;

    ascal_1080p u_scaler (
        .reset_na          (scaler_reset_n),

        .i_clk             (clkin_50_top),
        .i_ce              (vga_ce),
        .i_r               (vga_r),
        .i_g               (vga_g),
        .i_b               (vga_b),
        .i_hs              (vga_horiz_sync),
        .i_vs              (vga_vert_sync),
        .i_de              (vga_blank_n),

        .o_clk             (pixel_clk),
        .o_ce              (1'b1),
        .o_r               (scaler_r),
        .o_g               (scaler_g),
        .o_b               (scaler_b),
        .o_hs              (scaler_hs),
        .o_vs              (scaler_vs),
        .o_de              (scaler_de),

        .avl_clk           (scaler_mem_clk),
        .avl_waitrequest   (avl_waitrequest),
        .avl_readdata      (avl_readdata),
        .avl_readdatavalid (avl_readdatavalid),
        .avl_burstcount    (avl_burstcount),
        .avl_writedata     (avl_writedata),
        .avl_address       (avl_address),
        .avl_write         (avl_write),
        .avl_read          (avl_read),
        .avl_byteenable    (avl_byteenable)
    );

    memory u_memory (
        .bridge_0_avalon_master_address          (scaler_memory_address),
        .bridge_0_avalon_master_burstcount       (avl_burstcount),
        .bridge_0_avalon_master_byteenable       (avl_byteenable),
        .bridge_0_avalon_master_read             (avl_read),
        .bridge_0_avalon_master_readdata         (avl_readdata),
        .bridge_0_avalon_master_readdatavalid    (avl_readdatavalid),
        .bridge_0_avalon_master_waitrequest      (avl_waitrequest),
        .bridge_0_avalon_master_write            (avl_write),
        .bridge_0_avalon_master_writedata        (avl_writedata),
        .clk_0                                   (scaler_mem_clk),
        .reset_n                                 (scaler_reset_n),
        .bwe_n_to_the_ssram                      (memory_sram_bwe_n),
        .adsc_n_to_the_max2_inf                  (),
        .adsc_n_to_the_ssram                     (memory_sram_adsc_n),
        .chipenable1_n_to_the_max2_inf           (),
        .reset_n_to_the_ssram                    (),
        .write_n_to_the_ext_flash                (),
        .select_n_to_the_ext_flash               (),
        .flash_tristate_bridge_address           (memory_fsm_address),
        .flash_tristate_bridge_data              (fsm_d),
        .reset_n_to_the_max2_inf                 (),
        .outputenable_n_to_the_max2_inf          (),
        .bw_n_to_the_ssram                       (memory_sram_bw_n),
        .bw_n_to_the_max2_inf                    (),
        .bwe_n_to_the_max2_inf                   (),
        .read_n_to_the_ext_flash                 (),
        .outputenable_n_to_the_ssram             (memory_sram_outputenable_n),
        .chipenable1_n_to_the_ssram              (memory_sram_chipenable1_n)
    );

    assign fsm_a = {2'b0, memory_fsm_address};
    assign sram_clk = ssram_clk_0deg;
    assign sram_cen = memory_sram_chipenable1_n[0];
    assign sram_bwn = memory_sram_bw_n;
    assign sram_bwen = memory_sram_bwe_n[0];
    assign sram_oen = memory_sram_outputenable_n[0];
    assign sram_adscn = memory_sram_adsc_n[0];
    assign sram_advn = 1'b1;
    assign sram_adspn = 1'b1;
    assign sram_gwn = 1'b1;
    assign sram_zz = 1'b0;
    assign sram_mode = 1'b1;
    assign sram_dqp = 4'hz;

    dvi_tx_top u_dvi_tx_top (
        .pll_refclk          (refclk2_qr1_p),
        .fabric_clk          (clkin_50_top),
        .pixel_clock         (pixel_clk),
        .reset               (~board_reset_n),
        .den                 (scaler_de),
        .hsync               (scaler_hs),
        .vsync               (scaler_vs),
        .pixel_data          ({scaler_r, scaler_g, scaler_b}),
        .pll_locked_out      (hdmi_pll_locked),
        .tmds_clk_p          (hdmi_tx_clkout_p),
        .tmds_d0_p           (hdmi_tx_p[0]),
        .tmds_d1_p           (hdmi_tx_p[1]),
        .tmds_d2_p           (hdmi_tx_p[2]),
        .dbg_tx_analogreset  (),
        .dbg_tx_cal_busy     (),
        .dbg_reset_state     (),
        .dbg_reset_fab       ()
    );

    reg [18:0] breath_rate_cnt = 19'd0;
    reg [6:0]  breath_pwm_cnt = 7'd0;
    reg [6:0]  breath_duty = 7'd0;
    reg        breath_ramp_up = 1'b0;
    reg        breath_led = 1'b0;

    wire breath_step = &breath_rate_cnt;

    always_ff @(posedge pci_clk or negedge pci_reset_n) begin
        if (!pci_reset_n) begin
            breath_rate_cnt <= 19'd0;
            breath_pwm_cnt  <= 7'd0;
            breath_duty     <= 7'd0;
            breath_ramp_up  <= 1'b0;
            breath_led      <= 1'b0;
        end else begin
            breath_rate_cnt <= breath_rate_cnt + 19'd1;
            breath_pwm_cnt  <= breath_pwm_cnt + 7'd1;

            if (breath_step) begin
                breath_duty <= breath_duty + 7'd1;
                if (&breath_duty) begin
                    breath_ramp_up <= ~breath_ramp_up;
                end
            end

            if (breath_ramp_up) begin
                breath_led <= breath_pwm_cnt < breath_duty;
            end else begin
                breath_led <= breath_pwm_cnt > breath_duty;
            end
        end
    end

    assign hdmi_tx_oen = 1'b0;
    assign user_led[0] = ~board_reset_n;
    assign user_led[1] = pci_config_not_done;
    assign user_led[2] = hdmi_pll_locked & hdmi_tx_hpd;
    assign user_led[3] = breath_led;
endmodule

`default_nettype wire
