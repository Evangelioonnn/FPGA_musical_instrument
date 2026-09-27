// Local playable-gallery fork; baseline sources remain unchanged.
// Isolated fork of palette module at db653ef; see SPEC.md.
module custom_gallery_bank #(parameter PROFILE=6,parameter TONE_SHIFT=0,parameter BALANCE_MODE=0,parameter N=8,parameter SW=(N>1?$clog2(N):1))(
    input wire clk,rst,sample_ce,event_valid,
    output wire event_ready,
    input wire event_off,input wire [31:0] event_token,
    input wire [6:0] event_note,input wire [2:0] event_timbre,
    input wire pedal,sostenuto,input wire [15:0] reference_release,input wire [2:0] glide_index,
    input wire [1:0] lead_attack_index,
    input wire [16:0] bend_factor,
    input wire [8:0] coeff0,coeff1,coeff2,coeff3,
    output reg accepted,rejected,output reg [31:0] rejected_count,unmatched_off_count,
    output wire [N-1:0] occupied,held,
    output reg out_valid,output reg signed [15:0] out_sample,
    output reg clipped,deadline_missed
);
    reg [6:0] note;
    reg [1:0] mix_state;
    reg [N-1:0] start_mask,stop_mask;
    wire [N-1:0] busy;
    wire [N*20-1:0] samples;
    wire [N*32-1:0] phases;
    wire [N*7-1:0] tone_notes;
    wire [N*16-1:0] envelopes,brightness;
    wire [N*3-1:0] voice_timbres;
    wire [N*32-1:0] voice_steps;
    wire [N-1:0] harmonic_valid;
    wire signed [19:0] harmonic_sample;
    wire tone_deadline;
    reg [31:0] new_step;reg [9:0] new_length;
    reg [15:0] new_fraction;reg [24:0] new_reciprocal;
    wire [31:0] lookup_step;wire [9:0] lookup_length;
    wire [15:0] lookup_fraction;wire [24:0] lookup_reciprocal;
    note_table notes(event_note,lookup_step);
    pluck_note_table strings(event_note,lookup_length,lookup_fraction,lookup_reciprocal);
    custom_gallery_shared_tone #(.PROFILE(PROFILE),.TONE_SHIFT(TONE_SHIFT),.BALANCE_MODE(BALANCE_MODE),.N(N)) tones(clk,rst,sample_ce,
        phases,envelopes,brightness,tone_notes,voice_timbres,coeff0,coeff1,coeff2,coeff3,
        harmonic_sample,harmonic_valid,tone_deadline);
    reg [31:0] tokens[0:N-1];
    reg [2:0] timbre;
    reg [2:0] glide_latched;
    reg free_found,duplicate,match_found;
    reg [SW-1:0] free_slot,match_slot;
    localparam TREE_N=1<<$clog2(N);
    reg [2*TREE_N-1:1] lead_tree_valid;
    reg [31:0] lead_tree_token[1:2*TREE_N-1];
    reg [31:0] lead_tree_step[1:2*TREE_N-1];
    reg [3:0] pair_valid;
    reg [31:0] pair_token[0:3],pair_step[0:3];
    wire take_pair1=pair_valid[1] && (!pair_valid[0] || pair_token[1]>pair_token[0]);
    wire take_pair3=pair_valid[3] && (!pair_valid[2] || pair_token[3]>pair_token[2]);
    reg [1:0] mid_valid;
    reg [31:0] mid_token0,mid_token1,mid_step0,mid_step1;
    wire choose_right=mid_valid[1] && (!mid_valid[0] || mid_token1>mid_token0);
    wire lead_found=|mid_valid;
    wire [31:0] lead_step=choose_right ? mid_step1 : mid_step0;
    reg lead_found_q;
    reg [31:0] lead_step_q;
    reg [3:0] accept_pause;
    reg [31:0] glide_start_latched;
    integer i,j,p;
    assign occupied=busy|start_mask;
    assign event_ready=!rst && accept_pause==0 && !sample_ce && mix_state==0 && !(|start_mask) && !(|stop_mask);
    always @* begin
        free_found=0;free_slot=0;duplicate=0;match_found=0;match_slot=0;
        for(i=0;i<N;i=i+1) begin
            if(!occupied[i] && !free_found) begin free_found=1;free_slot=i;end
            if(occupied[i] && tokens[i]==event_token) begin
                duplicate=1;match_found=1;match_slot=i;
            end
        end
    end
    always @(posedge clk) begin
        if(rst) begin
            pair_valid<=0;
            for(p=0;p<4;p=p+1) begin pair_token[p]<=0;pair_step[p]<=0;end
            mid_valid<=0;mid_token0<=0;mid_token1<=0;mid_step0<=0;mid_step1<=0;
            lead_found_q<=0;lead_step_q<=0;accept_pause<=0;
        end else begin
            for(p=0;p<4;p=p+1) begin
                pair_valid[p]<=lead_tree_valid[4+p];
                pair_token[p]<=lead_tree_token[4+p];
                pair_step[p]<=lead_tree_step[4+p];
            end
            mid_valid<={pair_valid[2]||pair_valid[3],pair_valid[0]||pair_valid[1]};
            mid_token0<=take_pair1 ? pair_token[1] : pair_token[0];
            mid_token1<=take_pair3 ? pair_token[3] : pair_token[2];
            mid_step0<=take_pair1 ? pair_step[1] : pair_step[0];
            mid_step1<=take_pair3 ? pair_step[3] : pair_step[2];
            lead_found_q<=lead_found;lead_step_q<=lead_step;
            if(event_valid && event_ready) accept_pause<=4'd8;
            else if(accept_pause!=0) accept_pause<=accept_pause-1'b1;
        end
    end
    always @* begin
        for(i=0;i<TREE_N;i=i+1) begin
            lead_tree_valid[TREE_N+i]=i<N && occupied[i] && held[i] &&
                voice_steps[i*32+:32]!=0 &&
                voice_timbres[i*3+:3]==4;
            lead_tree_token[TREE_N+i]=i<N ? tokens[i] : 0;
            lead_tree_step[TREE_N+i]=i<N ? voice_steps[i*32+:32] : 0;
        end
        for(i=TREE_N-1;i>0;i=i-1) begin
            if(lead_tree_valid[2*i+1] &&
               (!lead_tree_valid[2*i] || lead_tree_token[2*i+1]>lead_tree_token[2*i])) begin
                lead_tree_valid[i]=1;
                lead_tree_token[i]=lead_tree_token[2*i+1];
                lead_tree_step[i]=lead_tree_step[2*i+1];
            end else begin
                lead_tree_valid[i]=lead_tree_valid[2*i];
                lead_tree_token[i]=lead_tree_token[2*i];
                lead_tree_step[i]=lead_tree_step[2*i];
            end
        end
    end
    genvar g;
    generate for(g=0;g<N;g=g+1) begin: slots
        gallery_slot #(.PROFILE(PROFILE)) slot(clk,rst,sample_ce,start_mask[g],stop_mask[g],note,timbre,
            new_step,new_length,new_fraction,new_reciprocal,
            glide_start_latched,
            glide_latched,harmonic_sample,harmonic_valid[g],
            phases[g*32+:32],envelopes[g*16+:16],brightness[g*16+:16],tone_notes[g*7+:7],
            voice_timbres[g*3+:3],voice_steps[g*32+:32],
            pedal,sostenuto,reference_release,bend_factor,lead_attack_index,
            busy[g],held[g],samples[g*20+:20]);
    end endgenerate
    always @(posedge clk) begin
        if(rst) begin
            start_mask<=0;stop_mask<=0;note<=60;timbre<=0;glide_latched<=0;
            new_step<=32'h0164A274;new_length<=10'd185;
            new_fraction<=16'd17192;new_reciprocal<=25'd90688;
            glide_start_latched<=0;accepted<=0;rejected<=0;
            rejected_count<=0;unmatched_off_count<=0;
            for(j=0;j<N;j=j+1) tokens[j]<=0;
        end else begin
            start_mask<=0;stop_mask<=0;accepted<=0;rejected<=0;
            if(event_valid && event_ready) begin
        if(event_off) begin
                    if(match_found && event_token!=0) stop_mask[match_slot]<=1;
                    else unmatched_off_count<=unmatched_off_count+1'b1;
                end else if(free_found && !duplicate && event_token!=0 &&
                    event_note>=36 && event_note<=84 && event_timbre<=5) begin
                    start_mask[free_slot]<=1;tokens[free_slot]<=event_token;
                    note<=event_note;new_step<=lookup_step;new_length<=lookup_length;
                    new_fraction<=lookup_fraction;new_reciprocal<=lookup_reciprocal;
                    timbre<=event_timbre;glide_latched<=glide_index;
                    glide_start_latched<=(glide_index!=0 && lead_found_q &&
                        event_timbre==4) ? lead_step_q : 0;
                    accepted<=1;
                end else begin
                    rejected<=1;rejected_count<=rejected_count+1'b1;
                end
            end
        end
    end
    reg [15:0] wait_left;
    reg [SW-1:0] index;
    reg [N*20-1:0] frame;
    reg signed [31:0] sum;
    wire signed [19:0] term=frame[index*20+:20];
    wire signed [31:0] next_sum=sum+{{12{term[19]}},term};
    wire signed [31:0] rounded_sum = next_sum<0 ? -(((-next_sum)+8)>>>4) : (next_sum+8)>>>4;
    always @(posedge clk) begin
        if(rst) begin
            wait_left<=0;mix_state<=0;index<=0;frame<=0;sum<=0;
            out_valid<=0;out_sample<=0;clipped<=0;deadline_missed<=0;
        end else begin
            out_valid<=0;clipped<=0;
            if(tone_deadline) deadline_missed<=1;
            if(sample_ce) begin
                if(mix_state!=0) deadline_missed<=1;
                wait_left<=16+N*20;mix_state<=1;
            end else case(mix_state)
                // The custom four-partial scan takes longer than the fixed
                // gallery presets; wait for all eight voice latches before
                // capturing the mixer frame.
                1: if(wait_left==1) begin frame<=samples;sum<=0;index<=0;mix_state<=2;end
                   else wait_left<=wait_left-1'b1;
                2: begin
                    sum<=next_sum;
                    if(index==N-1) begin
                        if(rounded_sum>32767) begin out_sample<=32767;clipped<=1;end
                        else if(rounded_sum< -32768) begin out_sample<=-32768;clipped<=1;end
                        else out_sample<=rounded_sum[15:0];
                        out_valid<=1;mix_state<=0;
                    end else index<=index+1'b1;
                end
                default:mix_state<=0;
            endcase
        end
    end
endmodule
