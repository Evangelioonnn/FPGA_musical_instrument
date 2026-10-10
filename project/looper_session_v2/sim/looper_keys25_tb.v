`timescale 1ns/1ps
module looper_keys25_tb;
reg clk=0;always #10 clk=~clk;reg rst=1,external_panic=0,changed=0,ghost=0,all_released=1;
reg [24:0] keys=0;reg [2:0] timbre=0;reg [6:0] left_base=48,right_base=60;
wire event_valid,event_off,fault_pulse,blocked,overflow_seen,token_exhausted;wire [31:0] event_token,fault_count;
wire [6:0] event_note;wire [2:0] event_timbre;reg event_ready=1;integer accepted=0,phase=0,i,pitch;
looper_keys #(.KEYS(25),.SPLIT(12),.DIATONIC(0)) dut(.*);
always @(posedge clk) if(!rst && event_valid && event_ready) begin
 pitch=phase<2 ? 48+(accepted%25) : (accepted%25)<12 ? 36+(accepted%25) : 72+(accepted%25)-12;
 if(event_note!=pitch || event_off!=(phase==1) || event_token!=(phase==1 ? (accepted%25)+1 : phase==2 ? (accepted%25)+26 : (accepted%25)+1)) $fatal(1,"25-key lifecycle expected pitch%d actual%d token%d phase%d",pitch,event_note,event_token,phase);
 if(event_timbre!=(phase==2 ? 3 : 0)) $fatal(1,"held-note preset identity");accepted=accepted+1;
end
task state;input [24:0] k;begin @(negedge clk);keys=k;all_released=k==0;changed=1;@(negedge clk);changed=0;repeat(200) @(negedge clk);end endtask
initial begin repeat(4) @(negedge clk);rst=0;repeat(3) @(negedge clk);state(25'h1ffffff);
if(accepted!=25) $fatal(1,"25 independent strikes");left_base=36;right_base=72;timbre=3;state(25'h1ffffff);
if(accepted!=25) $fatal(1,"octave change retriggered held notes");phase=1;state(0);if(accepted!=50) $fatal(1,"original instances did not all release");
phase=2;state(25'h1ffffff);if(accepted!=75||fault_count||overflow_seen||token_exhausted) $fatal(1,"new zones/preset lifecycle");
$display("LOOPER_KEYS25_TB_PASS chromatic48_to72 split12 zone_shift original_off_tokens 25_independent");$finish;end
initial begin #1000000;$fatal(1,"keys watchdog");end
endmodule
