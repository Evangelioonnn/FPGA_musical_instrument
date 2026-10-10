`timescale 1ns/1ps
module session_unpacker_tb;
reg clk=0;always #10 clk=~clk;reg rst=1,valid=0,first=0,last=0,session_start=0;
reg [31:0] data=0;reg [4:0] index=0;wire ready,updated,new_session,protocol_error;
wire [639:0] ui;wire [31:0] sequence,drops;integer i;
session_ui_unpacker dut(.*);
task word;input integer idx;input [31:0] value;input f,l;
begin @(negedge clk);index=idx;data=value;first=f;last=l;valid=1;@(negedge clk);valid=0;end endtask
initial begin
 repeat(4) @(negedge clk);rst=0;
 word(0,32'h4c550117,1,0);word(1,17,0,0);word(2,3,0,0);
 for(i=3;i<23;i=i+1) word(i,i*101,0,i==22);
 if(!updated || sequence!=17 || drops!=3 || ui[0+:32]!=303 || ui[608+:32]!=2222) $fatal(1,"good unpack");
 word(0,32'h4c520136,1,0);if(!protocol_error || updated) $fatal(1,"LR1 cannot decode as LU1");
 word(0,32'h4c550117,1,0);word(1,999,0,0);word(3,9,0,0);
 if(!protocol_error || updated || sequence!=17) $fatal(1,"out of order packet changed committed state");
 word(0,32'h4c550117,1,0);word(1,18,0,0);word(2,4,0,1);
 if(updated || sequence!=17) $fatal(1,"early last accepted");
 @(negedge clk);rst=1;@(negedge clk);rst=0;if(protocol_error||ui!=0) $fatal(1,"reset");
 word(0,32'h4c550117,1,0);word(1,19,0,0);word(2,5,0,0);for(i=3;i<23;i=i+1) word(i,i,0,i==22);
 if(!updated || sequence!=19 || protocol_error) $fatal(1,"resync after reset");
 $display("SESSION_UNPACKER_TB_PASS wrong_version order premature_last committed_state_held recovery");$finish;
end
endmodule
