module instrument_top (
    input wire sys_clk,
    output wire hp_bck, hp_ws, hp_din, pa_en
);
    reg [4:0] startup = 0;
    wire rst = !startup[4];
    always @(posedge sys_clk) if (rst) startup <= startup + 1'b1;
    wire sample_ce, note_on, note_off;
    wire [6:0] note;
    wire [31:0] phase_step;
    wire signed [15:0] sample;
    wire sample_valid;
    wire [15:0] envelope;
    wire [2:0] env_state;
    assign pa_en = 1'b0;
    demo_events demo(sys_clk, rst, sample_ce, note_on, note_off, note);
    note_table notes(note, phase_step);
    synth_voice voice(sys_clk, rst, sample_ce, note_on, note_off, 1'b0,
        phase_step, sample, sample_valid, envelope, env_state);
    pt8211_tx tx(sys_clk, rst, sample, sample, sample_ce, hp_bck, hp_ws, hp_din);
endmodule
