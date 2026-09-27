// Local playable-gallery fork; baseline sources remain unchanged.
// Isolated fork of palette module at db653ef; see SPEC.md.
module gallery_engine #(parameter PROFILE=6,parameter TONE_SHIFT=0,parameter N=8,parameter BUTTON_CYCLES=150000,parameter LONG_CYCLES=50000000)(
    input wire clk,rst,sample_ce,
    input wire [15:0] keys,input wire changed,ghost,all_released,
    input wire [2:0] button_n,input wire step_valid,input wire signed [1:0] step,
    output wire final_valid,output wire signed [15:0] final_sample,
    output wire [2:0] timbre,control_mode,output wire sustain,release_mode,blocked,
    output wire [4:0] volume_index,output wire [2:0] reference_release_index,
    output wire rejected,output wire fault_pulse,output wire [N-1:0] occupied,
    output wire deadline_missed,output reg muting
);
    wire panic,overflow_seen,token_exhausted;
    wire [31:0] fault_count,rejected_count,unmatched_off_count;
    wire [16:0] volume_target,gain;
    wire [15:0] reference_release;
    wire [2:0] glide_index;wire [6:0] left_base,right_base;
    gallery_controls #(.PROFILE(PROFILE),.BUTTON_CYCLES(BUTTON_CYCLES),.LONG_CYCLES(LONG_CYCLES)) controls(
        clk,rst,button_n,step_valid,step,fault_pulse,timbre,sustain,release_mode,control_mode,left_base,right_base,panic,
        volume_index,reference_release_index,glide_index,volume_target,reference_release);
    wire event_valid,event_ready,event_off;
    wire [31:0] event_token;
    wire [6:0] event_note;
    wire [2:0] event_timbre;
    gallery_keys #(.KEYS(16),.SPLIT(8),.DIATONIC(1)) keys_adapter(clk,rst,panic||muting,changed,ghost,all_released,keys,
        timbre,left_base,right_base,event_valid,event_ready,event_off,event_token,event_note,event_timbre,
        fault_pulse,blocked,overflow_seen,token_exhausted,fault_count);
    wire bank_valid,bank_ready,accepted,clip;
    wire signed [15:0] bank_sample;
    wire [N-1:0] held;
    reg clear_bank;
    assign event_ready=bank_ready && !muting && !panic && !fault_pulse;
    gallery_bank #(.PROFILE(PROFILE),.TONE_SHIFT(TONE_SHIFT),.N(N)) bank(clk,rst||clear_bank,sample_ce,
        event_valid && !muting && !panic && !fault_pulse,bank_ready,event_off,event_token,
        event_note,event_timbre,sustain,reference_release,glide_index,accepted,rejected,rejected_count,
        unmatched_off_count,occupied,held,bank_valid,bank_sample,clip,deadline_missed);
    knob_gain volume(clk,rst,bank_valid,bank_sample,muting ? 17'd0 : volume_target,
        final_valid,final_sample,gain);
    always @(posedge clk) begin
        if(rst) begin muting<=0;clear_bank<=0;end
        else begin
            clear_bank<=0;
            if(panic || fault_pulse) muting<=1;
            else if(muting && gain==0 && bank_valid) begin clear_bank<=1;muting<=0;end
        end
    end
endmodule
