// One product voice. Harmonic voice keeps the validated clean candidate;
// pluck voice keeps its natural decay and deliberately ignores sustain.
module palette_slot #(parameter PROFILE=0,
    parameter PLUCK_MIN_SAMPLES=12000,
    parameter PLUCK_QUIET_SAMPLES=4096,
    parameter PLUCK_MAX_SAMPLES=1442308
)(
    input wire clk,rst,sample_ce,start,stop,
    input wire [6:0] note,
    input wire [1:0] timbre,
    input wire [31:0] new_step, input wire [9:0] new_length,
    input wire [15:0] new_fraction, input wire [24:0] new_reciprocal,
    input wire signed [19:0] harmonic_sample, input wire harmonic_valid,
    output wire [31:0] tone_phase, output wire [15:0] tone_envelope, tone_brightness,
    input wire pedal,
    input wire [15:0] reference_release,
    output wire busy,held,
    output reg signed [19:0] sample
);
    localparam IDLE=0,RESET_VOICE=1,START_VOICE=2,HELD=3,
               SEND_OFF=4,RELEASING=5,DRAIN=6;
    reg [2:0] state;
    reg [6:0] held_note;
    reg [1:0] held_timbre;
    reg key_down,drain_wait;
    reg [20:0] age;
    reg [12:0] quiet_samples;
    reg [15:0] release_step;
    wire voice_rst=rst || state==IDLE || state==RESET_VOICE;
    wire on_cmd=state==START_VOICE && !sample_ce;
    wire off_cmd=state==SEND_OFF && !sample_ce;
    reg [31:0] phase_step;
    reg [9:0] length; reg [15:0] fraction; reg [24:0] reciprocal;
    reg signed [15:0] prior_a, prior_b;
    wire signed [18:0] warm_sum = $signed(pluck_sample) + ($signed(prior_a) * 19'sd2) + $signed(prior_b);
    wire signed [15:0] pluck_sample;
    wire pluck_valid,pluck_ready,pluck_active;
    wire [2:0] harmonic_state;
    wire harmonic_active=harmonic_state!=0;
    wire selected_pluck=held_timbre==1;
    wire ready=selected_pluck ? pluck_ready : 1'b1;
    wire active=selected_pluck ? pluck_active : harmonic_active;
    wire valid=selected_pluck ? pluck_valid : harmonic_valid;
    wire signed [15:0] raw=pluck_sample;
    wire signed [15:0] attenuated=raw>>>5;
    assign busy=state!=IDLE;
    assign held=busy && key_down;

    palette_tone_state #(.PROFILE(PROFILE)) harmonic(clk,voice_rst,sample_ce,
        on_cmd && !selected_pluck,off_cmd && !selected_pluck,phase_step,release_step,
        tone_phase,tone_envelope,tone_brightness,harmonic_state);
    palette_pluck #(.LOGIC_SCALE(1)) pluck(clk,voice_rst,sample_ce,
        (on_cmd||off_cmd) && selected_pluck,off_cmd ? 2'd1 : 2'd0,
        held_note,9'd256,32'h12345678,length,fraction,reciprocal,pluck_ready,,pluck_active,
        pluck_sample,pluck_valid);

    always @(posedge clk) begin
        if(rst) begin
            phase_step<=0;length<=0;fraction<=0;reciprocal<=0;prior_a<=0;prior_b<=0;
            state<=IDLE;held_note<=60;held_timbre<=0;key_down<=0;
            drain_wait<=0;age<=0;quiet_samples<=0;release_step<=3;sample<=0;
        end else begin
            if(stop && busy) key_down<=0;
            if(valid && !voice_rst) begin
                if(!selected_pluck) sample<=harmonic_sample;
                else if(PROFILE==5) sample<=$signed(raw) >>> 1;
                else if(PROFILE==6) sample<=warm_sum >>> 3;
                else if(attenuated>511) sample<=20'sd8176;
                else if(attenuated < -512) sample<=-20'sd8192;
                else sample<=$signed({attenuated,4'b0});
                if(selected_pluck) begin prior_b<=prior_a;prior_a<=raw;end
                if(selected_pluck && state==HELD) begin
                    if(age<PLUCK_MAX_SAMPLES) age<=age+1'b1;
                    if(age>=PLUCK_MIN_SAMPLES && raw>-32 && raw<32) begin
                        if(quiet_samples<PLUCK_QUIET_SAMPLES)
                            quiet_samples<=quiet_samples+1'b1;
                    end else quiet_samples<=0;
                end
            end
            case(state)
                IDLE: begin
                    sample<=0;key_down<=0;age<=0;quiet_samples<=0;prior_a<=0;prior_b<=0;
                    if(start) begin
                        held_note<=note;held_timbre<=timbre;key_down<=1;
                        phase_step<=new_step;length<=new_length;fraction<=new_fraction;reciprocal<=new_reciprocal;
                        state<=RESET_VOICE;
                    end
                end
                RESET_VOICE: state<=START_VOICE;
                START_VOICE: if(on_cmd && ready) state<=HELD;
                HELD: begin
                    if(selected_pluck) begin
                        if(quiet_samples>=PLUCK_QUIET_SAMPLES || age>=PLUCK_MAX_SAMPLES)
                            state<=SEND_OFF;
                    end else if(!key_down && !pedal) begin
                        release_step<=reference_release;
                        state<=SEND_OFF;
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
