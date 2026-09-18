// Controlled alternative to instrument/synth_voice: interpolate, then round.
module quality_voice #(
    parameter [15:0] ATTACK_STEP=68, DECAY_STEP=6,
    parameter [15:0] SUSTAIN_LEVEL=32768, RELEASE_STEP=3
)(
    input wire clk, rst, sample_ce, note_on, note_off, pitch_we,
    input wire [31:0] phase_step,
    output reg signed [15:0] sample=0,
    output reg sample_valid=0,
    output wire [15:0] envelope,
    output wire [2:0] env_state
);
    reg [31:0] phase=0, step_hold=0;
    reg [4:0] pipe_ce=0;
    wire [31:0] selected_step=(pitch_we || note_on) ? phase_step : step_hold;
    wire [9:0] next_addr=phase[31:22]+10'd1;
    wire signed [15:0] sine_a,sine_b;
    wire signed [16:0] difference={sine_b[15],sine_b}-{sine_a[15],sine_a};
    wire signed [8:0] fraction={1'b0,phase[21:14]};
    reg signed [25:0] delta=0;
    reg signed [15:0] base=0,interpolated=0;
    reg signed [32:0] product=0;
    wire signed [25:0] rounded_delta=(delta+26'sd128) >>> 8;
    wire signed [25:0] interpolated_wide={{10{base[15]}},base}+rounded_delta;
    wire signed [32:0] rounded_output=(product+33'sd2097152) >>> 22;
    adsr_envelope env(clk,rst,sample_ce,note_on,note_off,
        ATTACK_STEP,DECAY_STEP,SUSTAIN_LEVEL,RELEASE_STEP,envelope,env_state);
    sine_rom rom_a(clk,phase[31:22],sine_a);
    sine_rom rom_b(clk,next_addr,sine_b);
    always @(posedge clk) begin
        if(rst) begin
            phase<=0; step_hold<=0; pipe_ce<=0;
            delta<=0; base<=0; interpolated<=0; product<=0;
            sample<=0; sample_valid<=0;
        end else begin
            if(note_on || pitch_we) step_hold<=phase_step;
            if(sample_ce) phase<=phase+selected_step;
            pipe_ce<={pipe_ce[3:0],sample_ce};
            sample_valid<=pipe_ce[4];
            if(pipe_ce[1]) begin delta<=difference*fraction; base<=sine_a; end
            // Linear interpolation is bounded by the two signed 16-bit samples.
            if(pipe_ce[2]) interpolated<=interpolated_wide[15:0];
            if(pipe_ce[3]) product<=interpolated*$signed({1'b0,envelope});
            if(pipe_ce[4]) sample<=rounded_output[15:0];
        end
    end
endmodule
