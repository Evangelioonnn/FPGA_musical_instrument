`timescale 1ns/1ps
module drum_revision_tb;
reg clk=0;always #10 clk=~clk;
reg rst=1;integer divider=0;wire sample_ce=divider==63;
always @(negedge clk) if(rst) divider=0;else divider=(divider+1)%64;
reg strike_valid=0;reg [3:0] strike_pad=0,old_pad=2;reg [7:0] strike_velocity=255;
wire strike_ready,strike_accepted,sample_valid,old_valid;wire signed [19:0] sample,old_sample;
wire active;wire [3:0] active_pads;wire [31:0] late_strikes,rejected_strikes;
looper_drum_engine #(.VOICES(1)) dut(.clk(clk),.rst(rst),.sample_ce(sample_ce),.strike_valid(strike_valid),
 .strike_ready(strike_ready),.strike_accepted(strike_accepted),.strike_pad(strike_pad),.strike_velocity(strike_velocity),
 .strike_layer(2'd0),.strike_track(3'd4),.track_gains({4{17'd65536}}),.flush_all(1'b0),.flush_valid(1'b0),
 .flush_track(2'd0),.flush_layer(2'd0),.flush_whole_track(1'b0),.sample_valid(sample_valid),.sample(sample),.active(active),.active_pads(active_pads),.late_strikes(late_strikes),.rejected_strikes(rejected_strikes));
original_drum #(.VOICES(1)) oracle(.clk(clk),.rst(rst),.sample_ce(sample_ce),.strike_valid(strike_valid),.strike_pad(old_pad),.strike_velocity(strike_velocity),
 .strike_layer(2'd0),.strike_track(3'd4),.track_gains({4{17'd65536}}),.flush_all(1'b0),.flush_valid(1'b0),
 .flush_track(2'd0),.flush_layer(2'd0),.flush_whole_track(1'b0),.sample_valid(old_valid),.sample(old_sample));
integer frames=0,comparisons=0,mode=0,i,j,fd=0,peak=0,absolute;
always @(posedge clk) begin
 #1;if(sample_valid&&!rst) begin
  frames=frames+1;
  if(fd) $fdisplay(fd,"%0d",sample);
  absolute=sample<0 ? -sample : sample;if(absolute>peak) peak=absolute;
  if(mode==1 && (!old_valid || sample!==old_sample)) $fatal(1,"unchanged kick/snare mismatch pad%0d frame%0d",strike_pad,frames);
  if(mode==2 && (!old_valid || sample!==(old_sample>>>1))) $fatal(1,"closed hat not old open half gain frame%0d",frames);
  if(mode>0) comparisons=comparisons+1;
  if(late_strikes) $fatal(1,"drum render late");
 end
end
task start;input integer padid;input integer oldid;input integer vel;
begin
 @(negedge clk);rst=1;mode=0;frames=0;peak=0;strike_valid=0;repeat(4) @(negedge clk);rst=0;
 strike_pad=padid;old_pad=oldid;strike_velocity=vel;@(negedge clk);
 while(!strike_ready) @(negedge clk);
 strike_valid=1;@(negedge clk);strike_valid=0;
end endtask
reg [127:0] filename;integer pads[0:11];integer velocities[0:2];integer n;
initial begin
 pads[0]=0;pads[1]=1;pads[2]=2;pads[3]=3;pads[4]=4;pads[5]=9;
 pads[6]=5;pads[7]=6;pads[8]=7;pads[9]=8;pads[10]=12;pads[11]=13;
 velocities[0]=64;velocities[1]=127;velocities[2]=255;
 for(j=0;j<3;j=j+1) begin
  start(0,2,velocities[j]);mode=1;wait(frames==4096);
  start(1,1,velocities[j]);mode=1;wait(frames==4096);
  start(5,6,velocities[j]);mode=2;wait(frames==4096);
 end
 // Fixed velocities for an independently computed integer-model comparison.
 for(i=0;i<12;i=i+1) for(j=0;j<3;j=j+1) begin
  start(pads[i],0,velocities[j]);
  fd=$fopen($sformatf("audio/drum_vector_%0d_%0d.txt",pads[i],velocities[j]),"w");
  if(!fd) $fatal(1,"vector file");wait(frames==4096);$fclose(fd);fd=0;
  if(peak>36864) $fatal(1,"single slot arithmetic bound pad%0d peak%0d",pads[i],peak);
 end
 for(n=10;n<16;n=n+1) if(n!=12&&n!=13) begin start(n,0,255);if(active || rejected_strikes!=1) $fatal(1,"removed voice accepted");end
 $display("DRUM_REVISION_TB_PASS original_PCM_checks=%0d kick_old_low_tom snare_unchanged closed_old_open_half disabled_consumed vectors=36 bound=36864 offline_CE64",comparisons);$finish;
end
initial begin #500000000;$fatal(1,"drum revision watchdog");end
endmodule
