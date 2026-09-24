// Clean candidate voices for the audio-clean-lab experiment.
// MODE 0: original sine path at a higher useful DAC level.
// MODE 1: low-order additive harmonic voice.
// MODE 2: low-index FM-like additive voice (carrier plus a quiet second harmonic).
// MODE 3: band-limited-by-construction triangle voice.
module clean_voice #(parameter MODE=0)(
    input wire clk, rst, sample_ce,
    input wire note_on, note_off,
    input wire [31:0] phase_step,
    output reg signed [15:0] sample,
    output reg sample_valid,
    output wire [2:0] env_state
);
    wire [15:0] envelope;
    adsr_envelope env(clk, rst, sample_ce, note_on, note_off,
        16'd68, 16'd6, 16'd32768, 16'd3, envelope, env_state);

    reg [31:0] phase, step_hold;
    reg [2:0] pipe_ce;
    reg signed [32:0] product;
    wire signed [15:0] sine_a;
    wire signed [15:0] sine_b;
    wire signed [15:0] sine_c;
    wire signed [15:0] sine_d;
    wire signed [15:0] harmonic_sum;
    wire signed [16:0] harmonic_wide;
    wire signed [16:0] triangle_wide;
    wire signed [15:0] source_sample;

    // All ROM addresses are derived from the same phase. Synchronous ROM
    // latency is shared, so the harmonic components remain phase aligned.
    generate if (MODE == 0 || MODE == 1 || MODE == 2) begin: with_rom
        sine_rom rom_a(clk, phase[31:22], sine_a);
    end endgenerate
    generate if (MODE == 1 || MODE == 2) begin: with_two_harmonics
        sine_rom rom_b(clk, phase[30:21], sine_b);
    end endgenerate
    wire [31:0] phase_three = phase + (phase << 1);
    generate if (MODE == 1) begin: with_four_harmonics
        sine_rom rom_c(clk, phase_three[31:22], sine_c);
        sine_rom rom_d(clk, phase[29:20], sine_d);
    end endgenerate

    // The shifts keep the sum below full scale before the ADSR multiply.
    // MODE 2 is deliberately a very low-index, low-order spectrum candidate.
    assign harmonic_sum = MODE == 1 ?
        $signed(sine_a >>> 1) + $signed(sine_b >>> 3) +
        $signed(sine_c >>> 4) + $signed(sine_d >>> 5) :
        $signed(sine_a >>> 1) + $signed(sine_b >>> 4);
    assign harmonic_wide = $signed(harmonic_sum);
    // phase[30:16] is the rising half-cycle magnitude. Mirroring it gives a
    // triangle with no high-frequency discontinuity or extra ROM.
    wire [15:0] triangle_unsigned = phase[31] ? ~phase[30:16] : phase[30:16];
    assign triangle_wide = $signed({1'b0, triangle_unsigned}) - 17'sd32768;
    assign source_sample = MODE == 3 ? triangle_wide[15:0] :
        MODE == 0 ? sine_a : harmonic_wide[15:0];

    always @(posedge clk) begin
        if (rst) begin
            phase <= 0;
            step_hold <= 0;
            pipe_ce <= 0;
            product <= 0;
            sample <= 0;
            sample_valid <= 0;
        end else begin
            if (note_on) step_hold <= phase_step;
            if (sample_ce) phase <= phase + (note_on ? phase_step : step_hold);
            pipe_ce <= {pipe_ce[1:0], sample_ce};
            sample_valid <= pipe_ce[2];
            // One extra bit of output level relative to the old monitoring
            // path is intentional: the candidate is meant to exercise the
            // DAC/analog chain at a useful level without final-stage gain.
            if (pipe_ce[1]) product <= source_sample * $signed({1'b0, envelope});
            if (pipe_ce[2]) begin
                if (product > 33'sd2147418112) sample <= 16'sh7fff;
                else if (product < -33'sd2147483648) sample <= -16'sh8000;
                else sample <= product >>> 19;
            end
        end
    end
endmodule
