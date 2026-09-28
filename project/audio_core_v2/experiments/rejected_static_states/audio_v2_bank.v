// Thirty-two independent harmonic states share one pitch multiply and renderer.
// Warm pluck has its own bounded pool; total occupied logical slots never exceed N.
module audio_v2_bank #(parameter N=32,PLUCK_N=8,SW=(N>1?$clog2(N):1))(
    input wire clk,rst,sample_ce,event_valid,output wire event_ready,
    input wire event_off,input wire [31:0] event_token,input wire [6:0] event_note,
    input wire [2:0] event_timbre,input wire pedal,sostenuto,
    input wire [15:0] reference_release,input wire [2:0] glide_index,
    input wire [1:0] lead_attack_index,input wire [16:0] bend_factor,lead_bend_factor,
    input wire envelope_override,custom_hold,
    input wire [15:0] adsr_attack,adsr_decay,adsr_sustain,adsr_release,
    input wire [8:0] coeff0,coeff1,coeff2,coeff3,
    output reg accepted,rejected,output reg [31:0] rejected_count,unmatched_off_count,
    output wire [N-1:0] occupied,held,gated,sost_latched,
    output wire [N*7-1:0] notes_snapshot,output wire [N*3-1:0] presets_snapshot,
    output wire [N*32-1:0] tokens_snapshot,output wire [N*16-1:0] envelopes_snapshot,
    output reg out_valid,output reg signed [15:0] out_sample,
    output reg clipped,deadline_missed
);
    reg [N-1:0] hstart,hstop,proc_ce;
    reg [PLUCK_N-1:0] pstart,pstop;
    wire [N-1:0] hbusy,hheld,hgated,hsost,tone_valid;
    wire [PLUCK_N-1:0] pbusy,pheld,pgated,psost;
    wire [N*32-1:0] phases,steps;
    wire [N*17-1:0] slews;
    wire [N*16-1:0] envs,brightness;
    wire [N*7-1:0] tone_notes;
    wire [N*3-1:0] tone_presets;
    wire [N*20-1:0] hsamples;
    wire [PLUCK_N*20-1:0] psamples;
    reg [SW-1:0] powner[0:PLUCK_N-1];
    reg [31:0] tokens[0:N-1];
    reg [6:0] notes[0:N-1];
    reg [2:0] presets[0:N-1];
    reg [N-1:0] pmapped,pmapped_held,pmapped_gated,pmapped_sost;
    reg [N*20-1:0] mapped_samples;
    integer i,j;
    always @* begin
        pmapped=0;pmapped_held=0;pmapped_gated=0;pmapped_sost=0;mapped_samples=0;
        for(i=0;i<PLUCK_N;i=i+1) begin
            if(pbusy[i] || pstart[i]) begin
                pmapped[powner[i]]=1;pmapped_held[powner[i]]=pheld[i];
                pmapped_gated[powner[i]]=pgated[i];pmapped_sost[powner[i]]=psost[i];
                mapped_samples[powner[i]*20+:20]=psamples[i*20+:20];
            end
        end
    end
    assign occupied=hbusy|hstart|pmapped;
    assign held=hheld|pmapped_held;
    assign gated=hgated|pmapped_gated;
    assign sost_latched=hsost|pmapped_sost;
    reg [3:0] state,pause_count;
    reg [SW-1:0] index;
    reg [15:0] wait_left;
    reg tone_ce;
    wire signed [19:0] tone_sample;
    wire tone_deadline;
    reg [31:0] pitch_operand;
    reg [16:0] slew_operand;
    reg [48:0] pitch_product;
    wire [48:0] pitch_next=pitch_operand*slew_operand;
    reg free_found,match_found,pluck_free_found;
    reg [SW-1:0] free_slot,match_slot;
    integer pluck_free_slot;
    reg lead_found;
    reg [31:0] latest_token,latest_step;
    always @* begin
        free_found=0;match_found=0;pluck_free_found=0;free_slot=0;match_slot=0;pluck_free_slot=0;
        lead_found=0;latest_token=0;latest_step=0;
        for(i=0;i<N;i=i+1) begin
            if(!occupied[i] && !free_found) begin free_found=1;free_slot=i;end
            if(occupied[i] && tokens[i]==event_token) begin match_found=1;match_slot=i;end
            if(hheld[i] && presets[i]==4 && (!lead_found || tokens[i]>latest_token)) begin
                lead_found=1;latest_token=tokens[i];latest_step=steps[i*32+:32];
            end
        end
        for(i=0;i<PLUCK_N;i=i+1)
            if(!pbusy[i] && !pstart[i] && !pluck_free_found) begin
                pluck_free_found=1;pluck_free_slot=i;
            end
    end
    assign event_ready=!rst && !sample_ce && state==0 && pause_count==0 && !(|hstart) && !(|pstart);
    reg [6:0] new_note;
    reg [2:0] new_timbre,new_glide;
    reg [31:0] new_step,glide_source;
    reg [9:0] new_length;
    reg [15:0] new_fraction;
    reg [24:0] new_reciprocal;
    wire [31:0] lookup_step;
    wire [9:0] lookup_length;
    wire [15:0] lookup_fraction;
    wire [24:0] lookup_reciprocal;
    note_table note_lookup(event_note,lookup_step);
    pluck_note_table pluck_lookup(event_note,lookup_length,lookup_fraction,lookup_reciprocal);
    always @(posedge clk) begin
        if(rst) begin
            hstart<=0;hstop<=0;pstart<=0;pstop<=0;pause_count<=0;
            new_note<=60;new_timbre<=0;new_glide<=0;new_step<=0;glide_source<=0;
            new_length<=0;new_fraction<=0;new_reciprocal<=0;
            accepted<=0;rejected<=0;rejected_count<=0;unmatched_off_count<=0;
            for(j=0;j<N;j=j+1) begin tokens[j]<=0;notes[j]<=60;presets[j]<=0;end
            for(j=0;j<PLUCK_N;j=j+1) powner[j]<=0;
        end else begin
            hstart<=0;hstop<=0;pstart<=0;pstop<=0;accepted<=0;rejected<=0;
            if(pause_count!=0) pause_count<=pause_count-1'b1;
            if(event_valid && event_ready) begin
                pause_count<=8;
                if(event_off) begin
                    if(match_found && event_token!=0) begin
                        if(presets[match_slot]==2) begin
                            for(j=0;j<PLUCK_N;j=j+1)
                                if(pbusy[j] && powner[j]==match_slot) pstop[j]<=1;
                        end else hstop[match_slot]<=1;
                    end else unmatched_off_count<=unmatched_off_count+1'b1;
                end else if(free_found && !match_found && event_token!=0 &&
                    event_note>=36 && event_note<=84 &&
                    (event_timbre==0 || event_timbre==2 || event_timbre==3 || event_timbre==4 || event_timbre==5) &&
                    (event_timbre!=2 || pluck_free_found)) begin
                    tokens[free_slot]<=event_token;notes[free_slot]<=event_note;presets[free_slot]<=event_timbre;
                    new_note<=event_note;new_timbre<=event_timbre;new_step<=lookup_step;new_glide<=glide_index;
                    new_length<=lookup_length;new_fraction<=lookup_fraction;new_reciprocal<=lookup_reciprocal;
                    glide_source<=event_timbre==4 && glide_index!=0 && lead_found ? latest_step : lookup_step;
                    if(event_timbre==2) begin pstart[pluck_free_slot]<=1;powner[pluck_free_slot]<=free_slot;end
                    else hstart[free_slot]<=1;
                    accepted<=1;
                end else begin rejected<=1;rejected_count<=rejected_count+1'b1;end
            end
        end
    end
    custom_gallery_shared_tone #(.PROFILE(6),.N(N)) tones(clk,rst,tone_ce,
        phases,envs,brightness,tone_notes,tone_presets,coeff0,coeff1,coeff2,coeff3,
        tone_sample,tone_valid,tone_deadline);
    genvar g;
    generate for(g=0;g<N;g=g+1) begin: harmonics
        assign tokens_snapshot[g*32+:32]=tokens[g];
        assign notes_snapshot[g*7+:7]=notes[g];
        assign presets_snapshot[g*3+:3]=presets[g];
        assign envelopes_snapshot[g*16+:16]=pmapped[g] ? 16'd0 : envs[g*16+:16];
        audio_v2_slot slot(clk,rst,sample_ce,hstart[g],hstop[g],new_note,new_timbre,
            new_step,new_length,new_fraction,new_reciprocal,glide_source,new_glide,
            tone_sample,tone_valid[g],phases[g*32+:32],envs[g*16+:16],brightness[g*16+:16],
            tone_notes[g*7+:7],tone_presets[g*3+:3],steps[g*32+:32],
            pedal,sostenuto,reference_release,bend_factor,lead_bend_factor,lead_attack_index,
            envelope_override,custom_hold,adsr_attack,adsr_decay,adsr_sustain,adsr_release,
            hbusy[g],hheld[g],hgated[g],hsost[g],hsamples[g*20+:20],proc_ce[g],pitch_product,slews[g*17+:17]);
    end
    for(g=0;g<PLUCK_N;g=g+1) begin: plucks
        audio_v2_slot #(.PLUCK_ONLY(1)) slot(.clk(clk),.rst(rst),.sample_ce(sample_ce),
            .start(pstart[g]),.stop(pstop[g]),.note(new_note),.timbre(3'd2),
            .new_step(new_step),.new_length(new_length),.new_fraction(new_fraction),.new_reciprocal(new_reciprocal),
            .glide_start_step(32'd0),.glide_index(3'd0),.harmonic_sample(20'sd0),.harmonic_valid(1'b0),
            .pedal(pedal),.sostenuto(sostenuto),.reference_release(reference_release),
            .bend_factor(bend_factor),.lead_bend_factor(lead_bend_factor),.lead_attack_index(lead_attack_index),
            .envelope_override(envelope_override),.custom_hold(custom_hold),
            .adsr_attack(adsr_attack),.adsr_decay(adsr_decay),.adsr_sustain(adsr_sustain),.adsr_release(adsr_release),
            .busy(pbusy[g]),.held(pheld[g]),.gated(pgated[g]),.sost_latched(psost[g]),
            .sample(psamples[g*20+:20]),.proc_ce(1'b0),.shared_bend_product(49'd0));
    end endgenerate
    reg [N*22-1:0] frame;
    reg signed [31:0] sum;
    wire signed [21:0] term=frame[index*22+:22];
    wire signed [31:0] next_sum=sum+{{10{term[21]}},term};
    // Q4 harmonics at 1/4 level; Q4 pluck gets x4 before the common Q6 mix.
    wire signed [31:0] rounded_sum=next_sum<0 ? -(((-next_sum)+32)>>>6) : (next_sum+32)>>>6;
    always @(posedge clk) begin
        if(rst) begin
            state<=0;index<=0;proc_ce<=0;tone_ce<=0;wait_left<=0;
            pitch_operand<=0;slew_operand<=65536;pitch_product<=0;
            frame<=0;sum<=0;out_valid<=0;out_sample<=0;clipped<=0;deadline_missed<=0;
        end else begin
            proc_ce<=0;tone_ce<=0;out_valid<=0;clipped<=0;
            if(tone_deadline) deadline_missed<=1;
            if(sample_ce) begin
                if(state!=0) deadline_missed<=1;
                state<=1;index<=0;
            end else case(state)
                1:begin pitch_operand<=steps[index*32+:32];slew_operand<=slews[index*17+:17];state<=2;end
                2:begin pitch_product<=pitch_next;state<=3;end
                3:begin proc_ce[index]<=1;state<=4;end
                4:if(index==N-1) begin state<=5;index<=0;end
                  else begin index<=index+1'b1;state<=1;end
                5:begin tone_ce<=1;wait_left<=16+N*20;state<=6;end
                6:if(wait_left==1) begin
                    for(j=0;j<N;j=j+1) begin
                        if(pmapped[j]) frame[j*22+:22]<=$signed(psample_for_slot(j))<<<2;
                        else frame[j*22+:22]<={{2{hsamples[j*20+19]}},hsamples[j*20+:20]};
                    end
                    sum<=0;index<=0;state<=7;
                  end else wait_left<=wait_left-1'b1;
                7:begin
                    sum<=next_sum;
                    if(index==N-1) begin
                        if(rounded_sum>32767) begin out_sample<=32767;clipped<=1;end
                        else if(rounded_sum< -32768) begin out_sample<=-32768;clipped<=1;end
                        else out_sample<=rounded_sum[15:0];
                        out_valid<=1;state<=0;
                    end else index<=index+1'b1;
                end
                default:state<=0;
            endcase
        end
    end
    function signed [21:0] psample_for_slot;
        input integer slot;
        begin psample_for_slot={{2{mapped_samples[slot*20+19]}},mapped_samples[slot*20+:20]};end
    endfunction
endmodule
