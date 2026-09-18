module synth_voice #(
    parameter [15:0] ATTACK_STEP=68, DECAY_STEP=6,
    parameter [15:0] SUSTAIN_LEVEL=32768, RELEASE_STEP=3
)(
    input wire clk, rst, sample_ce,
    input wire note_on, note_off, pitch_we,
    input wire [31:0] phase_step,
    output reg signed [15:0] sample = 0,
    output reg sample_valid = 0,
    output wire [15:0] envelope,
    output wire [2:0] env_state
);
    reg [31:0] phase = 0, step_hold = 0;
    reg [2:0] pipe_ce = 0;
    wire signed [15:0] sine;
    reg signed [32:0] product = 0;
    wire [31:0] selected_step = (pitch_we || note_on) ? phase_step : step_hold;
    adsr_envelope env(clk, rst, sample_ce, note_on, note_off,
        ATTACK_STEP, DECAY_STEP, SUSTAIN_LEVEL, RELEASE_STEP, envelope, env_state);
    sine_rom wave_rom(clk, phase[31:22], sine);
    always @(posedge clk) begin
        if (rst) begin
            phase <= 0;
            step_hold <= 0;
            pipe_ce <= 0;
            product <= 0;
            sample <= 0;
            sample_valid <= 0;
        end else begin
            if (pitch_we || note_on) step_hold <= phase_step;
            if (sample_ce) phase <= phase + selected_step;
            pipe_ce <= {pipe_ce[1:0],sample_ce};
            sample_valid <= pipe_ce[2];
            if (pipe_ce[1]) product <= sine * $signed({1'b0,envelope});
            // Fixed low monitoring gain: signed result stays in -512..511.
            if (pipe_ce[2]) sample <= product >>> 22;
        end
    end
endmodule
