`timescale 1ns/1ps
module drum_capacity_tb;
reg clk=0;always #10 clk=~clk;reg rst=1,sample_ce=0,strike_valid=0,mono_strike=0;
reg [3:0] strike_pad=9;reg [2:0] strike_track=4;reg flush_all=0;
wire strike_ready,strike_accepted,sample_valid,mono_valid;wire signed [19:0] sample,mono_sample;
wire [7:0] active;wire [31:0] late_strikes,rejected_strikes;
looper_drum_engine dut(.clk(clk),.rst(rst),.sample_ce(sample_ce),.strike_valid(strike_valid),.strike_ready(strike_ready),.strike_accepted(strike_accepted),
 .strike_pad(strike_pad),.strike_velocity(8'd255),.strike_track(strike_track),.strike_layer(2'd0),.track_gains({4{17'd65536}}),
 .flush_all(flush_all),.flush_valid(1'b0),.flush_track(2'd0),.flush_layer(2'd0),.flush_whole_track(1'b0),
 .sample_valid(sample_valid),.sample(sample),.active(active),.late_strikes(late_strikes),.rejected_strikes(rejected_strikes));
looper_drum_engine #(.VOICES(1)) mono(.clk(clk),.rst(rst),.sample_ce(sample_ce),.strike_valid(mono_strike),
 .strike_pad(strike_pad),.strike_velocity(8'd255),.strike_track(strike_track),.strike_layer(2'd0),.track_gains({4{17'd65536}}),
 .flush_all(flush_all),.flush_valid(1'b0),.flush_track(2'd0),.flush_layer(2'd0),.flush_whole_track(1'b0),.sample_valid(mono_valid),.sample(mono_sample));
task reset;begin @(negedge clk);rst=1;sample_ce=0;strike_valid=0;mono_strike=0;repeat(4) @(negedge clk);rst=0;end endtask
task hit;input [3:0] p;input single;
begin @(negedge clk);strike_pad=p;strike_valid=1;mono_strike=single;
 if(!strike_ready) $fatal(1,"strike not ready");@(negedge clk);strike_valid=0;mono_strike=0;end endtask
integer i,n,cycle,checks=0,peak=0,absolute,max_render=0;
task render;input integer count;input compare;
begin for(n=0;n<count;n=n+1) begin
 @(negedge clk);sample_ce=1;@(negedge clk);sample_ce=0;cycle=0;
 while(!sample_valid) begin @(negedge clk);cycle=cycle+1;if(cycle>=1040) $fatal(1,"drum render deadline");end
 if(cycle>max_render) max_render=cycle;
 if(compare) begin
  if($signed(sample)!=$signed(mono_sample)*8) $fatal(1,"eight toms not linear frame%0d mix%0d mono%0d",n,sample,mono_sample);
  checks=checks+1;
 end
 absolute=sample<0 ? -sample : sample;if(absolute>peak) peak=absolute;
 if(absolute>294912 || late_strikes) $fatal(1,"eight tom arithmetic bound/deadline");
 repeat(1038-cycle) @(negedge clk);
end end endtask
initial begin
 reset();for(i=0;i<8;i=i+1) hit(9,i==0);if(active!=255) $fatal(1,"eight tom allocation");
 hit(7,0);if(rejected_strikes!=1 || active!=255) $fatal(1,"full valid pad must reject without stealing");
 render(1024,1);if(peak==0) $fatal(1,"mix silent");
 reset();strike_track=0;for(i=0;i<8;i=i+1) hit(6,0);render(128,0);hit(5,0);
 if(!strike_accepted || dut.forced_release!=8'hfe || dut.pad[0]!=5 || rejected_strikes) $fatal(1,"full-pool explicit hat choke");
 render(520,0);
 reset();strike_track=1;for(i=0;i<8;i=i+1) hit(8,0);render(128,0);
 @(negedge clk);flush_all=1;@(negedge clk);flush_all=0;render(520,0);
 if(active) $fatal(1,"track stop flush left indefinite drum tails");
 $display("DRUM_CAPACITY_TB_PASS linear8tom_checks=%0d no_active_count_scaling valid_full_rejection choke8 flush natural_declick real_CE1040 max_render=%0d peak=%0d bound294912",checks,max_render,peak);$finish;
end
initial begin #100000000;$fatal(1,"capacity watchdog");end
endmodule
