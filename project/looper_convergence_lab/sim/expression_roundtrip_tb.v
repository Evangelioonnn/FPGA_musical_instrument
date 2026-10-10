`timescale 1ns/1ps
module expression_roundtrip_tb;
reg clk=0;always #10 clk=~clk;reg rst=1;integer divider=0,frames=0;
wire sample_ce=divider==1039;always @(negedge clk) if(rst) divider=0;else divider=(divider+1)%1040;
reg [15:0] keys=0;reg changed=0;reg [11:0] tick=0;reg start=0,wrap=0,play=0;
reg host_valid=0;wire host_ready;reg [4:0] addr=0;reg [31:0] value=0;
wire recording,commit,overflow,error,rv,rr,busy;wire [11:0] rt;wire [1:0] rk;wire [6:0] rn;wire [15:0] ri;wire [7:0] rvel;
wire lv,lr,off,drum,control;wire [1:0] tr,la;wire [11:0] et;wire [6:0] en;wire [15:0] ei;wire [7:0] ev;
wire [2:0] preset;wire [135:0] patch,current_patch;wire [15:0] layers;
wire final_valid,deadline,expression_overflow;wire signed [15:0] left,right;wire [3:0] occupied,held,gated;wire [31:0] route_faults;
looper_event_store #(.RECORD_TICK_INPUT(1),.SERIAL_NOTES(1)) store(
 .clk(clk),.rst(rst),.play_enable(play),.playback_reset(1'b0),.loop_wrap(wrap),.loop_tick(tick),.loop_length(12'd96),.quantize_mode(2'd0),
 .record_start(start),.record_lane(4'd0),.record_patch(current_patch),.record_event_valid(rv),.record_tick(rt),.record_busy(busy),
 .record_event_ready(rr),.record_event_kind(rk),.record_note(rn),.record_note_id(ri),.record_velocity(rvel),
 .recording(recording),.record_commit(commit),.record_overflow(overflow),.record_error(error),.record_cancel(1'b0),
 .clear_valid(1'b0),.clear_track(2'd0),.undo_valid(1'b0),.undo_lane(4'd0),.layer_valid(layers),
 .event_valid(lv),.event_ready(lr),.event_off(off),.event_drum(drum),.event_control(control),.event_track(tr),.event_layer(la),
 .event_tick(et),.event_note(en),.event_note_id(ei),.event_velocity(ev),.event_preset(preset),.event_patch(patch));
looper_audio_core #(.N(4),.PLUCK_N(1),.WITH_FX(0),.WITH_EXPRESSION(1)) audio(
 .clk(clk),.rst(rst),.sample_ce(sample_ce),.keys(keys),.changed(changed),.ghost(1'b0),.all_released(keys==0),
 .button_n(3'b111),.step_valid(1'b0),.step(2'sd0),.recording(recording),.capture_recording(recording),
 .current_loop_tick(tick),.record_ready(rr),.record_busy(busy),.record_event_tick(rt),.drum_mode(1'b0),.auxiliary_sample(16'sd0),
 .flush_all(1'b0),.flush_valid(1'b0),.flush_whole_track(1'b0),.flush_track(2'd0),.flush_layer(2'd0),
 .loop_event_valid(lv),.loop_event_ready(lr),.loop_event_off(off),.loop_event_drum(drum),.loop_event_control(control),
 .loop_event_track(tr),.loop_event_layer(la),.loop_event_id(ei),.loop_event_tick(et),.loop_event_note(en),
 .loop_event_velocity(ev),.loop_event_preset(preset),.loop_event_patch(patch),.track_gains({4{17'd65536}}),
 .record_event_valid(rv),.record_event_kind(rk),.record_event_note(rn),.record_event_id(ri),.record_event_velocity(rvel),
 .record_patch_current(current_patch),.expression_overflow(expression_overflow),.loop_route_faults(route_faults),
 .drum_event_ready(1'b1),.drum_event_accepted(1'b1),.host_valid(host_valid),.host_ready(host_ready),.host_addr(addr),.host_value(value),
 .adc_valid(1'b0),.adc_ch0(12'd0),.adc_ch1(12'd0),.adc_ch2(12'd0),.adc_ch3(12'd0),.adc_ch4(12'd0),
 .final_valid(final_valid),.final_left(left),.final_right(right),.deadline_missed(deadline),.occupied(occupied),.held(held),.gated(gated));
integer recorded_controls=0,recorded_notes=0,replayed_controls=0,nonzero=0,slot1=-1,slot2=-1,i,fd;
always @(posedge clk) if(!rst) begin
 if(sample_ce) frames=frames+1;
 if(rv&&rr) begin if(rk==3) recorded_controls=recorded_controls+1;else recorded_notes=recorded_notes+1;end
 if(audio.event_router.expression_valid) replayed_controls=replayed_controls+1;
 #1;
 if(deadline||expression_overflow||overflow||route_faults) $fatal(1,"roundtrip fault");
 if(final_valid) begin
  if((^left)===1'bx) $fatal(1,"unknown roundtrip PCM");
  if(left!=0) nonzero=nonzero+1;
  if(fd) $fdisplay(fd,"%0d",left);
 end
end
task advance;input integer n;integer target;begin target=frames+n;wait(frames>=target);wait(final_valid);@(negedge clk);end endtask
task cfg;input [4:0] a;input [31:0] v;
begin @(negedge clk);addr=a;value=v;host_valid=1;#1;while(!host_ready) begin @(negedge clk);#1;end
@(posedge clk);#2;host_valid=0;wait(audio.ack_valid);@(negedge clk);advance(2);end endtask
task key;input [15:0] k;begin @(negedge clk);keys=k;changed=1;@(negedge clk);changed=0;advance(8);end endtask
task position;input [11:0] t;begin @(negedge clk);tick=t;advance(8);end endtask
task find_slots;begin
 slot1=-1;slot2=-1;for(i=0;i<4;i=i+1) if(audio.bank.loop_mask[i]) begin
  if(audio.bank.notes[i]==48) slot1=i;if(audio.bank.notes[i]==50) slot2=i;
 end
end endtask
initial begin fd=0;repeat(4) @(negedge clk);rst=0;advance(8);cfg(0,4);cfg(1,65536);
@(negedge clk);start=1;@(negedge clk);start=0;advance(8);
tick=10;key(1);tick=20;cfg(5,1);tick=30;cfg(6,1);tick=40;cfg(9,8);
tick=50;key(3);tick=60;key(2);tick=65;key(0);tick=70;cfg(5,0);tick=80;cfg(6,0);
advance(20);tick=95;wrap=1;@(negedge clk);wrap=0;wait(commit);@(negedge clk);
if(recorded_controls!=8 || recorded_notes!=4 || !layers[0]) $fatal(1,"record event count controls%d notes%d",recorded_controls,recorded_notes);
// A conflicting live state must not alter recorded loop controls.
cfg(5,1);cfg(6,1);cfg(9,-8);advance(600);tick=0;play=1;
fd=$fopen("audio/expression_roundtrip.txt","w");if(!fd) $fatal(1,"audio path unavailable");position(0);
if(audio.bank.loop_pedal[0] || audio.bank.loop_sost[0] || audio.bank.loop_bend[0]!=65536) $fatal(1,"initial loop state poisoned by live state");
position(10);position(20);position(30);position(40);
if(audio.bank.loop_bend[0]!=73562) $fatal(1,"recorded bend not replayed");
position(50);position(60);position(65);position(70);find_slots;
if(slot1<0||slot2<0||held[slot1]||held[slot2]||!gated[slot1]||gated[slot2]) $fatal(1,"selective subset after ordinary release slots%d/%d gated%b",slot1,slot2,gated);
position(80);if(gated[slot1]) $fatal(1,"selective release failed");position(95);
if(replayed_controls!=8 || nonzero<100) $fatal(1,"roundtrip replay count/PCM");
$fclose(fd);fd=0;
$display("EXPRESSION_ROUNDTRIP_TB_PASS actual_core_store controls8 notes4 live_poison_ignored selective_subset bend realtime_CE1040");$finish;end
initial begin #50000000;$fatal(1,"roundtrip watchdog");end
endmodule
