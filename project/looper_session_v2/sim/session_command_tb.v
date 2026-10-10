`timescale 1ns/1ps
module session_command_tb;
reg audio_clk=0,client_clk=0;always #10 audio_clk=~audio_clk;always #7.3 client_clk=~client_clk;
reg arst=1,client_valid=0,reply_ready=0;wire client_ready,reply_valid;
reg [7:0] client_addr=0;reg [31:0] client_value=0;reg [15:0] client_tag=0;
wire [7:0] reply_addr,host_addr;wire [31:0] reply_value,host_value;wire [15:0] reply_tag;
wire reply_accepted,reply_applied;wire [7:0] reply_reason;wire host_valid;reg host_ready=1;
reg ack_valid=0,ack_source=1,ack_accepted=0,ack_applied=0;reg [7:0] ack_addr=0,ack_reason=0;reg [31:0] ack_value=0;
wire audio_protocol_error;session_command_bridge dut(.*);
integer consumed=0,delay_left=0;reg [7:0] pending_addr;reg [31:0] pending_value;reg pause=0;
always @(posedge audio_clk) begin
 if(arst) begin delay_left<=0;ack_valid<=0;end
 else begin
  ack_valid<=0;
  if(host_valid&&host_ready) begin
   if(delay_left!=0) $fatal(1,"two audio requests outstanding");
   consumed=consumed+1;pending_addr<=host_addr;pending_value<=host_value;delay_left<=9;
  end
  if(delay_left>1&&!pause) delay_left<=delay_left-1;
  else if(delay_left==1&&!pause) begin
   ack_valid<=1;ack_addr<=pending_addr;ack_value<=pending_value;
   ack_accepted<=!pending_addr[0];ack_applied<=!pending_addr[0];ack_reason<=pending_addr[0] ? 2 : 0;delay_left<=0;
  end
 end
end
task reset_link;begin
 @(negedge client_clk);arst=1;client_valid=0;reply_ready=0;repeat(6) @(negedge audio_clk);arst=0;
 repeat(8) @(negedge client_clk);
end endtask
task send;input [7:0] a;input [31:0] v;input [15:0] t;
begin
 @(negedge client_clk);while(!client_ready) @(negedge client_clk);
 client_addr=a;client_value=v;client_tag=t;client_valid=1;@(negedge client_clk);client_valid=0;
end endtask
integer i,n;reg [65:0] held;
initial begin
 reset_link();
 for(i=0;i<32;i=i+1) begin
  send('h20+i,32'h159a0000+i,'h7100+i);wait(reply_valid);
  if(reply_addr!='h20+i || reply_value!=32'h159a0000+i || reply_tag!='h7100+i ||
    reply_accepted!=!i[0] || reply_applied!=!i[0] || reply_reason!=(i[0] ? 2 : 0)) $fatal(1,"tagged reason8 reply");
  held={reply_addr,reply_value,reply_tag,reply_accepted,reply_applied,reply_reason};
  for(n=0;n<37;n=n+1) begin @(negedge client_clk);
   if(!reply_valid||client_ready||{reply_addr,reply_value,reply_tag,reply_accepted,reply_applied,reply_reason}!==held) $fatal(1,"reply under backpressure");
  end
  reply_ready=1;@(negedge client_clk);reply_ready=0;repeat(3) @(negedge client_clk);
 end
 if(consumed!=32 || audio_protocol_error) $fatal(1,"duplicate or leaked ACK");
 host_ready=0;send('h28,30000,'hdead);wait(host_valid);repeat(12) @(negedge audio_clk);reset_link();host_ready=1;
 repeat(25) @(negedge audio_clk);if(reply_valid || host_valid) $fatal(1,"reset pending host");
 pause=1;send('h28,32000,'hdeae);wait(delay_left>0);reset_link();pause=0;
 repeat(25) @(negedge audio_clk);if(reply_valid) $fatal(1,"reset after request");
 send('h28,12345,'h1234);wait(reply_valid);reset_link();if(reply_valid) $fatal(1,"reset stalled reply");
 send('h2f,42,'h5678);wait(reply_valid);if(reply_tag!='h5678 || reply_reason!=2) $fatal(1,"restart");
 @(negedge client_clk);reply_ready=1;@(negedge client_clk);reply_ready=0;repeat(8) @(negedge audio_clk);
 // Foreign audio ACK source must be ignored; malformed owned ACK diagnosed.
 force dut.ack_valid=1;force dut.ack_source=0;repeat(2) @(negedge audio_clk);
 if(audio_protocol_error || reply_valid) $fatal(1,"foreign ACK");
 force dut.ack_source=1;repeat(2) @(negedge audio_clk);release dut.ack_valid;release dut.ack_source;
 if(!audio_protocol_error || reply_valid) $fatal(1,"unexpected ACK");
 $display("SESSION_COMMAND_TB_PASS addr8 reason8 transactions32 held_tag backpressure reset_before_after_host reset_reply source_ownership malformed_ACK");$finish;
end
initial begin #2000000;$fatal(1,"command watchdog");end
endmodule
