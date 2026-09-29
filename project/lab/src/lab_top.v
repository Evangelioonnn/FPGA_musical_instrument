// Ten-second repeating diagnostic: 1s silence, 6s held original tone, release, silence.
// Keep original waveform/envelope/electrical output and conservative digital level.
module lab_source #(parameter NOTE=60,SILENT=0,SLOT=48077)(
    input wire clk,rst,ce,output wire signed [15:0] sample,output wire valid
);
    reg [31:0] position;
    reg on_event,off_event;
    wire [31:0] phase_step;
    localparam [6:0] NOTE_CODE=NOTE;
    wire [15:0] envelope;wire [2:0] state;
    note_table table1(NOTE_CODE,phase_step);
    synth_voice voice(clk,rst,ce,on_event,off_event,1'b0,phase_step,sample,valid,envelope,state);
    always @(posedge clk) begin
        if(rst)begin position<=0;on_event<=0;off_event<=0;end
        else begin
            on_event<=0;off_event<=0;
            if(ce)begin
                position<=position==10*SLOT-1 ? 0 : position+1'b1;
                on_event<=!SILENT && position==SLOT;
                off_event<=!SILENT && position==7*SLOT;
            end
        end
    end
endmodule
module lab_top #(parameter NOTE=60,SILENT=0,SLOT=48077)(
    input wire sys_clk,output wire hp_bck,hp_ws,hp_din,pa_en
);
    reg [4:0] startup=0;
    wire rst=!startup[4];
    always @(posedge sys_clk) if(rst)startup<=startup+1'b1;
    wire ce,valid;wire signed [15:0] sample;
    assign pa_en=0;
    lab_source #(.NOTE(NOTE),.SILENT(SILENT),.SLOT(SLOT)) source(sys_clk,rst,ce,sample,valid);
    pt8211_tx tx(sys_clk,rst,sample,sample,ce,hp_bck,hp_ws,hp_din);
endmodule
module lab_a4_top(input wire sys_clk,output wire hp_bck,hp_ws,hp_din,pa_en);
    lab_top #(.NOTE(69)) dut(sys_clk,hp_bck,hp_ws,hp_din,pa_en);
endmodule
module lab_silent_top(input wire sys_clk,output wire hp_bck,hp_ws,hp_din,pa_en);
    lab_top #(.SILENT(1)) dut(sys_clk,hp_bck,hp_ws,hp_din,pa_en);
endmodule
