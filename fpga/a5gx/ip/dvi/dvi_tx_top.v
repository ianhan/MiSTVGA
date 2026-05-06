module dvi_tx_top (
    input              pll_refclk,    // Transceiver reference clock (can't clock fabric)
    input              fabric_clk,    // Fabric clock for reset sequencer
    output             pixel_clock,   // Pixel clock output from PHY (use for VPG/encoders)
    input              reset,
    input              den,
    input              hsync,
    input              vsync,
    input  [23 : 0]    pixel_data,
    output             pll_locked_out,
    output             tmds_clk_p,
    output             tmds_clk_n,
    output             tmds_d0_p,
    output             tmds_d0_n,
    output             tmds_d1_p,
    output             tmds_d1_n,
    output             tmds_d2_p,
    output             tmds_d2_n,
    // Debug outputs
    output             dbg_tx_analogreset,
    output [3:0]       dbg_tx_cal_busy,
    output [1:0]       dbg_reset_state,
    output             dbg_reset_fab
);
`default_nettype none
    wire [5 : 0]  ctrl = {4'b0000, vsync, hsync};
    wire [29 : 0] tmds_enc;
    wire [3 : 0]  tx_serial_data; // Positive differential outputs (HSSI)
    wire [3 : 0]  tx_std_clkout;

    // Pixel clock comes from PHY's tx_std_clkout (derived from PLL)
    assign pixel_clock = tx_std_clkout[0];

    // TMDS encoding - runs on pixel_clock from PHY
    generate
        genvar i;
        for (i = 0; i < 3; i = i + 1) begin : gen_buff
            dvi_tx_tmds_enc inst (
                .clock (pixel_clock),
                .reset (reset),
                .den   (den),
                .data  (pixel_data[(8*i) +: 8]),
                .ctrl  (ctrl[(2*i) +: 2]),
                .tmds  (tmds_enc[(10*i) +: 10])
            );
        end
    endgenerate

    // Register clock pattern to match TMDS encoder latency (1 cycle)
    // LSB-first: 0000011111 on wire = 5 lows then 5 highs = clock
    reg [9:0] tmds_clk_pattern_r;
    always @(posedge pixel_clock or posedge reset)
        if (reset)
            tmds_clk_pattern_r <= 10'b0000011111;
        else
            tmds_clk_pattern_r <= 10'b0000011111;

    wire pll_locked;
    wire [3:0] tx_cal_busy;
    assign pll_locked_out = pll_locked;

    // Reconfiguration controller <-> PHY connections
    wire [349:0] reconfig_to_xcvr;
    wire [229:0] reconfig_from_xcvr;

    // Synchronize reset to fabric_clk domain
    reg [1:0] reset_sync = 2'b00;  // Start released
    wire reset_fab = reset_sync[1];
    always @(posedge fabric_clk)
        reset_sync <= {reset_sync[0], reset};

    // Synchronize pll_locked and tx_cal_busy to fabric_clk domain
    reg [1:0] pll_locked_sync = 2'b00;
    reg [1:0] cal_busy_sync [0:3];
    initial begin
        cal_busy_sync[0] = 2'b11;
        cal_busy_sync[1] = 2'b11;
        cal_busy_sync[2] = 2'b11;
        cal_busy_sync[3] = 2'b11;
    end
    wire pll_locked_fab = pll_locked_sync[1];
    wire [3:0] cal_busy_fab = {cal_busy_sync[3][1], cal_busy_sync[2][1],
                               cal_busy_sync[1][1], cal_busy_sync[0][1]};

    always @(posedge fabric_clk) begin
        pll_locked_sync <= {pll_locked_sync[0], pll_locked};
        cal_busy_sync[0] <= {cal_busy_sync[0][0], tx_cal_busy[0]};
        cal_busy_sync[1] <= {cal_busy_sync[1][0], tx_cal_busy[1]};
        cal_busy_sync[2] <= {cal_busy_sync[2][0], tx_cal_busy[2]};
        cal_busy_sync[3] <= {cal_busy_sync[3][0], tx_cal_busy[3]};
    end

    // Reset sequencer runs on fabric_clk (available before pixel_clock)
    reg [7:0] reset_cnt = 0;
    reg [1:0] reset_state = 2'b00;
    reg tx_analogreset = 1'b1;
    reg tx_digitalreset = 1'b1;

    always @(posedge fabric_clk) begin
        if (reset_fab) begin
            reset_state <= 2'b00;
            reset_cnt <= 0;
            tx_analogreset <= 1'b1;
            tx_digitalreset <= 1'b1;
        end else begin
            case (reset_state)
                2'b00: begin
                    // Hold analog reset for 64 cycles
                    reset_cnt <= reset_cnt + 1;
                    if (reset_cnt == 8'd63) begin
                        tx_analogreset <= 1'b0;
                        reset_state <= 2'b01;
                    end
                end
                2'b01: begin
                    // Wait for PLL lock AND calibration done
                    if (pll_locked_fab && (cal_busy_fab == 4'b0)) begin
                        tx_digitalreset <= 1'b0;
                        reset_state <= 2'b10;
                    end
                end
                2'b10: ; // Running
            endcase
        end
    end

    // Transceiver Reconfiguration Controller - handles calibration
    xcvr_reconfig xcvr_reconfig_inst (
        .mgmt_clk_clk       (fabric_clk),
        .mgmt_rst_reset     (reset_fab),
        .reconfig_to_xcvr   (reconfig_to_xcvr),
        .reconfig_from_xcvr (reconfig_from_xcvr),
        .reconfig_busy      ()  // Not used
    );

    // Transceiver PHY instantiation
    // Channel-to-pin mapping (from user): Ch0=AJ3, Ch1=AG3, Ch2=AE3, Ch3=AC3(CLK)
    tmds_tx_phy tmds_tx_phy_inst (
        .pll_powerdown          (1'b0),
        .tx_analogreset         ({4{tx_analogreset}}),
        .tx_digitalreset        ({4{tx_digitalreset}}),
        .tx_pll_refclk          (pll_refclk),          // Transceiver refclk
        .tx_std_coreclkin       ({4{pixel_clock}}),    // Pixel clock for parallel data
        .tx_serial_data         (tx_serial_data),
        .pll_locked             (pll_locked),
        .tx_std_clkout          (tx_std_clkout),       // Pixel clock output
        .tx_cal_busy            (tx_cal_busy),
        .reconfig_to_xcvr       (reconfig_to_xcvr),
        .reconfig_from_xcvr     (reconfig_from_xcvr),
        .tx_parallel_data       ({
                                 tmds_clk_pattern_r,   // [39:30] Ch3 → PIN_AC3 = Clock
                                 tmds_enc[29:20],      // [29:20] Ch2 → PIN_AE3 = D2/Red
                                 tmds_enc[19:10],      // [19:10] Ch1 → PIN_AG3 = D1/Green
                                 tmds_enc[9:0]         // [9:0]   Ch0 → PIN_AJ3 = D0/Blue
                                 }),
        .unused_tx_parallel_data (136'b0)
    );

    // Map transceiver outputs to TMDS positive signals
    // Physical channel order: Ch0=PIN_AJ3, Ch1=PIN_AG3, Ch2=PIN_AE3, Ch3=PIN_AC3(CLK)
    assign tmds_d0_p  = tx_serial_data[0];  // Ch0 → PIN_AJ3 = D0/Blue
    assign tmds_d1_p  = tx_serial_data[1];  // Ch1 → PIN_AG3 = D1/Green
    assign tmds_d2_p  = tx_serial_data[2];  // Ch2 → PIN_AE3 = D2/Red
    assign tmds_clk_p = tx_serial_data[3];  // Ch3 → PIN_AC3 = Clock

    // Differential negative signals are handled by transceiver pins (no explicit _n port)
    // Assign these in the .qsf file to corresponding _n pins

    // Debug outputs
    assign dbg_tx_analogreset = tx_analogreset;
    assign dbg_tx_cal_busy = tx_cal_busy;
    assign dbg_reset_state = reset_state;
    assign dbg_reset_fab = reset_fab;
endmodule