module poly_synth4 #(
    parameter [15:0] ATTACK_STEP=68,DECAY_STEP=6,
    parameter [15:0] SUSTAIN_LEVEL=32768,RELEASE_STEP=3
)(
    input wire clk,rst,sample_ce,event_valid,event_on,
    input wire [6:0] event_note,
    input wire all_notes_off,
    output wire event_ready,
    output wire signed [15:0] sample,
    output wire sample_valid,clipped,
    output wire [3:0] occupied,held,
    output wire [27:0] voice_notes,
    output wire [63:0] voice_samples,envelopes,
    output wire [11:0] voice_states,
    output wire voice_stolen,event_ignored
);
    wire [3:0] on_mask,off_mask,idle_mask,valid_mask;
    wire signed [17:0] sum_wide;
    voice_manager4 manager(clk,rst,event_valid,event_on,event_note,all_notes_off,idle_mask,
        event_ready,on_mask,off_mask,occupied,held,voice_notes,voice_stolen,event_ignored);
    genvar v;
    generate for(v=0;v<4;v=v+1) begin: voices
        wire [31:0] step;
        note_table notes(voice_notes[v*7 +: 7],step);
        synth_voice #(.ATTACK_STEP(ATTACK_STEP),.DECAY_STEP(DECAY_STEP),
            .SUSTAIN_LEVEL(SUSTAIN_LEVEL),.RELEASE_STEP(RELEASE_STEP)) voice(
            clk,rst,sample_ce,on_mask[v],off_mask[v],1'b0,step,
            voice_samples[v*16 +: 16],valid_mask[v],envelopes[v*16 +: 16],voice_states[v*3 +: 3]);
        assign idle_mask[v]=(voice_states[v*3 +: 3]==0);
    end endgenerate
    mixer4 mix(clk,rst,valid_mask[0],voice_samples[15:0],voice_samples[31:16],
        voice_samples[47:32],voice_samples[63:48],sample,sample_valid,clipped,sum_wide);
endmodule
