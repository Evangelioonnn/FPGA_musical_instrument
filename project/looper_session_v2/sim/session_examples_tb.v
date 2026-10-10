`timescale 1ns/1ps
module session_examples_tb;
reg clk=0;always #3.333 clk=~clk;reg rst=1;wire valid,ready,first,last,session_start;
wire [31:0] data;wire [4:0] index;wire updated,new_session,protocol_error;wire [639:0] ui;wire [31:0] sequence,drops;
session_ui_mock #(.UPDATE_CYCLES(37)) mock(.*);
session_ui_unpacker unpacker(.*);
wire [2:0] page,preset,meter,bars,beat_in_bar;wire [1:0] selected_track,record_track,quantize;
wire [7:0] bpm_requested,bpm_applied;wire [11:0] loop_length;wire [15:0] layers,keys,drum_pads,drum_sequence;
wire [16:0] master_target,master_applied;wire [67:0] track_gains;wire [35:0] coefficients;
session_ui_view view(.ui(ui),.page(page),.preset(preset),.selected_track(selected_track),.record_track(record_track),
 .meter(meter),.bars(bars),.quantize(quantize),.beat_in_bar(beat_in_bar),.bpm_requested(bpm_requested),.bpm_applied(bpm_applied),
 .loop_length(loop_length),.layers(layers),.keys(keys),.drum_pads(drum_pads),.drum_sequence(drum_sequence),
 .master_target(master_target),.master_applied(master_applied),.track_gains(track_gains),.coefficients(coefficients));
integer frames=0,sessions=0;
always @(posedge clk) begin #1;if(updated) begin
 if(protocol_error||drops||sequence!=frames) $fatal(1,"mock packet");
 if(page!=1 || preset!=(sequence[0] ? 6 : 0) || selected_track!=sequence[1:0] || record_track!=selected_track ||
    bpm_requested!=120 || bpm_applied!=120 || meter!=4 || bars!=1 || quantize!=2 || layers!=16'h1111 || loop_length!=384 ||
    keys!=(16'd1<<sequence[3:0]) || drum_pads!=keys || drum_sequence!=sequence || master_target!=8249 || master_applied!=8249 ||
    track_gains!={4{17'd65536}} || coefficients!={9'd16,9'd32,9'd64,9'd256}) $fatal(1,"LU1 named field offsets");
 frames=frames+1;if(new_session) sessions=sessions+1;
 if(frames==8) begin if(sessions!=1) $fatal(1,"mock session");$display("SESSION_EXAMPLES_TB_PASS mock_stream named_field_offsets frames8");$finish;end
end end
initial begin repeat(5) @(negedge clk);rst=0;end
initial begin #100000;$fatal(1,"example timeout");end
endmodule
