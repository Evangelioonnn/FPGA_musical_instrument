module expression_core #(parameter N=8, parameter MONITOR_SHIFT=6)(
    input wire clk,rst,sample_ce,event_valid,
    input wire [1:0] event_kind,
    input wire [6:0] event_note,event_value,
    input wire [8:0] event_velocity,
    output wire event_ready,
    input wire cfg_valid,
    input wire [3:0] cfg_addr,
    input wire [31:0] cfg_data,
    output wire cfg_ready,cfg_ack,cfg_accepted,
    output wire [31:0] cfg_applied,
    output wire signed [15:0] sample,
    output wire sample_valid,clipped,
    output wire [N-1:0] occupied,held,gated,sost_latched,
    output wire [N*7-1:0] notes,pitches,
    output wire [N*16-1:0] voice_samples,envelopes,
    output wire [N*32-1:0] steps,
    output wire stolen,ignored,
    output wire [16:0] gain,
    output wire [14:0] weight2,weight3,
    output wire meter_valid,
    output wire [15:0] meter_peak,
    output wire signed [15:0] meter_sample,
    output wire meter_clip
);
    wire [N-1:0] ons,offs,fresh,idle,valids;
    wire [N*9-1:0] velocities;
    wire [16:0] volume_target;
    wire [1:0] timbre;
    wire [17:0] bend_ratio;
    wire [30:0] glide_delta;
    wire sustain,sostenuto,panic;
    wire [15:0] a,d,s,r;
    expression_controls controls(clk,rst,sample_ce,cfg_valid,cfg_addr,cfg_data,cfg_ready,
        cfg_ack,cfg_accepted,cfg_applied,volume_target,gain,timbre,weight2,weight3,
        bend_ratio,glide_delta,sustain,sostenuto,panic,a,d,s,r);
    performance_manager #(.N(N)) manager(clk,rst,event_valid,event_kind,event_note,event_value,event_velocity,
        sustain,sostenuto,panic,idle,event_ready,ons,offs,fresh,occupied,held,gated,sost_latched,
        notes,pitches,velocities,stolen,ignored);
    genvar v;
    generate for(v=0;v<N;v=v+1) begin: voices
        wire [31:0] base_step,phase;
        wire [2:0] state;
        note_table table1(pitches[v*7 +: 7],base_step);
        expressive_voice voice(clk,rst,sample_ce,ons[v],offs[v],fresh[v],base_step,bend_ratio,glide_delta,
            velocities[v*9 +: 9],weight2,weight3,a,d,s,r,
            voice_samples[v*16 +: 16],valids[v],envelopes[v*16 +: 16],state,steps[v*32 +: 32],phase);
        assign idle[v]=state==0;
    end endgenerate
    expression_mixer #(.N(N),.MONITOR_SHIFT(MONITOR_SHIFT)) mix(clk,rst,valids[0],voice_samples,gain,sample,sample_valid,clipped);
    audio_meter meter(clk,rst,sample_valid,clipped,sample,meter_valid,meter_peak,meter_sample,meter_clip);
endmodule
