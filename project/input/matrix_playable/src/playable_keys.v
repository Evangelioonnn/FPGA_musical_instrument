// Snapshot queue + per-strike identity. Never merges equal note pitches.
module playable_keys #(parameter DEPTH=8)(
    input wire clk,rst,external_panic,changed,ghost,all_released,
    input wire [15:0] keys,input wire [1:0] timbre,
    output wire event_valid,input wire event_ready,
    output reg event_off,output reg [31:0] event_token,
    output reg [6:0] event_note,output reg [1:0] event_timbre,
    output wire fault_pulse,output reg blocked,overflow_seen,token_exhausted,
    output reg [31:0] fault_count
);
    wire q_ready,q_valid;
    wire [17:0] q_data;
    wire [$clog2(DEPTH+1)-1:0] level;
    reg working,previous_ghost,pending;
    reg [3:0] event_key;
    reg [15:0] target,owned;
    reg [1:0] target_timbre;
    reg [31:0] next_token;
    reg [31:0] tokens[0:15];
    reg found,off;
    reg [3:0] index;
    integer i,j;
    wire overflow=changed && !blocked && level==DEPTH && !external_panic && !ghost;
    wire exhausted_request=working && found && !off && next_token==0;
    assign fault_pulse=!rst && (overflow || (ghost && !previous_ghost) || (exhausted_request && !token_exhausted));
    wire flush=external_panic || blocked || fault_pulse;
    wire pop=!working && !flush;
    stream_fifo #(.WIDTH(18),.DEPTH(DEPTH)) snapshots(clk,rst,flush,
        changed && !ghost && !flush,{timbre,keys},q_ready,q_valid,q_data,pop,level);
    always @* begin
        found=0;index=0;off=0;
        for(i=0;i<16;i=i+1) if(owned[i] && !target[i] && !found) begin found=1;index=i;off=1;end
        for(i=0;i<16;i=i+1) if(!owned[i] && target[i] && !found) begin found=1;index=i;off=0;end
    end
    // Register the transaction: key priority/token lookup must not feed the
    // bank's identity comparator/allocator in the same 50MHz timing path.
    assign event_valid=pending && !flush && !token_exhausted;
    always @(posedge clk) begin
        if(rst) begin
            blocked<=1;overflow_seen<=0;token_exhausted<=0;fault_count<=0;previous_ghost<=0;
            working<=0;target<=0;owned<=0;target_timbre<=0;next_token<=1;
            pending<=0;event_key<=0;event_off<=0;event_token<=0;event_note<=60;event_timbre<=0;
            for(j=0;j<16;j=j+1) tokens[j]<=0;
        end else begin
            previous_ghost<=ghost;
            if(overflow) overflow_seen<=1;
            if(exhausted_request) token_exhausted<=1;
            if(fault_pulse) fault_count<=fault_count+1'b1;
            if(external_panic || fault_pulse) blocked<=1;
            else if(blocked && all_released && keys==0 && !ghost && !token_exhausted) blocked<=0;
            if(flush) begin working<=0;target<=0;owned<=0;pending<=0;end
            else if(!working && q_valid) begin working<=1;target<=q_data[15:0];target_timbre<=q_data[17:16];end
            else if(working) begin
                if(pending) begin
                    if(event_valid && event_ready) begin
                        pending<=0;owned[event_key]<=!event_off;
                        if(!event_off) begin tokens[event_key]<=next_token;next_token<=next_token+1'b1;end
                    end
                end else if(!found) working<=0;
                else if(!exhausted_request) begin
                    pending<=1;event_key<=index;event_off<=off;
                    event_token<=off ? tokens[index] : next_token;
                    event_note<=7'd60+{3'd0,index};event_timbre<=target_timbre;
                end
            end
        end
    end
endmodule
