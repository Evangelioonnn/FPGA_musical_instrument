// Queue complete debounced snapshots. An unqueueable transition is explicit:
// release all engine voices and require an all-up frame before re-arming.
module key_pipeline #(parameter KEYS=16,DEPTH=8)(
    input wire clk,rst,external_panic,changed,ghost,all_released,
    input wire [KEYS-1:0] keys,
    input wire [KEYS*7-1:0] note_map,
    input wire [8:0] velocity,
    output wire event_valid,output wire [1:0] event_kind,
    output wire [6:0] event_note,output wire [8:0] event_velocity,
    input wire event_ready,
    output wire fault_pulse,
    output reg blocked,overflow_seen,
    output reg [31:0] fault_count
);
    localparam WIDTH=KEYS*8+9;
    wire q_ready,q_valid,router_ready;
    wire [WIDTH-1:0] q_data;
    wire [$clog2(DEPTH+1)-1:0] queue_level;
    wire [KEYS-1:0] unused_owned;
    reg previous_ghost;
    // Use registered occupancy, not in_ready: ready includes router_ready,
    // which is suppressed by fault_pulse. Testing ready here forms a loop.
    // Conservatively trip on full even if a simultaneous dequeue is possible.
    wire overflow=changed && !blocked && queue_level==DEPTH && !external_panic && !ghost;
    wire ghost_edge=ghost && !previous_ghost;
    wire flush=blocked || external_panic;
    assign fault_pulse=!rst && (overflow || ghost_edge);
    stream_fifo #(.WIDTH(WIDTH),.DEPTH(DEPTH)) snapshots(clk,rst,flush,
        changed && !blocked && !ghost && !external_panic,{note_map,velocity,keys},
        q_ready,q_valid,q_data,router_ready,queue_level);
    key_router #(.KEYS(KEYS)) router(clk,rst,flush || fault_pulse,q_valid,
        q_data[KEYS-1:0],q_data[WIDTH-1:KEYS+9],q_data[KEYS +: 9],router_ready,
        event_valid,event_kind,event_note,event_velocity,event_ready,unused_owned);
    always @(posedge clk) begin
        if(rst) begin blocked<=1;overflow_seen<=0;fault_count<=0;previous_ghost<=0;end
        else begin
            previous_ghost<=ghost;
            if(overflow) overflow_seen<=1;
            if(fault_pulse) fault_count<=fault_count+1'b1;
            if(external_panic || fault_pulse) blocked<=1;
            else if(blocked && all_released && !ghost) blocked<=0;
        end
    end
endmodule
