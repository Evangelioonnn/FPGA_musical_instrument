// Unified functional test: the original sine + ADSR sound, with one control changed at a time.
module baseline_demo #(parameter integer SLOT=48077)(
    input wire clk, rst, ce,
    output reg event_valid,
    output reg [1:0] event_kind,
    output reg [6:0] event_note,event_value,
    output reg [8:0] event_velocity,
    output reg cfg_valid,
    output reg [3:0] cfg_addr,
    output reg [31:0] cfg_data
);
    reg [4:0] slot;
    reg [31:0] position;
    localparam integer GATE = SLOT*13/20;
    localparam integer PEDAL_UP = SLOT*17/20;
    localparam integer OFF = SLOT*16/20;

    task write_cfg;
        input [3:0] addr; input [31:0] data;
        begin cfg_valid<=1; cfg_addr<=addr; cfg_data<=data; end
    endtask
    task emit_note;
        input [1:0] kind; input [6:0] id,target; input [8:0] velocity;
        begin event_valid<=1; event_kind<=kind; event_note<=id; event_value<=target; event_velocity<=velocity; end
    endtask

    always @(posedge clk) begin
        if(rst) begin
            slot<=0; position<=0; event_valid<=0; event_kind<=0;
            event_note<=0; event_value<=0; event_velocity<=0;
            cfg_valid<=0; cfg_addr<=0; cfg_data<=0;
        end else begin
            event_valid<=0; cfg_valid<=0;
            if(ce) begin
                if(position==SLOT-1) begin
                    position<=0;
                    slot<=slot==15 ? 5'd0 : slot+5'd1;
                end else position<=position+1'b1;
                case(slot)
                    // Establish the same baseline for every run.
                    0: begin
                        if(position==0)  write_cfg(1,0);       // pure sine
                        if(position==2)  write_cfg(3,0);       // no glide
                        if(position==4)  write_cfg(2,65536);   // no bend
                        if(position==6)  write_cfg(0,65536);   // full level
                        if(position==8)  write_cfg(4,0);       // sustain off
                        if(position==10) write_cfg(5,0);       // sostenuto off
                        if(position==12) write_cfg(7,68);      // attack
                        if(position==14) write_cfg(8,6);       // decay
                        if(position==16) write_cfg(9,32768);   // sustain level
                        if(position==18) write_cfg(10,3);       // release
                    end
                    // One baseline note, with the original envelope.
                    1: begin
                        if(position==0) emit_note(0,60,0,256);
                        if(position==GATE) emit_note(1,60,0,0);
                    end
                    2: ; // silence between demonstrations
                    // Volume only: the sound remains the baseline sine.
                    3: begin
                        if(position==0) emit_note(0,69,0,256);
                        if(position==SLOT*6/20) write_cfg(0,16384);
                        if(position==SLOT*10/20) write_cfg(0,0);
                        if(position==SLOT*14/20) write_cfg(0,65536);
                        if(position==SLOT*18/20) emit_note(1,69,0,0);
                    end
                    4: ; // Volume demo releases at 3.9 s; allow its full tail.
                    // Velocity only: equal note, envelope and timbre.
                    5,6,7: begin
                        if(position==0) emit_note(0,69,0,slot==5 ? 9'd64 : slot==6 ? 9'd128 : 9'd256);
                        if(position==GATE) emit_note(1,69,0,0);
                    end
                    // Ordinary sustain: three notes release only after the pedal rises.
                    8: begin
                        if(position==0) write_cfg(4,1);
                        if(position==4) emit_note(0,60,0,256);
                        if(position==6) emit_note(0,64,0,256);
                        if(position==8) emit_note(0,67,0,256);
                        if(position==GATE) begin
                            emit_note(1,60,0,0);
                            // The following events use later positions so each is accepted.
                        end
                        if(position==GATE+2) emit_note(1,64,0,0);
                        if(position==GATE+4) emit_note(1,67,0,0);
                        if(position==PEDAL_UP) write_cfg(4,0);
                    end
                    9: ;
                    // Selective sustain: the first chord is captured; A4 is deliberately new.
                    10: begin
                        if(position==0) emit_note(0,60,0,256);
                        if(position==2) emit_note(0,64,0,256);
                        if(position==4) emit_note(0,67,0,256);
                        if(position==SLOT/10) write_cfg(5,1);
                        if(position==SLOT/4) emit_note(1,60,0,0);
                        if(position==SLOT/4+2) emit_note(1,64,0,0);
                        if(position==SLOT/4+4) emit_note(1,67,0,0);
                        if(position==SLOT*8/20) emit_note(0,69,0,256);
                        if(position==SLOT*14/20) emit_note(1,69,0,0);
                        if(position==PEDAL_UP) write_cfg(5,0);
                    end
                    11: ;
                    // Four voices are introduced one at a time, still using the baseline sound.
                    12: begin
                        if(position==0) emit_note(0,60,0,256);
                        if(position==SLOT*18/100) emit_note(0,64,0,256);
                        if(position==SLOT*36/100) emit_note(0,67,0,256);
                        if(position==SLOT*54/100) emit_note(0,72,0,256);
                        if(position==OFF) begin
                            emit_note(1,60,0,0);
                        end
                        if(position==OFF+2) emit_note(1,64,0,0);
                        if(position==OFF+4) emit_note(1,67,0,0);
                        if(position==OFF+6) emit_note(1,72,0,0);
                    end
                    // Eight distinct pitches of a spread C-major chord.
                    // A full C-D-E-F-G-A-B-C cluster obscures the reference tone.
                    13: ; // Let the previous chord finish its release before all eight voices.
                    14: begin
                        if(position==0)  emit_note(0,48,0,256);
                        if(position==2)  emit_note(0,55,0,256);
                        if(position==4)  emit_note(0,60,0,256);
                        if(position==6)  emit_note(0,64,0,256);
                        if(position==8)  emit_note(0,67,0,256);
                        if(position==10) emit_note(0,72,0,256);
                        if(position==12) emit_note(0,76,0,256);
                        if(position==14) emit_note(0,79,0,256);
                        if(position==OFF)    emit_note(1,48,0,0);
                        if(position==OFF+2)  emit_note(1,55,0,0);
                        if(position==OFF+4)  emit_note(1,60,0,0);
                        if(position==OFF+6)  emit_note(1,64,0,0);
                        if(position==OFF+8)  emit_note(1,67,0,0);
                        if(position==OFF+10) emit_note(1,72,0,0);
                        if(position==OFF+12) emit_note(1,76,0,0);
                        if(position==OFF+14) emit_note(1,79,0,0);
                    end
                    15: ;
                endcase
            end
        end
    end
endmodule
