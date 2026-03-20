module a2gx_i2c_hdmi_config (
    input  iCLK,
    input  iRST_N,
    output I2C_SCLK,
    inout  I2C_SDAT,
    input  HDMI_TX_INT,
    output reg READY
);

parameter CLK_FREQ = 50000000;
parameter I2C_FREQ = 20000;
parameter LUT_SIZE = 11;
localparam integer I2C_STEP_DIV = (CLK_FREQ / I2C_FREQ) * 2;

reg [15:0] mI2C_CLK_DIV = 16'd0;
reg [23:0] mI2C_DATA = 24'd0;
reg        mI2C_GO = 1'b0;
reg [15:0] LUT_DATA = 16'd0;
reg [5:0]  LUT_INDEX = 6'd0;
reg [3:0]  mSetup_ST = 4'd0;
reg [15:0] counter_100us = 16'd0;
reg        mI2C_STEP = 1'b0;

wire mI2C_END;
wire mI2C_ACK;

always @(*) begin
    case (LUT_INDEX)
        6'd0: LUT_DATA = 16'h0000;
        6'd1: LUT_DATA = 16'h041f;
        6'd2: LUT_DATA = 16'h0400;
        6'd3: LUT_DATA = 16'hc000;
        6'd4: LUT_DATA = 16'h0407;
        6'd5: LUT_DATA = 16'h6110;
        6'd6: LUT_DATA = 16'h6288;
        6'd7: LUT_DATA = 16'h6310;
        6'd8: LUT_DATA = 16'h6484;
        6'd9: LUT_DATA = 16'h6100;
        6'd10: LUT_DATA = 16'hc100;
        default: LUT_DATA = 16'h0000;
    endcase
end

always @(posedge iCLK or negedge iRST_N) begin
    if (!iRST_N) begin
        mI2C_CLK_DIV <= 16'd0;
        mI2C_STEP <= 1'b0;
    end else begin
        mI2C_STEP <= 1'b0;
        if (mI2C_CLK_DIV < (I2C_STEP_DIV - 1)) begin
            mI2C_CLK_DIV <= mI2C_CLK_DIV + 16'd1;
        end else begin
            mI2C_CLK_DIV <= 16'd0;
            mI2C_STEP <= 1'b1;
        end
    end
end

a2gx_i2c_controller u0 (
    .CLOCK    (iCLK),
    .STEP_EN  (mI2C_STEP),
    .I2C_DATA (mI2C_DATA),
    .GO       (mI2C_GO),
    .RESET    (iRST_N),
    .W_R      (1'b0),
    .I2C_SDAT (I2C_SDAT),
    .I2C_SCLK (I2C_SCLK),
    .END      (mI2C_END),
    .ACK      (mI2C_ACK)
);

always @(posedge iCLK or negedge iRST_N) begin
    if (!iRST_N) begin
        READY <= 1'b0;
        LUT_INDEX <= 6'd0;
        mSetup_ST <= 4'd0;
        mI2C_GO <= 1'b0;
        counter_100us <= 16'd0;
    end else if (mI2C_STEP) begin
        if (LUT_INDEX < LUT_SIZE) begin
            READY <= 1'b0;
            case (mSetup_ST)
                4'd0: begin
                    mI2C_DATA <= {8'h98, LUT_DATA};
                    mI2C_GO <= 1'b1;
                    mSetup_ST <= 4'd1;
                end
                4'd1: begin
                    if (mI2C_END) begin
                        if (!mI2C_ACK)
                            mSetup_ST <= 4'd2;
                        else
                            mSetup_ST <= 4'd0;
                        mI2C_GO <= 1'b0;
                    end
                end
                4'd2: begin
                    if (LUT_INDEX < 6'd3) begin
                        if (counter_100us < 16'd10) begin
                            counter_100us <= counter_100us + 16'd1;
                        end else begin
                            counter_100us <= 16'd0;
                            mSetup_ST <= 4'd3;
                        end
                    end else begin
                        counter_100us <= 16'd0;
                        mSetup_ST <= 4'd3;
                    end
                end
                4'd3: begin
                    LUT_INDEX <= LUT_INDEX + 6'd1;
                    mSetup_ST <= 4'd0;
                end
                default: begin
                    mSetup_ST <= 4'd0;
                end
            endcase
        end else begin
            READY <= 1'b1;
            if (!HDMI_TX_INT)
                LUT_INDEX <= 6'd0;
        end
    end
end

endmodule
