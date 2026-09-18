module adsr_envelope (
    input wire clk, rst, sample_ce, note_on, note_off,
    input wire [15:0] attack_step, decay_step, sustain_level, release_step,
    output reg [15:0] level = 0,
    output reg [2:0] state = 0
);
    localparam IDLE=0, ATTACK=1, DECAY=2, SUSTAIN=3, RELEASE=4;
    wire [15:0] a_step = attack_step == 0 ? 16'd1 : attack_step;
    wire [15:0] d_step = decay_step == 0 ? 16'd1 : decay_step;
    wire [15:0] r_step = release_step == 0 ? 16'd1 : release_step;
    wire [16:0] attack_sum = {1'b0,level} + {1'b0,a_step};
    wire [16:0] decay_floor = {1'b0,sustain_level} + {1'b0,d_step};
    always @(posedge clk) begin
        if (rst) begin
            level <= 0;
            state <= IDLE;
        end else if (note_on) begin
            // Keep amplitude continuous on retrigger, including during release.
            state <= ATTACK;
        end else if (note_off) begin
            if (state != IDLE) state <= RELEASE;
        end else if (sample_ce) begin
            case (state)
                IDLE: level <= 0;
                ATTACK: begin
                    if (attack_sum >= 17'd65535) begin
                        level <= 16'd65535;
                        state <= DECAY;
                    end else level <= attack_sum[15:0];
                end
                DECAY: begin
                    if ({1'b0,level} <= decay_floor) begin
                        level <= sustain_level;
                        state <= SUSTAIN;
                    end else level <= level - d_step;
                end
                SUSTAIN: level <= sustain_level;
                RELEASE: begin
                    if (level <= r_step) begin
                        level <= 0;
                        state <= IDLE;
                    end else level <= level - r_step;
                end
                default: begin level <= 0; state <= IDLE; end
            endcase
        end
    end
endmodule
