module polyphony_top #(parameter integer SLOT_SAMPLES=48077)(
    input wire sys_clk,
    output wire hp_bck,hp_ws,hp_din,pa_en
);
    reg [4:0] startup=0;
    wire rst=!startup[4];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    wire ce,ev_valid,ev_on,ready,valid,clipped,stolen,ignored;
    wire [6:0] note;
    wire signed [15:0] sample;
    wire [3:0] occupied,held;
    wire [27:0] notes;
    wire [63:0] voice_samples,envelopes;
    wire [11:0] states;
    assign pa_en=0;
    poly_demo_events #(.SLOT_SAMPLES(SLOT_SAMPLES)) demo(sys_clk,rst,ce,ev_valid,ev_on,note);
    poly_synth4 core(sys_clk,rst,ce,ev_valid,ev_on,note,1'b0,ready,sample,valid,clipped,
        occupied,held,notes,voice_samples,envelopes,states,stolen,ignored);
    pt8211_tx tx(sys_clk,rst,sample,sample,ce,hp_bck,hp_ws,hp_din);
endmodule
