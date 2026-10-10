`timescale 1ns/1ps
module expression_empty_tb;
reg clk=0;always #10 clk=~clk;reg rst=1,play=0,reset_play=0,wrap=0,start=0,rv=0;
reg [11:0] tick=0;reg [1:0] kind=0;reg [6:0] note=0;reg [15:0] id=0;reg [7:0] velocity=0;
wire rr,recording,commit,overflow,error,lv,lr,off,drum,control;
wire [1:0] tr,la;wire [11:0] et;wire [6:0] en;wire [15:0] ei;wire [7:0] ev;
wire [2:0] preset;wire [135:0] patch;wire [15:0] layer_valid;
wire bv,bo,expression_valid;wire [31:0] bt;wire [1:0] ek,ext,exl;wire [16:0] exv;
reg br=0;reg [31:0] random=32'h31415926;integer music=0,expressions=0,cycles=0;
reg [31:0] on_token;wire [31:0] faults,unmatched;
always @(negedge clk) begin random={random[30:0],random[31]^random[21]^random[1]^random[0]};br=random[0];end
looper_event_store #(.RECORD_TICK_INPUT(1),.SERIAL_NOTES(1)) store(
 .clk(clk),.rst(rst),.play_enable(play),.playback_reset(reset_play),.loop_wrap(wrap),.loop_tick(tick),.loop_length(12'd96),.quantize_mode(2'd0),
 .record_start(start),.record_lane(4'd0),.record_patch(136'd4),.record_event_valid(rv),.record_tick(tick),.record_busy(1'b0),
 .record_event_ready(rr),.record_event_kind(kind),.record_note(note),.record_note_id(id),.record_velocity(velocity),
 .recording(recording),.record_commit(commit),.record_overflow(overflow),.record_error(error),.record_cancel(1'b0),
 .clear_valid(1'b0),.clear_track(2'd0),.undo_valid(1'b0),.undo_lane(4'd0),.layer_valid(layer_valid),
 .event_valid(lv),.event_ready(lr),.event_off(off),.event_drum(drum),.event_control(control),.event_track(tr),.event_layer(la),
 .event_tick(et),.event_note(en),.event_note_id(ei),.event_velocity(ev),.event_preset(preset),.event_patch(patch));
looper_event_router #(.VOICES(4)) router(
 .clk(clk),.rst(rst),.live_valid(1'b0),.live_tick(12'd0),.live_off(1'b0),.live_token(32'd0),.live_note(7'd0),.live_preset(3'd0),
 .recording(1'b0),.record_ready(1'b1),.bank_accepted(1'b0),.bank_rejected(1'b0),.flush_all(1'b0),.flush_valid(1'b0),
 .flush_track(2'd0),.flush_layer(2'd0),.flush_whole_track(1'b0),
 .loop_valid(lv),.loop_ready(lr),.loop_off(off),.loop_drum(drum),.loop_control(control),.loop_track(tr),.loop_layer(la),
 .loop_local_id(ei),.loop_note(en),.loop_velocity(ev),.loop_preset(preset),.loop_patch(patch),
 .bank_valid(bv),.bank_ready(br),.bank_off(bo),.bank_token(bt),
 .expression_valid(expression_valid),.expression_kind(ek),.expression_track(ext),.expression_layer(exl),.expression_value(exv),
 .drum_ready(1'b1),.drum_accepted(1'b1),.route_faults(faults),.unmatched_offs(unmatched));
always @(posedge clk) if(!rst) begin
 if(expression_valid) begin
  case(expressions)
   0:if(ek!=0 || exv!=1) $fatal(1,"initial pedal");
   1:if(ek!=1 || exv!=0) $fatal(1,"initial selective");
   2:if(ek!=2 || exv!=65536) $fatal(1,"initial bend");
   3:if(ek!=2 || exv!=73562) $fatal(1,"bend value17");
   4:if(ek!=0 || exv!=0) $fatal(1,"pedal release");
   default:$fatal(1,"duplicate control");
  endcase
  if(ext!=0 || exl!=0 || bv) $fatal(1,"control allocated a voice");expressions=expressions+1;
 end
 if(bv && br) begin
  if(music==0) begin if(bo || expressions!=3) $fatal(1,"note before initial controls");on_token=bt;end
  else if(music==1) begin if(!bo || bt!=on_token) $fatal(1,"off identity");end
  else $fatal(1,"duplicate music");music=music+1;
 end
end
task record;input [11:0] t;input [1:0] k;input [6:0] n;input [15:0] local_id;input [7:0] v;
begin @(negedge clk);tick=t;kind=k;note=n;id=local_id;velocity=v;rv=1;#2;
while(!rr) begin @(negedge clk);#2;end
@(posedge clk);#2;@(negedge clk);rv=0;repeat(3) @(negedge clk);end endtask
initial begin repeat(4) @(negedge clk);rst=0;start=1;@(negedge clk);start=0;
record(0,3,0,0,0);record(0,3,1,0,0);record(0,3,2,0,1);
wrap=1;@(negedge clk);wrap=0;wait(!recording);wait(!store.close_pending);@(negedge clk);
if(layer_valid!=0 || commit || overflow) $fatal(1,"control-only take used a musical layer");
$display("EXPRESSION_EMPTY_TB_PASS three_initial_controls no_musical_event no_layer_commit");$finish;end
initial begin #1000000;$fatal(1,"store/router watchdog");end
endmodule
