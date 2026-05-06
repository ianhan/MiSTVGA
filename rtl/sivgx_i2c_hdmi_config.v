module sivgx_i2c_hdmi_config (
    input  iCLK,
    input  iRST_N,
    output I2C_SCLK,
    inout  I2C_SDAT,
    input  HDMI_TX_INT,
    output reg READY
);

parameter CLK_FREQ = 50000000;
parameter I2C_FREQ = 20000;
parameter LUT_SIZE = 15;

reg [15:0] mI2C_CLK_DIV = 16'd0;
reg        mI2C_CTRL_CLK = 1'b0;
reg [23:0] mI2C_DATA = 24'd0;
reg        mI2C_GO = 1'b0;
reg [15:0] LUT_DATA = 16'd0;
reg [5:0]  LUT_INDEX = 6'd0;
reg [3:0]  mSetup_ST = 4'd0;

wire mI2C_END;
wire mI2C_ACK;

always @(*) begin
    case (LUT_INDEX)
        6'd0:  LUT_DATA = 16'h4100;
        6'd1:  LUT_DATA = 16'h0a00;
        6'd2:  LUT_DATA = 16'h9807;
        6'd3:  LUT_DATA = 16'h9c38;
        6'd4:  LUT_DATA = 16'h9d61;
        6'd5:  LUT_DATA = 16'ha287;
        6'd6:  LUT_DATA = 16'ha387;
        6'd7:  LUT_DATA = 16'hbbff;
        6'd8:  LUT_DATA = 16'h1500;
        6'd9:  LUT_DATA = 16'h1800;
        6'd10: LUT_DATA = 16'h4080;
        6'd11: LUT_DATA = 16'haf02;
        6'd12: LUT_DATA = 16'h4500;
        6'd13: LUT_DATA = 16'h4080;
        6'd14: LUT_DATA = 16'h94c0;
        default: LUT_DATA = 16'h4100;
    endcase
end

always @(posedge iCLK or negedge iRST_N) begin
    if (!iRST_N) begin
        mI2C_CLK_DIV <= 16'd0;
        mI2C_CTRL_CLK <= 1'b0;
    end else begin
        if (mI2C_CLK_DIV < (CLK_FREQ / I2C_FREQ)) begin
            mI2C_CLK_DIV <= mI2C_CLK_DIV + 16'd1;
        end else begin
            mI2C_CLK_DIV <= 16'd0;
            mI2C_CTRL_CLK <= ~mI2C_CTRL_CLK;
        end
    end
end

a2gx_i2c_controller u0 (
    .CLOCK    (mI2C_CTRL_CLK),
    .STEP_EN  (1'b1),
    .I2C_DATA (mI2C_DATA),
    .GO       (mI2C_GO),
    .RESET    (iRST_N),
    .W_R      (1'b0),
    .I2C_SDAT (I2C_SDAT),
    .I2C_SCLK (I2C_SCLK),
    .END      (mI2C_END),
    .ACK      (mI2C_ACK)
);

always @(posedge mI2C_CTRL_CLK or negedge iRST_N) begin
    if (!iRST_N) begin
        READY <= 1'b0;
        LUT_INDEX <= 6'd0;
        mSetup_ST <= 4'd0;
        mI2C_GO <= 1'b0;
    end else begin
        if (LUT_INDEX < LUT_SIZE) begin
            READY <= 1'b0;
            case (mSetup_ST)
                4'd0: begin
                    mI2C_DATA <= {8'h72, LUT_DATA};
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
