module expression_top #(parameter SLOT=48077)(
    input wire sys_clk,
    output wire hp_bck,hp_ws,hp_din,pa_en
);
    reg [4:0] startup=0;
    wire rst=!startup[4];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    wire ce,event_valid,event_ready,cfg_valid,cfg_ready,cfg_ack,cfg_accepted;
    wire [1:0] kind;
    wire [6:0] note,value;
    wire [8:0] velocity;
    wire [3:0] addr;
    wire [31:0] data,applied;
    wire signed [15:0] sample;
    wire valid,clipped;
    assign pa_en=0;
    expression_demo #(.SLOT(SLOT)) demo(sys_clk,rst,ce,event_valid,kind,note,value,velocity,cfg_valid,addr,data);
    expression_core core(.clk(sys_clk),.rst(rst),.sample_ce(ce),.event_valid(event_valid),
        .event_kind(kind),.event_note(note),.event_value(value),.event_velocity(velocity),.event_ready(event_ready),
        .cfg_valid(cfg_valid),.cfg_addr(addr),.cfg_data(data),.cfg_ready(cfg_ready),.cfg_ack(cfg_ack),
        .cfg_accepted(cfg_accepted),.cfg_applied(applied),.sample(sample),.sample_valid(valid),.clipped(clipped),
        .occupied(),.held(),.gated(),.sost_latched(),.notes(),.pitches(),.voice_samples(),.envelopes(),.steps(),
        .stolen(),.ignored(),.gain(),.weight2(),.weight3(),.meter_valid(),.meter_peak(),.meter_sample(),.meter_clip());
    pt8211_tx tx(sys_clk,rst,sample,sample,ce,hp_bck,hp_ws,hp_din);
endmodule
