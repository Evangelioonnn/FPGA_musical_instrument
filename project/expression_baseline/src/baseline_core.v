// Baseline-only polyphonic core.
// Every voice is the original instrument synth_voice: sine DDS + ADSR.
// Expression features stay outside this reference path so the board test has
// one stable, repeatable piano-like tone.
module baseline_voice(
    input wire clk,rst,sample_ce,note_on,note_off,
    input wire [31:0] phase_step,
    input wire [8:0] velocity,
    output reg signed [15:0] sample,
    output reg sample_valid,
    output wire [2:0] env_state,
    output wire [15:0] envelope
);
    wire signed [15:0] raw_sample;
    wire raw_valid;
    // Explicit signed Q8 arithmetic.  The previous 26-bit assignment also
    // supplied a width context; this makes that intent local to the operands.
    wire signed [25:0] raw_ext = {{10{raw_sample[15]}},raw_sample};
    wire signed [25:0] velocity_ext = {{17{1'b0}},velocity};
    wire signed [25:0] velocity_product = raw_ext * velocity_ext;
    wire signed [25:0] velocity_scaled = velocity_product >>> 8;

    synth_voice voice(clk,rst,sample_ce,note_on,note_off,1'b0,phase_step,
        raw_sample,raw_valid,envelope,env_state);

    always @(posedge clk) begin
        if(rst) begin
            sample<=0;
            sample_valid<=0;
        end else begin
            sample_valid<=raw_valid;
            // Q8 velocity scaling: velocity=256 preserves the original
            // synth_voice level, while lower values attenuate it smoothly.
            if(raw_valid) sample<=velocity_scaled[15:0];
        end
    end
endmodule

// Full-width sum and Q16 master gain. No averaging by maximum voice count.
// Preserve headroom until the final 16-bit saturation, including at SHIFT=0.
module baseline_mixer #(parameter N=8)(
    input wire clk,rst,valid,
    input wire [N*16-1:0] voices,
    input wire [16:0] gain,
    output reg signed [15:0] sample,
    output reg sample_valid,clipped
);
    localparam SUM_W=16+((N>1) ? $clog2(N) : 0);
    localparam PRODUCT_W=SUM_W+18;
    reg signed [SUM_W-1:0] sum,sum_hold;
    reg [16:0] gain_hold;
    reg signed [PRODUCT_W-1:0] product;
    wire signed [PRODUCT_W-1:0] sum_ext = {{(PRODUCT_W-SUM_W){sum_hold[SUM_W-1]}},sum_hold};
    wire signed [PRODUCT_W-1:0] gain_ext = {{(PRODUCT_W-17){1'b0}},gain_hold};
    wire signed [PRODUCT_W-1:0] scaled=product >>> 16;
    reg [1:0] pipe_valid;
    integer i;
    always @* begin
        sum=0;
        for(i=0;i<N;i=i+1) sum=sum+$signed(voices[i*16 +: 16]);
    end
    always @(posedge clk) begin
        if(rst) begin
            sum_hold<=0;gain_hold<=0;product<=0;sample<=0;sample_valid<=0;clipped<=0;pipe_valid<=0;
        end else begin
            pipe_valid<={pipe_valid[0],valid};sample_valid<=pipe_valid[1];clipped<=0;
            if(valid) begin sum_hold<=sum;gain_hold<=gain;end
            if(pipe_valid[0]) product<=sum_ext*gain_ext;
            if(pipe_valid[1]) begin
                if(scaled>32767) begin sample<=32767;clipped<=1;end
                else if(scaled < -32768) begin sample<=-32768;clipped<=1;end
                else sample<=scaled[15:0];
            end
        end
    end
endmodule

module baseline_core #(parameter N=8)(
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
    wire [1:0] timbre_unused;
    wire [14:0] weight2_unused,weight3_unused;
    wire [17:0] bend_unused;
    wire [30:0] glide_unused;
    wire sustain,sostenuto,panic;
    wire [15:0] a_unused,d_unused,s_unused,r_unused;

    expression_controls controls(clk,rst,sample_ce,cfg_valid,cfg_addr,cfg_data,
        cfg_ready,cfg_ack,cfg_accepted,cfg_applied,volume_target,gain,
        timbre_unused,weight2_unused,weight3_unused,bend_unused,glide_unused,
        sustain,sostenuto,panic,a_unused,d_unused,s_unused,r_unused);
    performance_manager #(.N(N)) manager(clk,rst,event_valid,event_kind,event_note,
        event_value,event_velocity,sustain,sostenuto,panic,idle,event_ready,ons,offs,
        fresh,occupied,held,gated,sost_latched,notes,pitches,velocities,stolen,ignored);

    genvar v;
    generate for(v=0;v<N;v=v+1) begin: voices
        wire [31:0] phase_step;
        wire [2:0] state;
        note_table table1(pitches[v*7 +: 7],phase_step);
        baseline_voice voice(clk,rst,sample_ce,ons[v],offs[v],phase_step,
            velocities[v*9 +: 9],voice_samples[v*16 +: 16],valids[v],state,
            envelopes[v*16 +: 16]);
        assign idle[v]=(state==0);
        assign steps[v*32 +: 32]=phase_step;
    end endgenerate

    // Do not divide a single voice by the maximum voice count. The original
    // instrument's sustain level is about 256 codes; a full eight-voice chord
    // has a theoretical peak <=4096 codes (sustain <=2048).
    baseline_mixer #(.N(N)) mix(clk,rst,valids[0],
        voice_samples,gain,sample,sample_valid,clipped);
    assign weight2=15'd0;
    assign weight3=15'd0;
    assign meter_valid=1'b0;
    assign meter_peak=16'd0;
    assign meter_sample=16'sd0;
    assign meter_clip=1'b0;
endmodule
