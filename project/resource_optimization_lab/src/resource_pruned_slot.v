// One default sine voice. FM and pluck are intentionally absent in this
// lower-bound experiment; event_timbre is filtered by the bank.
module resource_pruned_slot #(
    parameter REFERENCE_RELEASE=16'd3
)(
    input wire clk,rst,sample_ce,start,stop,
    input wire [6:0] note,
    input wire pedal,input wire [15:0] reference_release,
    output wire busy,held,output reg signed [15:0] sample
);
    localparam IDLE=0,RESET_VOICE=1,START_VOICE=2,HELD=3,
        SEND_OFF=4,RELEASING=5,DRAIN=6;
    reg [2:0] state;
    reg [6:0] held_note;
    reg key_down,drain_wait;
    reg [15:0] release_step;
    wire voice_rst=rst || state==IDLE || state==RESET_VOICE;
    wire on_cmd=state==START_VOICE && !sample_ce;
    wire off_cmd=state==SEND_OFF && !sample_ce;
    wire [31:0] phase_step;
    wire signed [15:0] sine_sample;
    wire sine_valid;
    wire [2:0] sine_state;
    wire active=sine_state!=0;
    assign busy=state!=IDLE;
    assign held=busy && key_down;
    note_table notes(held_note,phase_step);
    knob_reference_voice #(.DYNAMIC_ADSR(1)) sine(
        clk,voice_rst,sample_ce,on_cmd,off_cmd,phase_step,
        16'd68,16'd6,16'd32768,release_step,
        sine_sample,sine_valid,sine_state);

    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE;held_note<=60;key_down<=0;drain_wait<=0;
            release_step<=REFERENCE_RELEASE;sample<=0;
        end else begin
            if(stop && busy) key_down<=0;
            if(sine_valid && !voice_rst) sample<=sine_sample;
            case(state)
                IDLE: begin
                    sample<=0;key_down<=0;
                    if(start) begin
                        held_note<=note;key_down<=1;state<=RESET_VOICE;
                    end
                end
                RESET_VOICE: state<=START_VOICE;
                START_VOICE: if(on_cmd) state<=HELD;
                HELD: if(!key_down && !pedal) begin
                    release_step<=reference_release;
                    state<=SEND_OFF;
                end
                SEND_OFF: if(off_cmd) state<=RELEASING;
                RELEASING: if(!active) begin state<=DRAIN;drain_wait<=0;end
                DRAIN: if(sample_ce) begin
                    if(drain_wait) begin state<=IDLE;sample<=0;end
                    else drain_wait<=1;
                end
                default: state<=IDLE;
            endcase
        end
    end
endmodule
