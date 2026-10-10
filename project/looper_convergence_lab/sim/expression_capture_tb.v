`timescale 1ns/1ps
module expression_capture_tb;
reg clk=0;always #10 clk=~clk;reg rst=1,ce=0,recording=0,capture=1,pedal=1,sost=0,ready=1;
reg [11:0] tick=0;reg [16:0] bend=65536;wire valid,busy,overflow;
wire [11:0] et;wire [1:0] kind;wire [16:0] value;
reg checking=1;integer received=0;integer expected_kind[0:15];integer expected_value[0:15];integer expected_tick[0:15];
looper_expression_capture #(.BEND_INTERVAL_FRAMES(4)) dut(clk,rst,ce,recording,capture,tick,pedal,sost,bend,valid,ready,et,kind,value,busy,overflow);
always @(posedge clk) if(checking && !rst && valid && ready) begin
    if(kind!==expected_kind[received] || value!==expected_value[received] || et!==expected_tick[received])
        $fatal(1,"automation queue %d kind %d value %d tick %d",received,kind,value,et);
    received=received+1;
end
task frame;input [11:0] t;begin @(negedge clk);tick=t;ce=1;@(negedge clk);ce=0;repeat(6) @(negedge clk);end endtask
initial begin
expected_kind[0]=0;expected_value[0]=1;expected_tick[0]=0;
expected_kind[1]=1;expected_value[1]=0;expected_tick[1]=0;
expected_kind[2]=2;expected_value[2]=65536;expected_tick[2]=0;
expected_kind[3]=0;expected_value[3]=0;expected_tick[3]=12;
expected_kind[4]=1;expected_value[4]=1;expected_tick[4]=12;
expected_kind[5]=2;expected_value[5]=66489;expected_tick[5]=12;
expected_kind[6]=2;expected_value[6]=67456;expected_tick[6]=17;
repeat(4) @(negedge clk);rst=0;recording=1;repeat(12) @(negedge clk);
if(received!=3) $fatal(1,"missing initial states");
ready=0;pedal=0;sost=1;bend=66489;frame(12);repeat(8) @(negedge clk);
if(!busy || !valid) $fatal(1,"no queued update");ready=1;repeat(12) @(negedge clk);
if(received!=6) $fatal(1,"lost simultaneous controls");
bend=67456;frame(13);frame(14);frame(15);frame(16);frame(17);repeat(8) @(negedge clk);
if(received!=7 || overflow) $fatal(1,"bend rate limiter");
capture=0;pedal=1;frame(18);if(received!=7) $fatal(1,"capture after take boundary");
recording=0;repeat(4) @(negedge clk);if(busy || valid) $fatal(1,"cancel queue");
checking=0;ready=0;capture=1;recording=1;repeat(12) @(negedge clk);
repeat(10) begin pedal=!pedal;frame(tick+1);end
if(!overflow) $fatal(1,"bounded queue overflow diagnostic missing");recording=0;repeat(4) @(negedge clk);
if(overflow || busy || valid) $fatal(1,"overflow prevented fresh take");ready=1;recording=1;repeat(12) @(negedge clk);
if(overflow || busy) $fatal(1,"fresh take could not recover");
$display("EXPRESSION_CAPTURE_TB_PASS overflow_retry initial3 same_tick stable_backpressure bounded_bend capture_boundary cancel");$finish;
end
initial begin #1000000;$fatal(1,"watchdog");end
endmodule
