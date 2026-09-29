// Complete eight-voice sine bank candidate. Each voice keeps independent
// phase/envelope/event state; one synchronous sine ROM and one waveform*envelope
// multiplier are serviced once per voice inside the 1040-clock audio period.
module resource_shared_sine_bank #(parameter N=8,parameter SW=(N>1?$clog2(N):1))(
    input wire clk,rst,sample_ce,event_valid,
    output wire event_ready,
    input wire event_off,input wire [31:0] event_token,
    input wire [6:0] event_note,input wire [1:0] event_timbre,
    input wire pedal,input wire [15:0] reference_release,input wire [2:0] fm_release_index,
    output reg accepted,rejected,output reg [31:0] rejected_count,unmatched_off_count,
    output wire [N-1:0] occupied,held,
    output reg out_valid,output reg signed [15:0] out_sample,
    output reg clipped,deadline_missed
);
    localparam IDLE=0,ATTACK=1,DECAY=2,SUSTAIN=3,RELEASE=4;
    reg [2:0] voice_state[0:N-1];
    reg key_down[0:N-1];
    reg [31:0] tokens[0:N-1];
    reg [6:0] notes[0:N-1];
    reg [31:0] phase[0:N-1],step[0:N-1];
    reg [31:0] render_phase[0:N-1];
    reg [15:0] envelope[0:N-1],release_hold[0:N-1];
    reg [N-1:0] start_mask,stop_mask,key_mask;
    wire [N-1:0] busy;
    assign busy = {N{1'b0}} | {
        (voice_state[7]!=IDLE),(voice_state[6]!=IDLE),(voice_state[5]!=IDLE),(voice_state[4]!=IDLE),
        (voice_state[3]!=IDLE),(voice_state[2]!=IDLE),(voice_state[1]!=IDLE),(voice_state[0]!=IDLE)};
    assign occupied=busy|start_mask;
    assign held = busy & key_mask;
    reg free_found,match_found;
    reg [SW-1:0] free_slot,match_slot;
    wire [31:0] event_step;
    note_table event_notes(event_note,event_step);
    integer i,j;
    always @* begin
        free_found=0;free_slot=0;match_found=0;match_slot=0;
        for(i=0;i<N;i=i+1) begin
            if(!occupied[i] && !free_found) begin free_found=1;free_slot=i;end
            if(occupied[i] && tokens[i]==event_token && event_token!=0) begin match_found=1;match_slot=i;end
        end
    end

    reg running;
    // 0 idle, 1 address issued, 2 synchronous ROM data is ready to consume.
    reg [1:0] rom_pending;
    reg [3:0] sched_count;
    reg [SW-1:0] sched_index,pending_index;
    reg [9:0] rom_addr;
    wire signed [15:0] rom_data;
    sine_rom shared_rom(clk,rom_addr,rom_data);
    reg signed [31:0] mix_accum;
    // Match knob_reference_voice/synth_voice exactly: the signed Q15
    // waveform times the unsigned Q16 envelope is reduced by 22 bits.
    wire signed [32:0] envelope_product = $signed(rom_data) * $signed({1'b0,envelope[pending_index]});
    wire signed [31:0] scaled_value = envelope_product >>> 22;
    assign event_ready=!rst && !running && !(|start_mask) && !(|stop_mask);

    always @(posedge clk) begin
        if(rst) begin
            start_mask<=0;stop_mask<=0;key_mask<=0;accepted<=0;rejected<=0;
            rejected_count<=0;unmatched_off_count<=0;
            running<=0;rom_pending<=0;sched_count<=0;sched_index<=0;pending_index<=0;
            rom_addr<=0;mix_accum<=0;out_valid<=0;out_sample<=0;clipped<=0;deadline_missed<=0;
            for(j=0;j<N;j=j+1) begin
                voice_state[j]<=IDLE;key_down[j]<=0;tokens[j]<=0;notes[j]<=60;
                phase[j]<=0;render_phase[j]<=0;step[j]<=0;envelope[j]<=0;release_hold[j]<=16'd3;
            end
        end else begin
            start_mask<=0;stop_mask<=0;accepted<=0;rejected<=0;out_valid<=0;clipped<=0;
            if(event_valid && event_ready) begin
                if(event_off) begin
                    if(match_found) begin
                        stop_mask[match_slot]<=1;key_mask[match_slot]<=0;
                        release_hold[match_slot]<=reference_release;
                    end else unmatched_off_count<=unmatched_off_count+1'b1;
                end else if(free_found && event_timbre==0 && event_token!=0 &&
                    event_note>=48 && event_note<=84) begin
                    start_mask[free_slot]<=1;key_mask[free_slot]<=1;tokens[free_slot]<=event_token;
                    notes[free_slot]<=event_note;step[free_slot]<=event_step;
                    phase[free_slot]<=0;envelope[free_slot]<=0;voice_state[free_slot]<=ATTACK;
                    accepted<=1;
                end else begin rejected<=1;rejected_count<=rejected_count+1'b1;end
            end
            // A release begins at the next sample boundary from any active
            // ADSR phase. Pedal keeps the physical key held until it opens.
            for(j=0;j<N;j=j+1) begin
                if(!key_mask[j] && voice_state[j]!=IDLE && voice_state[j]!=RELEASE && !pedal)
                    voice_state[j]<=RELEASE;
                // Do not clear key_mask here: an accepted start may move a
                // slot from IDLE to ATTACK in this same clock. The old
                // key_mask value is still zero during this loop, so clearing
                // it would cancel the newly accepted note.
                if(voice_state[j]==IDLE) key_down[j]<=0;
            end
            if(sample_ce && !running) begin
                if(running) deadline_missed<=1;
                running<=1;rom_pending<=0;sched_count<=0;sched_index<=0;mix_accum<=0;
                // The production voices advance phase and ADSR exactly at
                // sample_ce. The shared arithmetic below only renders those
                // already-updated states; it must not become the state clock.
                for(j=0;j<N;j=j+1) begin
                    if(busy[j]) begin
                phase[j]<=phase[j]+step[j];
                        // synth_voice addresses the ROM with the phase that
                        // existed at the sample boundary, then advances the
                        // accumulator for the next sample.
                        render_phase[j]<=phase[j];
                        if(!key_mask[j] && !pedal && voice_state[j]!=IDLE && voice_state[j]!=RELEASE) begin
                            if(envelope[j]<=release_hold[j]) begin envelope[j]<=0;voice_state[j]<=IDLE;key_mask[j]<=0;end
                            else begin envelope[j]<=envelope[j]-release_hold[j];voice_state[j]<=RELEASE;end
                        end else begin
                            case(voice_state[j])
                                ATTACK: begin
                                    if(envelope[j]>=16'd65467) begin envelope[j]<=16'd65535;voice_state[j]<=DECAY;end
                                    else envelope[j]<=envelope[j]+16'd68;
                                end
                                DECAY: begin
                                    if(envelope[j]<=16'd32774) begin envelope[j]<=16'd32768;voice_state[j]<=SUSTAIN;end
                                    else envelope[j]<=envelope[j]-16'd6;
                                end
                                SUSTAIN: envelope[j]<=16'd32768;
                                RELEASE: begin
                                    if(envelope[j]<=release_hold[j]) begin envelope[j]<=0;voice_state[j]<=IDLE;key_mask[j]<=0;end
                                    else envelope[j]<=envelope[j]-release_hold[j];
                                end
                                default: begin envelope[j]<=0;voice_state[j]<=IDLE;key_mask[j]<=0;end
                            endcase
                        end
                    end
                end
            end else if(running) begin
                if(rom_pending==2) begin
                    if(busy[pending_index]) begin
                        // Keep the full-width sum throughout the frame. The
                        // reference bank saturates only after all voices are
                        // added; per-voice clipping would change chords.
                        mix_accum<=mix_accum+scaled_value;
                    end
                    rom_pending<=0;
                end else if(rom_pending==1) begin
                    rom_pending<=2;
                end else if(sched_count<N) begin
                    // sine_rom is synchronous: issue one address, then wait
                    // one clock before consuming its returned sample. Keeping
                    // issue and consume mutually exclusive avoids assigning a
                    // voice's waveform value to the next voice.
                    rom_addr<=render_phase[sched_index][31:22];pending_index<=sched_index;
                    sched_index<=sched_index+1'b1;sched_count<=sched_count+1'b1;rom_pending<=1;
                end else begin
                    running<=0;out_valid<=1;
                    if(mix_accum>32767) begin out_sample<=16'sh7fff;clipped<=1;end
                    else if(mix_accum< -32768) begin out_sample<=-16'sh8000;clipped<=1;end
                    else out_sample<=mix_accum[15:0];
                end
            end
        end
    end
endmodule
