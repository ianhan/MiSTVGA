// Dual-port dual-clock RAM — simulation model
// Port A: read/write on clk_a
// Port B: read-only on clk_b with clock enable
//
// Parameters: (ADDR_WIDTH_A, DATA_WIDTH_A, ADDR_WIDTH_B, DATA_WIDTH_B)
// Port B address width may differ from A when data widths differ (wider/narrower),
// but for the VGA module they are always the same.

module dpram_difclk #(
    parameter ADDR_WIDTH_A = 16,
    parameter DATA_WIDTH_A = 8,
    parameter ADDR_WIDTH_B = 16,
    parameter DATA_WIDTH_B = 8
) (
    input                          clk_a,
    input      [ADDR_WIDTH_A-1:0]  address_a,
    input      [DATA_WIDTH_A-1:0]  data_a,
    input                          wren_a,
    output     [DATA_WIDTH_A-1:0]  q_a,

    input                          clk_b,
    input                          enable_b,
    input      [ADDR_WIDTH_B-1:0]  address_b,
    output     [DATA_WIDTH_B-1:0]  q_b
);

    localparam DEPTH_A = 2**ADDR_WIDTH_A;

`ifndef VERILATOR
    wire [DATA_WIDTH_A-1:0] q_a_int;
    wire [DATA_WIDTH_B-1:0] q_b_int;
    wire [DATA_WIDTH_B-1:0] data_b = {DATA_WIDTH_B{1'b0}};

    assign q_a = q_a_int;
    assign q_b = q_b_int;

    altsyncram altsyncram_component (
        .clock0         (clk_a),
        .clock1         (clk_b),
        .clocken0       (1'b1),
        .clocken1       (1'b1),
        .clocken2       (1'b1),
        .clocken3       (1'b1),
        .aclr0          (1'b0),
        .aclr1          (1'b0),
        .address_a      (address_a),
        .address_b      (address_b),
        .addressstall_a (1'b0),
        .addressstall_b (1'b0),
        .byteena_a      (1'b1),
        .byteena_b      (1'b1),
        .data_a         (data_a),
        .data_b         (data_b),
        .rden_a         (1'b1),
        .rden_b         (enable_b),
        .wren_a         (wren_a),
        .wren_b         (1'b0),
        .q_a            (q_a_int),
        .q_b            (q_b_int),
        .eccstatus      ()
    );
    defparam
        altsyncram_component.address_reg_b = "CLOCK1",
        altsyncram_component.clock_enable_input_a = "BYPASS",
        altsyncram_component.clock_enable_input_b = "BYPASS",
        altsyncram_component.clock_enable_output_a = "BYPASS",
        altsyncram_component.clock_enable_output_b = "BYPASS",
        altsyncram_component.indata_aclr_a = "NONE",
        altsyncram_component.indata_aclr_b = "NONE",
        altsyncram_component.indata_reg_b = "CLOCK1",
        altsyncram_component.intended_device_family = "Arria II GX",
        altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
        altsyncram_component.lpm_type = "altsyncram",
        altsyncram_component.numwords_a = DEPTH_A,
        altsyncram_component.numwords_b = (2**ADDR_WIDTH_B),
        altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
        altsyncram_component.outdata_aclr_a = "NONE",
        altsyncram_component.outdata_aclr_b = "NONE",
        altsyncram_component.outdata_reg_a = "UNREGISTERED",
        altsyncram_component.outdata_reg_b = "UNREGISTERED",
        altsyncram_component.power_up_uninitialized = "FALSE",
        altsyncram_component.ram_block_type = "AUTO",
        altsyncram_component.read_during_write_mode_mixed_ports = "DONT_CARE",
        altsyncram_component.width_a = DATA_WIDTH_A,
        altsyncram_component.width_b = DATA_WIDTH_B,
        altsyncram_component.widthad_a = ADDR_WIDTH_A,
        altsyncram_component.widthad_b = ADDR_WIDTH_B,
        altsyncram_component.width_byteena_a = 1,
        altsyncram_component.width_byteena_b = 1,
        altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK1";
`else
    reg [DATA_WIDTH_A-1:0] mem [0:DEPTH_A-1];
    reg [DATA_WIDTH_A-1:0] q_a_reg;
    reg [DATA_WIDTH_B-1:0] q_b_reg;

    assign q_a = q_a_reg;
    assign q_b = q_b_reg;

    // Port A: synchronous read + write
    always @(posedge clk_a) begin
        if (wren_a)
            mem[address_a] <= data_a;
        q_a_reg <= mem[address_a];
    end

    // Port B: synchronous read with clock enable
    always @(posedge clk_b) begin
        if (enable_b)
            q_b_reg <= mem[address_b];
    end

    // Initialize to zero for simulation only
`ifdef VERILATOR
    integer i;
    initial begin
        for (i = 0; i < DEPTH_A; i = i + 1)
            mem[i] = {DATA_WIDTH_A{1'b0}};
    end
`endif
`endif

endmodule
