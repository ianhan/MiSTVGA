`default_nettype none

module avalon_framebuffer_ram #(
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 128
) (
    input  wire                        clk,

    input  wire [ADDR_WIDTH-1:0]       avl_address,
    input  wire [7:0]                  avl_burstcount,
    input  wire [DATA_WIDTH-1:0]       avl_writedata,
    input  wire [(DATA_WIDTH/8)-1:0]   avl_byteenable,
    input  wire                        avl_write,
    input  wire                        avl_read,
    output wire                        avl_waitrequest,
    output logic [DATA_WIDTH-1:0]      avl_readdata,
    output logic                       avl_readdatavalid
);
    localparam int BYTE_COUNT = DATA_WIDTH / 8;
    localparam int WORD_COUNT = 1 << ADDR_WIDTH;

    logic [ADDR_WIDTH-1:0] write_addr = '0;
    logic                  write_active = 1'b0;

    logic [ADDR_WIDTH-1:0] read_addr = '0;
    logic [8:0]            read_remaining = 9'd0;
    logic                  read_active = 1'b0;
    logic                  ram_rden_d = 1'b0;
    wire                   ram_rden;
    wire                   ram_wren;
    wire [ADDR_WIDTH-1:0]  ram_addr;
    logic [DATA_WIDTH-1:0] ram_q;

    assign avl_waitrequest = 1'b0;
    assign ram_wren = avl_write;
    assign ram_rden = (avl_read || read_active) && !avl_write;
    assign ram_addr = avl_write ? (write_active ? write_addr : avl_address) :
                      avl_read  ? avl_address : read_addr;

`ifndef VERILATOR
    altsyncram altsyncram_component (
        .clock0         (clk),
        .clock1         (1'b1),
        .clocken0       (1'b1),
        .clocken1       (1'b1),
        .clocken2       (1'b1),
        .clocken3       (1'b1),
        .aclr0          (1'b0),
        .aclr1          (1'b0),
        .address_a      (ram_addr),
        .address_b      (1'b0),
        .addressstall_a (1'b0),
        .addressstall_b (1'b0),
        .byteena_a      (avl_byteenable),
        .byteena_b      (1'b1),
        .data_a         (avl_writedata),
        .data_b         (1'b0),
        .rden_a         (ram_rden),
        .rden_b         (1'b0),
        .wren_a         (ram_wren),
        .wren_b         (1'b0),
        .q_a            (ram_q),
        .q_b            (),
        .eccstatus      ()
    );
    defparam
        altsyncram_component.clock_enable_input_a = "BYPASS",
        altsyncram_component.clock_enable_output_a = "BYPASS",
        altsyncram_component.indata_aclr_a = "NONE",
        altsyncram_component.intended_device_family = "Arria V",
        altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
        altsyncram_component.lpm_type = "altsyncram",
        altsyncram_component.numwords_a = WORD_COUNT,
        altsyncram_component.operation_mode = "SINGLE_PORT",
        altsyncram_component.outdata_aclr_a = "NONE",
        altsyncram_component.outdata_reg_a = "UNREGISTERED",
        altsyncram_component.power_up_uninitialized = "FALSE",
        altsyncram_component.ram_block_type = "M10K",
        altsyncram_component.read_during_write_mode_port_a = "DONT_CARE",
        altsyncram_component.width_a = DATA_WIDTH,
        altsyncram_component.width_byteena_a = BYTE_COUNT,
        altsyncram_component.widthad_a = ADDR_WIDTH;
`else
    (* ramstyle = "M10K, no_rw_check" *) logic [DATA_WIDTH-1:0] mem [0:WORD_COUNT-1];

    always_ff @(posedge clk) begin
        if (ram_wren) begin
            for (int i = 0; i < BYTE_COUNT; i++) begin
                if (avl_byteenable[i]) begin
                    mem[ram_addr][(8*i) +: 8] <= avl_writedata[(8*i) +: 8];
                end
            end
        end
        if (ram_rden) begin
            ram_q <= mem[ram_addr];
        end
    end
`endif

    always_ff @(posedge clk) begin
        ram_rden_d <= ram_rden;
        avl_readdatavalid <= ram_rden_d;
        if (ram_rden_d) begin
            avl_readdata <= ram_q;
        end

        if (avl_write) begin
            if (!write_active) begin
                write_addr <= avl_address + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
            end else begin
                write_addr <= write_addr + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
            end
            write_active <= 1'b1;
        end else begin
            write_active <= 1'b0;
        end

        if (avl_read && !avl_write) begin
            read_addr <= avl_address + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
            read_remaining <= {1'b0, avl_burstcount} - 9'd1;
            read_active <= (avl_burstcount != 8'd1);
        end else if (read_active && !avl_write) begin
            read_addr <= read_addr + {{(ADDR_WIDTH-1){1'b0}}, 1'b1};
            read_remaining <= read_remaining - 9'd1;
            read_active <= (read_remaining != 9'd1);
        end
    end
endmodule

`default_nettype wire
