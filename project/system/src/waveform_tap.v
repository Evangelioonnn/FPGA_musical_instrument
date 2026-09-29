// Fixed decimation, for scope display (not an anti-aliased spectrum input).
module waveform_tap #(parameter DECIMATE=48,parameter W=(DECIMATE>1?$clog2(DECIMATE):1))(
    input wire clk,rst,valid,input wire signed [15:0] sample,
    output reg tap_valid,output reg signed [15:0] tap_sample,
    output reg [31:0] sample_index
);
    reg [W-1:0] count;
    reg [31:0] index;
    always @(posedge clk) begin
        if(rst) begin count<=0;index<=0;tap_valid<=0;tap_sample<=0;sample_index<=0;end
        else begin
            tap_valid<=0;
            if(valid) begin
                index<=index+1'b1;
                if(count==0) begin tap_valid<=1;tap_sample<=sample;sample_index<=index;end
                if(count==DECIMATE-1)count<=0;else count<=count+1'b1;
            end
        end
    end
endmodule
