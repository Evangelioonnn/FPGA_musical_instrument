module noise_pt8211_tx #(parameter OSR=1)(
    input wire clk,rst,
    input wire signed [15:0] sample_left,sample_right,
    output wire frame_ce,
    output reg hp_bck=0,hp_ws=0,hp_din=0
);
    localparam HALF_QUOTIENT=13/OSR;
    localparam HALF_REMAINDER=13%OSR;
    reg [4:0] bck_div;
    reg [5:0] bit_count;
    reg [2:0] fraction_acc;
    reg [15:0] left_hold,right_hold;
    wire [3:0] fraction_sum=fraction_acc+HALF_REMAINDER;
    wire [4:0] half_period=HALF_QUOTIENT+(fraction_sum>=OSR);
    wire [3:0] reduced_fraction=fraction_sum-OSR;
    wire [2:0] next_fraction=(fraction_sum>=OSR)?
        reduced_fraction[2:0]:fraction_sum[2:0];

    assign frame_ce=!rst && bck_div==half_period-1 && hp_bck && bit_count==39;

    always @(posedge clk) begin
        if(rst) begin
            bck_div<=0;bit_count<=0;fraction_acc<=0;hp_bck<=0;hp_ws<=0;hp_din<=0;
            left_hold<=0;right_hold<=0;
        end else if(bck_div==half_period-1) begin
            bck_div<=0;fraction_acc<=next_fraction;hp_bck<=~hp_bck;
            if(hp_bck) begin
                if(bit_count==19) begin
                    hp_ws<=1;bit_count<=20;hp_din<=0;
                end else if(bit_count==39) begin
                    hp_ws<=0;bit_count<=0;hp_din<=0;
                    left_hold<=sample_left;right_hold<=sample_right;
                end else if(bit_count>=3 && bit_count<=18) begin
                    bit_count<=bit_count+1'b1;
                    hp_din<=right_hold[18-bit_count];
                end else if(bit_count>=23 && bit_count<=38) begin
                    bit_count<=bit_count+1'b1;
                    hp_din<=left_hold[38-bit_count];
                end else begin
                    bit_count<=bit_count+1'b1;hp_din<=0;
                end
            end
        end else bck_div<=bck_div+1'b1;
    end
endmodule
