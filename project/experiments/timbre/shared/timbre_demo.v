// Ten monophonic slots. This is an audition source, not a live input adapter.
module timbre_demo #(
    parameter SLOT_SAMPLES = 36058, // round(0.75 * 50MHz/1040)
    parameter GATE_SAMPLES = 25481 // round(0.53 * 50MHz/1040)
)(
    input wire clk, rst, sample_ce, cmd_ready,
    output reg cmd_valid,
    output reg [1:0] cmd_kind,
    output reg [6:0] note,
    output reg [8:0] velocity,
    output reg [31:0] seed
);
    reg [15:0] position;
    reg [3:0] slot;
    reg [6:0] next_note;
    reg [8:0] next_velocity;
    always @* begin
        next_note = 60;
        next_velocity = 205;
        case(slot)
            0: next_note=48;
            1: next_note=55;
            2: next_note=60;
            3: next_note=64;
            4: next_note=67;
            5: next_note=72;
            // The offline chord is deliberately a single C4 in this mono demo.
            6: next_velocity=154;
            7: next_velocity=64;
            8: next_velocity=128;
            9: next_velocity=230;
            default: next_note=60;
        endcase
    end
    always @(posedge clk) begin
        if(rst) begin
            position<=0; slot<=0;
            cmd_valid<=0; cmd_kind<=0; note<=60; velocity<=0; seed<=1;
        end else begin
            if(cmd_valid && cmd_ready) cmd_valid<=0;
            // Pause the score under backpressure, keeping every command field
            // stable even if a future receiver stalls for an entire slot.
            if(sample_ce && (!cmd_valid || cmd_ready)) begin
                if(position==SLOT_SAMPLES-1) begin
                    position<=0;
                    if(slot==9) slot<=0; else slot<=slot+1'b1;
                end else position<=position+1'b1;
                // At the documented 1040-clock cadence the voice always
                // accepts well before the next scheduled event (0.53s).
                if(position==0) begin
                    cmd_valid<=1; cmd_kind<=0;
                    note<=next_note; velocity<=next_velocity;
                    seed<=32'd2000+next_note+slot;
                end else if(position==GATE_SAMPLES) begin
                    cmd_valid<=1; cmd_kind<=1;
                end
            end
        end
    end
endmodule
