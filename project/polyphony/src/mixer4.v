module mixer4 #(parameter integer OUTPUT_SHIFT=2)(
    input wire clk,rst,sample_valid,
    input wire signed [15:0] voice0,voice1,voice2,voice3,
    output reg signed [15:0] sample=0,
    output reg output_valid=0,clipped=0,
    output wire signed [17:0] sum_wide
);
    wire signed [17:0] sum01=$signed({{2{voice0[15]}},voice0})+$signed({{2{voice1[15]}},voice1});
    wire signed [17:0] sum23=$signed({{2{voice2[15]}},voice2})+$signed({{2{voice3[15]}},voice3});
    assign sum_wide=sum01+sum23;
    wire signed [17:0] scaled=sum_wide >>> OUTPUT_SHIFT;
    always @(posedge clk) begin
        if(rst) begin sample<=0; output_valid<=0; clipped<=0; end
        else begin
            output_valid<=sample_valid; clipped<=0;
            if(sample_valid) begin
                if(scaled>18'sd32767) begin sample<=16'sh7fff; clipped<=1; end
                else if(scaled < -18'sd32768) begin sample<=16'sh8000; clipped<=1; end
                else sample<=scaled[15:0];
            end
        end
    end
endmodule
