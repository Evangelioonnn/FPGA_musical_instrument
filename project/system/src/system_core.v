module system_voice(
    input wire clk,rst,sample_ce,note_on,note_off,pitch_we,
    input wire [31:0] phase_step,input wire [8:0] velocity,
    output reg signed [15:0] sample,output reg sample_valid,
    output wire [2:0] env_state,output wire [15:0] envelope
);
    wire signed [15:0] raw;
    wire valid;
    wire signed [25:0] x={{10{raw[15]}},raw};
    wire signed [25:0] v={{17{1'b0}},velocity};
    wire signed [25:0] scaled=(x*v) >>> 8;
    synth_voice original(clk,rst,sample_ce,note_on,note_off,pitch_we,phase_step,raw,valid,envelope,env_state);
    always @(posedge clk) begin
        if(rst) begin sample<=0;sample_valid<=0;end
        else begin sample_valid<=valid;if(valid) sample<=scaled[15:0];end
    end
endmodule

module system_core #(parameter N=8)(
    input wire clk,rst,sample_ce,emergency,
    input wire event_valid,input wire [1:0] event_kind,
    input wire [6:0] event_note,event_value,input wire [8:0] event_velocity,
    output wire event_ready,
    input wire cfg_valid,input wire [3:0] cfg_addr,input wire [31:0] cfg_data,
    input wire [16:0] pressure_gain,
    output wire cfg_ready,cfg_ack,cfg_accepted,output wire [31:0] cfg_applied,
    output wire signed [15:0] sample,output wire sample_valid,clipped,panic,
    output wire [N-1:0] occupied,held,gated,sost_latched,
    output wire [N*7-1:0] notes,pitches,
    output wire [N*16-1:0] voice_samples,envelopes,
    output wire [N*32-1:0] steps,
    output wire [16:0] gain,master_volume,
    output wire sustain,sostenuto,stolen,ignored,
    output wire meter_valid,output wire [15:0] meter_peak,
    output wire signed [15:0] meter_sample,output wire meter_clip
);
    wire control_panic;
    wire [N-1:0] ons,offs,fresh,idle,valids;
    wire [N*9-1:0] velocities;
    reg [N-1:0] retune;
    assign panic=control_panic || emergency;
    system_controls controls(clk,rst,sample_ce,cfg_valid,cfg_addr,cfg_data,pressure_gain,
        cfg_ready,cfg_ack,cfg_accepted,cfg_applied,master_volume,gain,sustain,sostenuto,control_panic);
    performance_manager #(.N(N)) manager(clk,rst,event_valid && event_ready,event_kind,event_note,
        event_value,event_velocity,sustain,sostenuto,panic,idle,event_ready,ons,offs,fresh,
        occupied,held,gated,sost_latched,notes,pitches,velocities,stolen,ignored);
    integer i;
    always @(posedge clk) begin
        if(rst || panic) retune<=0;
        else for(i=0;i<N;i=i+1)
            retune[i]<=event_valid && event_ready && event_kind==2 && occupied[i] && notes[i*7 +: 7]==event_note;
    end
    genvar k;
    generate for(k=0;k<N;k=k+1) begin:voices
        wire [2:0] state;
        note_table table1(pitches[k*7 +: 7],steps[k*32 +: 32]);
        system_voice voice(clk,rst,sample_ce,ons[k],offs[k],retune[k],steps[k*32 +: 32],
            velocities[k*9 +: 9],voice_samples[k*16 +: 16],valids[k],state,envelopes[k*16 +: 16]);
        assign idle[k]=state==0;
    end endgenerate
    baseline_mixer #(.N(N)) mix(clk,rst,valids[0],voice_samples,gain,sample,sample_valid,clipped);
    audio_meter meter(clk,rst,sample_valid,clipped,sample,meter_valid,meter_peak,meter_sample,meter_clip);
endmodule
