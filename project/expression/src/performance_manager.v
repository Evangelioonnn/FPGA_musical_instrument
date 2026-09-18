module performance_manager #(parameter N=8, parameter AGE_W=$clog2(N))(
    input wire clk,rst,event_valid,
    input wire [1:0] event_kind,
    input wire [6:0] event_note,event_value,
    input wire [8:0] event_velocity,
    input wire sustain,sostenuto,panic,
    input wire [N-1:0] idle,
    output wire event_ready,
    output reg [N-1:0] on_mask,off_mask,fresh_mask,occupied,held,gated,sost_latched,
    output reg [N*7-1:0] notes,pitches,
    output reg [N*9-1:0] velocities,
    output reg stolen,ignored
);
    reg sost_prev;
    reg [AGE_W-1:0] age[0:N-1], age_next[0:N-1];
    reg [N-1:0] occ_n,held_n,gate_n,sost_n,on_n,off_n,fresh_n;
    reg [N*7-1:0] notes_n,pitches_n;
    reg [N*9-1:0] vel_n;
    reg stolen_n,ignored_n;
    reg [N-1:0] matches,first_free,winner,chosen;
    reg [AGE_W+1:0] priority_score[0:N-1];
    reg free_seen;
    reg [AGE_W-1:0] chosen_age;
    integer i,j,k;
    assign event_ready=!rst && !panic;
    always @* begin
        occ_n=occupied & (gated | held | ~idle);
        held_n=held & occ_n; gate_n=gated & occ_n;
        sost_n=sostenuto ? (sost_prev ? sost_latched & occ_n : held & occ_n) : 0;
        notes_n=notes; pitches_n=pitches; vel_n=velocities;
        on_n=0; off_n=0; fresh_n=0; stolen_n=0; ignored_n=0;
        matches=0;first_free=0;winner=0;chosen=0;free_seen=0;chosen_age=0;
        for(i=0;i<N;i=i+1) begin
            age_next[i]=age[i];
            if(gate_n[i] && !held_n[i] && !sustain && !sost_n[i]) begin
                gate_n[i]=0; off_n[i]=1;
            end
            matches[i]=occ_n[i] && notes[i*7 +: 7]==event_note;
            first_free[i]=!occ_n[i] && !free_seen;
            free_seen=free_seen || !occ_n[i];
            priority_score[i]={(!gate_n[i] ? 2'd0 : !held_n[i] ? 2'd1 : 2'd2),age[i]};
        end
        // Pairwise comparison creates parallel trees instead of an N-deep minimum chain.
        for(i=0;i<N;i=i+1) begin
            winner[i]=occ_n[i];
            for(j=0;j<N;j=j+1)
                if(j!=i && occ_n[j] && priority_score[j]<priority_score[i]) winner[i]=0;
        end
        chosen=(|matches) ? matches : (|first_free) ? first_free : winner;
        for(i=0;i<N;i=i+1) chosen_age=chosen_age | (age[i] & {AGE_W{chosen[i]}});
        for(i=0;i<N;i=i+1) begin
            if(panic) begin
                off_n[i]=occ_n[i];held_n[i]=0;gate_n[i]=0;sost_n[i]=0;
            end else if(event_valid) begin
                if(event_kind==0 && event_velocity!=0) begin
                    if(chosen[i]) begin
                        on_n[i]=1;off_n[i]=0;fresh_n[i]=!occ_n[i];
                        occ_n[i]=1;held_n[i]=1;gate_n[i]=1;
                        if(!matches[i]) sost_n[i]=0;
                        notes_n[i*7 +: 7]=event_note;pitches_n[i*7 +: 7]=event_note;
                        vel_n[i*9 +: 9]=event_velocity>256 ? 9'd256 : event_velocity;
                        age_next[i]=N-1;
                    end else if(age[i]>chosen_age) age_next[i]=age[i]-1'b1;
                end else if(event_kind==1 || (event_kind==0 && event_velocity==0)) begin
                    if(matches[i] && held[i]) begin
                        held_n[i]=0;
                        if(!sustain && !sost_n[i]) begin gate_n[i]=0;off_n[i]=1;end
                    end
                end else if(event_kind==2 && matches[i]) pitches_n[i*7 +: 7]=event_value;
            end
        end
        if(!panic && event_valid) begin
            if(event_kind==0 && event_velocity!=0) begin
                stolen_n=!(|matches) && !(|first_free);
            end else if(event_kind==1 || (event_kind==0 && event_velocity==0)) begin
                ignored_n=!(|(matches & held));
            end else ignored_n=(event_kind!=2) || !(|matches);
        end
    end
    always @(posedge clk) begin
        if(rst) begin
            on_mask<=0;off_mask<=0;fresh_mask<=0;occupied<=0;held<=0;gated<=0;sost_latched<=0;
            notes<=0;pitches<=0;velocities<=0;stolen<=0;ignored<=0;sost_prev<=0;
            for(k=0;k<N;k=k+1) age[k]<=k;
        end else begin
            on_mask<=on_n;off_mask<=off_n;fresh_mask<=fresh_n;
            occupied<=occ_n;held<=held_n;gated<=gate_n;sost_latched<=sost_n;
            notes<=notes_n;pitches<=pitches_n;velocities<=vel_n;
            stolen<=stolen_n;ignored<=ignored_n;sost_prev<=sostenuto;
            for(k=0;k<N;k=k+1) age[k]<=age_next[k];
        end
    end
endmodule
