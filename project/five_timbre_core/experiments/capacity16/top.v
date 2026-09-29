// Synthesis-only capacity probe. Its unconstrained event pins are not a board pinout.
module five_capacity16(
    input wire sys_clk,rst,changed,ghost,all_released,
    input wire [15:0] keys,input wire [2:0] button_n,
    input wire step_valid,input wire signed [1:0] step,
    output wire final_valid,output wire signed [15:0] final_sample,
    output wire [15:0] occupied,output wire rejected,deadline_missed
);
    reg [9:0] frame_count;
    always @(posedge sys_clk) begin
        if(rst || frame_count==10'd1039) frame_count<=0;
        else frame_count<=frame_count+1'b1;
    end
    wire sample_ce=frame_count==10'd1039;
    gallery_engine #(.N(16)) core(.clk(sys_clk),.rst(rst),.sample_ce(sample_ce),
        .keys(keys),.changed(changed),.ghost(ghost),.all_released(all_released),
        .button_n(button_n),.step_valid(step_valid),.step(step),
        .final_valid(final_valid),.final_sample(final_sample),
        .rejected(rejected),.occupied(occupied),.deadline_missed(deadline_missed));
endmodule
