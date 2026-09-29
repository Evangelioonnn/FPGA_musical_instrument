// Derived by tools/generate_fm.py; runtime release + sample-exact output pipeline.
// Independent single-voice FM experiment. See ../README.md and ../../RTL_SPEC.md.
// Runtime synthesis of y=.13*v*(1-exp(-t/.006))*exp(-t/1.15)
// *sin(w*t + (1.2+1.8*v)*exp(-t/.16)*sin(w*t)). No PCM playback.
// A shared registered 32 x 32 signed multiplier is used in a 18-clock pipeline with registered rounding/saturation.
module playable_fm_voice(
    input wire clk, input wire rst, input wire sample_ce,
    input wire cmd_valid, input wire [1:0] cmd_kind,
    input wire [6:0] note, input wire [8:0] velocity,
    input wire [31:0] seed, input wire [2:0] release_index,
    output wire cmd_ready, output reg cmd_rejected,
    output reg active, output reg signed [15:0] sample,
    output reg sample_valid
);
localparam [28:0] ONE = 29'd268435456;
// Sample counts at 50MHz/1040; index 3 is bit-exact legacy release.
reg [16:0] release_length;
reg [28:0] release_step,held_release_step;
always @* case(release_index)
    3'd0: begin release_length=17'd1442; release_step=29'd186155; end
    3'd1: begin release_length=17'd2885; release_step=29'd93046; end
    3'd2: begin release_length=17'd4808; release_step=29'd55832; end
    3'd3: begin release_length=17'd7212; release_step=29'd37226; end
    3'd4: begin release_length=17'd14423; release_step=29'd18612; end
    3'd5: begin release_length=17'd28846; release_step=29'd9306; end
    3'd6: begin release_length=17'd48077; release_step=29'd5584; end
    3'd7: begin release_length=17'd96154; release_step=29'd2792; end
