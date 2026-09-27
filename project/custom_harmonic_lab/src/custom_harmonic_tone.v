// Four-harmonic voice renderer with one time-shared multiplier.
//
// This module follows gallery_shared_tone's transaction shape: phases and
// envelopes are captured at sample_ce, then one voice is reported at a time
// with a one-hot valid bit. The caller may use sample/valid to fill its voice
// frame. A single palette_sine ROM is shared by all voices and harmonics.
//
// coeff0..coeff3 are unsigned Q8 amplitudes (256 == 1.0). Their intended
// contract is sum(coeff*) <= 368, enforced by custom_harmonic_params. The
// envelope input is unsigned Q16. The renderer uses the same 17x27
// multiplier for both sine*coefficient and harmonic_sum*envelope, selected by
// state, so it does not instantiate 8*4 harmonic multipliers.
module custom_harmonic_tone #(
    parameter integer N = 8,
    parameter integer IW = (N > 1 ? $clog2(N) : 1)
) (
    input  wire                 clk,
    input  wire                 rst,
    input  wire                 sample_ce,
    input  wire [N*32-1:0]      phases,
    input  wire [N*16-1:0]      envelopes,
    input  wire [8:0]           coeff0,
    input  wire [8:0]           coeff1,
    input  wire [8:0]           coeff2,
    input  wire [8:0]           coeff3,
    output reg  signed [19:0]   sample,
    output reg  [N-1:0]         valid,
    output reg                  deadline_missed
);
    localparam [3:0] ST_IDLE     = 4'd0;
    localparam [3:0] ST_CAPTURE  = 4'd1;
    localparam [3:0] ST_ADDR     = 4'd2;
    localparam [3:0] ST_ROM_WAIT = 4'd3;
    localparam [3:0] ST_ROM_GET  = 4'd4;
    localparam [3:0] ST_ACCUM    = 4'd5;
    localparam [3:0] ST_ENV_OUT  = 4'd6;

    reg [3:0] state;
    reg [IW-1:0] voice_index;
    reg [1:0] harmonic_index;
    reg [N*32-1:0] phase_frame;
    reg [N*16-1:0] envelope_frame;
    reg [8:0] coeff0_frame,coeff1_frame,coeff2_frame,coeff3_frame;
    reg [31:0] address_phase;
    reg signed [26:0] harmonic_acc;
    reg signed [26:0] coeff_product;
    reg signed [43:0] envelope_product;

    wire [31:0] selected_phase = phase_frame[voice_index*32 +: 32];
    wire [15:0] selected_envelope = envelope_frame[voice_index*16 +: 16];
    wire [8:0] selected_coeff =
        harmonic_index == 2'd0 ? coeff0_frame :
        harmonic_index == 2'd1 ? coeff1_frame :
        harmonic_index == 2'd2 ? coeff2_frame : coeff3_frame;
    wire signed [15:0] sine_data;
    // palette_sine is the existing 4096-entry shared sine table.
    palette_sine sine_lut(clk,address_phase[31:20],sine_data);

    // The ROM product and the envelope product use the same multiplier.
    // The two operations occur in disjoint FSM states.
    reg signed [26:0] multiplier_a;
    reg signed [16:0] multiplier_b;
    wire signed [43:0] multiplier_a_wide =
        {{17{multiplier_a[26]}},multiplier_a};
    wire signed [43:0] multiplier_b_wide =
        {{27{multiplier_b[16]}},multiplier_b};
    wire signed [43:0] multiplier_result = multiplier_a_wide * multiplier_b_wide;
    wire signed [27:0] sum_with_term =
        $signed({harmonic_acc[26],harmonic_acc}) +
        $signed({coeff_product[26],coeff_product});

    always @* begin
        multiplier_a = 27'sd0;
        multiplier_b = 17'sd0;
        if (state == ST_ROM_GET) begin
            multiplier_a = $signed({{11{sine_data[15]}},sine_data});
            multiplier_b = $signed({1'b0,selected_coeff});
        end else if (state == ST_ACCUM && harmonic_index == 2'd3) begin
            multiplier_a = sum_with_term[26:0];
            multiplier_b = $signed({1'b0,selected_envelope});
        end
    end

    function signed [19:0] saturate_sample;
        input signed [43:0] value;
        reg signed [43:0] shifted;
        begin
            // Match gallery_shared_tone's symmetric round-to-nearest rule,
            // with the extra Q8 coefficient scale included in the shift.
            if (value < 0)
                shifted = -(((-value) + 44'd8388608) >>> 24);
            else
                shifted = (value + 44'd8388608) >>> 24;
            if (shifted > 44'sd524287)
                saturate_sample = 20'sh7ffff;
            else if (shifted < -44'sd524288)
                saturate_sample = -20'sd524288;
            else
                saturate_sample = shifted[19:0];
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            state          <= ST_IDLE;
            voice_index    <= 0;
            harmonic_index <= 0;
            phase_frame    <= 0;
            envelope_frame <= 0;
            coeff0_frame   <= 9'd256;
            coeff1_frame   <= 9'd64;
            coeff2_frame   <= 9'd32;
            coeff3_frame   <= 9'd16;
            address_phase  <= 0;
            harmonic_acc   <= 0;
            coeff_product  <= 0;
            envelope_product <= 0;
            sample         <= 0;
            valid          <= 0;
            deadline_missed <= 0;
        end else begin
            valid <= 0;
            if (sample_ce) begin
                // A new frame arriving while the previous scan is active is
                // a deterministic deadline violation; retain the diagnostic.
                if (state != ST_IDLE)
                    deadline_missed <= 1'b1;
                phase_frame    <= phases;
                envelope_frame <= envelopes;
                coeff0_frame   <= coeff0;
                coeff1_frame   <= coeff1;
                coeff2_frame   <= coeff2;
                coeff3_frame   <= coeff3;
                voice_index    <= 0;
                harmonic_index <= 0;
                harmonic_acc   <= 0;
                state          <= ST_CAPTURE;
            end else begin
                case (state)
                    ST_CAPTURE: begin
                        state <= ST_ADDR;
                    end
                    ST_ADDR: begin
                        // One address is used for each harmonic. Left shift
                        // wraps naturally in the 32-bit phase accumulator.
                        case (harmonic_index)
                            2'd0: address_phase <= selected_phase;
                            2'd1: address_phase <= selected_phase << 1;
                            2'd2: address_phase <= selected_phase + (selected_phase << 1);
                            default: address_phase <= selected_phase << 2;
                        endcase
                        state <= ST_ROM_WAIT;
                    end
                    ST_ROM_WAIT: begin
                        // palette_sine is synchronous; this cycle lets its
                        // output register receive the requested address.
                        state <= ST_ROM_GET;
                    end
                    ST_ROM_GET: begin
                        coeff_product <= multiplier_result[26:0];
                        state <= ST_ACCUM;
                    end
                    ST_ACCUM: begin
                        if (harmonic_index == 2'd3) begin
                            // Reuse the same multiplier for the final
                            // harmonic sum and the voice envelope.
                            envelope_product <= multiplier_result;
                            state <= ST_ENV_OUT;
                        end else begin
                            harmonic_acc <= sum_with_term[26:0];
                            harmonic_index <= harmonic_index + 1'b1;
                            state <= ST_ADDR;
                        end
                    end
                    ST_ENV_OUT: begin
                        sample <= saturate_sample(envelope_product);
                        valid[voice_index] <= 1'b1;
                        if (voice_index == N-1) begin
                            state <= ST_IDLE;
                        end else begin
                            voice_index <= voice_index + 1'b1;
                            harmonic_index <= 0;
                            harmonic_acc <= 0;
                            state <= ST_ADDR;
                        end
                    end
                    default: state <= ST_IDLE;
                endcase
            end
        end
    end
endmodule
