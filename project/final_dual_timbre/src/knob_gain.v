module knob_gain(
    input wire clk,rst,in_valid,input wire signed [15:0] in_sample,
    input wire [16:0] target,
    output reg out_valid,output reg signed [15:0] out_sample,
    output reg [16:0] gain
);
    wire [16:0] bounded=target>65536 ? 17'd65536 : target;
    wire [16:0] next_gain=gain<bounded ? (bounded-gain<=128 ? bounded : gain+17'd128) :
        (gain-bounded<=128 ? bounded : gain-17'd128);
    reg signed [33:0] product;
    reg pending;
    wire signed [33:0] scaled=product<0 ? -((-product)>>>16) : product>>>16;
    always @(posedge clk) begin
        if(rst) begin gain<=65536;product<=0;pending<=0;out_valid<=0;out_sample<=0;end
        else begin
            pending<=in_valid;out_valid<=pending;
            if(in_valid) begin gain<=next_gain;product<=in_sample*$signed({1'b0,next_gain});end
            if(pending) out_sample<=scaled[15:0];
        end
    end
endmodule
