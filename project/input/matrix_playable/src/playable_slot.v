// A physical slot owns one strike until its tail has finished.
module playable_slot #(parameter PLUCK_MIN_SAMPLES=12000,PLUCK_QUIET_SAMPLES=4096,
    parameter PLUCK_MAX_SAMPLES=1442308)(
    input wire clk,rst,sample_ce,start,stop,
    input wire [6:0] note,input wire [1:0] timbre,
    input wire pedal,input wire [15:0] reference_release,
    input wire [2:0] fm_release_index,
    output wire busy,held,output reg signed [15:0] sample
);
    localparam IDLE=0,RESET_VOICE=1,START_VOICE=2,HELD=3,SEND_OFF=4,RELEASING=5,DRAIN=6;
    reg [2:0] state;
    reg [6:0] held_note;
    reg [1:0] held_timbre;
    reg key_down,drain_wait;
    reg [15:0] r;
    reg [2:0] fm_r;
    reg [20:0] age;
    reg [12:0] quiet_samples;
    wire voice_rst=rst || state==IDLE || state==RESET_VOICE;
    wire on_cmd=state==START_VOICE && !sample_ce;
    wire off_cmd=state==SEND_OFF && !sample_ce;
    wire [31:0] phase_step;
    wire signed [15:0] sine_sample,fm_sample,pluck_sample;
    wire sine_valid,fm_valid,pluck_valid,fm_ready,pluck_ready,fm_active,pluck_active;
    wire [2:0] sine_state;
    wire ready=held_timbre==0 ? 1'b1 : held_timbre==1 ? pluck_ready : fm_ready;
    wire active=held_timbre==0 ? sine_state!=0 : held_timbre==1 ? pluck_active : fm_active;
    wire valid=held_timbre==0 ? sine_valid : held_timbre==1 ? pluck_valid : fm_valid;
    wire signed [15:0] raw=held_timbre==0 ? sine_sample : held_timbre==1 ? pluck_sample : fm_sample;
    wire signed [15:0] attenuated=raw>>>5;
    assign busy=state!=IDLE;
    assign held=busy && key_down;
    note_table notes(held_note,phase_step);
    knob_reference_voice #(.DYNAMIC_ADSR(1)) sine(clk,voice_rst,sample_ce,
        on_cmd && held_timbre==0,off_cmd && held_timbre==0,phase_step,
        16'd68,16'd6,16'd32768,r,sine_sample,sine_valid,sine_state);
    playable_fm_voice fm(.clk(clk),.rst(voice_rst),.sample_ce(sample_ce),
        .cmd_valid((on_cmd||off_cmd)&&held_timbre==2),.cmd_kind(off_cmd?2'd1:2'd0),
        .note(held_note),.velocity(9'd256),.seed(32'h12345678),.release_index(fm_r),
        .cmd_ready(fm_ready),.cmd_rejected(),.active(fm_active),.sample(fm_sample),.sample_valid(fm_valid));
    pluck_voice #(.LOGIC_SCALE(1)) pluck(.clk(clk),.rst(voice_rst),.sample_ce(sample_ce),
        .cmd_valid((on_cmd||off_cmd)&&held_timbre==1),.cmd_kind(off_cmd?2'd1:2'd0),
        .note(held_note),.velocity(9'd256),.seed(32'h12345678),
        .cmd_ready(pluck_ready),.cmd_rejected(),.active(pluck_active),.sample(pluck_sample),.sample_valid(pluck_valid));
    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE;held_note<=60;held_timbre<=0;key_down<=0;
            drain_wait<=0;r<=3;fm_r<=3;age<=0;quiet_samples<=0;sample<=0;
        end else begin
            if(stop && busy) key_down<=0;
            if(valid && !voice_rst) begin
                if(held_timbre==0) sample<=raw;
                else if(attenuated>511) sample<=511;
                else if(attenuated< -512) sample<=-512;
                else sample<=attenuated;
                if(held_timbre==1 && state==HELD) begin
                    if(age<PLUCK_MAX_SAMPLES) age<=age+1'b1;
                    if(age>=PLUCK_MIN_SAMPLES && raw>-32 && raw<32) begin
                        if(quiet_samples<PLUCK_QUIET_SAMPLES) quiet_samples<=quiet_samples+1'b1;
                    end else quiet_samples<=0;
                end
            end
            case(state)
                IDLE: begin
                    sample<=0;key_down<=0;age<=0;quiet_samples<=0;
                    if(start) begin held_note<=note;held_timbre<=timbre;key_down<=1;state<=RESET_VOICE;end
                end
                RESET_VOICE: state<=START_VOICE;
                START_VOICE: if(on_cmd && ready) state<=HELD;
                HELD: begin
                    if(held_timbre==1) begin
                        if(quiet_samples>=PLUCK_QUIET_SAMPLES || age>=PLUCK_MAX_SAMPLES) state<=SEND_OFF;
                    end else if(!key_down && !pedal) begin
                        r<=reference_release;fm_r<=fm_release_index;state<=SEND_OFF;
                    end
                end
                SEND_OFF: if(off_cmd && ready) state<=RELEASING;
                RELEASING: if(!active) begin state<=DRAIN;drain_wait<=0;end
                DRAIN: if(sample_ce) begin
                    if(drain_wait) begin state<=IDLE;sample<=0;end
                    else drain_wait<=1;
                end
                default:state<=IDLE;
            endcase
        end
    end
endmodule
