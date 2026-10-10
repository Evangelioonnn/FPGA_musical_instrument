// Combinational names for the held, validated LU1 payload in C's clock domain.
// C may copy these only at VBlank; this module performs no additional CDC.
module session_ui_view(input wire [639:0] ui,
 output wire [2:0] page,mode,preset,beat_in_bar,meter,bars,
 output wire [1:0] selected_track,record_track,quantize,master_owner,
 output wire run,count_in,playing,recording,armed,met_enable,fault,clip,clock_run,busy,flushing,
 output wire [3:0] muted,mixer_pickup,
 output wire [7:0] bpm_requested,bpm_applied,take_events,drum_slots,
 output wire [11:0] loop_tick,loop_length,
 output wire [6:0] tick_in_beat,
 output wire [15:0] layers,keys,drum_pads,drum_sequence,
 output wire [3:0] last_drum_pad,errors,
 output wire [16:0] master_target,master_applied,
 output wire [67:0] track_gains,
 output wire [35:0] coefficients,
 output wire [31:0] loop_number,action_result
);
assign page=ui[2:0];assign mode=ui[5:3];assign selected_track=ui[7:6];assign preset=ui[10:8];
assign run=ui[11];assign count_in=ui[12];assign playing=ui[13];assign recording=ui[14];assign armed=ui[15];
assign met_enable=ui[16];assign fault=ui[17];assign clip=ui[18];assign clock_run=ui[19];assign busy=ui[20];assign flushing=ui[21];
assign muted=ui[25:22];assign record_track=ui[28:27];
assign bpm_requested=ui[39:32];assign bpm_applied=ui[47:40];assign meter=ui[50:48];assign bars=ui[53:51];assign quantize=ui[55:54];
assign loop_tick=ui[75:64];assign tick_in_beat=ui[82:76];assign beat_in_bar=ui[85:83];
assign layers=ui[111:96];assign loop_length=ui[123:112];
assign master_target=ui[144:128];assign master_owner=ui[146:145];assign master_applied=ui[176:160];
assign track_gains={ui[288+:17],ui[256+:17],ui[224+:17],ui[192+:17]};
assign coefficients={ui[352+:9],ui[320+:27]};
assign keys=ui[399:384];assign drum_pads=ui[415:400];assign drum_sequence=ui[431:416];assign last_drum_pad=ui[435:432];
assign loop_number=ui[448+:32];assign take_events=ui[487:480];assign drum_slots=ui[495:488];assign mixer_pickup=ui[499:496];
assign action_result=ui[512+:32];assign errors=ui[611:608];
endmodule
