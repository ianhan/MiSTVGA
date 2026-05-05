// Readable SystemVerilog wrapper around the external VHDL ASCAL scaler core.
`default_nettype none

module ascal_1080p (
    input  wire         reset_na,
    input  wire         debug_display_mode,
    input  wire         scaler_filter_disabled,
    input  wire         palette_clk,
    input  wire [17:0]  palette_data,
    input  wire [7:0]   palette_address,
    input  wire         palette_write,
    input  wire [7:0]   border_color_index,

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
    localparam [7:0]   SCALER_MASK          = 8'h11;
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
    localparam [11:0]  HDMI_HMIN_CENTERED   = 12'd240;
    localparam [11:0]  HDMI_HMAX_CENTERED   = 12'd1679;
    localparam [11:0]  HDMI_HMIN_DEBUG      = 12'd0;
    localparam [11:0]  HDMI_HMAX_DEBUG      = 12'd1439;
    localparam [11:0]  DEBUG_COLUMN_X       = 12'd1440;
    localparam [11:0]  DEBUG_COLUMN_WIDTH   = 12'd480;
    localparam [11:0]  DEBUG_TOP_SPACING    = 12'd29;
    localparam [11:0]  DEBUG_MID_SPACING    = 12'd30;
    localparam [11:0]  DEBUG_PANEL_X        = DEBUG_COLUMN_X;
    localparam [11:0]  DEBUG_PANEL_Y        = DEBUG_TOP_SPACING;
    localparam [11:0]  DEBUG_PANEL_SIZE     = 12'd480;
    localparam [11:0]  DEBUG_PANEL_BORDER   = 12'd4;
    localparam [11:0]  DEBUG_GRID_ORIGIN    = 12'd10;
    localparam [11:0]  DEBUG_CELL_SIZE      = 12'd25;
    localparam [11:0]  DEBUG_CELL_GAP       = 12'd4;
    localparam [11:0]  DEBUG_CELL_PITCH     = 12'd29;
    localparam [11:0]  DEBUG_GRID_SIZE      = 12'd460;
    localparam [11:0]  DEBUG_HISTORY_X      =
        DEBUG_PANEL_X + DEBUG_GRID_ORIGIN;
    localparam [11:0]  DEBUG_HISTORY_Y      =
        DEBUG_PANEL_Y + DEBUG_PANEL_SIZE + DEBUG_MID_SPACING;
    localparam [11:0]  DEBUG_HISTORY_WIDTH  = DEBUG_GRID_SIZE;
    localparam [11:0]  DEBUG_HISTORY_HEIGHT = 12'd512;
    localparam [8:0]   DEBUG_HISTORY_COLS   = 9'(DEBUG_GRID_SIZE);
    localparam int     HDMI_VTOTAL          = 1125;
    localparam int     HDMI_VSSTART         = 1084;
    localparam int     HDMI_VSEND           = 1089;
    localparam int     HDMI_VDISP           = 1080;
    localparam int     HDMI_VMIN            = 0;
    localparam int     HDMI_VMAX            = 1079;

    localparam [4:0]   SCALE_MODE_NEAREST   = 5'd0;
    localparam [4:0]   SCALE_MODE_POLYPHASE = 5'd4;
    localparam [1:0]   SCALE_FORMAT_16BPP   = 2'd0;
    localparam [5:0]   FRAMEBUFFER_FORMAT   = 6'd4;
    localparam int     POLY_PHASE_COUNT     = 1 << FRACTION_BITS;
    localparam int     COEFFS_PER_PHASE     = 4;
    localparam int     FILTER_AXIS_COUNT     = 2;
    localparam int     FILTER_WRITE_COUNT    =
        FILTER_AXIS_COUNT * POLY_PHASE_COUNT * COEFFS_PER_PHASE;
    localparam int     FILTER_WRITE_INDEX_WIDTH = $clog2(FILTER_WRITE_COUNT);
    localparam [FILTER_WRITE_INDEX_WIDTH-1:0] FILTER_WRITE_LAST_INDEX =
        FILTER_WRITE_INDEX_WIDTH'(FILTER_WRITE_COUNT - 1);

    function automatic [39:0] lcd_effect_01_h_filter_phase(input [5:0] phase);
        begin
            case (phase)
            6'd0: lcd_effect_01_h_filter_phase = {10'd0, 10'd250, 10'd0, 10'd0};
            6'd1: lcd_effect_01_h_filter_phase = {10'd0, 10'd252, 10'd0, 10'd0};
            6'd2: lcd_effect_01_h_filter_phase = {10'd0, 10'd254, 10'd0, 10'd0};
            6'd3: lcd_effect_01_h_filter_phase = {10'd0, 10'd256, 10'd0, 10'd0};
            6'd4: lcd_effect_01_h_filter_phase = {10'd0, 10'd256, 10'd0, 10'd0};
            6'd5: lcd_effect_01_h_filter_phase = {10'd0, 10'd256, 10'd0, 10'd0};
            6'd6: lcd_effect_01_h_filter_phase = {10'd0, 10'd258, 10'd0, 10'd0};
            6'd7: lcd_effect_01_h_filter_phase = {10'd0, 10'd256, 10'd0, 10'd0};
            6'd8: lcd_effect_01_h_filter_phase = {10'd0, 10'd256, 10'd0, 10'd0};
            6'd9: lcd_effect_01_h_filter_phase = {10'd0, 10'd254, 10'd0, 10'd0};
            6'd10: lcd_effect_01_h_filter_phase = {10'd0, 10'd252, 10'd0, 10'd0};
            6'd11: lcd_effect_01_h_filter_phase = {10'd0, 10'd248, 10'd2, 10'd0};
            6'd12: lcd_effect_01_h_filter_phase = {10'd0, 10'd244, 10'd2, 10'd0};
            6'd13: lcd_effect_01_h_filter_phase = {10'd0, 10'd240, 10'd2, 10'd0};
            6'd14: lcd_effect_01_h_filter_phase = {10'd0, 10'd234, 10'd2, 10'd0};
            6'd15: lcd_effect_01_h_filter_phase = {10'd0, 10'd228, 10'd4, 10'd0};
            6'd16: lcd_effect_01_h_filter_phase = {10'd0, 10'd220, 10'd4, 10'd0};
            6'd17: lcd_effect_01_h_filter_phase = {10'd0, 10'd212, 10'd6, 10'd0};
            6'd18: lcd_effect_01_h_filter_phase = {10'd0, 10'd204, 10'd6, 10'd0};
            6'd19: lcd_effect_01_h_filter_phase = {10'd0, 10'd196, 10'd8, 10'd0};
            6'd20: lcd_effect_01_h_filter_phase = {10'd0, 10'd188, 10'd10, 10'd0};
            6'd21: lcd_effect_01_h_filter_phase = {10'd0, 10'd180, 10'd12, 10'd0};
            6'd22: lcd_effect_01_h_filter_phase = {10'd0, 10'd174, 10'd14, 10'd0};
            6'd23: lcd_effect_01_h_filter_phase = {10'd0, 10'd168, 10'd18, 10'd0};
            6'd24: lcd_effect_01_h_filter_phase = {10'd0, 10'd162, 10'd22, 10'd0};
            6'd25: lcd_effect_01_h_filter_phase = {10'd0, 10'd156, 10'd26, 10'd0};
            6'd26: lcd_effect_01_h_filter_phase = {10'd0, 10'd148, 10'd32, 10'd0};
            6'd27: lcd_effect_01_h_filter_phase = {10'd0, 10'd140, 10'd40, 10'd0};
            6'd28: lcd_effect_01_h_filter_phase = {10'd0, 10'd132, 10'd48, 10'd0};
            6'd29: lcd_effect_01_h_filter_phase = {10'd0, 10'd122, 10'd58, 10'd0};
            6'd30: lcd_effect_01_h_filter_phase = {10'd0, 10'd114, 10'd68, 10'd0};
            6'd31: lcd_effect_01_h_filter_phase = {10'd0, 10'd102, 10'd80, 10'd0};
            6'd32: lcd_effect_01_h_filter_phase = {10'd0, 10'd92, 10'd92, 10'd0};
            6'd33: lcd_effect_01_h_filter_phase = {10'd0, 10'd80, 10'd104, 10'd0};
            6'd34: lcd_effect_01_h_filter_phase = {10'd0, 10'd70, 10'd116, 10'd0};
            6'd35: lcd_effect_01_h_filter_phase = {10'd0, 10'd60, 10'd128, 10'd0};
            6'd36: lcd_effect_01_h_filter_phase = {10'd0, 10'd50, 10'd140, 10'd0};
            6'd37: lcd_effect_01_h_filter_phase = {10'd0, 10'd42, 10'd150, 10'd0};
            6'd38: lcd_effect_01_h_filter_phase = {10'd0, 10'd34, 10'd160, 10'd0};
            6'd39: lcd_effect_01_h_filter_phase = {10'd0, 10'd30, 10'd170, 10'd0};
            6'd40: lcd_effect_01_h_filter_phase = {10'd0, 10'd24, 10'd178, 10'd0};
            6'd41: lcd_effect_01_h_filter_phase = {10'd0, 10'd20, 10'd186, 10'd0};
            6'd42: lcd_effect_01_h_filter_phase = {10'd0, 10'd16, 10'd192, 10'd0};
            6'd43: lcd_effect_01_h_filter_phase = {10'd0, 10'd12, 10'd196, 10'd0};
            6'd44: lcd_effect_01_h_filter_phase = {10'd0, 10'd10, 10'd200, 10'd0};
            6'd45: lcd_effect_01_h_filter_phase = {10'd0, 10'd8, 10'd202, 10'd0};
            6'd46: lcd_effect_01_h_filter_phase = {10'd0, 10'd6, 10'd206, 10'd0};
            6'd47: lcd_effect_01_h_filter_phase = {10'd0, 10'd4, 10'd206, 10'd0};
            6'd48: lcd_effect_01_h_filter_phase = {10'd0, 10'd4, 10'd208, 10'd0};
            6'd49: lcd_effect_01_h_filter_phase = {10'd0, 10'd4, 10'd210, 10'd0};
            6'd50: lcd_effect_01_h_filter_phase = {10'd0, 10'd2, 10'd210, 10'd0};
            6'd51: lcd_effect_01_h_filter_phase = {10'd0, 10'd2, 10'd210, 10'd0};
            6'd52: lcd_effect_01_h_filter_phase = {10'd0, 10'd2, 10'd212, 10'd0};
            6'd53: lcd_effect_01_h_filter_phase = {10'd0, 10'd2, 10'd214, 10'd0};
            6'd54: lcd_effect_01_h_filter_phase = {10'd0, 10'd0, 10'd216, 10'd0};
            6'd55: lcd_effect_01_h_filter_phase = {10'd0, 10'd0, 10'd218, 10'd0};
            6'd56: lcd_effect_01_h_filter_phase = {10'd0, 10'd0, 10'd220, 10'd0};
            6'd57: lcd_effect_01_h_filter_phase = {10'd0, 10'd0, 10'd224, 10'd0};
            6'd58: lcd_effect_01_h_filter_phase = {10'd0, 10'd0, 10'd228, 10'd0};
            6'd59: lcd_effect_01_h_filter_phase = {10'd0, 10'd0, 10'd232, 10'd0};
            6'd60: lcd_effect_01_h_filter_phase = {10'd0, 10'd0, 10'd236, 10'd0};
            6'd61: lcd_effect_01_h_filter_phase = {10'd0, 10'd0, 10'd240, 10'd0};
            6'd62: lcd_effect_01_h_filter_phase = {10'd0, 10'd0, 10'd244, 10'd0};
            6'd63: lcd_effect_01_h_filter_phase = {10'd0, 10'd0, 10'd248, 10'd0};
            default: lcd_effect_01_h_filter_phase = {10'd0, 10'd256, 10'd0, 10'd0};
            endcase
        end
    endfunction

    function automatic [39:0] lcd_effect_01_v_filter_phase(input [5:0] phase);
        begin
            case (phase)
            6'd0: lcd_effect_01_v_filter_phase = {10'd0, 10'd256, 10'd0, 10'd0};
            6'd1: lcd_effect_01_v_filter_phase = {10'd0, 10'd256, 10'd0, 10'd0};
            6'd2: lcd_effect_01_v_filter_phase = {10'd0, 10'd256, 10'd0, 10'd0};
            6'd3: lcd_effect_01_v_filter_phase = {10'd0, 10'd256, 10'd0, 10'd0};
            6'd4: lcd_effect_01_v_filter_phase = {10'd0, 10'd256, 10'd0, 10'd0};
            6'd5: lcd_effect_01_v_filter_phase = {10'd0, 10'd256, 10'd0, 10'd0};
            6'd6: lcd_effect_01_v_filter_phase = {10'd0, 10'd256, 10'd0, 10'd0};
            6'd7: lcd_effect_01_v_filter_phase = {10'd0, 10'd256, 10'd0, 10'd0};
            6'd8: lcd_effect_01_v_filter_phase = {10'd0, 10'd256, 10'd0, 10'd0};
            6'd9: lcd_effect_01_v_filter_phase = {10'd0, 10'd256, 10'd0, 10'd0};
            6'd10: lcd_effect_01_v_filter_phase = {10'd0, 10'd256, 10'd0, 10'd0};
            6'd11: lcd_effect_01_v_filter_phase = {10'd0, 10'd254, 10'd0, 10'd0};
            6'd12: lcd_effect_01_v_filter_phase = {10'd0, 10'd254, 10'd0, 10'd0};
            6'd13: lcd_effect_01_v_filter_phase = {10'd0, 10'd254, 10'd0, 10'd0};
            6'd14: lcd_effect_01_v_filter_phase = {10'd0, 10'd252, 10'd0, 10'd0};
            6'd15: lcd_effect_01_v_filter_phase = {10'd0, 10'd252, 10'd0, 10'd0};
            6'd16: lcd_effect_01_v_filter_phase = {10'd0, 10'd250, 10'd0, 10'd0};
            6'd17: lcd_effect_01_v_filter_phase = {10'd0, 10'd248, 10'd0, 10'd0};
            6'd18: lcd_effect_01_v_filter_phase = {10'd0, 10'd246, 10'd0, 10'd0};
            6'd19: lcd_effect_01_v_filter_phase = {10'd0, 10'd244, 10'd0, 10'd0};
            6'd20: lcd_effect_01_v_filter_phase = {10'd0, 10'd242, 10'd0, 10'd0};
            6'd21: lcd_effect_01_v_filter_phase = {10'd0, 10'd240, 10'd0, 10'd0};
            6'd22: lcd_effect_01_v_filter_phase = {10'd0, 10'd238, 10'd0, 10'd0};
            6'd23: lcd_effect_01_v_filter_phase = {10'd0, 10'd234, 10'd0, 10'd0};
            6'd24: lcd_effect_01_v_filter_phase = {10'd0, 10'd230, 10'd0, 10'd0};
            6'd25: lcd_effect_01_v_filter_phase = {10'd0, 10'd224, 10'd2, 10'd0};
            6'd26: lcd_effect_01_v_filter_phase = {10'd0, 10'd218, 10'd6, 10'd0};
            6'd27: lcd_effect_01_v_filter_phase = {10'd0, 10'd208, 10'd12, 10'd0};
            6'd28: lcd_effect_01_v_filter_phase = {10'd0, 10'd194, 10'd24, 10'd0};
            6'd29: lcd_effect_01_v_filter_phase = {10'd0, 10'd176, 10'd40, 10'd0};
            6'd30: lcd_effect_01_v_filter_phase = {10'd0, 10'd156, 10'd60, 10'd0};
            6'd31: lcd_effect_01_v_filter_phase = {10'd0, 10'd132, 10'd84, 10'd0};
            6'd32: lcd_effect_01_v_filter_phase = {10'd0, 10'd108, 10'd108, 10'd0};
            6'd33: lcd_effect_01_v_filter_phase = {10'd0, 10'd84, 10'd132, 10'd0};
            6'd34: lcd_effect_01_v_filter_phase = {10'd0, 10'd60, 10'd156, 10'd0};
            6'd35: lcd_effect_01_v_filter_phase = {10'd0, 10'd40, 10'd176, 10'd0};
            6'd36: lcd_effect_01_v_filter_phase = {10'd0, 10'd24, 10'd194, 10'd0};
            6'd37: lcd_effect_01_v_filter_phase = {10'd0, 10'd12, 10'd208, 10'd0};
            6'd38: lcd_effect_01_v_filter_phase = {10'd0, 10'd6, 10'd218, 10'd0};
            6'd39: lcd_effect_01_v_filter_phase = {10'd0, 10'd2, 10'd224, 10'd0};
            6'd40: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd230, 10'd0};
            6'd41: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd234, 10'd0};
            6'd42: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd238, 10'd0};
            6'd43: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd240, 10'd0};
            6'd44: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd242, 10'd0};
            6'd45: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd244, 10'd0};
            6'd46: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd246, 10'd0};
            6'd47: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd248, 10'd0};
            6'd48: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd250, 10'd0};
            6'd49: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd252, 10'd0};
            6'd50: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd252, 10'd0};
            6'd51: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd254, 10'd0};
            6'd52: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd254, 10'd0};
            6'd53: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd254, 10'd0};
            6'd54: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd256, 10'd0};
            6'd55: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd256, 10'd0};
            6'd56: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd256, 10'd0};
            6'd57: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd256, 10'd0};
            6'd58: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd256, 10'd0};
            6'd59: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd256, 10'd0};
            6'd60: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd256, 10'd0};
            6'd61: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd256, 10'd0};
            6'd62: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd256, 10'd0};
            6'd63: lcd_effect_01_v_filter_phase = {10'd0, 10'd0, 10'd256, 10'd0};
            default: lcd_effect_01_v_filter_phase = {10'd0, 10'd256, 10'd0, 10'd0};
            endcase
        end
    endfunction

    function automatic [4:0] debug_cell_coord(input [11:0] grid_coord);
        integer cell_idx;
        reg [31:0] cell_start;
    begin
        debug_cell_coord = 5'd16;
        for (cell_idx = 0; cell_idx < 16; cell_idx = cell_idx + 1) begin
            cell_start = cell_idx * DEBUG_CELL_PITCH;
            if (grid_coord >= cell_start[11:0] &&
                grid_coord < cell_start[11:0] + DEBUG_CELL_SIZE) begin
                debug_cell_coord = cell_idx[4:0];
            end
        end
    end
    endfunction

    function automatic [23:0] palette_6bpc_to_8bpc(input [17:0] color);
    begin
        palette_6bpc_to_8bpc =
            {color[17:12], color[17:16],
             color[11:6],  color[11:10],
             color[5:0],   color[5:4]};
    end
    endfunction

    reg [FILTER_WRITE_INDEX_WIDTH-1:0] filter_write_index = '0;
    reg [1:0]                          filter_write_cycle = 2'd0;
    reg                                filter_loaded = 1'b0;
    reg [11:0]                         poly_a = 12'd0;
    reg [9:0]                          poly_dw = 10'd0;
    reg                                poly_wr = 1'b0;
    reg [1:0]                          debug_display_mode_sync = 2'b00;
    reg [1:0]                          scaler_filter_disabled_sync = 2'b00;
    reg                                debug_display_mode_active = 1'b0;
    reg                                scaler_filter_disabled_active = 1'b0;
    reg                                ascal_vs_last = 1'b0;
    reg [7:0]                          border_color_index_meta = 8'd0;
    reg [7:0]                          border_color_index_sync = 8'd0;
    reg [7:0]                          border_color_index_active = 8'd0;
    reg [11:0]                         active_x = 12'd0;
    reg [11:0]                         active_y = 12'd0;
    reg                                active_frame_seen = 1'b0;
    reg                                coord_de_last = 1'b0;
    reg                                coord_vs_last = 1'b0;
    reg [7:0]                          ascal_r_d = 8'd0;
    reg [7:0]                          ascal_g_d = 8'd0;
    reg [7:0]                          ascal_b_d = 8'd0;
    reg                                ascal_hs_d = 1'b0;
    reg                                ascal_vs_d = 1'b0;
    reg                                ascal_de_d = 1'b0;
    reg                                palette_border_d = 1'b0;
    reg                                palette_cell_d = 1'b0;
    reg                                palette_history_d = 1'b0;
    reg                                debug_column_d = 1'b0;
    reg [8:0]                          palette_history_write_col = 9'd0;
    reg [8:0]                          palette_history_capture_count = 9'd0;
    reg [7:0]                          palette_history_capture_entry = 8'd0;
    reg                                palette_history_capture_active = 1'b0;
    reg                                palette_history_capture_valid = 1'b0;
    reg [16:0]                         palette_history_write_address = 17'd0;
    reg [17:0]                         palette_history_write_data = 18'd0;
    reg                                palette_history_write_enable = 1'b0;
    reg [7:0]                          o_r_reg = 8'd0;
    reg [7:0]                          o_g_reg = 8'd0;
    reg [7:0]                          o_b_reg = 8'd0;
    reg                                o_hs_reg = 1'b0;
    reg                                o_vs_reg = 1'b0;
    reg                                o_de_reg = 1'b0;

    wire [7:0]                         ascal_r;
    wire [7:0]                         ascal_g;
    wire [7:0]                         ascal_b;
    wire                               ascal_hs;
    wire                               ascal_vs;
    wire                               ascal_de;

    wire                               filter_axis = filter_write_index[10];
    wire [7:0]                         filter_phase = filter_write_index[9:2];
    wire [5:0]                         filter_source_phase = filter_phase[7:2];
    wire [1:0]                         filter_tap = filter_write_index[1:0];
    wire [11:0]                        filter_poly_a = {1'b0, filter_axis, filter_phase, filter_tap};
    wire [39:0]                        filter_phase_coeffs =
        filter_axis ? lcd_effect_01_v_filter_phase(filter_source_phase) :
                      lcd_effect_01_h_filter_phase(filter_source_phase);
    wire [23:0]                        palette_rgb =
        palette_6bpc_to_8bpc(palette_data);
    wire [23:0]                        palette_cell_rgb;
    wire [23:0]                        palette_border_rgb;
    wire [17:0]                        palette_history_source_q;
    wire [17:0]                        palette_history_q;
    wire [23:0]                        palette_history_rgb =
        palette_6bpc_to_8bpc(palette_history_q);
    wire [7:0]                         palette_cell_address;
    wire [7:0]                         palette_history_source_address;
    wire [16:0]                        palette_history_read_address;

    assign o_r = o_r_reg;
    assign o_g = o_g_reg;
    assign o_b = o_b_reg;
    assign o_hs = o_hs_reg;
    assign o_vs = o_vs_reg;
    assign o_de = o_de_reg;

    reg [9:0] filter_poly_dw;
    always @* begin
        case (filter_tap)
        2'd0: filter_poly_dw = filter_phase_coeffs[39:30];
        2'd1: filter_poly_dw = filter_phase_coeffs[29:20];
        2'd2: filter_poly_dw = filter_phase_coeffs[19:10];
        default: filter_poly_dw = filter_phase_coeffs[9:0];
        endcase
    end

    dpram_difclk #(8, 24, 8, 24) u_debug_palette_cell (
        .clk_a     (palette_clk),
        .address_a (palette_address),
        .data_a    (palette_rgb),
        .wren_a    (palette_write),
        .q_a       (),

        .clk_b     (o_clk),
        .enable_b  (o_ce),
        .address_b (palette_cell_address),
        .q_b       (palette_cell_rgb)
    );

    dpram_difclk #(8, 24, 8, 24) u_debug_palette_border (
        .clk_a     (palette_clk),
        .address_a (palette_address),
        .data_a    (palette_rgb),
        .wren_a    (palette_write),
        .q_a       (),

        .clk_b     (o_clk),
        .enable_b  (o_ce),
        .address_b (border_color_index_active),
        .q_b       (palette_border_rgb)
    );

    dpram_difclk #(8, 18, 8, 18) u_debug_palette_history_source (
        .clk_a     (palette_clk),
        .address_a (palette_address),
        .data_a    (palette_data),
        .wren_a    (palette_write),
        .q_a       (),

        .clk_b     (o_clk),
        .enable_b  (o_ce),
        .address_b (palette_history_source_address),
        .q_b       (palette_history_source_q)
    );

    dpram_difclk #(17, 18, 17, 18) u_debug_palette_history (
        .clk_a     (o_clk),
        .address_a (palette_history_write_address),
        .data_a    (palette_history_write_data),
        .wren_a    (palette_history_write_enable),
        .q_a       (),

        .clk_b     (o_clk),
        .enable_b  (o_ce),
        .address_b (palette_history_read_address),
        .q_b       (palette_history_q)
    );

    always @(posedge i_clk or negedge reset_na) begin
        if (!reset_na) begin
            filter_write_index <= '0;
            filter_write_cycle <= 2'd0;
            filter_loaded <= 1'b0;
            poly_a <= 12'd0;
            poly_dw <= 10'd0;
            poly_wr <= 1'b0;
        end else if (!filter_loaded) begin
            case (filter_write_cycle)
            2'd0: begin
                poly_a <= filter_poly_a;
                poly_dw <= filter_poly_dw;
                poly_wr <= 1'b1;
                filter_write_cycle <= 2'd1;
            end
            2'd1: begin
                poly_wr <= 1'b0;
                filter_write_cycle <= 2'd2;
            end
            default: begin
                poly_wr <= 1'b0;
                filter_write_cycle <= 2'd0;
                if (filter_write_index == FILTER_WRITE_LAST_INDEX) begin
                    filter_loaded <= 1'b1;
                end else begin
                    filter_write_index <= filter_write_index + 1'b1;
                end
            end
            endcase
        end else begin
            poly_wr <= 1'b0;
        end
    end

    always @(posedge o_clk or negedge reset_na) begin
        if (!reset_na) begin
            debug_display_mode_sync <= 2'b00;
            scaler_filter_disabled_sync <= 2'b00;
            debug_display_mode_active <= 1'b0;
            scaler_filter_disabled_active <= 1'b0;
            ascal_vs_last <= 1'b0;
            border_color_index_meta <= 8'd0;
            border_color_index_sync <= 8'd0;
            border_color_index_active <= 8'd0;
        end else begin
            debug_display_mode_sync <= {debug_display_mode_sync[0], debug_display_mode};
            scaler_filter_disabled_sync <= {scaler_filter_disabled_sync[0], scaler_filter_disabled};
            border_color_index_meta <= border_color_index;
            border_color_index_sync <= border_color_index_meta;
            ascal_vs_last <= ascal_vs;
            if (ascal_vs != ascal_vs_last) begin
                debug_display_mode_active <= debug_display_mode_sync[1];
                scaler_filter_disabled_active <= scaler_filter_disabled_sync[1];
                border_color_index_active <= border_color_index_sync;
            end
        end
    end

    wire [11:0] hdmi_hmin =
        debug_display_mode_active ? HDMI_HMIN_DEBUG : HDMI_HMIN_CENTERED;
    wire [11:0] hdmi_hmax =
        debug_display_mode_active ? HDMI_HMAX_DEBUG : HDMI_HMAX_CENTERED;

    wire debug_column_active = debug_display_mode_active && ascal_de &&
        active_x >= DEBUG_COLUMN_X &&
        active_x < DEBUG_COLUMN_X + DEBUG_COLUMN_WIDTH;
    wire panel_x_active =
        active_x >= DEBUG_PANEL_X && active_x < DEBUG_PANEL_X + DEBUG_PANEL_SIZE;
    wire panel_y_active =
        active_y >= DEBUG_PANEL_Y && active_y < DEBUG_PANEL_Y + DEBUG_PANEL_SIZE;
    wire panel_active = debug_display_mode_active && ascal_de &&
        panel_x_active && panel_y_active;
    wire [11:0] panel_x = active_x - DEBUG_PANEL_X;
    wire [11:0] panel_y = active_y - DEBUG_PANEL_Y;
    wire panel_border_active =
        panel_active &&
        (panel_x < DEBUG_PANEL_BORDER ||
         panel_x >= DEBUG_PANEL_SIZE - DEBUG_PANEL_BORDER ||
         panel_y < DEBUG_PANEL_BORDER ||
         panel_y >= DEBUG_PANEL_SIZE - DEBUG_PANEL_BORDER);
    wire grid_x_active =
        panel_x >= DEBUG_GRID_ORIGIN &&
        panel_x < DEBUG_GRID_ORIGIN + DEBUG_GRID_SIZE;
    wire grid_y_active =
        panel_y >= DEBUG_GRID_ORIGIN &&
        panel_y < DEBUG_GRID_ORIGIN + DEBUG_GRID_SIZE;
    wire [11:0] grid_x = panel_x - DEBUG_GRID_ORIGIN;
    wire [11:0] grid_y = panel_y - DEBUG_GRID_ORIGIN;
    wire [4:0] cell_col = debug_cell_coord(grid_x);
    wire [4:0] cell_row = debug_cell_coord(grid_y);
    wire palette_cell_active =
        panel_active && grid_x_active && grid_y_active &&
        !cell_col[4] && !cell_row[4];
    assign palette_cell_address = {cell_row[3:0], cell_col[3:0]};

    wire history_x_active =
        active_x >= DEBUG_HISTORY_X &&
        active_x < DEBUG_HISTORY_X + DEBUG_HISTORY_WIDTH;
    wire history_y_active =
        active_y >= DEBUG_HISTORY_Y && active_y < DEBUG_HISTORY_Y + DEBUG_HISTORY_HEIGHT;
    wire palette_history_active = debug_display_mode_active && ascal_de &&
        history_x_active && history_y_active;
    wire [11:0] history_x = active_x - DEBUG_HISTORY_X;
    wire [11:0] history_y = active_y - DEBUG_HISTORY_Y;
    wire [9:0] history_col_sum =
        {1'b0, palette_history_write_col} + {1'b0, history_x[8:0]};
    wire [9:0] history_col_wrapped =
        history_col_sum - {1'b0, DEBUG_HISTORY_COLS};
    wire [8:0] history_col =
        (history_col_sum >= {1'b0, DEBUG_HISTORY_COLS}) ?
        history_col_wrapped[8:0] :
        history_col_sum[8:0];
    assign palette_history_read_address = {history_col, history_y[8:1]};
    assign palette_history_source_address =
        (palette_history_capture_active &&
         palette_history_capture_count < 9'd256) ?
        palette_history_capture_count[7:0] : 8'd0;

    wire output_frame_start = ascal_vs && !coord_vs_last;

    always @(posedge o_clk or negedge reset_na) begin
        if (!reset_na) begin
            palette_history_write_col <= 9'd0;
            palette_history_capture_count <= 9'd0;
            palette_history_capture_entry <= 8'd0;
            palette_history_capture_active <= 1'b0;
            palette_history_capture_valid <= 1'b0;
            palette_history_write_address <= 17'd0;
            palette_history_write_data <= 18'd0;
            palette_history_write_enable <= 1'b0;
        end else if (o_ce) begin
            palette_history_write_enable <= 1'b0;

            if (output_frame_start) begin
                palette_history_capture_count <= 9'd1;
                palette_history_capture_entry <= 8'd0;
                palette_history_capture_active <= 1'b1;
                palette_history_capture_valid <= 1'b1;
            end else if (palette_history_capture_active) begin
                if (palette_history_capture_valid) begin
                    palette_history_write_address <=
                        {palette_history_write_col, palette_history_capture_entry};
                    palette_history_write_data <= palette_history_source_q;
                    palette_history_write_enable <= 1'b1;
                end

                if (palette_history_capture_count < 9'd256) begin
                    palette_history_capture_entry <= palette_history_capture_count[7:0];
                    palette_history_capture_valid <= 1'b1;
                    palette_history_capture_count <= palette_history_capture_count + 9'd1;
                end else begin
                    palette_history_capture_active <= 1'b0;
                    palette_history_capture_valid <= 1'b0;
                    palette_history_capture_count <= 9'd0;
                    if (palette_history_write_col == DEBUG_HISTORY_COLS - 9'd1) begin
                        palette_history_write_col <= 9'd0;
                    end else begin
                        palette_history_write_col <= palette_history_write_col + 9'd1;
                    end
                end
            end
        end
    end

    always @(posedge o_clk or negedge reset_na) begin
        if (!reset_na) begin
            active_x <= 12'd0;
            active_y <= 12'd0;
            active_frame_seen <= 1'b0;
            coord_de_last <= 1'b0;
            coord_vs_last <= 1'b0;
            ascal_r_d <= 8'd0;
            ascal_g_d <= 8'd0;
            ascal_b_d <= 8'd0;
            ascal_hs_d <= 1'b0;
            ascal_vs_d <= 1'b0;
            ascal_de_d <= 1'b0;
            palette_border_d <= 1'b0;
            palette_cell_d <= 1'b0;
            palette_history_d <= 1'b0;
            debug_column_d <= 1'b0;
            o_r_reg <= 8'd0;
            o_g_reg <= 8'd0;
            o_b_reg <= 8'd0;
            o_hs_reg <= 1'b0;
            o_vs_reg <= 1'b0;
            o_de_reg <= 1'b0;
        end else if (o_ce) begin
            if (palette_border_d) begin
                o_r_reg <= palette_border_rgb[23:16];
                o_g_reg <= palette_border_rgb[15:8];
                o_b_reg <= palette_border_rgb[7:0];
            end else if (palette_cell_d) begin
                o_r_reg <= palette_cell_rgb[23:16];
                o_g_reg <= palette_cell_rgb[15:8];
                o_b_reg <= palette_cell_rgb[7:0];
            end else if (palette_history_d) begin
                o_r_reg <= palette_history_rgb[23:16];
                o_g_reg <= palette_history_rgb[15:8];
                o_b_reg <= palette_history_rgb[7:0];
            end else if (debug_column_d) begin
                o_r_reg <= palette_border_rgb[23:16];
                o_g_reg <= palette_border_rgb[15:8];
                o_b_reg <= palette_border_rgb[7:0];
            end else begin
                o_r_reg <= ascal_r_d;
                o_g_reg <= ascal_g_d;
                o_b_reg <= ascal_b_d;
            end
            o_hs_reg <= ascal_hs_d;
            o_vs_reg <= ascal_vs_d;
            o_de_reg <= ascal_de_d;

            ascal_r_d <= ascal_r;
            ascal_g_d <= ascal_g;
            ascal_b_d <= ascal_b;
            ascal_hs_d <= ascal_hs;
            ascal_vs_d <= ascal_vs;
            ascal_de_d <= ascal_de;
            palette_border_d <= panel_border_active;
            palette_cell_d <= palette_cell_active;
            palette_history_d <= palette_history_active;
            debug_column_d <= debug_column_active;

            coord_de_last <= ascal_de;
            coord_vs_last <= ascal_vs;
            if (ascal_vs != coord_vs_last) begin
                active_x <= 12'd0;
                active_y <= 12'd0;
                active_frame_seen <= 1'b0;
            end else if (ascal_de) begin
                if (!coord_de_last) begin
                    active_x <= 12'd1;
                    if (active_frame_seen) begin
                        active_y <= active_y + 12'd1;
                    end else begin
                        active_frame_seen <= 1'b1;
                    end
                end else begin
                    active_x <= active_x + 12'd1;
                end
            end else begin
                active_x <= 12'd0;
            end
        end
    end

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

        .o_r(ascal_r),
        .o_g(ascal_g),
        .o_b(ascal_b),
        .o_hs(ascal_hs),
        .o_vs(ascal_vs),
        .o_de(ascal_de),
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
        .mode((filter_loaded && !scaler_filter_disabled_active) ? SCALE_MODE_POLYPHASE : SCALE_MODE_NEAREST),
        .bob_deint(1'b0),

        .htotal(HDMI_HTOTAL),
        .hsstart(HDMI_HSSTART),
        .hsend(HDMI_HSEND),
        .hdisp(HDMI_HDISP),
        .hmin(hdmi_hmin),
        .hmax(hdmi_hmax),
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
        .poly_dw(poly_dw),
        .poly_a(poly_a),
        .poly_wr(poly_wr),

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
