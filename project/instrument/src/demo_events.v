// Control events only: all audio is computed live by synth_voice.
module demo_events #(
    parameter integer SLOT_SAMPLES=48077,
    parameter integer GATE_SAMPLES=31250
)(
    input wire clk, rst, sample_ce,
    output reg note_on = 0, note_off = 0,
    output reg [6:0] note = 60
);
    reg [15:0] sample_count = 0;
    reg [2:0] slot = 0;
    always @(posedge clk) begin
        if (rst) begin
            sample_count <= 0;
            slot <= 0;
            note_on <= 0;
            note_off <= 0;
            note <= 60;
        end else begin
            note_on <= 0;
            note_off <= 0;
            if (sample_ce) begin
                if (sample_count == 0 && slot >= 1 && slot <= 4) begin
                    note_on <= 1;
                    case (slot)
                        1: note <= 60;
                        2: note <= 64;
                        3: note <= 67;
                        4: note <= 72;
                        default: note <= 60;
                    endcase
                end
                if (sample_count == GATE_SAMPLES && slot >= 1 && slot <= 4)
                    note_off <= 1;
                if (sample_count == SLOT_SAMPLES-1) begin
                    sample_count <= 0;
                    if (slot == 3'd5) slot <= 3'd0;
                    else slot <= slot + 3'd1;
                end else sample_count <= sample_count + 1'b1;
            end
        end
    end
endmodule
