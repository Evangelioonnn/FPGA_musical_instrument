// Resource/timing probe only. It feeds the verified sine voice into the
// bypassable delay and uses the same five known NEO Dock audio pins.
module delay_top(input wire sys_clk,output wire hp_bck,hp_ws,hp_din,pa_en);
    reg [4:0] startup=0;wire rst=!startup[4];
    always @(posedge sys_clk)if(rst)startup<=startup+1'b1;
    wire tx_ce;wire signed [15:0] voice_sample,delayed_sample;wire voice_valid,delay_valid;
    wire [31:0] step;wire [15:0] env;wire [2:0] state;
    reg started;
    always @(posedge sys_clk)if(rst)started<=0;else if(!started)started<=1;
    note_table table1(7'd60,step);
    synth_voice voice(sys_clk,rst,tx_ce,!started && !rst,1'b0,1'b0,step,voice_sample,voice_valid,env,state);
    feedback_delay delay1(.clk(sys_clk),.rst(rst),.in_valid(voice_valid),.bypass(1'b0),
        .in_sample(voice_sample),.in_ready(),.out_valid(delay_valid),
        .out_sample(delayed_sample),.clipped());
    pt8211_tx tx(sys_clk,rst,delayed_sample,delayed_sample,tx_ce,hp_bck,hp_ws,hp_din);
    assign pa_en=1'b0;
endmodule
