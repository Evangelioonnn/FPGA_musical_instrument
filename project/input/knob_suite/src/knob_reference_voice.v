// Dynamic-ADSR companion to instrument/synth_voice. Default mode uses the
// original module directly; the dynamic path preserves its exact DDS pipeline.
module knob_reference_voice #(parameter DYNAMIC_ADSR=0)(
    input wire clk,rst,sample_ce,note_on,note_off,
    input wire [31:0] phase_step,
    input wire [15:0] attack,decay,sustain,release_step,
    output wire signed [15:0] sample,
    output wire sample_valid,
    output wire [2:0] env_state
);
    wire [15:0] envelope;
    generate if(!DYNAMIC_ADSR) begin: original
        synth_voice voice(.clk(clk),.rst(rst),.sample_ce(sample_ce),
            .note_on(note_on),.note_off(note_off),.pitch_we(1'b0),
            .phase_step(phase_step),.sample(sample),.sample_valid(sample_valid),
            .envelope(envelope),.env_state(env_state));
    end else begin: dynamic
        reg [31:0] phase,step_hold;
        reg [2:0] pipe_ce;
        wire signed [15:0] sine;
        reg signed [32:0] product;
        reg signed [15:0] result;
        reg valid;
        assign sample=result;
        assign sample_valid=valid;
        adsr_envelope env(clk,rst,sample_ce,note_on,note_off,
            attack,decay,sustain,release_step,envelope,env_state);
        sine_rom wave_rom(clk,phase[31:22],sine);
        always @(posedge clk) begin
            if(rst) begin
                phase<=0;step_hold<=0;pipe_ce<=0;product<=0;result<=0;valid<=0;
            end else begin
                if(note_on) step_hold<=phase_step;
                if(sample_ce) phase<=phase+(note_on ? phase_step : step_hold);
                pipe_ce<={pipe_ce[1:0],sample_ce};valid<=pipe_ce[2];
                if(pipe_ce[1]) product<=sine*$signed({1'b0,envelope});
                if(pipe_ce[2]) result<=product>>>22;
            end
        end
    end endgenerate
endmodule
