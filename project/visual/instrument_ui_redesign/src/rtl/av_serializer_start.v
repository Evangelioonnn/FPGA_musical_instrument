// Reset is released with both serializer clocks stopped. At 50 MHz each
// guard is 320 ns: far longer than clock-gate latency and reset routing.
module av_serializer_start(input wire clk, input wire rst,
 output reg clocks_enable=0, output reg serializer_reset=1);
 reg [5:0] wait_count=0;
 always @(posedge clk or posedge rst) begin
  if(rst) begin wait_count<=0;clocks_enable<=0;serializer_reset<=1;end
  else if(!clocks_enable) begin
   wait_count<=wait_count+1'b1;
   if(wait_count==6'd15) serializer_reset<=0;
   if(wait_count==6'd31) clocks_enable<=1;
  end
 end
endmodule
