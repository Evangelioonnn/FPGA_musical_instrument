`timescale 1ns/1ps
module session_ui_tb;
reg src_clk=0;always #10 src_clk=~src_clk;
reg dst_clk=0;always #3.7 dst_clk=~dst_clk;
reg arst=1,src_valid=0;reg [639:0] src_data=0;wire [31:0] src_drops;
wire valid;reg gate_ready=1;wire unpack_ready;wire ready=gate_ready&&unpack_ready;
wire [31:0] data;wire [4:0] index;wire first,last,session_start;
session_ui_bridge bridge(.src_clk(src_clk),.dst_clk(dst_clk),.arst(arst),.src_valid(src_valid),.src_data(src_data),.src_drops(src_drops),
 .dst_valid(valid),.dst_ready(ready),.dst_data(data),.dst_index(index),.dst_first(first),.dst_last(last),.dst_session_start(session_start));
wire rst;audio_transport_reset resetter(dst_clk,arst,rst);
wire updated,new_session,protocol_error;wire [639:0] ui;wire [31:0] sequence,drops;
session_ui_unpacker unpacker(.clk(dst_clk),.rst(rst),.valid(valid&&gate_ready),.ready(unpack_ready),.data(data),.index(index),.first(first),.last(last),.session_start(session_start),.*);
reg [639:0] expected[0:31];reg [31:0] exp_drops[0:31];integer pub=0,checks=0,sessions=0,j;
reg stalled=0;reg [39:0] held;integer words=0;
always @(posedge dst_clk) if(!rst) begin
 if(stalled && (!valid||{data,index,first,last,session_start}!==held)) $fatal(1,"LU1 changed during stall");
 stalled=valid&&!ready;held={data,index,first,last,session_start};
 if(valid&&ready) begin
  if(first) begin if(index!=0||data!==32'h4c550117) $fatal(1,"header");words=0;end
  words=words+1;if(last && words!=23) $fatal(1,"length");
 end
 #1;if(updated) begin
  if(ui!==expected[sequence] || drops!==exp_drops[sequence]) $fatal(1,"torn frame seq%0d drops%0d expected%0d",sequence,drops,exp_drops[sequence]);
  checks=checks+1;if(new_session) sessions=sessions+1;
 end
 if(protocol_error) $fatal(1,"valid bridge frame rejected");
end else stalled=0;
task publish;input integer value;
begin
 @(negedge src_clk);for(j=0;j<20;j=j+1) src_data[j*32+:32]=(value<<16)|j;
 expected[pub]=src_data;exp_drops[pub]=src_drops+(bridge.copying&&!bridge.owned);
 src_valid=1;pub=pub+1;@(negedge src_clk);src_valid=0;
end endtask
initial begin
 repeat(5) @(negedge src_clk);arst=0;repeat(10) @(negedge src_clk);
 publish(1);wait(checks==1);if(sessions!=1) $fatal(1,"initial session");repeat(8) @(negedge src_clk);
 gate_ready=0;publish(2);wait(valid);repeat(20) @(negedge src_clk);
 publish(3);publish(4);if(src_drops!=2) $fatal(1,"owned bank drops");
 gate_ready=1;wait(checks==2);repeat(8) @(negedge src_clk);publish(5);wait(checks==3);
 // Copy restart must use a whole new source frame.
 repeat(8) @(negedge src_clk);publish(6);repeat(5) @(negedge src_clk);publish(7);wait(checks==4);
 if(sequence!=6 || src_drops!=3) $fatal(1,"copy restart/drop");
 repeat(8) @(negedge src_clk);gate_ready=0;publish(8);wait(valid);gate_ready=1;wait(index==9);@(negedge dst_clk);arst=1;
 repeat(5) @(negedge src_clk);pub=0;arst=0;repeat(10) @(negedge src_clk);publish(9);wait(checks==5);
 if(sequence!=0 || drops!=0 || sessions!=2) $fatal(1,"reset partial packet/session");
 $display("SESSION_UI_TB_PASS frames=%0d asynchronous torn_frame=0 backpressure copy_restart drops reset_partial session",checks);$finish;
end
initial begin #1000000;$fatal(1,"UI watchdog checks%0d",checks);end
endmodule
