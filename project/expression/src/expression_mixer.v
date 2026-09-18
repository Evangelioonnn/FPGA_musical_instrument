module expression_mixer #(parameter N=8,parameter SHIFT=$clog2(N),parameter MONITOR_SHIFT=6)(
    input wire clk,rst,valid,
    input wire [N*16-1:0] voices,
    input wire [16:0] gain,
    output reg signed [15:0] sample,
    output reg sample_valid,clipped
);
    reg signed [16+SHIFT-1:0] sum;
    reg signed [15:0] average;
    reg signed [33:0] product;
    wire signed [33:0] scaled=product >>> (16+MONITOR_SHIFT);
    reg [1:0] pipe_valid;
    integer i;
    always @* begin
        sum=0;
        for(i=0;i<N;i=i+1) sum=sum+$signed(voices[i*16 +: 16]);
    end
    always @(posedge clk) begin
        if(rst) begin average<=0;product<=0;sample<=0;sample_valid<=0;clipped<=0;pipe_valid<=0;end
        else begin
            pipe_valid<={pipe_valid[0],valid};sample_valid<=pipe_valid[1];clipped<=0;
            if(valid) average<=sum >>> SHIFT;
            if(pipe_valid[0]) product<=average*$signed({1'b0,gain});
            if(pipe_valid[1]) begin
                if(scaled>32767) begin sample<=32767;clipped<=1;end
                else if(scaled < -32768) begin sample<=-32768;clipped<=1;end
                else sample<=scaled[15:0];
            end
        end
    end
endmodule
