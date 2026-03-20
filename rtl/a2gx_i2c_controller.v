module a2gx_i2c_controller (
    input         CLOCK,
    input         STEP_EN,
    input  [23:0] I2C_DATA,
    input         GO,
    input         RESET,
    input         W_R,
    inout         I2C_SDAT,
    output        I2C_SCLK,
    output        END,
    output        ACK
);

wire sdao;

assign I2C_SDAT = sdao ? 1'bz : 1'b0;

a2gx_i2c_write_wdata wrd (
    .RESET_N       (RESET),
    .PT_CK         (CLOCK),
    .STEP_EN       (STEP_EN),
    .GO            (GO),
    .END_OK        (END),
    .ACK_OK        (ACK),
    .BYTE_NUM      (8'd2),
    .SDAI          (I2C_SDAT),
    .SDAO          (sdao),
    .SCLO          (I2C_SCLK),
    .SLAVE_ADDRESS (I2C_DATA[23:16]),
    .REG_DATA      (I2C_DATA[15:0])
);

endmodule
