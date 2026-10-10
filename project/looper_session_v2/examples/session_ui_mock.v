// DEMO ONLY. C can exercise the LU1 decoder/renderer before connecting audio.
// This is not board evidence and does not implement command ACKs or synthesize PCM.
module session_ui_mock #(parameter UPDATE_CYCLES=15000000)(
 input wire clk,rst,output wire valid,input wire ready,output wire [31:0] data,
 output reg [4:0] index,output wire first,last,session_start
);
reg [31:0] timer,sequence,record_sequence;reg [639:0] payload;
reg sending,session;integer k;
assign valid=sending&&!rst;assign first=index==0;assign last=index==22;assign session_start=first&&session;
assign data=index==0 ? 32'h4c550117 : index==1 ? record_sequence : index==2 ? 32'd0 : payload[(index-3)*32+:32];
always @(posedge clk) begin
 if(rst) begin timer<=0;sequence<=0;record_sequence<=0;payload<=0;sending<=0;index<=0;session<=1;end
 else begin
  if(sending) begin
   if(ready) begin
    if(first) session<=0;
    if(last) begin sending<=0;index<=0;end else index<=index+1'b1;
   end
  end else if(timer==0) begin
   timer<=UPDATE_CYCLES-1;payload<=0;record_sequence<=sequence;sequence<=sequence+1'b1;sending<=1;
   payload[2:0]<=1;payload[7:6]<=sequence[1:0];payload[10:8]<=sequence[0] ? 6 : 0;
   payload[11]<=1;payload[13]<=1;payload[16]<=1;payload[19]<=1;
   payload[26]<=1;payload[28:27]<=sequence[1:0];
   payload[39:32]<=120;payload[47:40]<=120;payload[50:48]<=4;payload[53:51]<=1;payload[55:54]<=2;
   payload[75:64]<=sequence[7:0];payload[82:76]<=sequence%96;payload[85:83]<=sequence[3:2];
   payload[111:96]<=16'h1111;payload[123:112]<=384;
   payload[144:128]<=8249;payload[176:160]<=8249;
   for(k=0;k<4;k=k+1) payload[192+k*32+:17]<=65536;
   payload[320+:9]<=256;payload[329+:9]<=64;payload[338+:9]<=32;payload[352+:9]<=16;
   payload[399:384]<=16'd1<<sequence[3:0];payload[415:400]<=16'd1<<sequence[3:0];
   payload[431:416]<=sequence[15:0];payload[435:432]<=sequence[3:0];payload[448+:32]<=sequence>>2;
  end else timer<=timer-1'b1;
 end
end
endmodule
