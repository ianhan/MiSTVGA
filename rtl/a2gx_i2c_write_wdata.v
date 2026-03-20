module a2gx_i2c_write_wdata (
    input              RESET_N,
    input              PT_CK,
    input              STEP_EN,
    input              GO,
    input      [15:0]  REG_DATA,
    input      [7:0]   SLAVE_ADDRESS,
    input              SDAI,
    output reg         SDAO,
    output reg         SCLO,
    output reg         END_OK,
    output reg [7:0]   ST,
    output reg [7:0]   CNT,
    output reg [7:0]   BYTE,
    output reg         ACK_OK,
    input      [7:0]   BYTE_NUM
);

reg [8:0] A;

always @(negedge RESET_N or posedge PT_CK) begin
    if (!RESET_N) begin
        ST <= 8'd0;
        SDAO <= 1'b1;
        SCLO <= 1'b1;
        END_OK <= 1'b1;
        CNT <= 8'd0;
        BYTE <= 8'd0;
        ACK_OK <= 1'b0;
        A <= 9'd0;
    end else if (STEP_EN) begin
        case (ST)
            8'd0: begin
                SDAO   <= 1'b1;
                SCLO   <= 1'b1;
                ACK_OK <= 1'b0;
                CNT    <= 8'd0;
                END_OK <= 1'b1;
                BYTE   <= 8'd0;
                if (GO)
                    ST <= 8'd30;
            end
            8'd1: begin
                ST <= 8'd2;
                {SDAO, SCLO} <= 2'b01;
                A <= {SLAVE_ADDRESS, 1'b1};
            end
            8'd2: begin
                ST <= 8'd3;
                {SDAO, SCLO} <= 2'b00;
            end
            8'd3: begin
                ST <= 8'd4;
                {SDAO, A} <= {A, 1'b0};
            end
            8'd4: begin
                ST <= 8'd5;
                SCLO <= 1'b1;
                CNT <= CNT + 8'd1;
            end
            8'd5: begin
                SCLO <= 1'b0;
                if (CNT == 8'd9) begin
                    if (BYTE == BYTE_NUM) begin
                        ST <= 8'd6;
                    end else begin
                        CNT <= 8'd0;
                        ST <= 8'd2;
                        if (BYTE == 8'd0) begin
                            BYTE <= 8'd1;
                            A <= {REG_DATA[15:8], 1'b1};
                        end else if (BYTE == 8'd1) begin
                            BYTE <= 8'd2;
                            A <= {REG_DATA[7:0], 1'b1};
                        end
                    end
                    if (SDAI)
                        ACK_OK <= 1'b1;
                end else begin
                    ST <= 8'd2;
                end
            end
            8'd6: begin
                ST <= 8'd7;
                {SDAO, SCLO} <= 2'b00;
            end
            8'd7: begin
                ST <= 8'd8;
                {SDAO, SCLO} <= 2'b01;
            end
            8'd8: begin
                ST <= 8'd9;
                {SDAO, SCLO} <= 2'b11;
            end
            8'd9: begin
                ST <= 8'd30;
                SDAO   <= 1'b1;
                SCLO   <= 1'b1;
                CNT    <= 8'd0;
                END_OK <= 1'b1;
                BYTE   <= 8'd0;
            end
            8'd30: begin
                if (!GO)
                    ST <= 8'd31;
            end
            8'd31: begin
                END_OK <= 1'b0;
                ACK_OK <= 1'b0;
                ST <= 8'd1;
            end
            default: begin
                ST <= 8'd0;
            end
        endcase
    end
end

endmodule
