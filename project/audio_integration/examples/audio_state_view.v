`include "../include/audio_api_v2.vh"
// Compact UI fields: shadow only what the UI needs, commit complete records.
module audio_state_view #(parameter KEYS=25)(
    input wire clk,rst,in_valid,
    output wire in_ready,
    input wire [63:0] in_data,
    input wire [5:0] in_word_index,
    input wire in_first,in_last,in_session_start,
    output reg view_valid,view_gap,view_session_start,
    output reg [31:0] transport_sequence,source_drops,snapshot_sequence,parameter_revision,pcm_index,
    output reg [16:0] master_target,master_applied,
    output reg [2:0] selected_preset,
    output reg sustain,sostenuto,clip_seen,deadline_seen,blocked,
    output reg [15:0] peak,stream_reset_count,
    output reg [KEYS-1:0] keys,
    output reg [31:0] occupied,held,gated,
    output reg [223:0] notes,
    output reg [95:0] presets,
    output reg [31:0] malformed_records
);
    assign in_ready=1'b1;
    reg receiving,have_previous,session_pending;
    reg [5:0] expected_index;
    reg [31:0] shadow_transport,shadow_drops,shadow_sequence,shadow_revision,shadow_pcm;
    reg [16:0] shadow_target,shadow_applied;
    reg [2:0] shadow_preset;
    reg shadow_sustain,shadow_sostenuto,shadow_clip,shadow_deadline,shadow_blocked;
    reg [15:0] shadow_peak,shadow_reset;
    reg [31:0] shadow_occupied,shadow_held,shadow_gated;
    reg [223:0] shadow_notes;
    reg [95:0] shadow_presets;
    wire valid_header=in_data[63:48]==`AUDIO_STATE_MAGIC &&
        in_data[47:40]==`AUDIO_TRANSPORT_VERSION && in_data[39:32]==`AUDIO_STATE_WORDS &&
        in_data[31:24]==`AUDIO_STATE_BASE_WORDS && in_data[23:16]==`AUDIO_STATE_EXTENSION_WORDS &&
        in_data[15:8]==KEYS && in_data[7:0]==0;
    wire valid_cap0=in_data[15:0]==`AUDIO_API_VERSION && in_data[31:16]==32 &&
        in_data[47:32]==12 && in_data[63:48]==KEYS;
    wire valid_cap1=in_data[7:0]==`AUDIO_PRESET_MASK && in_data[15:8]==2 &&
        in_data[23:16]==0 && in_data[31:24]==64 && in_data[47:32]==2368 && in_data[63:48]==320;
    integer voice_index;
    always @(posedge clk) begin
        if(rst) begin
            receiving<=0;have_previous<=0;session_pending<=1;expected_index<=0;
            view_valid<=0;view_gap<=0;view_session_start<=0;malformed_records<=0;
            transport_sequence<=0;source_drops<=0;snapshot_sequence<=0;parameter_revision<=0;pcm_index<=0;
            master_target<=0;master_applied<=0;selected_preset<=0;
            sustain<=0;sostenuto<=0;clip_seen<=0;deadline_seen<=0;blocked<=0;
            peak<=0;stream_reset_count<=0;keys<=0;occupied<=0;held<=0;gated<=0;notes<=0;presets<=0;
        end else begin
            view_valid<=0;view_session_start<=0;
            if(in_valid) begin
                if(in_session_start) begin have_previous<=0;session_pending<=1;end
                if(in_first) begin
                    if(receiving) malformed_records<=malformed_records+1'b1;
                    if(in_word_index==0 && !in_last && valid_header) begin
                        receiving<=1;expected_index<=1;
                    end else begin
                        receiving<=0;malformed_records<=malformed_records+1'b1;
                    end
                end else if(receiving) begin
                    if(in_word_index!=expected_index || in_last!=(in_word_index==`AUDIO_WORD_KEYS) ||
                        (in_word_index==2 && !valid_cap0) || (in_word_index==3 && !valid_cap1)) begin
                        receiving<=0;malformed_records<=malformed_records+1'b1;
                    end else begin
                        expected_index<=expected_index+1'b1;
                        case(in_word_index)
                            1:begin shadow_transport<=in_data[31:0];shadow_drops<=in_data[63:32];end
                            4:begin shadow_sequence<=in_data[31:0];shadow_revision<=in_data[63:32];end
                            5:begin
                                shadow_target<=in_data[16:0];shadow_applied<=in_data[33:17];
                                shadow_preset<=in_data[36:34];shadow_sustain<=in_data[37];shadow_sostenuto<=in_data[38];
                                shadow_clip<=in_data[42];shadow_deadline<=in_data[43];shadow_blocked<=in_data[44];
                            end
                            8:begin shadow_peak<=in_data[25:10];shadow_reset<=in_data[54:39];end
                            41:shadow_pcm<=in_data[31:0];
                            45:begin
                                receiving<=0;view_valid<=1;view_session_start<=session_pending;
                                view_gap<=!have_previous || shadow_transport!=transport_sequence+1'b1 ||
                                    shadow_drops!=source_drops || shadow_reset!=stream_reset_count;
                                have_previous<=1;session_pending<=0;
                                transport_sequence<=shadow_transport;source_drops<=shadow_drops;
                                snapshot_sequence<=shadow_sequence;parameter_revision<=shadow_revision;pcm_index<=shadow_pcm;
                                master_target<=shadow_target;master_applied<=shadow_applied;selected_preset<=shadow_preset;
                                sustain<=shadow_sustain;sostenuto<=shadow_sostenuto;clip_seen<=shadow_clip;
                                deadline_seen<=shadow_deadline;blocked<=shadow_blocked;
                                peak<=shadow_peak;stream_reset_count<=shadow_reset;
                                keys<=in_data[KEYS-1:0];occupied<=shadow_occupied;held<=shadow_held;gated<=shadow_gated;
                                notes<=shadow_notes;presets<=shadow_presets;
                            end
                            default:begin
                                if(in_word_index>=9 && in_word_index<41) begin
                                    voice_index=in_word_index-9;
                                    shadow_occupied[voice_index]<=in_data[42];shadow_held[voice_index]<=in_data[43];
                                    shadow_gated[voice_index]<=in_data[44];
                                    shadow_notes[voice_index*7+:7]<=in_data[38:32];
                                    shadow_presets[voice_index*3+:3]<=in_data[41:39];
                                end
                            end
                        endcase
                    end
                end
            end
        end
    end
endmodule
