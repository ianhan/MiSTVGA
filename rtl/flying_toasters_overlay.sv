// Flying Toasters-style line-rendered sprite overlay.
`default_nettype none

module flying_toasters_overlay #(
    parameter SPRITE_MEM_FILE = "../../rtl/flying_toasters_sprite.mem",
    parameter int AREA_WIDTH = 1440,
    parameter int AREA_HEIGHT = 1080
) (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        ce,
    input  wire        frame_start,
    input  wire        line_start,
    input  wire        in_area,
    input  wire [11:0] x,
    input  wire [11:0] y,
    input  wire [11:0] active_width,
    input  wire [11:0] active_height,
    output wire        sprite_active,
    output wire [7:0]  sprite_r,
    output wire [7:0]  sprite_g,
    output wire [7:0]  sprite_b
);
    localparam int NUM_OBJECTS = 4;
    localparam int NUM_SAFE_SOURCE_OBJECTS = 35;
    localparam int SPRITE_SIZE = 64;
    localparam int SPRITE_PIXELS = SPRITE_SIZE * SPRITE_SIZE;
    localparam int SPRITE_FRAMES = 5;
    localparam int SPRITE_ROM_SIZE = 32768;
    localparam int RENDER_LANES = 4;
    localparam int MAX_ACTIVE_OBJECTS = 4;
    localparam int LOW_RES_ACTIVE_OBJECTS = 3;
    localparam int OBJECT_INDEX_WIDTH = $clog2(NUM_OBJECTS);
    localparam int OBJECT_COUNT_WIDTH = $clog2(NUM_OBJECTS + 1);
    localparam int LINE_BANK_DEPTH = AREA_WIDTH / RENDER_LANES;
    localparam int LINE_INDEX_WIDTH = $clog2(LINE_BANK_DEPTH);
    localparam [11:0] AREA_WIDTH_12 = 12'(AREA_WIDTH);
    localparam [11:0] AREA_HEIGHT_12 = 12'(AREA_HEIGHT);
    localparam int LAYOUT_WIDTH = 1440;
    localparam int LAYOUT_HEIGHT = 1080;
    localparam int TRAVEL_PIXELS = 1600;
    localparam int MIN_ACTIVE_WIDTH = 320;
    localparam int MIN_ACTIVE_HEIGHT = 200;
    localparam int LAYOUT_SAFE_MAX_X =
        ((MIN_ACTIVE_WIDTH - SPRITE_SIZE) * LAYOUT_WIDTH) / MIN_ACTIVE_WIDTH;
    localparam int LAYOUT_SAFE_MAX_Y =
        ((MIN_ACTIVE_HEIGHT - SPRITE_SIZE) * LAYOUT_HEIGHT) / MIN_ACTIVE_HEIGHT;
    localparam int LAYOUT_MIN_SPRITE_X =
        (SPRITE_SIZE * LAYOUT_WIDTH) / MIN_ACTIVE_WIDTH;
    localparam signed [13:0] LAYOUT_SAFE_MAX_X_S = 14'(LAYOUT_SAFE_MAX_X);
    localparam signed [13:0] LAYOUT_SAFE_MAX_Y_S = 14'(LAYOUT_SAFE_MAX_Y);
    localparam signed [13:0] LAYOUT_MIN_SPRITE_X_S = 14'(LAYOUT_MIN_SPRITE_X);
    localparam signed [13:0] TRAVEL_PIXELS_S = 14'(TRAVEL_PIXELS);
    localparam int SCALE_SHIFT = 24;
    localparam int X_SCALE_RECIP = ((1 << SCALE_SHIFT) + (LAYOUT_WIDTH / 2)) / LAYOUT_WIDTH;
    localparam int Y_SCALE_RECIP = ((1 << SCALE_SHIFT) + (LAYOUT_HEIGHT / 2)) / LAYOUT_HEIGHT;
    localparam int TRAVEL_FP = TRAVEL_PIXELS * 256;
    localparam int FAST_STEP_FP = 342;   // 1600px / 20s at 60Hz, Q8.
    localparam int MID_STEP_FP = 214;    // 1600px / 32s at 60Hz, Q8.
    localparam int SLOW_STEP_FP = 142;   // 1600px / 48s at 60Hz, Q8.

    reg [7:0] sprite_rom0 [0:SPRITE_ROM_SIZE-1];
    reg [7:0] sprite_rom1 [0:SPRITE_ROM_SIZE-1];
    reg [7:0] sprite_rom2 [0:SPRITE_ROM_SIZE-1];
    reg [7:0] sprite_rom3 [0:SPRITE_ROM_SIZE-1];
    reg [7:0] linebuf0_b0 [0:LINE_BANK_DEPTH-1];
    reg [7:0] linebuf0_b1 [0:LINE_BANK_DEPTH-1];
    reg [7:0] linebuf0_b2 [0:LINE_BANK_DEPTH-1];
    reg [7:0] linebuf0_b3 [0:LINE_BANK_DEPTH-1];
    reg [7:0] linebuf1_b0 [0:LINE_BANK_DEPTH-1];
    reg [7:0] linebuf1_b1 [0:LINE_BANK_DEPTH-1];
    reg [7:0] linebuf1_b2 [0:LINE_BANK_DEPTH-1];
    reg [7:0] linebuf1_b3 [0:LINE_BANK_DEPTH-1];

    initial begin
        $readmemh(SPRITE_MEM_FILE, sprite_rom0);
        $readmemh(SPRITE_MEM_FILE, sprite_rom1);
        $readmemh(SPRITE_MEM_FILE, sprite_rom2);
        $readmemh(SPRITE_MEM_FILE, sprite_rom3);
    end

    reg [20:0] travel_fp [0:NUM_OBJECTS-1];
    reg [5:0]  source_idx_reg [0:NUM_OBJECTS-1];
    reg [15:0] random_lfsr = 16'hace1;
    reg        random_seeded = 1'b0;
    reg [1:0]  flap_frame = 2'd0;
    reg [1:0]  flap_div = 2'd0;
    reg        flap_forward = 1'b1;

    integer update_idx;

    function automatic [15:0] advance_lfsr(input [15:0] state);
        begin
            advance_lfsr = {state[14:0], state[15] ^ state[13] ^ state[12] ^ state[10]};
        end
    endfunction

    function automatic [5:0] random_source_idx(input [5:0] value);
        reg [5:0] safe_value;
        begin
            safe_value = (value >= 6'(NUM_SAFE_SOURCE_OBJECTS)) ?
                value - 6'(NUM_SAFE_SOURCE_OBJECTS) : value;
            case (safe_value)
            6'd0: random_source_idx = 6'd0;
            6'd1: random_source_idx = 6'd1;
            6'd2: random_source_idx = 6'd2;
            6'd3: random_source_idx = 6'd3;
            6'd4: random_source_idx = 6'd4;
            6'd5: random_source_idx = 6'd5;
            6'd6: random_source_idx = 6'd6;
            6'd7: random_source_idx = 6'd7;
            6'd8: random_source_idx = 6'd10;
            6'd9: random_source_idx = 6'd11;
            6'd10: random_source_idx = 6'd12;
            6'd11: random_source_idx = 6'd13;
            6'd12: random_source_idx = 6'd14;
            6'd13: random_source_idx = 6'd16;
            6'd14: random_source_idx = 6'd17;
            6'd15: random_source_idx = 6'd21;
            6'd16: random_source_idx = 6'd22;
            6'd17: random_source_idx = 6'd24;
            6'd18: random_source_idx = 6'd26;
            6'd19: random_source_idx = 6'd27;
            6'd20: random_source_idx = 6'd28;
            6'd21: random_source_idx = 6'd29;
            6'd22: random_source_idx = 6'd31;
            6'd23: random_source_idx = 6'd32;
            6'd24: random_source_idx = 6'd33;
            6'd25: random_source_idx = 6'd34;
            6'd26: random_source_idx = 6'd36;
            6'd27: random_source_idx = 6'd37;
            6'd28: random_source_idx = 6'd39;
            6'd29: random_source_idx = 6'd40;
            6'd30: random_source_idx = 6'd41;
            6'd31: random_source_idx = 6'd42;
            6'd32: random_source_idx = 6'd45;
            6'd33: random_source_idx = 6'd46;
            default: random_source_idx = 6'd47;
            endcase
        end
    endfunction

    function automatic [5:0] initial_source_idx(input integer idx);
        begin
            case (idx)
            0: initial_source_idx = 6'd0;
            1: initial_source_idx = 6'd13;
            2: initial_source_idx = 6'd27;
            default: initial_source_idx = 6'd41;
            endcase
        end
    endfunction

    function automatic signed [13:0] object_start_x(input integer idx);
        begin
            case (idx)
            0: object_start_x = 14'sd1405;
            1: object_start_x = 14'sd1232;
            2: object_start_x = 14'sd1088;
            3: object_start_x = 14'sd944;
            4: object_start_x = 14'sd656;
            5: object_start_x = 14'sd512;
            6: object_start_x = 14'sd1621;
            7: object_start_x = 14'sd1650;
            8: object_start_x = 14'sd1707;
            9: object_start_x = 14'sd1736;
            10: object_start_x = 14'sd1232;
            11: object_start_x = 14'sd1088;
            12: object_start_x = 14'sd944;
            13: object_start_x = 14'sd1750;
            14: object_start_x = 14'sd800;
            15: object_start_x = 14'sd1794;
            16: object_start_x = 14'sd1232;
            17: object_start_x = 14'sd944;
            18: object_start_x = 14'sd2038;
            19: object_start_x = 14'sd2182;
            20: object_start_x = 14'sd2082;
            21: object_start_x = 14'sd1376;
            22: object_start_x = 14'sd800;
            23: object_start_x = 14'sd1894;
            24: object_start_x = 14'sd1088;
            25: object_start_x = 14'sd1678;
            26: object_start_x = 14'sd1376;
            27: object_start_x = 14'sd800;
            28: object_start_x = 14'sd1405;
            29: object_start_x = 14'sd656;
            30: object_start_x = 14'sd1678;
            31: object_start_x = 14'sd1232;
            32: object_start_x = 14'sd512;
            33: object_start_x = 14'sd800;
            34: object_start_x = 14'sd512;
            35: object_start_x = 14'sd1678;
            36: object_start_x = 14'sd1232;
            37: object_start_x = 14'sd512;
            38: object_start_x = 14'sd1707;
            39: object_start_x = 14'sd1088;
            40: object_start_x = 14'sd1750;
            41: object_start_x = 14'sd1088;
            42: object_start_x = 14'sd1621;
            43: object_start_x = 14'sd1736;
            44: object_start_x = 14'sd1894;
            45: object_start_x = 14'sd1650;
            46: object_start_x = 14'sd1376;
            47: object_start_x = 14'sd944;
            48: object_start_x = 14'sd1794;
            default: object_start_x = 14'sd0;
            endcase
        end
    endfunction

    function automatic signed [13:0] object_start_y(input integer idx);
        begin
            case (idx)
            0: object_start_y = -14'sd184;
            1: object_start_y = -14'sd205;
            2: object_start_y = -14'sd194;
            3: object_start_y = -14'sd216;
            4: object_start_y = -14'sd194;
            5: object_start_y = -14'sd216;
            6: object_start_y = 14'sd108;
            7: object_start_y = 14'sd216;
            8: object_start_y = 14'sd540;
            9: object_start_y = 14'sd756;
            10: object_start_y = -14'sd216;
            11: object_start_y = -14'sd389;
            12: object_start_y = -14'sd259;
            13: object_start_y = 14'sd108;
            14: object_start_y = -14'sd356;
            15: object_start_y = 14'sd540;
            16: object_start_y = -14'sd605;
            17: object_start_y = -14'sd648;
            18: object_start_y = 14'sd108;
            19: object_start_y = 14'sd216;
            20: object_start_y = 14'sd324;
            21: object_start_y = -14'sd497;
            22: object_start_y = -14'sd227;
            23: object_start_y = 14'sd324;
            24: object_start_y = -14'sd529;
            25: object_start_y = 14'sd324;
            26: object_start_y = -14'sd281;
            27: object_start_y = -14'sd356;
            28: object_start_y = -14'sd184;
            29: object_start_y = -14'sd194;
            30: object_start_y = 14'sd324;
            31: object_start_y = -14'sd216;
            32: object_start_y = -14'sd432;
            33: object_start_y = -14'sd227;
            34: object_start_y = -14'sd432;
            35: object_start_y = 14'sd324;
            36: object_start_y = -14'sd205;
            37: object_start_y = -14'sd216;
            38: object_start_y = 14'sd540;
            39: object_start_y = -14'sd389;
            40: object_start_y = 14'sd108;
            41: object_start_y = -14'sd194;
            42: object_start_y = 14'sd108;
            43: object_start_y = 14'sd756;
            44: object_start_y = 14'sd324;
            45: object_start_y = 14'sd216;
            46: object_start_y = -14'sd281;
            47: object_start_y = -14'sd259;
            48: object_start_y = 14'sd540;
            default: object_start_y = 14'sd0;
            endcase
        end
    endfunction

    function automatic [20:0] object_step_fp(input integer idx);
        begin
            case (idx)
            0, 2, 4, 9, 13, 14, 16, 19, 21, 22, 23, 24:
                object_step_fp = 21'(FAST_STEP_FP);
            6, 8, 10, 12, 15, 17, 18:
                object_step_fp = 21'(MID_STEP_FP);
            default:
                object_step_fp = 21'(SLOW_STEP_FP);
            endcase
        end
    endfunction

    function automatic [10:0] object_visible_enter_px(input integer idx);
        reg signed [13:0] enter_x;
        reg signed [13:0] enter_y;
        reg signed [13:0] enter_px;
        begin
            enter_x = object_start_x(idx) - LAYOUT_SAFE_MAX_X_S;
            enter_y = -object_start_y(idx);
            enter_px = 14'sd0;
            if (enter_x > enter_px) begin
                enter_px = enter_x;
            end
            if (enter_y > enter_px) begin
                enter_px = enter_y;
            end
            if (enter_px > TRAVEL_PIXELS_S) begin
                object_visible_enter_px = 11'(TRAVEL_PIXELS);
            end else begin
                object_visible_enter_px = enter_px[10:0];
            end
        end
    endfunction

    function automatic [10:0] object_full_visible_exit_px(input integer idx);
        reg signed [13:0] exit_x;
        reg signed [13:0] exit_y;
        reg signed [13:0] exit_px;
        begin
            exit_x = object_start_x(idx);
            exit_y = LAYOUT_SAFE_MAX_Y_S - object_start_y(idx);
            exit_px = TRAVEL_PIXELS_S;
            if (exit_x < exit_px) begin
                exit_px = exit_x;
            end
            if (exit_y < exit_px) begin
                exit_px = exit_y;
            end
            if (exit_px < 14'sd0) begin
                object_full_visible_exit_px = 11'd0;
            end else begin
                object_full_visible_exit_px = exit_px[10:0];
            end
        end
    endfunction

    function automatic [10:0] object_offscreen_exit_px(input integer idx);
        reg signed [13:0] exit_x;
        reg signed [13:0] exit_y;
        reg signed [13:0] exit_px;
        begin
            exit_x = object_start_x(idx) + LAYOUT_MIN_SPRITE_X_S;
            exit_y = 14'(LAYOUT_HEIGHT) - object_start_y(idx);
            exit_px = TRAVEL_PIXELS_S;
            if (exit_x < exit_px) begin
                exit_px = exit_x;
            end
            if (exit_y < exit_px) begin
                exit_px = exit_y;
            end
            if (exit_px < 14'sd0) begin
                object_offscreen_exit_px = 11'd0;
            end else begin
                object_offscreen_exit_px = exit_px[10:0];
            end
        end
    endfunction

    function automatic [5:0] random_source_for_slot(
        input [15:0] state,
        input integer slot
    );
        reg [15:0] mixed;
        reg [5:0]  source_value;
        begin
            case (slot)
            0: mixed = state ^ 16'h4d25;
            1: mixed = {state[7:0], state[15:8]} ^ 16'h9e37;
            2: mixed = {state[4:0], state[15:5]} ^ 16'hb529;
            default: mixed = {state[10:0], state[15:11]} ^ 16'h68e3;
            endcase
            source_value = mixed[5:0] ^ mixed[11:6];
            random_source_for_slot = random_source_idx(source_value);
        end
    endfunction

    function automatic [20:0] object_visible_exit_fp(input integer idx);
        begin
            object_visible_exit_fp =
                {2'b00, object_offscreen_exit_px(idx), 8'd0};
        end
    endfunction

    function automatic [20:0] object_visible_enter_fp(input integer idx);
        begin
            object_visible_enter_fp = {2'b00, object_visible_enter_px(idx), 8'd0};
        end
    endfunction

    function automatic [20:0] random_initial_visible_travel_fp(
        input [15:0] state,
        input integer slot,
        input integer idx
    );
        reg [10:0] enter_px;
        reg [10:0] exit_px;
        reg [10:0] span_px;
        reg [10:0] offset_px;
        reg [1:0]  phase_sel;
            begin
            enter_px = object_visible_enter_px(idx);
            exit_px = object_full_visible_exit_px(idx);
            phase_sel = state[slot +: 2] ^ state[slot + 4 +: 2];
            if (exit_px > enter_px) begin
                span_px = exit_px - enter_px;
                case (phase_sel)
                2'd0: offset_px = span_px >> 2;
                2'd1: offset_px = span_px >> 1;
                2'd2: offset_px = span_px - (span_px >> 2);
                default: offset_px = 11'd0;
                endcase
            end else begin
                offset_px = 11'd0;
            end
            random_initial_visible_travel_fp = {2'b00, enter_px + offset_px, 8'd0};
        end
    endfunction

    function automatic object_reverse_flap(input integer idx);
        begin
            case (idx)
            6, 12, 18, 25, 26, 27, 36, 37, 38, 39, 40, 45, 46, 47, 48:
                object_reverse_flap = 1'b1;
            default:
                object_reverse_flap = 1'b0;
            endcase
        end
    endfunction

    function automatic [24:0] palette_entry(input [7:0] idx);
        begin
            case (idx)
            8'd1: palette_entry = {1'b1, 24'heeeeee};
            8'd2: palette_entry = {1'b1, 24'hffffff};
            8'd3: palette_entry = {1'b1, 24'hcccccc};
            8'd4: palette_entry = {1'b1, 24'h999999};
            8'd5: palette_entry = {1'b1, 24'h000000};
            8'd6: palette_entry = {1'b1, 24'h333300};
            8'd7: palette_entry = {1'b1, 24'h663300};
            8'd8: palette_entry = {1'b1, 24'h111111};
            8'd9: palette_entry = {1'b1, 24'h666633};
            8'd10: palette_entry = {1'b1, 24'hcc3300};
            8'd11: palette_entry = {1'b1, 24'h878787};
            8'd12: palette_entry = {1'b1, 24'hbababa};
            8'd13: palette_entry = {1'b1, 24'h545454};
            8'd14: palette_entry = {1'b1, 24'h666666};
            8'd15: palette_entry = {1'b1, 24'hffcc66};
            8'd16: palette_entry = {1'b1, 24'hffff99};
            8'd17: palette_entry = {1'b1, 24'hcc9933};
            8'd18: palette_entry = {1'b1, 24'h996600};
            8'd19: palette_entry = {1'b1, 24'hcc6600};
            default: palette_entry = {1'b0, 24'h000000};
            endcase
        end
    endfunction

    function automatic [LINE_INDEX_WIDTH-1:0] line_addr(input [11:0] px);
        begin
            line_addr = px[LINE_INDEX_WIDTH+1:2];
        end
    endfunction

    function automatic signed [13:0] scale_x_product_to_coord(
        input signed [27:0] product
    );
        reg signed [47:0] scaled;
        reg signed [47:0] shifted;
        begin
            scaled = product * X_SCALE_RECIP;
            shifted = scaled >>> SCALE_SHIFT;
            scale_x_product_to_coord = shifted[13:0];
        end
    endfunction

    function automatic signed [13:0] scale_y_product_to_coord(
        input signed [27:0] product
    );
        reg signed [47:0] scaled;
        reg signed [47:0] shifted;
        begin
            scaled = product * Y_SCALE_RECIP;
            shifted = scaled >>> SCALE_SHIFT;
            scale_y_product_to_coord = shifted[13:0];
        end
    endfunction

    function automatic [OBJECT_COUNT_WIDTH-1:0] object_count_for_height(input [11:0] height);
        begin
            if (height <= 12'd240) begin
                object_count_for_height = OBJECT_COUNT_WIDTH'(LOW_RES_ACTIVE_OBJECTS);
            end else begin
                object_count_for_height = OBJECT_COUNT_WIDTH'(MAX_ACTIVE_OBJECTS);
            end
        end
    endfunction

    wire [15:0] frame_random_lfsr =
        advance_lfsr(random_lfsr ^ {active_width[7:0], active_height[7:0]});

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            flap_frame <= 2'd0;
            flap_div <= 2'd0;
            flap_forward <= 1'b1;
            random_lfsr <= 16'hace1;
            random_seeded <= 1'b0;
            for (update_idx = 0; update_idx < NUM_OBJECTS; update_idx = update_idx + 1) begin
                travel_fp[update_idx] <= 21'd0;
                source_idx_reg[update_idx] <= initial_source_idx(update_idx);
            end
        end else if (ce && frame_start) begin
            random_lfsr <= frame_random_lfsr;
            random_seeded <= 1'b1;

            if (flap_div == 2'd2) begin
                flap_div <= 2'd0;
                if (flap_forward) begin
                    if (flap_frame == 2'd3) begin
                        flap_forward <= 1'b0;
                        flap_frame <= 2'd2;
                    end else begin
                        flap_frame <= flap_frame + 2'd1;
                    end
                end else begin
                    if (flap_frame == 2'd0) begin
                        flap_forward <= 1'b1;
                        flap_frame <= 2'd1;
                    end else begin
                        flap_frame <= flap_frame - 2'd1;
                    end
                end
            end else begin
                flap_div <= flap_div + 2'd1;
            end

            for (update_idx = 0; update_idx < NUM_OBJECTS; update_idx = update_idx + 1) begin
                if (!random_seeded) begin
                    reg [5:0] next_source_idx;

                    next_source_idx = random_source_for_slot(frame_random_lfsr, update_idx);
                    source_idx_reg[update_idx] <= next_source_idx;
                    travel_fp[update_idx] <= random_initial_visible_travel_fp(
                        frame_random_lfsr,
                        update_idx,
                        int'(next_source_idx)
                    );
                end else if (travel_fp[update_idx] + object_step_fp(int'(source_idx_reg[update_idx])) >=
                             object_visible_exit_fp(int'(source_idx_reg[update_idx]))) begin
                    reg [5:0] next_source_idx;

                    next_source_idx = random_source_for_slot(frame_random_lfsr, update_idx);
                    source_idx_reg[update_idx] <= next_source_idx;
                    travel_fp[update_idx] <= object_visible_enter_fp(int'(next_source_idx));
                end else begin
                    travel_fp[update_idx] <= travel_fp[update_idx] + object_step_fp(int'(source_idx_reg[update_idx]));
                end
            end
        end
    end

    localparam [2:0] RENDER_IDLE        = 3'd0;
    localparam [2:0] RENDER_CLEAR       = 3'd1;
    localparam [2:0] RENDER_OBJECT      = 3'd2;
    localparam [2:0] RENDER_SCALE_AREA  = 3'd3;
    localparam [2:0] RENDER_SCALE_COORD = 3'd4;
    localparam [2:0] RENDER_OBJECT_TEST = 3'd5;
    localparam [2:0] RENDER_PIXELS      = 3'd6;

    reg [2:0]  render_state = RENDER_IDLE;
    reg        render_buf = 1'b0;
    reg        display_buf = 1'b0;
    reg [11:0] render_y = 12'd0;
    reg [11:0] render_width = AREA_WIDTH_12;
    reg [11:0] render_height = AREA_HEIGHT_12;
    reg [OBJECT_COUNT_WIDTH-1:0] render_object_count = OBJECT_COUNT_WIDTH'(NUM_OBJECTS);
    reg [11:0] clear_x_base = 12'd0;
    reg [OBJECT_INDEX_WIDTH-1:0] render_obj_idx = '0;
    reg [5:0]  render_source_idx = 6'd0;
    reg signed [13:0] scale_obj_x_raw = 14'sd0;
    reg signed [13:0] scale_obj_y_raw = 14'sd0;
    reg signed [13:0] scale_line_y = 14'sd0;
    reg [1:0]  scale_toaster_frame = 2'd0;
    reg signed [27:0] scale_x_area = 28'sd0;
    reg signed [27:0] scale_y_area = 28'sd0;
    reg signed [13:0] scale_obj_x = 14'sd0;
    reg signed [13:0] scale_obj_y = 14'sd0;
    reg signed [13:0] render_obj_x = 14'sd0;
    reg [5:0]  render_rel_y = 6'd0;
    reg [2:0]  render_frame = 3'd0;
    reg [6:0]  render_rel_x_base = 7'd0;
    reg        render_write_pending = 1'b0;
    reg        render_write_buf = 1'b0;
    reg [3:0]  render_write_valid = 4'b0000;
    reg [11:0] render_write_x0 = 12'd0;
    reg [11:0] render_write_x1 = 12'd0;
    reg [11:0] render_write_x2 = 12'd0;
    reg [11:0] render_write_x3 = 12'd0;
    reg [7:0]  render_sprite_q0 = 8'd0;
    reg [7:0]  render_sprite_q1 = 8'd0;
    reg [7:0]  render_sprite_q2 = 8'd0;
    reg [7:0]  render_sprite_q3 = 8'd0;
    reg [7:0]  sprite_index_q = 8'd0;
    reg        sprite_valid_q = 1'b0;

    wire [11:0] visible_width =
        (active_width != 12'd0 && active_width <= AREA_WIDTH_12) ?
        active_width : AREA_WIDTH_12;
    wire [11:0] visible_height =
        (active_height != 12'd0 && active_height <= AREA_HEIGHT_12) ?
        active_height : AREA_HEIGHT_12;
    wire [24:0] sprite_palette = palette_entry(sprite_index_q);
    wire        read_buf = line_start ? y[0] : display_buf;
    wire        read_active = in_area && x < visible_width;
    wire [LINE_INDEX_WIDTH-1:0] read_addr = line_addr(x);

    task automatic write_line_pixel;
        input        line_buf;
        input [11:0] px;
        input [7:0]  value;
        begin
            case ({line_buf, px[1:0]})
            3'd0: linebuf0_b0[line_addr(px)] <= value;
            3'd1: linebuf0_b1[line_addr(px)] <= value;
            3'd2: linebuf0_b2[line_addr(px)] <= value;
            3'd3: linebuf0_b3[line_addr(px)] <= value;
            3'd4: linebuf1_b0[line_addr(px)] <= value;
            3'd5: linebuf1_b1[line_addr(px)] <= value;
            3'd6: linebuf1_b2[line_addr(px)] <= value;
            default: linebuf1_b3[line_addr(px)] <= value;
            endcase
        end
    endtask

    task automatic start_render_line;
        input        line_buf;
        input [11:0] line_y;
        begin
            render_buf <= line_buf;
            render_y <= line_y;
            render_width <= visible_width;
            render_height <= visible_height;
            render_object_count <= object_count_for_height(visible_height);
            clear_x_base <= 12'd0;
            render_obj_idx <= OBJECT_INDEX_WIDTH'(object_count_for_height(visible_height) - 1'b1);
            render_write_pending <= 1'b0;
            render_state <= RENDER_CLEAR;
        end
    endtask

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            render_state <= RENDER_IDLE;
            render_buf <= 1'b0;
            display_buf <= 1'b0;
            render_y <= 12'd0;
            render_width <= AREA_WIDTH_12;
            render_height <= AREA_HEIGHT_12;
            render_object_count <= OBJECT_COUNT_WIDTH'(NUM_OBJECTS);
            clear_x_base <= 12'd0;
            render_obj_idx <= '0;
            render_source_idx <= 6'd0;
            scale_obj_x_raw <= 14'sd0;
            scale_obj_y_raw <= 14'sd0;
            scale_line_y <= 14'sd0;
            scale_toaster_frame <= 2'd0;
            scale_x_area <= 28'sd0;
            scale_y_area <= 28'sd0;
            scale_obj_x <= 14'sd0;
            scale_obj_y <= 14'sd0;
            render_obj_x <= 14'sd0;
            render_rel_y <= 6'd0;
            render_frame <= 3'd0;
            render_rel_x_base <= 7'd0;
            render_write_pending <= 1'b0;
            render_write_buf <= 1'b0;
            render_write_valid <= 4'b0000;
            render_write_x0 <= 12'd0;
            render_write_x1 <= 12'd0;
            render_write_x2 <= 12'd0;
            render_write_x3 <= 12'd0;
            render_sprite_q0 <= 8'd0;
            render_sprite_q1 <= 8'd0;
            render_sprite_q2 <= 8'd0;
            render_sprite_q3 <= 8'd0;
            sprite_index_q <= 8'd0;
            sprite_valid_q <= 1'b0;
        end else if (ce) begin
            if (read_active) begin
                sprite_valid_q <= 1'b1;
                case ({read_buf, x[1:0]})
                3'd0: sprite_index_q <= linebuf0_b0[read_addr];
                3'd1: sprite_index_q <= linebuf0_b1[read_addr];
                3'd2: sprite_index_q <= linebuf0_b2[read_addr];
                3'd3: sprite_index_q <= linebuf0_b3[read_addr];
                3'd4: sprite_index_q <= linebuf1_b0[read_addr];
                3'd5: sprite_index_q <= linebuf1_b1[read_addr];
                3'd6: sprite_index_q <= linebuf1_b2[read_addr];
                default: sprite_index_q <= linebuf1_b3[read_addr];
                endcase
            end else begin
                sprite_valid_q <= 1'b0;
                sprite_index_q <= 8'd0;
            end

            if (line_start) begin
                display_buf <= y[0];
            end

            if (render_write_pending) begin
                if (render_write_valid[0] && render_sprite_q0 != 8'd0) begin
                    write_line_pixel(render_write_buf, render_write_x0, render_sprite_q0);
                end
                if (render_write_valid[1] && render_sprite_q1 != 8'd0) begin
                    write_line_pixel(render_write_buf, render_write_x1, render_sprite_q1);
                end
                if (render_write_valid[2] && render_sprite_q2 != 8'd0) begin
                    write_line_pixel(render_write_buf, render_write_x2, render_sprite_q2);
                end
                if (render_write_valid[3] && render_sprite_q3 != 8'd0) begin
                    write_line_pixel(render_write_buf, render_write_x3, render_sprite_q3);
                end
                render_write_pending <= 1'b0;
            end

            if (frame_start) begin
                start_render_line(1'b0, 12'd0);
            end else if (line_start && y < visible_height - 12'd1) begin
                start_render_line(~y[0], y + 12'd1);
            end else begin
                case (render_state)
                RENDER_IDLE: begin
                    render_write_pending <= 1'b0;
                end

                RENDER_CLEAR: begin
                    write_line_pixel(render_buf, clear_x_base, 8'd0);
                    write_line_pixel(render_buf, clear_x_base + 12'd1, 8'd0);
                    write_line_pixel(render_buf, clear_x_base + 12'd2, 8'd0);
                    write_line_pixel(render_buf, clear_x_base + 12'd3, 8'd0);
                    if (clear_x_base + 12'd4 >= render_width) begin
                        render_obj_idx <= OBJECT_INDEX_WIDTH'(render_object_count - 1'b1);
                        render_state <= RENDER_OBJECT;
                    end else begin
                        clear_x_base <= clear_x_base + 12'd4;
                    end
                end

                RENDER_OBJECT: begin
                    integer source_idx;
                    reg signed [13:0] travel_raw;

                    source_idx = int'(source_idx_reg[render_obj_idx]);
                    travel_raw = $signed({1'b0, travel_fp[render_obj_idx][20:8]});
                    render_source_idx <= 6'(source_idx);
                    scale_obj_x_raw <= object_start_x(source_idx) - travel_raw;
                    scale_obj_y_raw <= object_start_y(source_idx) + travel_raw;
                    scale_line_y <= $signed({2'b00, render_y});
                    scale_toaster_frame <=
                        object_reverse_flap(source_idx) ? (2'd3 - flap_frame) : flap_frame;
                    render_state <= RENDER_SCALE_AREA;
                end

                RENDER_SCALE_AREA: begin
                    scale_x_area <= scale_obj_x_raw * $signed({1'b0, render_width});
                    scale_y_area <= scale_obj_y_raw * $signed({1'b0, render_height});
                    render_state <= RENDER_SCALE_COORD;
                end

                RENDER_SCALE_COORD: begin
                    scale_obj_x <= scale_x_product_to_coord(scale_x_area);
                    scale_obj_y <= scale_y_product_to_coord(scale_y_area);
                    render_state <= RENDER_OBJECT_TEST;
                end

                RENDER_OBJECT_TEST: begin
                    reg signed [13:0] rel_y_signed;

                    rel_y_signed = scale_line_y - scale_obj_y;

                    if (rel_y_signed >= 14'sd0 && rel_y_signed < 14'sd64) begin
                        render_obj_x <= scale_obj_x;
                        render_rel_y <= rel_y_signed[5:0];
                        render_frame <= {1'b0, scale_toaster_frame};
                        render_rel_x_base <= 7'd0;
                        render_state <= RENDER_PIXELS;
                    end else if (render_obj_idx == '0) begin
                        render_state <= RENDER_IDLE;
                    end else begin
                        render_obj_idx <= render_obj_idx - 1'b1;
                    end
                end

                RENDER_PIXELS: begin
                    reg [5:0] rel_x0;
                    reg [5:0] rel_x1;
                    reg [5:0] rel_x2;
                    reg [5:0] rel_x3;
                    reg signed [13:0] dest_x0;
                    reg signed [13:0] dest_x1;
                    reg signed [13:0] dest_x2;
                    reg signed [13:0] dest_x3;
                    reg signed [13:0] render_width_signed;

                    rel_x0 = render_rel_x_base[5:0];
                    rel_x1 = render_rel_x_base[5:0] + 6'd1;
                    rel_x2 = render_rel_x_base[5:0] + 6'd2;
                    rel_x3 = render_rel_x_base[5:0] + 6'd3;
                    render_width_signed = $signed({2'b00, render_width});
                    dest_x0 = render_obj_x + $signed({8'd0, rel_x0});
                    dest_x1 = render_obj_x + $signed({8'd0, rel_x1});
                    dest_x2 = render_obj_x + $signed({8'd0, rel_x2});
                    dest_x3 = render_obj_x + $signed({8'd0, rel_x3});

                    render_sprite_q0 <= sprite_rom0[{render_frame, render_rel_y, rel_x0}];
                    render_sprite_q1 <= sprite_rom1[{render_frame, render_rel_y, rel_x1}];
                    render_sprite_q2 <= sprite_rom2[{render_frame, render_rel_y, rel_x2}];
                    render_sprite_q3 <= sprite_rom3[{render_frame, render_rel_y, rel_x3}];
                    render_write_buf <= render_buf;
                    render_write_valid[0] <= dest_x0 >= 14'sd0 && dest_x0 < render_width_signed;
                    render_write_valid[1] <= dest_x1 >= 14'sd0 && dest_x1 < render_width_signed;
                    render_write_valid[2] <= dest_x2 >= 14'sd0 && dest_x2 < render_width_signed;
                    render_write_valid[3] <= dest_x3 >= 14'sd0 && dest_x3 < render_width_signed;
                    render_write_x0 <= dest_x0[11:0];
                    render_write_x1 <= dest_x1[11:0];
                    render_write_x2 <= dest_x2[11:0];
                    render_write_x3 <= dest_x3[11:0];
                    render_write_pending <= 1'b1;

                    if (render_rel_x_base == 7'd60) begin
                        if (render_obj_idx == '0) begin
                            render_state <= RENDER_IDLE;
                        end else begin
                            render_obj_idx <= render_obj_idx - 1'b1;
                            render_state <= RENDER_OBJECT;
                        end
                    end else begin
                        render_rel_x_base <= render_rel_x_base + 7'd4;
                    end
                end

                default: begin
                    render_state <= RENDER_IDLE;
                end
                endcase
            end
        end
    end

    assign sprite_active = sprite_valid_q && sprite_palette[24];
    assign sprite_r = sprite_palette[23:16];
    assign sprite_g = sprite_palette[15:8];
    assign sprite_b = sprite_palette[7:0];
endmodule

`default_nettype wire
