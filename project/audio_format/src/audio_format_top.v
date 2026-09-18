module audio_format_top #(
    parameter integer SLOT_SAMPLES=48077, GATE_SAMPLES=31250
)(input wire sys_clk, output wire hp_bck,hp_ws,hp_din,pa_en);
    reg [4:0] startup=0;
    wire rst=!startup[4];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    wire sample_ce,note_on,note_off;
    wire [6:0] note;
    wire [31:0] phase_step;
    wire signed [15:0] sample;
    wire sample_valid;
    wire [15:0] envelope;
    wire [2:0] env_state;
    reg [18:0] frame_count=0;
    reg format16_request=0;
    wire format16_active;
    always @(posedge sys_clk) begin
        if(rst) begin frame_count<=0; format16_request<=0; end
        else if(sample_ce) begin
            if(frame_count==6*SLOT_SAMPLES-1) begin
                frame_count<=0; format16_request<=~format16_request;
            end else frame_count<=frame_count+1'b1;
        end
    end
    assign pa_en=0;
    demo_events #(.SLOT_SAMPLES(SLOT_SAMPLES),.GATE_SAMPLES(GATE_SAMPLES))
        demo(sys_clk,rst,sample_ce,note_on,note_off,note);
    note_table notes(note,phase_step);
    synth_voice voice(sys_clk,rst,sample_ce,note_on,note_off,1'b0,
        phase_step,sample,sample_valid,envelope,env_state);
    pt8211_format_tx tx(sys_clk,rst,sample,sample,format16_request,
        sample_ce,hp_bck,hp_ws,hp_din,format16_active);
endmodule
