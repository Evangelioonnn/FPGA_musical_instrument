// C4 -> C4/E4 -> C4/E4/G4 -> C4/E4/G4/C5 -> release E4 -> release all.
module poly_demo_events #(parameter integer SLOT_SAMPLES=48077)(
    input wire clk,rst,sample_ce,
    output reg event_valid=0,event_on=0,
    output reg [6:0] event_note=0
);
    reg [15:0] sample_count=0;
    reg [2:0] slot=0;
    always @(posedge clk) begin
        if(rst) begin sample_count<=0; slot<=0; event_valid<=0; event_on<=0; event_note<=0; end
        else begin
            event_valid<=0;
            if(sample_ce) begin
                if(sample_count==0) begin
                    case(slot)
                        1: begin event_valid<=1; event_on<=1; event_note<=60; end
                        2: begin event_valid<=1; event_on<=1; event_note<=64; end
                        3: begin event_valid<=1; event_on<=1; event_note<=67; end
                        4: begin event_valid<=1; event_on<=1; event_note<=72; end
                        5: begin event_valid<=1; event_on<=0; event_note<=64; end
                        6: begin event_valid<=1; event_on<=0; event_note<=60; end
                        default: begin end
                    endcase
                end else if(slot==6 && sample_count==64) begin
                    event_valid<=1; event_on<=0; event_note<=67;
                end else if(slot==6 && sample_count==128) begin
                    event_valid<=1; event_on<=0; event_note<=72;
                end
                if(sample_count==SLOT_SAMPLES-1) begin sample_count<=0; slot<=slot+3'd1; end
                else sample_count<=sample_count+1'b1;
            end
        end
    end
endmodule
