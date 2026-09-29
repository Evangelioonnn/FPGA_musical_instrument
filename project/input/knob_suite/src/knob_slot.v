// One physical voice slot per strike. Pitch equality never merges lifetimes.
module knob_slot #(parameter MULTI=0,DYNAMIC_ADSR=0)(
    input wire clk,rst,sample_ce,start,
    input wire [6:0] note,
    input wire [1:0] timbre,
    input wire [23:0] gate_samples,
    input wire [15:0] attack,decay,sustain_level,release_step,
    input wire pedal_sustain,pedal_sostenuto,all_release,
    output wire busy,gated,sost_captured,
    output reg done,
    output reg signed [15:0] sample
);
    localparam IDLE=0,RESET_VOICE=1,START_VOICE=2,HELD=3,
        SEND_OFF=4,RELEASING=5,DRAIN=6;
    reg [2:0] state;
    reg [6:0] held_note;
    reg [1:0] held_timbre;
    reg [23:0] gate_left;
    reg [15:0] a,d,s,r;
    reg gate_down,sost_latch,sost_previous,force_off,drain_wait;
    wire voice_rst=rst || state==IDLE || state==RESET_VOICE;
    wire on_cmd=state==START_VOICE && !sample_ce && !all_release && !force_off;
    wire off_cmd=state==SEND_OFF && !sample_ce;
    wire [31:0] phase_step;
    wire signed [15:0] sine_sample,fm_sample,pluck_sample;
    wire sine_valid,fm_valid,pluck_valid,fm_ready,pluck_ready,fm_active,pluck_active;
    wire [2:0] sine_state;
    wire selected_ready=held_timbre==0 ? 1'b1 : held_timbre==1 ? pluck_ready : fm_ready;
    wire selected_active=held_timbre==0 ? sine_state!=0 : held_timbre==1 ? pluck_active : fm_active;
    wire selected_valid=held_timbre==0 ? sine_valid : held_timbre==1 ? pluck_valid : fm_valid;
    wire signed [15:0] selected_raw=held_timbre==0 ? sine_sample : held_timbre==1 ? pluck_sample : fm_sample;
    wire signed [15:0] attenuated=selected_raw>>>5;
    assign busy=state!=IDLE;
    assign gated=gate_down && busy;
    assign sost_captured=sost_latch && busy;
    note_table notes(held_note,phase_step);
    knob_reference_voice #(.DYNAMIC_ADSR(DYNAMIC_ADSR)) sine(
        clk,voice_rst,sample_ce,on_cmd && held_timbre==0,off_cmd && held_timbre==0,
        phase_step,a,d,s,r,sine_sample,sine_valid,sine_state);
    generate if(MULTI) begin: extra
        wire unused_fm_reject,unused_pluck_reject;
        fm_voice fm(.clk(clk),.rst(voice_rst),.sample_ce(sample_ce),
            .cmd_valid((on_cmd||off_cmd)&&held_timbre==2),.cmd_kind(off_cmd ? 2'd1 : 2'd0),
            .note(held_note),.velocity(9'd256),.seed(32'h12345678),
            .cmd_ready(fm_ready),.cmd_rejected(unused_fm_reject),.active(fm_active),
            .sample(fm_sample),.sample_valid(fm_valid));
        pluck_voice #(.LOGIC_SCALE(1)) pluck(.clk(clk),.rst(voice_rst),.sample_ce(sample_ce),
            .cmd_valid((on_cmd||off_cmd)&&held_timbre==1),.cmd_kind(off_cmd ? 2'd1 : 2'd0),
            .note(held_note),.velocity(9'd256),.seed(32'h12345678),
            .cmd_ready(pluck_ready),.cmd_rejected(unused_pluck_reject),.active(pluck_active),
            .sample(pluck_sample),.sample_valid(pluck_valid));
    end else begin: no_extra
        assign fm_sample=0;assign pluck_sample=0;
        assign fm_valid=0;assign pluck_valid=0;
        assign fm_ready=1;assign pluck_ready=1;
        assign fm_active=0;assign pluck_active=0;
    end endgenerate
    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE;held_note<=60;held_timbre<=0;gate_left<=0;
            a<=68;d<=6;s<=32768;r<=3;gate_down<=0;sost_latch<=0;
            sost_previous<=0;force_off<=0;drain_wait<=0;sample<=0;done<=0;
        end else begin
            done<=0;sost_previous<=pedal_sostenuto;
            if(!pedal_sostenuto) sost_latch<=0;
            else if(!sost_previous && gate_down) sost_latch<=1;
            if(all_release && busy) begin force_off<=1;gate_down<=0;sost_latch<=0;end
            if(selected_valid && !voice_rst) begin
                if(held_timbre==0) sample<=selected_raw;
                else if(attenuated>511) sample<=511;
                else if(attenuated< -512) sample<= -512;
                else sample<=attenuated;
            end
            case(state)
                IDLE: begin
                    sample<=0;gate_down<=0;sost_latch<=0;force_off<=0;
                    if(start && !all_release) begin
                        held_note<=note;held_timbre<=timbre;gate_left<=gate_samples;
                        a<=attack;d<=decay;s<=sustain_level;r<=release_step;
                        state<=RESET_VOICE;
                    end
                end
                RESET_VOICE: if(all_release) begin state<=IDLE;done<=1;end
                    else state<=START_VOICE;
                START_VOICE: if(all_release || force_off) begin state<=IDLE;done<=1;end
                    else if(on_cmd && selected_ready) begin gate_down<=1;state<=HELD;end
                HELD: begin
                    if(sample_ce && gate_down) begin
                        if(gate_left<=1) begin gate_left<=0;gate_down<=0;end
                        else gate_left<=gate_left-1'b1;
                    end
                    if(force_off || all_release || (!gate_down && !pedal_sustain && !sost_latch))
                        state<=SEND_OFF;
                end
                SEND_OFF: if(off_cmd && selected_ready) state<=RELEASING;
                RELEASING: if(!selected_active) begin state<=DRAIN;drain_wait<=0;end
                DRAIN: if(sample_ce) begin
                    if(drain_wait) begin state<=IDLE;done<=1;sample<=0;end
                    else drain_wait<=1;
                end
                default: state<=IDLE;
            endcase
        end
    end
endmodule
