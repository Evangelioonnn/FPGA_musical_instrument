// One authoritative target state for local, host and coherent fader scans.
module audio_parameter_service #(
    parameter [16:0] DEFAULT_MASTER = 17'd8249,
    parameter [11:0] PICKUP_TOLERANCE = 12'd16
) (
    input wire clk,
    input wire rst,
    input wire sample_ce,
    input wire local_valid,
    output wire local_ready,
    input wire [4:0] local_addr,
    input wire [31:0] local_value,
    input wire host_valid,
    output wire host_ready,
    input wire [4:0] host_addr,
    input wire [31:0] host_value,
    output reg ack_valid,
    output reg ack_source,
    output reg [4:0] ack_addr,
    output reg [31:0] ack_value,
    output reg ack_accepted,
    output reg ack_applied,
    input wire adc_valid,
    output wire adc_ready,
    input wire [11:0] adc_ch0,
    input wire [11:0] adc_ch1,
    input wire [11:0] adc_ch2,
    input wire [11:0] adc_ch3,
    input wire [11:0] adc_ch4,
    output reg adc_overrun,
    output reg [4:0] fader_acquired,
    output reg [1:0] master_owner,
    output reg [16:0] master_volume_target,
    output reg [2:0] selected_preset,
    output reg [6:0] zone_left,
    output reg [6:0] zone_right,
    output reg ordinary_sustain,
    output reg selective_sustain,
    output reg [2:0] release_index,
    output reg [2:0] glide_index,
    output reg signed [4:0] bend_index,
    output reg [1:0] lead_attack_index,
    output reg [15:0] adsr_attack,
    output reg [15:0] adsr_decay,
    output reg [15:0] adsr_sustain,
    output reg [15:0] adsr_release,
    output reg envelope_override,
    output reg custom_hold,
    output reg [6:0] vibrato_depth,
    output reg [2:0] vibrato_speed,
    output reg effect_enable,
    output reg [7:0] effect_mix,
    output reg [11:0] raw_ch1,
    output reg [11:0] raw_ch2,
    output reg [11:0] raw_ch3,
    output reg [11:0] raw_ch4,
    output reg harmonic_snapshot_valid,
    input wire harmonic_snapshot_ready,
    output reg [11:0] harmonic_snapshot_ch1,
    output reg [11:0] harmonic_snapshot_ch2,
    output reg [11:0] harmonic_snapshot_ch3,
    output reg [11:0] harmonic_snapshot_ch4,
    output reg panic_pulse,
    output reg params_updated,
    output reg [31:0] parameter_revision
);
    reg pending_cfg;
    reg pending_source;
    reg [4:0] pending_addr;
    reg [31:0] pending_value;
    reg prefer_host;
    reg pending_adc;
    reg [11:0] scan [0:4];
    reg [11:0] previous_scan [0:4];
    reg have_scan_history;
    reg prefer_adc;
    reg request_legal;
    wire harmonic_changed;

    wire source_choice = local_valid && host_valid ? prefer_host : host_valid;
    assign local_ready = !rst && !pending_cfg && !source_choice;
    assign host_ready = !rst && !pending_cfg && source_choice;
    assign adc_ready = !rst && !pending_adc;
    wire bundle_free = !harmonic_snapshot_valid || harmonic_snapshot_ready;
    wire cfg_needs_bundle = (pending_addr >= 5'd20 && pending_addr <= 5'd23) ||
                            pending_addr == 5'd31;
    wire cfg_can_commit = pending_cfg &&
        (!request_legal || !cfg_needs_bundle || bundle_free);
    wire adc_can_commit = pending_adc && (!harmonic_changed || bundle_free);
    wire commit_cfg = sample_ce && cfg_can_commit &&
                      (!adc_can_commit || !prefer_adc);
    wire commit_adc = sample_ce && adc_can_commit &&
                      (!cfg_can_commit || prefer_adc);

    function legal_zone;
        input [31:0] value;
        begin
            legal_zone = value == 32'd36 || value == 32'd48 ||
                         value == 32'd60 || value == 32'd72;
        end
    endfunction

    always @* begin
        request_legal = 1'b0;
        case (pending_addr)
            5'd0: request_legal = pending_value == 0 || pending_value == 2 ||
                                     pending_value == 3 || pending_value == 4 ||
                                     pending_value == 5;
            5'd1: request_legal = pending_value <= 32'd65536;
            5'd2: request_legal = $signed(pending_value) >= -32'sd65536 &&
                                   $signed(pending_value) <= 32'sd65536;
            5'd3,5'd4: request_legal = legal_zone(pending_value);
            5'd5,5'd6,5'd15,5'd18,5'd24: request_legal = pending_value <= 1;
            5'd7,5'd17: request_legal = pending_value <= 7;
            5'd8: request_legal = pending_value <= 4;
            5'd9: request_legal = $signed(pending_value) >= -32'sd8 &&
                                   $signed(pending_value) <= 32'sd8;
            5'd10: request_legal = pending_value <= 3;
            5'd11,5'd12,5'd14: request_legal = pending_value >= 1 &&
                                             pending_value <= 32'd65535;
            5'd13: request_legal = pending_value <= 32'd65535;
            5'd16: request_legal = pending_value <= 64;
            5'd19: request_legal = pending_value <= 128;
            5'd20,5'd21,5'd22,5'd23: request_legal = pending_value <= 4095;
            5'd30,5'd31: request_legal = pending_value == 1;
            default: request_legal = 1'b0;
        endcase
    end

    wire signed [32:0] volume_sum =
        $signed({16'd0, master_volume_target}) +
        $signed({pending_value[31], pending_value});
    wire [16:0] relative_volume = volume_sum < 0 ? 17'd0 :
        volume_sum > 33'sd65536 ? 17'd65536 : volume_sum[16:0];
    wire [16:0] rounded_master = master_volume_target + 17'd8;
    wire [11:0] master_pickup_target = rounded_master >= 17'd65520 ?
        12'd4095 : rounded_master[15:4];

    function channel_pickup;
        input acquired;
        input [11:0] position;
        input [11:0] previous;
        input [11:0] target;
        input history;
        reg [12:0] distance;
        begin
            distance = position >= target ? {1'b0,position} - {1'b0,target} :
                                            {1'b0,target} - {1'b0,position};
            channel_pickup = acquired || distance <= {1'b0,PICKUP_TOLERANCE} ||
                (history && ((previous <= target && position >= target) ||
                             (previous >= target && position <= target)));
        end
    endfunction

    function [16:0] volume_from_adc;
        input [11:0] position;
        begin
            volume_from_adc = position == 12'd4095 ? 17'd65536 :
                {1'b0,position,4'b0000} + {13'd0,position[11:8]};
        end
    endfunction

    wire acquire_master = scan[0] == 0 ||
        channel_pickup(fader_acquired[0],scan[0],previous_scan[0],
                       master_pickup_target,have_scan_history);
    wire acquire1 = channel_pickup(fader_acquired[1],scan[1],previous_scan[1],
                                  raw_ch1,have_scan_history);
    wire acquire2 = channel_pickup(fader_acquired[2],scan[2],previous_scan[2],
                                  raw_ch2,have_scan_history);
    wire acquire3 = channel_pickup(fader_acquired[3],scan[3],previous_scan[3],
                                  raw_ch3,have_scan_history);
    wire acquire4 = channel_pickup(fader_acquired[4],scan[4],previous_scan[4],
                                  raw_ch4,have_scan_history);
    wire [11:0] next_raw1 = selected_preset == 5 && acquire1 ? scan[1] : raw_ch1;
    wire [11:0] next_raw2 = selected_preset == 5 && acquire2 ? scan[2] : raw_ch2;
    wire [11:0] next_raw3 = selected_preset == 5 && acquire3 ? scan[3] : raw_ch3;
    wire [11:0] next_raw4 = selected_preset == 5 && acquire4 ? scan[4] : raw_ch4;
    assign harmonic_changed = next_raw1 != raw_ch1 || next_raw2 != raw_ch2 ||
                              next_raw3 != raw_ch3 || next_raw4 != raw_ch4;
    wire [16:0] next_master = acquire_master ? volume_from_adc(scan[0]) :
                                             master_volume_target;
    wire fader_changed = next_master != master_volume_target || harmonic_changed;
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            pending_cfg <= 0;
            pending_source <= 0;
            pending_addr <= 0;
            pending_value <= 0;
            prefer_host <= 0;
            pending_adc <= 0;
            prefer_adc <= 0;
            have_scan_history <= 0;
            for (i=0;i<5;i=i+1) begin scan[i] <= 0; previous_scan[i] <= 0; end
            ack_valid <= 0;
            ack_source <= 0;
            ack_addr <= 0;
            ack_value <= 0;
            ack_accepted <= 0;
            ack_applied <= 0;
            adc_overrun <= 0;
            fader_acquired <= 0;
            master_owner <= 0;
            master_volume_target <= DEFAULT_MASTER;
            selected_preset <= 0;
            zone_left <= 48;
            zone_right <= 60;
            ordinary_sustain <= 0;
            selective_sustain <= 0;
            release_index <= 5;
            glide_index <= 0;
            bend_index <= 0;
            lead_attack_index <= 2;
            adsr_attack <= 68;
            adsr_decay <= 6;
            adsr_sustain <= 32768;
            adsr_release <= 3;
            envelope_override <= 0;
            custom_hold <= 0;
            vibrato_depth <= 0;
            vibrato_speed <= 0;
            effect_enable <= 0;
            effect_mix <= 32;
            raw_ch1 <= 4095;
            raw_ch2 <= 1024;
            raw_ch3 <= 512;
            raw_ch4 <= 256;
            harmonic_snapshot_valid <= 1;
            harmonic_snapshot_ch1 <= 4095;
            harmonic_snapshot_ch2 <= 1024;
            harmonic_snapshot_ch3 <= 512;
            harmonic_snapshot_ch4 <= 256;
            panic_pulse <= 0;
            params_updated <= 0;
            parameter_revision <= 0;
        end else begin
            ack_valid <= 0;
            panic_pulse <= 0;
            params_updated <= 0;
            if (harmonic_snapshot_valid && harmonic_snapshot_ready)
                harmonic_snapshot_valid <= 0;
            if (!pending_cfg && (local_valid || host_valid)) begin
                pending_cfg <= 1;
                pending_source <= source_choice;
                pending_addr <= source_choice ? host_addr : local_addr;
                pending_value <= source_choice ? host_value : local_value;
                prefer_host <= !source_choice;
            end
            if (adc_valid) begin
                if (adc_ready) begin
                    pending_adc <= 1;
                    scan[0] <= adc_ch0;
                    scan[1] <= adc_ch1;
                    scan[2] <= adc_ch2;
                    scan[3] <= adc_ch3;
                    scan[4] <= adc_ch4;
                end else adc_overrun <= 1;
            end
            if (commit_cfg) begin
                pending_cfg <= 0;
                prefer_adc <= 1;
                ack_valid <= 1;
                ack_source <= pending_source;
                ack_addr <= pending_addr;
                ack_value <= pending_addr == 2 ? {15'd0,relative_volume} : pending_value;
                ack_accepted <= request_legal;
                ack_applied <= request_legal;
                if (request_legal) begin
                    params_updated <= 1;
                    parameter_revision <= parameter_revision + 1'b1;
                    case (pending_addr)
                        5'd0: begin
                            selected_preset <= pending_value[2:0];
                            if (pending_value == 5 && selected_preset != 5)
                                fader_acquired[4:1] <= 0;
                        end
                        5'd1,5'd2: begin
                            master_volume_target <= pending_addr == 2 ?
                                relative_volume : pending_value[16:0];
                            master_owner <= pending_source ? 2'd2 : 2'd1;
                            fader_acquired[0] <= 0;
                        end
                        5'd3: zone_left <= pending_value[6:0];
                        5'd4: zone_right <= pending_value[6:0];
                        5'd5: ordinary_sustain <= pending_value[0];
                        5'd6: selective_sustain <= pending_value[0];
                        5'd7: release_index <= pending_value[2:0];
                        5'd8: glide_index <= pending_value[2:0];
                        5'd9: bend_index <= pending_value[4:0];
                        5'd10: lead_attack_index <= pending_value[1:0];
                        5'd11: begin adsr_attack <= pending_value[15:0]; envelope_override <= 1; end
                        5'd12: begin adsr_decay <= pending_value[15:0]; envelope_override <= 1; end
                        5'd13: begin adsr_sustain <= pending_value[15:0]; envelope_override <= 1; end
                        5'd14: begin adsr_release <= pending_value[15:0]; envelope_override <= 1; end
                        5'd15: custom_hold <= pending_value[0];
                        5'd16: vibrato_depth <= pending_value[6:0];
                        5'd17: vibrato_speed <= pending_value[2:0];
                        5'd18: effect_enable <= pending_value[0];
                        5'd19: effect_mix <= pending_value[7:0];
                        5'd20,5'd21,5'd22,5'd23: begin
                            case (pending_addr)
                                5'd20: begin raw_ch1 <= pending_value[11:0]; fader_acquired[1] <= 0; end
                                5'd21: begin raw_ch2 <= pending_value[11:0]; fader_acquired[2] <= 0; end
                                5'd22: begin raw_ch3 <= pending_value[11:0]; fader_acquired[3] <= 0; end
                                5'd23: begin raw_ch4 <= pending_value[11:0]; fader_acquired[4] <= 0; end
                            endcase
                            harmonic_snapshot_valid <= 1;
                            harmonic_snapshot_ch1 <= pending_addr == 20 ? pending_value[11:0] : raw_ch1;
                            harmonic_snapshot_ch2 <= pending_addr == 21 ? pending_value[11:0] : raw_ch2;
                            harmonic_snapshot_ch3 <= pending_addr == 22 ? pending_value[11:0] : raw_ch3;
                            harmonic_snapshot_ch4 <= pending_addr == 23 ? pending_value[11:0] : raw_ch4;
                        end
                        5'd24: envelope_override <= pending_value[0];
                        5'd30: begin
                            panic_pulse <= 1;
                            ordinary_sustain <= 0;
                            selective_sustain <= 0;
                            bend_index <= 0;
                        end
                        5'd31: begin
                            master_volume_target <= DEFAULT_MASTER;
                            master_owner <= 0;
                            selected_preset <= 0;
                            zone_left <= 48;
                            zone_right <= 60;
                            ordinary_sustain <= 0;
                            selective_sustain <= 0;
                            release_index <= 5;
                            glide_index <= 0;
                            bend_index <= 0;
                            lead_attack_index <= 2;
                            adsr_attack <= 68;
                            adsr_decay <= 6;
                            adsr_sustain <= 32768;
                            adsr_release <= 3;
                            envelope_override <= 0;
                            custom_hold <= 0;
                            vibrato_depth <= 0;
                            vibrato_speed <= 0;
                            effect_enable <= 0;
                            effect_mix <= 32;
                            raw_ch1 <= 4095;
                            raw_ch2 <= 1024;
                            raw_ch3 <= 512;
                            raw_ch4 <= 256;
                            fader_acquired <= 0;
                            have_scan_history <= 0;
                            harmonic_snapshot_valid <= 1;
                            harmonic_snapshot_ch1 <= 4095;
                            harmonic_snapshot_ch2 <= 1024;
                            harmonic_snapshot_ch3 <= 512;
                            harmonic_snapshot_ch4 <= 256;
                        end
                    endcase
                end
            end else if (commit_adc) begin
                pending_adc <= 0;
                prefer_adc <= 0;
                have_scan_history <= 1;
                for (i=0;i<5;i=i+1) previous_scan[i] <= scan[i];
                fader_acquired[0] <= acquire_master;
                if (selected_preset == 5) begin
                    fader_acquired[1] <= acquire1;
                    fader_acquired[2] <= acquire2;
                    fader_acquired[3] <= acquire3;
                    fader_acquired[4] <= acquire4;
                end
                master_volume_target <= next_master;
                if (acquire_master) master_owner <= 3;
                if (fader_changed) begin
                    params_updated <= 1;
                    parameter_revision <= parameter_revision + 1'b1;
                end
                if (harmonic_changed) begin
                    raw_ch1 <= next_raw1;
                    raw_ch2 <= next_raw2;
                    raw_ch3 <= next_raw3;
                    raw_ch4 <= next_raw4;
                    harmonic_snapshot_valid <= 1;
                    harmonic_snapshot_ch1 <= next_raw1;
                    harmonic_snapshot_ch2 <= next_raw2;
                    harmonic_snapshot_ch3 <= next_raw3;
                    harmonic_snapshot_ch4 <= next_raw4;
                end
            end
        end
    end
endmodule
