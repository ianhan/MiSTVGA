// Bridge ASCAL's 128-bit Avalon bursts to the generated single-beat
// external interface on the Arria V starter-kit memory system.
`default_nettype none

module ascal_ssram_bridge #(
    parameter int ASCAL_ADDR_WIDTH  = 19,
    parameter int MEMORY_ADDR_WIDTH = 30,
    parameter logic [MEMORY_ADDR_WIDTH-1:0] MEMORY_BASE_ADDRESS = 30'h1000_0000
) (
    input  wire                              clk,
    input  wire                              reset_n,

    input  wire [ASCAL_ADDR_WIDTH-1:0]       avl_address,
    input  wire [7:0]                        avl_burstcount,
    input  wire [127:0]                      avl_writedata,
    input  wire [15:0]                       avl_byteenable,
    input  wire                              avl_write,
    input  wire                              avl_read,
    output wire                              avl_waitrequest,
    output logic [127:0]                     avl_readdata,
    output logic                             avl_readdatavalid,

    output logic [MEMORY_ADDR_WIDTH-1:0]     memory_address,
    output logic [15:0]                      memory_byteenable,
    output logic                             memory_read,
    output logic                             memory_write,
    output logic [127:0]                     memory_writedata,
    input  wire                              memory_acknowledge,
    input  wire [127:0]                      memory_readdata
);
    localparam int BYTE_ADDRESS_PAD_WIDTH = MEMORY_ADDR_WIDTH - ASCAL_ADDR_WIDTH - 4;

    typedef enum logic [1:0] {
        S_IDLE,
        S_WRITE_WAIT,
        S_WRITE_ACCEPT,
        S_READ_RUN
    } state_t;

    state_t state = S_IDLE;

    logic [MEMORY_ADDR_WIDTH-1:0] write_next_address = '0;
    logic [7:0]                   write_beats_remaining = 8'd0;
    logic [7:0]                   read_beats_remaining = 8'd0;

    assign avl_waitrequest = !((state == S_IDLE) || (state == S_WRITE_ACCEPT));

    function automatic [7:0] nonzero_burstcount(input [7:0] burstcount);
        begin
            nonzero_burstcount = (burstcount == 8'd0) ? 8'd1 : burstcount;
        end
    endfunction

    function automatic [MEMORY_ADDR_WIDTH-1:0] ascal_to_memory_address(
        input [ASCAL_ADDR_WIDTH-1:0] address
    );
        begin
            ascal_to_memory_address =
                MEMORY_BASE_ADDRESS + {{BYTE_ADDRESS_PAD_WIDTH{1'b0}}, address, 4'b0000};
        end
    endfunction

    function automatic [MEMORY_ADDR_WIDTH-1:0] next_beat_address(
        input [MEMORY_ADDR_WIDTH-1:0] address
    );
        begin
            next_beat_address = address + {{(MEMORY_ADDR_WIDTH-5){1'b0}}, 5'd16};
        end
    endfunction

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= S_IDLE;
            memory_address <= '0;
            memory_byteenable <= 16'hffff;
            memory_read <= 1'b0;
            memory_write <= 1'b0;
            memory_writedata <= 128'd0;
            avl_readdata <= 128'd0;
            avl_readdatavalid <= 1'b0;
            write_next_address <= '0;
            write_beats_remaining <= 8'd0;
            read_beats_remaining <= 8'd0;
        end else begin
            avl_readdatavalid <= 1'b0;

            unique case (state)
                S_IDLE: begin
                    memory_read <= 1'b0;
                    memory_write <= 1'b0;

                    if (avl_write) begin
                        memory_address <= ascal_to_memory_address(avl_address);
                        memory_byteenable <= avl_byteenable;
                        memory_writedata <= avl_writedata;
                        memory_write <= 1'b1;
                        write_next_address <= next_beat_address(ascal_to_memory_address(avl_address));
                        write_beats_remaining <= nonzero_burstcount(avl_burstcount) - 8'd1;
                        state <= S_WRITE_WAIT;
                    end else if (avl_read) begin
                        memory_address <= ascal_to_memory_address(avl_address);
                        memory_byteenable <= 16'hffff;
                        memory_read <= 1'b1;
                        read_beats_remaining <= nonzero_burstcount(avl_burstcount) - 8'd1;
                        state <= S_READ_RUN;
                    end
                end

                S_WRITE_WAIT: begin
                    if (memory_acknowledge) begin
                        memory_write <= 1'b0;
                        if (write_beats_remaining == 8'd0) begin
                            state <= S_IDLE;
                        end else begin
                            state <= S_WRITE_ACCEPT;
                        end
                    end
                end

                S_WRITE_ACCEPT: begin
                    memory_write <= 1'b0;

                    if (avl_write) begin
                        memory_address <= write_next_address;
                        memory_byteenable <= avl_byteenable;
                        memory_writedata <= avl_writedata;
                        memory_write <= 1'b1;
                        write_next_address <= next_beat_address(write_next_address);
                        write_beats_remaining <= write_beats_remaining - 8'd1;
                        state <= S_WRITE_WAIT;
                    end
                end

                S_READ_RUN: begin
                    if (memory_acknowledge) begin
                        avl_readdata <= memory_readdata;
                        avl_readdatavalid <= 1'b1;

                        if (read_beats_remaining == 8'd0) begin
                            memory_read <= 1'b0;
                            state <= S_IDLE;
                        end else begin
                            memory_address <= next_beat_address(memory_address);
                            read_beats_remaining <= read_beats_remaining - 8'd1;
                            memory_read <= 1'b1;
                        end
                    end
                end

                default: begin
                    state <= S_IDLE;
                    memory_read <= 1'b0;
                    memory_write <= 1'b0;
                end
            endcase
        end
    end
endmodule

`default_nettype wire
