`timescale 1ns/1ps
// Independent note/pedal expectations and DDS recurrence. Loop controls are
// scoped by track+layer; live pedal poisoning must not affect loop voices.
module expression_bank_tb;
reg clk=0;always #10 clk=~clk;reg rst=1;integer divider=0,frames=0;
wire ce=divider==1039;always @(negedge clk) if(rst) divider=0;else divider=(divider+1)%1040;
reg ev=0,off=0,force_off=0;reg [31:0] token=1;reg [6:0] note=60;reg [1:0] track=0,layer=0;
reg cv=0;reg [1:0] ck=0,ct=0,cl=0;reg [16:0] value=0;reg reset_controls=0;
reg [135:0] patch=0;wire ready,accepted,rejected,valid,deadline;
wire [3:0] occupied,held,gated;wire [31:0] rejects;
audio_v2_bank #(.N(4),.PLUCK_N(1)) dut(
 .clk(clk),.rst(rst),.sample_ce(ce),.event_valid(ev),.event_ready(ready),.event_off(off),
 .event_token(token),.event_note(note),.event_timbre(3'd4),.event_is_loop(1'b1),.event_track({1'b0,track}),
 .event_layer(layer),.event_force_release(force_off),.event_patch(patch),.track_gains({4{17'd65536}}),
 .expression_valid(cv),.expression_kind(ck),.expression_track(ct),.expression_layer(cl),.expression_value(value),
 .expression_reset_all(reset_controls),.expression_reset_valid(1'b0),.expression_reset_whole_track(1'b0),
 .expression_reset_track(2'd0),.expression_reset_layer(2'd0),
 .pedal(1'b1),.sostenuto(1'b1),.reference_release(16'd1),.glide_index(3'd0),.lead_attack_index(2'd0),
 .bend_factor(17'd58386),.lead_bend_factor(17'd58386),.envelope_override(1'b0),.custom_hold(1'b0),
 .adsr_attack(16'd1),.adsr_decay(16'd1),.adsr_sustain(16'd0),.adsr_release(16'd1),
 .coeff0(9'd0),.coeff1(9'd0),.coeff2(9'd0),.coeff3(9'd0),
 .accepted(accepted),.rejected(rejected),.rejected_count(rejects),.occupied(occupied),.held(held),.gated(gated),
 .out_valid(valid),.deadline_missed(deadline));
reg [31:0] phase_model[0:3],step_model[0:3],bent_model[0:3];
reg [16:0] slew_model[0:3],target_model[0:3];reg [3:0] model_active=0;
reg [63:0] product_model;integer i,checks=0;real frequency;
always @(posedge clk) if(!rst) begin
 if(ce) begin
  frames=frames+1;
  for(i=0;i<4;i=i+1) if(model_active[i]) begin
   phase_model[i]=phase_model[i]+(slew_model[i]==65536 ? step_model[i] : bent_model[i]);
   product_model=step_model[i]*64'd1*slew_model[i];bent_model[i]=product_model>>16;
   if(slew_model[i]+64<target_model[i]) slew_model[i]=slew_model[i]+64;
   else if(slew_model[i]>target_model[i]+64) slew_model[i]=slew_model[i]-64;
   else slew_model[i]=target_model[i];
  end
 end
 #1;
 if(valid) begin
  if(deadline || rejected || rejects) $fatal(1,"expression bank fault");
  for(i=0;i<4;i=i+1) if(model_active[i] && held[i]) begin
   if(dut.phases[i*32+:32]!==phase_model[i]) $fatal(1,"loop DDS recurrence slot%d frame%d expected%h actual%h",i,frames,phase_model[i],dut.phases[i*32+:32]);
   checks=checks+1;
  end
 end
end
task control;input [1:0] tr,la,k;input [16:0] v;
begin @(negedge clk);while(!ready) @(negedge clk);ct=tr;cl=la;ck=k;value=v;cv=1;
@(negedge clk);cv=0;repeat(2) @(negedge clk);end endtask
task command;input integer id;input stop,forced;input [1:0] tr,la;input [6:0] pitch;
begin @(negedge clk);while(!ready) @(negedge clk);token=id;off=stop;force_off=forced;track=tr;layer=la;note=pitch;ev=1;
@(negedge clk);ev=0;wait(accepted);@(negedge clk);
if(!stop) begin
 frequency=440.0*(2.0**(($itor(pitch)-69.0)/12.0));step_model[id-1]=$rtoi(frequency*4294967296.0/(50000000.0/1040.0)+0.5);
 phase_model[id-1]=0;bent_model[id-1]=step_model[id-1];slew_model[id-1]=65536;target_model[id-1]=65536;model_active[id-1]=1;
end end endtask
task advance;input integer n;integer target;begin target=frames+n;wait(frames>=target);wait(valid);@(negedge clk);end endtask
task reset_bank;begin @(negedge clk);rst=1;model_active=0;repeat(4) @(negedge clk);rst=0;end endtask
initial begin
patch[2:0]=4;patch[66:51]=65535;patch[82:67]=0;patch[98:83]=65535;patch[114:99]=512;patch[123]=1;patch[119:118]=2;
repeat(4) @(negedge clk);rst=0;
control(0,0,0,1);command(1,0,0,0,0,60);command(2,0,0,1,0,62);advance(5);
command(1,1,0,0,0,60);command(2,1,0,1,0,62);advance(5);
if(gated[1] || !gated[0] || held[0]) $fatal(1,"ordinary sustain leaked tracks");
control(0,0,0,0);advance(3);if(gated[0]) $fatal(1,"pedal up did not release");
reset_bank;command(1,0,0,0,0,60);advance(3);control(0,0,1,1);command(2,0,0,0,0,62);
command(1,1,0,0,0,60);command(2,1,0,0,0,62);advance(3);
if(!gated[0] || gated[1]) $fatal(1,"selective sustain did not freeze held subset");
control(0,0,1,0);advance(3);if(gated[0]) $fatal(1,"sostenuto release");
reset_bank;command(1,0,0,0,0,60);command(2,0,0,1,0,62);advance(4);
control(0,0,2,73562);target_model[0]=73562;advance(200);
if(dut.loop_bend[4]!=65536 || checks<300) $fatal(1,"bend track independence");
control(0,0,0,1);command(1,1,1,0,0,60);advance(4);if(gated[0]) $fatal(1,"auto-close force release under pedal");
control(1,0,0,1);command(2,1,0,1,0,62);advance(2);if(!gated[1]) $fatal(1,"second sustain");
reset_controls=1;@(negedge clk);reset_controls=0;advance(3);if(gated[1]) $fatal(1,"stop reset left sustain held");
$display("EXPRESSION_BANK_TB_PASS ordinary selective subset layer_scope live_poison independent_bend force_close reset DDS_checks=%0d",checks);$finish;
end
initial begin #20000000;$fatal(1,"expression bank watchdog");end
endmodule
