// Reuse the independently checked feedback delay; keep dry gain exactly one.
// Feedback=1/2 limits the history bound to twice the bounded input. External
// amount 0..1/2 adds echo, smoothly; amount=0 restores exact signed PCM dry.
module knob_effect(
    input wire clk,rst,in_valid,input wire signed [15:0] in_sample,
    input wire [15:0] wet_target,
    output wire in_ready,output reg out_valid,output reg signed [15:0] out_sample,
    output reg clipped
);
    wire delay_valid,delay_clip;
    wire signed [15:0] delay_sample;
    reg signed [15:0] dry;
    reg [15:0] wet,held_wet;
    wire [15:0] target=wet_target>16384 ? 16'd16384 : wet_target;
    wire [15:0] next_wet=wet<target ? (target-wet<=256 ? target : wet+16'd256) :
        (wet-target<=256 ? target : wet-16'd256);
    wire signed [16:0] difference=$signed({delay_sample[15],delay_sample})-$signed({dry[15],dry});
    reg signed [33:0] product;
    reg signed [15:0] held_dry;
    reg pending,held_clip;
    wire signed [33:0] term=product<0 ? -((-product)>>>15) : product>>>15;
    wire signed [33:0] total=held_dry+term;
    feedback_delay #(.FEEDBACK_Q15(16384),.WET_Q15(32768)) delay(
        clk,rst,in_valid,1'b0,in_sample,in_ready,delay_valid,delay_sample,delay_clip);
    always @(posedge clk) begin
        if(rst) begin
            dry<=0;wet<=0;held_wet<=0;product<=0;held_dry<=0;
            pending<=0;held_clip<=0;out_valid<=0;out_sample<=0;clipped<=0;
        end else begin
            out_valid<=pending;pending<=delay_valid;clipped<=0;
            if(in_valid && in_ready) begin dry<=in_sample;wet<=next_wet;held_wet<=next_wet;end
            if(delay_valid) begin
                product<=difference*$signed({1'b0,held_wet});held_dry<=dry;held_clip<=delay_clip;
            end
            if(pending) begin
                clipped<=held_clip || total>32767 || total< -32768;
                if(total>32767) out_sample<=32767;
                else if(total< -32768) out_sample<= -32768;
                else out_sample<=total[15:0];
            end
        end
    end
endmodule
