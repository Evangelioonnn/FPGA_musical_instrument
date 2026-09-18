module audio_quality_top #(
    parameter integer SLOT_SAMPLES=48077, GATE_SAMPLES=31250
)(input wire sys_clk, output wire hp_bck,hp_ws,hp_din,pa_en);
    reg [4:0] startup=0;
    wire rst=!startup[4];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    wire ce,on,off;
    wire [6:0] note;
    wire [31:0] step;
    wire signed [15:0] old_sample,new_sample;
    wire old_valid,new_valid;
    wire [15:0] old_env,new_env;
    wire [2:0] old_state,new_state;
    reg [18:0] frame_count=0;
    reg mode=0;
    always @(posedge sys_clk) begin
        if(rst) begin frame_count<=0; mode<=0; end
        else if(ce) begin
            if(frame_count==6*SLOT_SAMPLES-1) begin frame_count<=0; mode<=~mode; end
            else frame_count<=frame_count+1'b1;
        end
    end
    wire signed [15:0] selected_sample=mode ? new_sample : old_sample;
    assign pa_en=0;
    demo_events #(.SLOT_SAMPLES(SLOT_SAMPLES),.GATE_SAMPLES(GATE_SAMPLES)) demo(sys_clk,rst,ce,on,off,note);
    note_table notes(note,step);
    synth_voice original(sys_clk,rst,ce,on,off,1'b0,step,old_sample,old_valid,old_env,old_state);
    quality_voice candidate(sys_clk,rst,ce,on,off,1'b0,step,new_sample,new_valid,new_env,new_state);
    pt8211_tx tx(sys_clk,rst,selected_sample,selected_sample,ce,hp_bck,hp_ws,hp_din);
endmodule
