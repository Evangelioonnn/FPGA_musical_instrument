// One atomic key-state snapshot at a time. Release before press, note latched on press.
// Equal pitches share one engine identity; last physical owner releases that identity.
module key_router #(parameter KEYS=16,parameter INDEX_W=(KEYS>1?$clog2(KEYS):1))(
    input wire clk,rst,flush,state_valid,
    input wire [KEYS-1:0] key_state,
    input wire [KEYS*7-1:0] note_map,
    input wire [8:0] velocity,
    output wire state_ready,event_valid,
    output wire [1:0] event_kind,
    output wire [6:0] event_note,
    output wire [8:0] event_velocity,
    input wire event_ready,
    output reg [KEYS-1:0] owned
);
    reg busy,press_phase;
    reg [INDEX_W-1:0] index;
    reg [KEYS-1:0] target;
    reg [KEYS*7-1:0] mapping,latched_notes;
    reg [8:0] vel;
    wire change=press_phase ? (target[index] && !owned[index]) : (!target[index] && owned[index]);
    wire [6:0] selected=press_phase ? mapping[index*7 +: 7] : latched_notes[index*7 +: 7];
    reg another;
    integer j;
    always @* begin
        another=0;
        for(j=0;j<KEYS;j=j+1)
            if(j!=index && owned[j] && latched_notes[j*7 +: 7]==selected) another=1;
    end
    assign state_ready=!rst && !flush && !busy;
    assign event_valid=!rst && !flush && busy && change && !another;
    assign event_kind=press_phase ? 2'd0 : 2'd1;
    assign event_note=selected;
    assign event_velocity=vel;
    always @(posedge clk) begin
        if(rst || flush) begin busy<=0;press_phase<=0;index<=0;target<=0;mapping<=0;latched_notes<=0;vel<=256;owned<=0;end
        else if(state_valid && state_ready) begin
            target<=key_state;mapping<=note_map;vel<=velocity==0 ? 9'd1 : velocity>256 ? 9'd256 : velocity;
            busy<=1;press_phase<=0;index<=0;
        end else if(busy && (!event_valid || event_ready)) begin
            if(change) begin
                owned[index]<=press_phase;
                if(press_phase) latched_notes[index*7 +: 7]<=selected;
            end
            if(index==KEYS-1) begin
                index<=0;
                if(press_phase) busy<=0;else press_phase<=1;
            end else index<=index+1'b1;
        end
    end
endmodule