endcase
reg [4:0] state;
reg [31:0] phase, phase_step;
wire [31:0] selected_step;
reg [28:0] attack_tail, carrier_env, release_gain;
reg [31:0] index_phase;
reg [21:0] velocity_gain;
reg releasing;
reg [16:0] release_left;
reg [28:0] current_attack, current_carrier, current_release;
reg [31:0] current_index, current_phase;
reg signed [15:0] modulator;
reg signed [31:0] mul_a, mul_b;
reg signed [63:0] mul_p;
wire [8:0] clamped_velocity = (velocity > 9'd256) ? 9'd256 : velocity;
wire accepted = cmd_valid && cmd_ready;
wire illegal = (cmd_kind == 2'd3) ||
    ((cmd_kind == 2'd0) && ((note < 7'd36) || (note > 7'd84)));
assign cmd_ready = !rst && (((state == 0) && !sample_ce) || (cmd_kind == 2'd2));
fm_note_table notes(.note(note), .phase_step(selected_step));

wire lookup_request = (sample_ce && active && (state == 0) && !accepted) ||
    (state == 5'd8);
wire [31:0] modulated_phase = current_phase + mul_p[46:15];
wire [31:0] lookup_phase = (state == 5'd8) ? modulated_phase : phase;
wire lookup_valid;
wire signed [15:0] lookup_value;
fm_sine_interp sine(.clk(clk), .rst(rst), .request(lookup_request),
    .phase(lookup_phase), .valid(lookup_valid), .value(lookup_value));

// Round final Q24 conversion symmetrically before saturation. The theoretical
// raw bound is +/-4260; saturation also guards future coefficient changes.
wire round_up = mul_p[63] ? (mul_p[23:0] > 24'h800000) : (mul_p[23:0] >= 24'h800000);
wire signed [40:0] rounded_value = $signed(mul_p[63:24]) + $signed({40'd0,round_up});
reg signed [40:0] rounded_output;
always @(posedge clk) mul_p <= mul_a * mul_b;
always @(posedge clk) begin
    if (rst) begin
        state <= 0; phase <= 0; phase_step <= 0; rounded_output <= 0;
        attack_tail <= ONE; carrier_env <= ONE; index_phase <= 0;
        release_gain <= ONE; release_left <= 0; releasing <= 0; held_release_step <= 37226;
        velocity_gain <= 0; active <= 0; sample <= 0; sample_valid <= 0;
        cmd_rejected <= 0; mul_a <= 0; mul_b <= 0; modulator <= 0;
        current_attack <= 0; current_carrier <= 0; current_release <= 0;
        current_index <= 0; current_phase <= 0;
    end else begin
        sample_valid <= 0;
        cmd_rejected <= 0;
        if (accepted) begin
            if (illegal) cmd_rejected <= 1;
            else if (cmd_kind == 2'd2) begin
                // Panic is ready even during an in-flight computation. Complete
                // its pending sample with zero; no stale nonzero result escapes.
                sample <= 0; sample_valid <= sample_ce || (state != 0);
                active <= 0; releasing <= 0; state <= 0; phase <= 0;
            end else if ((cmd_kind == 2'd1) || (clamped_velocity == 0)) begin
                if (active && !releasing) begin
                    releasing <= 1; release_gain <= ONE;
                    release_left <= release_length; held_release_step <= release_step;
                end
            end else begin
                phase <= 0; phase_step <= selected_step; attack_tail <= ONE;
                carrier_env <= ONE;
                // index is radians expressed in 2^32 phase units, always <2^31.
                index_phase <= 32'd820278331 + clamped_velocity * 32'd4806318;
                velocity_gain <= clamped_velocity * 22'd8520;
                release_gain <= ONE; release_left <= 0; releasing <= 0; held_release_step <= 37226;
                active <= 1; sample <= 0;
            end
        end else if ((state == 0) && sample_ce) begin
            if (!active) begin sample <= 0; sample_valid <= 1; end
            else begin
                current_attack <= ONE - attack_tail;
                current_carrier <= carrier_env; current_index <= index_phase;
                current_release <= release_gain; current_phase <= phase;
                mul_a <= $signed({3'd0, attack_tail}); mul_b <= 32'sd928965;
                state <= 1;
            end
        end else begin
            case (state)
                1: state <= 2;
                2: begin
                    attack_tail <= attack_tail - ((mul_p + 64'sd134217728) >>> 28);
                    mul_a <= $signed({3'd0, carrier_env}); mul_b <= 32'sd4855;
                    state <= 3;
                end
                3: state <= 4;
                4: begin
                    carrier_env <= carrier_env - ((mul_p + 64'sd134217728) >>> 28);
                    modulator <= lookup_value;
                    mul_a <= $signed(index_phase); mul_b <= 32'sd34894;
                    state <= 5;
                end
                5: state <= 6;
                6: begin
                    index_phase <= index_phase - ((mul_p + 64'sd134217728) >>> 28);
                    mul_a <= $signed(current_index); mul_b <= $signed(modulator);
                    state <= 7;
                end
                7: state <= 8;
                8: begin
                    mul_a <= $signed({3'd0, current_attack});
                    mul_b <= $signed({3'd0, current_carrier}); state <= 9;
                end
                9: state <= 10;
                10: begin
                    mul_a <= $signed(mul_p[59:28]);
                    mul_b <= $signed({3'd0, current_release}); state <= 11;
                end
                11: state <= 12;
                12: begin
                    mul_a <= $signed(mul_p[59:28]);
                    mul_b <= $signed({10'd0, velocity_gain}); state <= 13;
                end
                13: state <= 14;
                14: begin
                    mul_a <= $signed(mul_p[59:28]);
                    mul_b <= $signed(lookup_value); state <= 15;
                end
                15: state <= 16;
                16: begin rounded_output <= rounded_value; state <= 17; end
                17: begin
                    if (rounded_output > 32767) sample <= 16'sh7FFF;
                    else if (rounded_output < -32768) sample <= 16'sh8000;
                    else sample <= rounded_output[15:0];
                    sample_valid <= 1; phase <= phase + phase_step; state <= 0;
                    if (releasing) begin
                        if (release_left <= 1) begin
                            sample <= 0; active <= 0; releasing <= 0;
                            release_left <= 0; release_gain <= 0;
                        end else begin
                            release_left <= release_left - 1'b1;
                            release_gain <= (release_gain > held_release_step) ?
                                release_gain - held_release_step : 29'd0;
                        end
                    end
                end
                default: state <= 0;
            endcase
        end
    end
end
endmodule
