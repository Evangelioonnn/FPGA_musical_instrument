module test_top (
    input  wire sys_clk,
    output reg  led = 1'b0
);

    reg [25:0] div_cnt = 26'd0;

    always @(posedge sys_clk) begin
        if (div_cnt == 26'd24_999_999) begin
            div_cnt <= 26'd0;
            led     <= ~led;
        end
        else begin
            div_cnt <= div_cnt + 1'b1;
        end
    end

endmodule