// Stub modules for lint/simulation only.
// Real implementations are Altera IP cores in the a2gx project.

module a2gx_mistvga_pll (
    input  areset,
    input  inclk0,
    output c0,
    output locked
);
    assign c0 = inclk0;
    assign locked = ~areset;
endmodule

module a2gx_pci_clk_pll (
    input  areset,
    input  inclk0,
    output c0,
    output locked
);
    assign c0 = inclk0;
    assign locked = ~areset;
endmodule

module sivgx_mistvga_pll (
    input  areset,
    input  inclk0,
    output c0,
    output locked
);
    assign c0 = inclk0;
    assign locked = ~areset;
endmodule

module a2gx_i2c_hdmi_config #(
    parameter CLK_FREQ = 50000000,
    parameter I2C_FREQ = 20000,
    parameter LUT_SIZE = 11
) (
    input  iCLK,
    input  iRST_N,
    output I2C_SCLK,
    inout  I2C_SDAT,
    input  HDMI_TX_INT,
    output READY
);
    assign I2C_SCLK = 1'b1;
    assign READY = 1'b1;
endmodule
