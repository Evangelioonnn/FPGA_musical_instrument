module ec11_audio_probe_top #(
    parameter EC11_SAMPLE_CYCLES = 2500,
    parameter EC11_AB_SAMPLES = 2,
    parameter EC11_STEPS_PER_DETENT = 4
)(
    input  wire        sys_clk,
    input  wire        enc_a,
    input  wire        enc_b,
    output wire        hp_bck,
    output wire        hp_ws,
    output wire        hp_din,
    output wire        pa_en
);
    // Keep reset local to this probe. The board has no reset input in this test.
    reg [4:0] startup = 5'd0;
    wire rst = !startup[4];
    always @(posedge sys_clk) begin
        if (rst) startup <= startup + 1'b1;
    end

    wire step_valid;
    wire signed [1:0] step;
    wire pressed_unused;
    wire button_changed_unused;
    wire invalid_transition_unused;
    // No push-button pin is bound in this probe; module C is not identified yet.
    ec11_input #(
        .SAMPLE_CYCLES(EC11_SAMPLE_CYCLES),
        .AB_SAMPLES(EC11_AB_SAMPLES),
        .STEPS_PER_DETENT(EC11_STEPS_PER_DETENT)
    ) encoder (
        .clk(sys_clk),
        .rst(rst),
        .a(enc_a),
        .b(enc_b),
        .button_n(1'b1),
        .step_valid(step_valid),
        .step(step),
        .pressed(pressed_unused),
        .button_changed(button_changed_unused),
        .invalid_transition(invalid_transition_unused)
    );

    // A4 starts the probe; each complete quadrature cycle changes one semitone.
    // Stay within C3..C6 for this listening test, saturating at both endpoints.
    reg [6:0] note = 7'd69;
    reg started = 1'b0;
    wire step_up = step_valid && (step > 2'sd0);
    wire step_down = step_valid && (step < 2'sd0);
    wire [6:0] target_note =
        step_up   ? ((note == 7'd84) ? 7'd84 : note + 7'd1) :
        step_down ? ((note == 7'd48) ? 7'd48 : note - 7'd1) :
        note;
    wire [31:0] phase_step;
    wire signed [15:0] sample;
    wire sample_valid_unused;
    wire [15:0] envelope_unused;
    wire [2:0] env_state_unused;
    wire sample_ce;

    note_table notes(target_note, phase_step);

    // The first cycle after reset starts the held note. Later step_valid pulses
    // use pitch_we, preserving the envelope while changing oscillator frequency.
    wire note_on = (!rst && !started);
    always @(posedge sys_clk) begin
        if (rst) begin
            note <= 7'd69;
            started <= 1'b0;
        end else begin
            if (!started) started <= 1'b1;
            if (step_valid) note <= target_note;
        end
    end

    synth_voice voice(
        .clk(sys_clk), .rst(rst), .sample_ce(sample_ce),
        .note_on(note_on), .note_off(1'b0), .pitch_we(step_valid),
        .phase_step(phase_step), .sample(sample),
        .sample_valid(sample_valid_unused), .envelope(envelope_unused),
        .env_state(env_state_unused)
    );

    assign pa_en = 1'b0;
    pt8211_tx tx(
        .clk(sys_clk), .rst(rst),
        .sample_left(sample), .sample_right(sample),
        .sample_ce(sample_ce),
        .hp_bck(hp_bck), .hp_ws(hp_ws), .hp_din(hp_din)
    );
endmodule
