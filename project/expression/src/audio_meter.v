module audio_meter #(parameter WINDOW=1024,parameter COUNT_W=$clog2(WINDOW))(
    input wire clk,rst,valid,clipped,
    input wire signed [15:0] sample,
    output reg snapshot_valid,
    output reg [15:0] peak,
    output reg signed [15:0] last_sample,
    output reg clip_seen
);
    reg [COUNT_W-1:0] count;
    reg [15:0] running_peak;
    reg running_clip;
    wire [15:0] magnitude=sample[15] ? (~sample+16'd1) : sample;
    wire [15:0] next_peak=magnitude>running_peak ? magnitude : running_peak;
    always @(posedge clk) begin
        if(rst) begin count<=0;running_peak<=0;running_clip<=0;snapshot_valid<=0;peak<=0;last_sample<=0;clip_seen<=0;end
        else begin
            snapshot_valid<=0;
            if(valid) begin
                if(count==WINDOW-1) begin
                    peak<=next_peak;last_sample<=sample;clip_seen<=running_clip|clipped;
                    count<=0;running_peak<=0;running_clip<=0;snapshot_valid<=1;
                end else begin count<=count+1'b1;running_peak<=next_peak;running_clip<=running_clip|clipped;end
            end
        end
    end
endmodule
