module audio_probe_top (
    input  wire        sys_clk,
    output reg         hp_bck = 1'b0,
    output reg         hp_ws  = 1'b0,
    output reg         hp_din = 1'b0,
    output wire        pa_en
);

    // The NEO Dock schematic defines PA_EN=0 as amplifier enabled.
    // With headphones inserted, the dock routes the audio to the headphone jack.
    assign pa_en = 1'b0;

    // PT8211 datasheet V1.6, p4: LSB-justified, WS low=right, high=left.
    // We choose 20 BCK/channel: 4 leading zeros then 16 data bits, no tail.
    // An integer divider gives a robust first transport test near 48 kHz.
    reg [4:0] bck_div = 5'd0;
    reg [5:0] bit_count = 6'd0;

    reg [31:0] tone_phase = 32'd0;
    reg [15:0] left_sample = 16'd512;
    reg [15:0] right_sample = 16'd512;

    // 440 Hz at the approximately 48.08 kHz frame rate.
    localparam [31:0] TONE_PHASE_INC = 32'h0257C915;
    wire [31:0] next_phase = tone_phase + TONE_PHASE_INC;

    always @(posedge sys_clk) begin
        if (bck_div == 5'd12) begin
            bck_div <= 5'd0;
            hp_bck <= ~hp_bck;

            // Change data and WS while BCK is low, before the next rising edge.
            if (hp_bck == 1'b1) begin
                if (bit_count == 6'd19) begin
                    hp_ws <= 1'b1;
                    bit_count <= 6'd20;
                    hp_din <= 1'b0;
                end else if (bit_count == 6'd39) begin
                    hp_ws <= 1'b0;
                    bit_count <= 6'd0;
                    hp_din <= 1'b0;

                    tone_phase <= next_phase;
                    if (next_phase[31]) begin
                        left_sample <= -16'sd512;
                        right_sample <= -16'sd512;
                    end else begin
                        left_sample <= 16'd512;
                        right_sample <= 16'd512;
                    end
                end else if (bit_count >= 6'd3 && bit_count <= 6'd18) begin
                    // Prepare rising-edge slots 4..19 of the right word.
                    bit_count <= bit_count + 1'b1;
                    hp_din <= right_sample[6'd18 - bit_count];
                end else if (bit_count >= 6'd23 && bit_count <= 6'd38) begin
                    // Prepare rising-edge slots 24..39 of the left word.
                    bit_count <= bit_count + 1'b1;
                    hp_din <= left_sample[6'd38 - bit_count];
                end else begin
                    bit_count <= bit_count + 1'b1;
                    hp_din <= 1'b0;
                end
            end
        end else begin
            bck_div <= bck_div + 1'b1;
        end
    end

endmodule
