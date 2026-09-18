module voice_manager4 (
    input wire clk,rst,event_valid,event_on,
    input wire [6:0] event_note,
    input wire all_notes_off,
    input wire [3:0] voice_idle,
    output wire event_ready,
    output reg [3:0] note_on=0,note_off=0,occupied=0,held=0,
    output reg [27:0] voice_notes=0,
    output reg voice_stolen=0,event_ignored=0
);
    // A permutation of 0..3: least recently triggered to most recently triggered.
    reg [1:0] age_rank[0:3];
    initial begin age_rank[0]=0; age_rank[1]=1; age_rank[2]=2; age_rank[3]=3; end
    wire [3:0] effective_occupied=occupied & (held | ~voice_idle);
    integer i,j,match_index,free_index,release_index,oldest_index,choice;
    integer release_rank,oldest_rank;
    assign event_ready=!rst && !all_notes_off;
    always @* begin
        match_index=-1; free_index=-1; release_index=-1; oldest_index=-1;
        release_rank=4; oldest_rank=4;
        for(i=0;i<4;i=i+1) begin
            if(effective_occupied[i]) begin
                if(voice_notes[i*7 +: 7]==event_note) match_index=i;
                if(age_rank[i]<oldest_rank) begin oldest_rank=age_rank[i]; oldest_index=i; end
                if(!held[i] && age_rank[i]<release_rank) begin
                    release_rank=age_rank[i]; release_index=i;
                end
            end else if(free_index<0) free_index=i;
        end
        if(match_index>=0) choice=match_index;
        else if(free_index>=0) choice=free_index;
        else if(release_index>=0) choice=release_index;
        else choice=oldest_index;
    end
    always @(posedge clk) begin
        if(rst) begin
            note_on<=0; note_off<=0; occupied<=0; held<=0; voice_notes<=0;
            voice_stolen<=0; event_ignored<=0;
            age_rank[0]<=0; age_rank[1]<=1; age_rank[2]<=2; age_rank[3]<=3;
        end else begin
            note_on<=0; note_off<=0; voice_stolen<=0; event_ignored<=0;
            occupied<=effective_occupied;
            held<=held & effective_occupied;
            if(all_notes_off) begin
                note_off<=effective_occupied; held<=0;
            end else if(event_valid) begin
                if(event_on && choice>=0) begin
                    note_on[choice]<=1; occupied[choice]<=1; held[choice]<=1;
                    voice_notes[choice*7 +: 7]<=event_note;
                    voice_stolen<=effective_occupied[choice] && match_index<0;
                    for(j=0;j<4;j=j+1) begin
                        if(j==choice) age_rank[j]<=3;
                        else if(age_rank[j]>age_rank[choice]) age_rank[j]<=age_rank[j]-1'b1;
                    end
                end else if(!event_on && match_index>=0 && held[match_index]) begin
                    note_off[match_index]<=1; held[match_index]<=0;
                end else event_ignored<=1;
            end
        end
    end
endmodule
