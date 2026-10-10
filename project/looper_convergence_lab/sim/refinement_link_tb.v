`timescale 1ns/1ps
// Full scanner/audio/ADC/owner arbitration and CDC. Async 150MHz consumer,
// independent packet/PCM scoreboards, actual SPI serial device model.
module refinement_link_tb;
reg sys_clk=0;always #10 sys_clk=~sys_clk;reg observer_clk=0;always #3.333 observer_clk=~observer_clk;
reg arst=1,enc_a=0,enc_b=0,adc_miso=0;reg [2:0] button_n=7;reg [3:0] matrix_col_n=15;
reg [15:0] physical=0;wire [3:0] matrix_row_n;wire hp_bck,hp_ws,hp_din,pa_en,status_led,adc_sclk,adc_mosi,adc_cs_n;
reg client_valid=0,reply_ready=0,state_ready=1,pcm_ready=1;reg [4:0] client_addr=0;reg [31:0] client_value=0;reg [15:0] client_tag=0;
wire client_ready,reply_valid,reply_accepted,reply_applied;wire [4:0] reply_addr;wire [31:0] reply_value;wire [15:0] reply_tag;
wire state_valid,state_first,state_last,state_session_start,pcm_valid,pcm_gap,pcm_session_start,pcm_overflow,protocol_error;
wire [63:0] state_data;wire [5:0] state_word_index;wire signed [15:0] pcm_left,pcm_right;wire [31:0] pcm_index,state_drops,pcm_drops,adc_skipped;
refinement_link #(.ROW_CYCLES(8),.DEBOUNCE_FRAMES(2),.BUTTON_CYCLES(8),.LONG_CYCLES(1000),.ENCODER_CYCLES(8)) dut(.*);
integer row,frames=0,pcm_checks=0,state_checks=0,replies=0,gaps=0,session_pcm=0;
reg signed [15:0] exp_left[0:8191],exp_right[0:8191];reg [3455:0] exp_record[0:7];integer record_sequence=0;
reg [31:0] random=32'h38ac1527;reg random_ready=0;reg [63:0] state_hold;reg previous_hold=0;
reg [31:0] record_id;integer words=0;
always @* begin matrix_col_n=15;for(row=0;row<4;row=row+1) if(matrix_row_n[row]===1'b0) matrix_col_n=matrix_col_n & ~physical[row*4+:4];end
always @(posedge sys_clk) if(!dut.platform.rst) begin
 if(dut.platform.tx_sample_ce) frames=frames+1;
 #1;
 if(dut.raw_pcm_valid) begin exp_left[dut.raw_index]=dut.raw_left;exp_right[dut.raw_index]=dut.raw_right;end
end
always @(posedge sys_clk) if(!dut.platform.rst && dut.raw_state_valid) begin
 if(!dut.state_bridge.src_busy) exp_record[record_sequence]={48'd0,dut.keys,dut.extension,dut.raw_state,dut.capabilities,state_drops,record_sequence,16'h4c52,8'd1,8'd54,8'd45,8'd4,8'd16,8'd0};
 record_sequence=record_sequence+1;
end
always @(negedge observer_clk) begin
 random={random[30:0],random[31]^random[21]^random[1]^random[0]};if(random_ready) state_ready=random[0];
end
always @(posedge observer_clk) if(!arst && !dut.rst) begin
 if(previous_hold && (!state_valid || state_data!==state_hold)) $fatal(1,"state packet changed under backpressure");
 previous_hold=state_valid&&!state_ready;state_hold=state_data;
 if(state_valid&&state_ready) begin
  if(state_first) begin if(state_data!==64'h4c5201362d041000 || state_word_index!=0) $fatal(1,"Looper header/count/version");record_id=state_data;words=0;end
  if(state_word_index==1) record_id=state_data[31:0];
  if(state_word_index>=1 && state_data!==exp_record[record_id][state_word_index*64+:64]) $fatal(1,"torn state word%d seq%d",state_word_index,record_id);
  words=words+1;if(state_last) begin if(words!=54) $fatal(1,"packet length");state_checks=state_checks+1;end
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
task cfg;input [4:0] a;input [31:0] v;input expected_ok;integer n;
begin @(negedge observer_clk);client_addr=a;client_value=v;client_tag=client_tag+1;client_valid=1;reply_ready=0;#1;
while(!client_ready) begin @(negedge observer_clk);#1;end
@(posedge observer_clk);#1;client_valid=0;wait(reply_valid);
if(reply_tag!=client_tag||reply_addr!=a||reply_value!=v||reply_accepted!=expected_ok||reply_applied!=expected_ok) $fatal(1,"reply payload/origin");
for(n=0;n<80;n=n+1) begin @(negedge observer_clk);if(!reply_valid||reply_tag!=client_tag||client_ready) $fatal(1,"held reply overwritten");end
reply_ready=1;@(posedge observer_clk);#1;reply_ready=0;repeat(8) @(negedge observer_clk);end endtask
task key;input integer k;begin @(negedge sys_clk);button_n[k]=0;repeat(50) @(negedge sys_clk);button_n[k]=1;repeat(50) @(negedge sys_clk);advance(3);end endtask
integer i;
initial begin
positions[0]=3000;positions[1]=4095;positions[2]=1024;positions[3]=512;positions[4]=256;positions[5]=1234;positions[6]=2345;positions[7]=4095;
repeat(8) @(negedge sys_clk);arst=0;wait(!dut.rst);advance(8);
cfg(1,20000,1);cfg(0,1,0);cfg(0,2,1);
physical=1;advance(40);physical=0;advance(10);key(0);
if(dut.platform.selected_preset!=3||replies!=3) $fatal(1,"local state sync or leaked local ACK");
cfg(0,4,1);physical=1;advance(100);
// Faders change purpose with soft pickup, master stays global.
key(2);key(2);if(!dut.mix_mode) $fatal(1,"mixer page");
for(i=1;i<5;i=i+1) positions[i]=4095;advance(110);
for(i=1;i<5;i=i+1) positions[i]=2048;advance(650);
for(i=0;i<4;i=i+1) if(dut.mixer_targets[i*17+:17]!=32768 || dut.platform.track_gains[i*17+:17]!=32768) $fatal(1,"fader mixer target/smooth%d",i);
if(dut.platform.audio.master_target!=20000) $fatal(1,"relative mixer changed absolute master actual=%d owner=%d adc=%h",dut.platform.audio.master_target,dut.platform.audio.master_owner,dut.adc_data);
key(2);key(2);key(2);advance(150);
if(dut.harmonic_targets!=={12'd256,12'd512,12'd1024,12'd4095}) $fatal(1,"mixer positions jumped harmonic edit targets");
random_ready=1;advance(1100);if(state_checks<1||pcm_checks<1000) $fatal(1,"real state/PCM consumer not reached");
pcm_ready=0;advance(100);if(!pcm_overflow||pcm_drops==0) $fatal(1,"PCM overflow not observed");pcm_ready=1;advance(100);
if(gaps<2) $fatal(1,"dropped PCM did not advertise gap");
physical=0;advance(100);if(adc_skipped||protocol_error||dut.platform.audio_deadline) $fatal(1,"full link deadline/ADC/ACK");
$display("REFINEMENT_LINK_TB_PASS real_audio_snapshot54 ADC500k scan8 local_remote_ACK fader_mode_pickup mixer_master_independent async150MHz PCM_checks=%d snapshots=%d gaps=%d",pcm_checks,state_checks,gaps);
$finish;end
initial begin #150000000;$fatal(1,"link watchdog frames%d",frames);end
endmodule
