// Shared VGA DAC conversion helpers.
// Constant table for ((x * 259 + 33) >> 6), avoiding inferred multipliers.

module dac_6bpc_to_8bpc (
    input  wire [5:0] value6,
    output reg  [7:0] value8
);
    always @* begin
        case (value6)
            6'd0 : value8 = 8'd0;
            6'd1 : value8 = 8'd4;
            6'd2 : value8 = 8'd8;
            6'd3 : value8 = 8'd12;
            6'd4 : value8 = 8'd16;
            6'd5 : value8 = 8'd20;
            6'd6 : value8 = 8'd24;
            6'd7 : value8 = 8'd28;
            6'd8 : value8 = 8'd32;
            6'd9 : value8 = 8'd36;
            6'd10: value8 = 8'd40;
            6'd11: value8 = 8'd45;
            6'd12: value8 = 8'd49;
            6'd13: value8 = 8'd53;
            6'd14: value8 = 8'd57;
            6'd15: value8 = 8'd61;
            6'd16: value8 = 8'd65;
            6'd17: value8 = 8'd69;
            6'd18: value8 = 8'd73;
            6'd19: value8 = 8'd77;
            6'd20: value8 = 8'd81;
            6'd21: value8 = 8'd85;
            6'd22: value8 = 8'd89;
            6'd23: value8 = 8'd93;
            6'd24: value8 = 8'd97;
            6'd25: value8 = 8'd101;
            6'd26: value8 = 8'd105;
            6'd27: value8 = 8'd109;
            6'd28: value8 = 8'd113;
            6'd29: value8 = 8'd117;
            6'd30: value8 = 8'd121;
            6'd31: value8 = 8'd125;
            6'd32: value8 = 8'd130;
            6'd33: value8 = 8'd134;
            6'd34: value8 = 8'd138;
            6'd35: value8 = 8'd142;
            6'd36: value8 = 8'd146;
            6'd37: value8 = 8'd150;
            6'd38: value8 = 8'd154;
            6'd39: value8 = 8'd158;
            6'd40: value8 = 8'd162;
            6'd41: value8 = 8'd166;
            6'd42: value8 = 8'd170;
            6'd43: value8 = 8'd174;
            6'd44: value8 = 8'd178;
            6'd45: value8 = 8'd182;
            6'd46: value8 = 8'd186;
            6'd47: value8 = 8'd190;
            6'd48: value8 = 8'd194;
            6'd49: value8 = 8'd198;
            6'd50: value8 = 8'd202;
            6'd51: value8 = 8'd206;
            6'd52: value8 = 8'd210;
            6'd53: value8 = 8'd215;
            6'd54: value8 = 8'd219;
            6'd55: value8 = 8'd223;
            6'd56: value8 = 8'd227;
            6'd57: value8 = 8'd231;
            6'd58: value8 = 8'd235;
            6'd59: value8 = 8'd239;
            6'd60: value8 = 8'd243;
            6'd61: value8 = 8'd247;
            6'd62: value8 = 8'd251;
            6'd63: value8 = 8'd255;
        endcase
    end
endmodule

module palette_6bpc_to_8bpc (
    input  wire [17:0] rgb6,
    output wire [23:0] rgb8
);
    dac_6bpc_to_8bpc u_red (
        .value6 (rgb6[17:12]),
        .value8 (rgb8[23:16])
    );

    dac_6bpc_to_8bpc u_green (
        .value6 (rgb6[11:6]),
        .value8 (rgb8[15:8])
    );

    dac_6bpc_to_8bpc u_blue (
        .value6 (rgb6[5:0]),
        .value8 (rgb8[7:0])
    );
endmodule
