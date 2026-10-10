`timescale 1ns/1ps
// Full scanner/audio/ADC/owner arbitration and CDC. Async 150MHz consumer,
// independent packet/PCM scoreboards, actual SPI serial device model.
module session_link_tb;
reg sys_clk=0;always #10 sys_clk=~sys_clk;reg observer_clk=0;always #3.333 observer_clk=~observer_clk;
reg arst=1,enc_a=0,enc_b=0,adc_miso=0;reg [2:0] button_n=7;reg [3:0] matrix_col_n=15;
reg [15:0] physical=0;wire [3:0] matrix_row_n;wire hp_bck,hp_ws,hp_din,pa_en,status_led,adc_sclk,adc_mosi,adc_cs_n;
reg client_valid=0,reply_ready=0,state_ready=1,pcm_ready=1;reg [7:0] client_addr=0;reg [31:0] client_value=0;reg [15:0] client_tag=0;
wire client_ready,reply_valid,reply_accepted,reply_applied;wire [7:0] reply_addr;wire [31:0] reply_value;wire [15:0] reply_tag;
wire state_valid,state_first,state_last,state_session_start,pcm_valid,pcm_gap,pcm_session_start,pcm_overflow,protocol_error;
wire [63:0] state_data;wire [5:0] state_word_index;wire signed [15:0] pcm_left,pcm_right;wire [31:0] pcm_index,state_drops,pcm_drops,adc_skipped;
session_link #(.ROW_CYCLES(8),.DEBOUNCE_FRAMES(2),.BUTTON_CYCLES(8),.LONG_CYCLES(1000),.ENCODER_CYCLES(8)) dut(.*);
wire [7:0] reply_reason;wire ui_valid,ui_first,ui_last,ui_session_start;wire [31:0] ui_data,ui_drops;wire [4:0] ui_index;wire ui_ready=state_ready;
integer row,frames=0,pcm_checks=0,state_checks=0,replies=0,gaps=0,session_pcm=0;
reg signed [15:0] exp_left[0:8191],exp_right[0:8191];reg [639:0] exp_record[0:255];integer record_sequence=0;
reg [31:0] random=32'h38ac1527;reg random_ready=0;reg [63:0] state_hold;reg previous_hold=0;
reg [31:0] record_id;integer words=0;
always @* begin matrix_col_n=15;for(row=0;row<4;row=row+1) if(matrix_row_n[row]===1'b0) matrix_col_n=matrix_col_n & ~physical[row*4+:4];end
always @(posedge sys_clk) if(!dut.platform.rst) begin
 if(dut.platform.tx_sample_ce) frames=frames+1;
 #1;
 if(dut.raw_pcm_valid) begin exp_left[dut.raw_index]=dut.raw_left;exp_right[dut.raw_index]=dut.raw_right;end
end
always @(posedge sys_clk) if(!dut.rst && dut.raw_ui_valid) begin
 if(!dut.ui_bridge.owned) exp_record[record_sequence]=dut.raw_ui;
 record_sequence=record_sequence+1;
end
always @(negedge observer_clk) begin
 random={random[30:0],random[31]^random[21]^random[1]^random[0]};if(random_ready) state_ready=random[0];
end
always @(posedge observer_clk) if(!arst && !dut.rst) begin
 if(previous_hold && (!ui_valid || {32'd0,ui_data}!==state_hold)) $fatal(1,"LU1 packet changed under backpressure");
 previous_hold=ui_valid&&!ui_ready;state_hold={32'd0,ui_data};
 if(ui_valid&&ui_ready) begin
  if(ui_first) begin if(ui_data!==32'h4c550117 || ui_index!=0) $fatal(1,"LU1 header");words=0;end
  if(ui_index==1) record_id=ui_data;
  if(ui_index>=3 && ui_data!==exp_record[record_id][(ui_index-3)*32+:32]) $fatal(1,"torn LU1 index%d seq%d",ui_index,record_id);
  words=words+1;if(ui_last) begin if(words!=23) $fatal(1,"length");state_checks=state_checks+1;end
 end
 if(pcm_valid&&pcm_ready) begin
  if(pcm_left!==exp_left[pcm_index] || pcm_right!==exp_right[pcm_index]) $fatal(1,"PCM CDC mismatch index%d",pcm_index);
  pcm_checks=pcm_checks+1;if(pcm_gap) gaps=gaps+1;if(pcm_session_start) session_pcm=session_pcm+1;
 end
 if(reply_valid&&reply_ready) replies=replies+1;
 if(protocol_error) $fatal(1,"ACK ownership protocol error");
end
// Independent MCP3208 protocol model, full default 24 clocks at 500kHz.
integer clocks=0,channel=0;reg [23:0] command;reg [11:0] sample_value;reg [11:0] positions[0:7];
always @(negedge adc_cs_n) begin clocks=0;command=0;adc_miso=0;end
always @(posedge adc_sclk) begin command={command[22:0],adc_mosi};clocks=clocks+1;
 if(clocks==10) begin if(command[9:3]!==7'b0000011) $fatal(1,"SPI framing");channel=command[2:0];sample_value=positions[channel];end end
always @(negedge adc_sclk) if(!adc_cs_n) begin if(clocks>=12&&clocks<=23) adc_miso=sample_value[23-clocks];else adc_miso=0;end
task advance;input integer n;integer target;begin target=frames+n;wait(frames>=target);@(negedge sys_clk);end endtask
task cfg;input [7:0] a;input [31:0] v;input [7:0] expected_reason;integer n;
begin @(negedge observer_clk);client_addr=a;client_value=v;client_tag=client_tag+1;client_valid=1;reply_ready=0;#1;
while(!client_ready) begin @(negedge observer_clk);#1;end
@(posedge observer_clk);#1;client_valid=0;wait(reply_valid);
if(reply_tag!=client_tag||reply_addr!=a||reply_value!=v||reply_accepted!=(expected_reason==0)||reply_applied!=(expected_reason==0)||reply_reason!=expected_reason) $fatal(1,"reply payload/origin");
for(n=0;n<80;n=n+1) begin @(negedge observer_clk);if(!reply_valid||reply_tag!=client_tag||client_ready) $fatal(1,"held reply overwritten");end
$display("SESSION_ACTION addr=%h value=%h reason=%0d frame=%0d",a,v,reply_reason,frames);reply_ready=1;@(posedge observer_clk);#1;reply_ready=0;repeat(8) @(negedge observer_clk);end endtask
task key;input integer k;begin @(negedge sys_clk);button_n[k]=0;repeat(50) @(negedge sys_clk);button_n[k]=1;repeat(50) @(negedge sys_clk);advance(3);end endtask
integer i,commits=0,ons=0,offs=0;
always @(posedge sys_clk) begin
 if(dut.platform.record_commit) commits=commits+1;
 if(dut.platform.record_event_valid&&dut.platform.record_event_ready) begin
  if(dut.platform.record_event_kind==0) ons=ons+1;
  if(dut.platform.record_event_kind==1) offs=offs+1;
 end
end
wire fast_tick=dut.platform.tx_sample_ce && dut.platform.transport_run;
wire fast_beat=fast_tick && frames%96==0;
wire fast_bar=fast_tick && frames%384==0;
// Only accelerate musical boundaries; synthesis/PCM/scanner/ADC retain real cadence.
initial begin
force dut.platform.tick_pulse=fast_tick;force dut.platform.beat_pulse=fast_beat;force dut.platform.bar_pulse=fast_bar;
positions[0]=3000;positions[1]=4095;positions[2]=1024;positions[3]=512;positions[4]=256;positions[5]=1234;positions[6]=2345;positions[7]=4095;
repeat(8) @(negedge sys_clk);arst=0;wait(!dut.rst);advance(8);
cfg(1,20000,0);cfg(0,1,6);cfg(0,2,0);cfg('h3f,1,1);
physical=1;advance(40);physical=0;advance(10);key(0);
if(dut.platform.selected_preset!=3 || replies!=4) $fatal(1,"local ACK leaked/sync");
cfg(0,0,0);cfg('h22,2,0);cfg('h25,1,0);cfg('h26,2,3);
wait(dut.platform.recording);physical=1;advance(24);physical=0;advance(20);
wait(commits==1);wait(!dut.platform.store_edit_busy);advance(10);
if(ons!=1 || offs!=1 || !dut.platform.layer_valid[8]) $fatal(1,"real take pair/track2");
cfg('h28,(2<<17)|32768,0);advance(260);
if(dut.platform.track_gains[34+:17]!=32768 || dut.platform.audio.master_target!=20000) $fatal(1,"relative gain/master");
cfg('h29,5,0);advance(515);if(dut.platform.track_gains[34+:17]!=0) $fatal(1,"mute ramp");cfg('h29,4,0);
cfg('h27,2,2);cfg('h26,2,0);wait(!dut.platform.layer_valid[8]);wait(!dut.platform.flushing);advance(10);cfg('h26,2,4);
cfg(0,6,0);advance(2);if(dut.platform.selected_preset!=6) $fatal(1,"remote drums translated but menu not committed");
physical=16'h0400;advance(10);physical=0;advance(10);if(dut.platform.drum_rejected!=0 || dut.platform.fault) $fatal(1,"disabled pad allocated");
cfg('h22,1,0);cfg('h25,1,0);wait(dut.platform.recording);physical=1;advance(24);physical=0;advance(20);
wait(commits==2);advance(450);if(!dut.platform.layer_valid[4] || dut.platform.store.patch_mem[4][2:0]!=6) $fatal(1,"drum track patch/replay");
cfg('h27,32'h434c5201,0);wait(dut.platform.layer_valid[7:4]==0);wait(!dut.platform.flushing);advance(10);
cfg('h24,1,0);wait(!dut.platform.transport_run);wait(!dut.platform.flushing);
cfg('h2e,1,0);cfg('h2a,180,0);advance(320);
if(!dut.platform.met_enable || dut.platform.transport_run || dut.platform.bpm!=180) $fatal(1,"global metronome/BPM");
random_ready=1;advance(600);if(state_checks<3 || pcm_checks<1000) $fatal(1,"real LU1/PCM not observed");
pcm_ready=0;advance(100);if(!pcm_overflow||pcm_drops==0) $fatal(1,"PCM loss observation");pcm_ready=1;advance(100);
if(gaps<2) $fatal(1,"PCM gap not flagged");
if(adc_skipped || protocol_error || dut.platform.audio_deadline || dut.platform.fault) $fatal(1,"integration fault");
$display("SESSION_LINK_TB_PASS real32_12_audio realADC async135MHz held_tagged_reply LUT_status take_track2 undo clear drum_track1 masked_pads master_mix_independent BPM_target PCM_gap snapshots=%0d",state_checks);
$finish;end
initial begin #400000000;$fatal(1,"link watchdog frames%d",frames);end
endmodule
