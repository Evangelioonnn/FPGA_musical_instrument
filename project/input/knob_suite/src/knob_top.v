module knob_engine #(parameter MODE=0,N=(MODE==2?8:16))(
    input wire sys_clk,rst,sample_ce,step_valid,
    input wire signed [1:0] step,
    output wire final_valid,output wire signed [15:0] final_sample
);
    wire strike_valid,strike_ready;
    wire [6:0] strike_note,selected_note;
    wire [1:0] strike_timbre,selected_timbre;
    wire [23:0] strike_gate;
    wire [15:0] strike_release,wet_target;
    wire [16:0] volume_target,gain;
    wire [4:0] volume_index,effect_index;
    wire [2:0] release_index;
    wire [31:0] queue_overflows,rejected_count;
    knob_controls #(.MODE(MODE)) controls(sys_clk,rst,sample_ce,step_valid,step,
        strike_valid,strike_ready,strike_note,strike_timbre,strike_gate,strike_release,
        volume_target,wet_target,selected_note,selected_timbre,volume_index,release_index,
        effect_index,queue_overflows);
    wire accepted,rejected,bank_valid,bank_clip,deadline_missed;
    wire [$clog2(N)-1:0] accepted_slot;
    wire [N-1:0] occupied,gated,sost_captured;
    wire signed [15:0] bank_sample,gained_sample;
    wire gain_valid;
    knob_bank #(.N(N),.MULTI(MODE==2),.DYNAMIC_ADSR(MODE==3)) bank(
        sys_clk,rst,sample_ce,strike_valid,strike_ready,strike_note,strike_timbre,
        strike_gate,16'd68,16'd6,16'd32768,strike_release,1'b0,1'b0,1'b0,
        accepted,rejected,accepted_slot,rejected_count,occupied,gated,sost_captured,
        bank_valid,bank_sample,bank_clip,deadline_missed);
    knob_gain volume(sys_clk,rst,bank_valid,bank_sample,volume_target,
        gain_valid,gained_sample,gain);
    generate if(MODE==4) begin: effect_path
        wire ready,clip;
        knob_effect effect(sys_clk,rst,gain_valid,gained_sample,wet_target,
            ready,final_valid,final_sample,clip);
    end else begin: dry_path
        assign final_sample=gained_sample;assign final_valid=gain_valid;
    end endgenerate
endmodule

module knob_audio_top #(parameter MODE=0, N=(MODE==2?8:16),
    parameter EC11_SAMPLE_CYCLES=2500,EC11_AB_SAMPLES=2)(
    input wire sys_clk,enc_a,enc_b,
    output wire hp_bck,hp_ws,hp_din,pa_en
);
    reg [4:0] startup=0;
    wire rst=!startup[4];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    wire sample_ce,step_valid;
    wire signed [1:0] step;
    wire button_unused,button_change_unused,invalid_transition;
    ec11_input #(.SAMPLE_CYCLES(EC11_SAMPLE_CYCLES),.AB_SAMPLES(EC11_AB_SAMPLES),
        .STEPS_PER_DETENT(4)) encoder(sys_clk,rst,enc_a,enc_b,1'b1,
        step_valid,step,button_unused,button_change_unused,invalid_transition);
    wire final_valid;
    wire signed [15:0] final_sample;
    knob_engine #(.MODE(MODE),.N(N)) engine(sys_clk,rst,sample_ce,step_valid,step,
        final_valid,final_sample);
    // Capture previous finished sample at each PT8211 frame boundary. Computation
    // completes well inside the 1040-cycle interval, checked by transport bench.
    pt8211_tx tx(sys_clk,rst,final_sample,final_sample,sample_ce,hp_bck,hp_ws,hp_din);
    assign pa_en=0;
endmodule

module knob_performance_top(input wire sys_clk,enc_a,enc_b,output wire hp_bck,hp_ws,hp_din,pa_en);
    knob_audio_top #(.MODE(0)) instrument(sys_clk,enc_a,enc_b,hp_bck,hp_ws,hp_din,pa_en);
endmodule
module knob_volume_top(input wire sys_clk,enc_a,enc_b,output wire hp_bck,hp_ws,hp_din,pa_en);
    knob_audio_top #(.MODE(1)) instrument(sys_clk,enc_a,enc_b,hp_bck,hp_ws,hp_din,pa_en);
endmodule
module knob_timbre_top(input wire sys_clk,enc_a,enc_b,output wire hp_bck,hp_ws,hp_din,pa_en);
    knob_audio_top #(.MODE(2)) instrument(sys_clk,enc_a,enc_b,hp_bck,hp_ws,hp_din,pa_en);
endmodule
module knob_release_top(input wire sys_clk,enc_a,enc_b,output wire hp_bck,hp_ws,hp_din,pa_en);
    knob_audio_top #(.MODE(3)) instrument(sys_clk,enc_a,enc_b,hp_bck,hp_ws,hp_din,pa_en);
endmodule
module knob_echo_top(input wire sys_clk,enc_a,enc_b,output wire hp_bck,hp_ws,hp_din,pa_en);
    knob_audio_top #(.MODE(4)) instrument(sys_clk,enc_a,enc_b,hp_bck,hp_ws,hp_din,pa_en);
endmodule
