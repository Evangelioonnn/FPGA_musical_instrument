// Operator-level resource baselines: eight independent harmonic or pluck
// voices on the same 50 MHz/PT8211 shell. These are not product top levels.
module resource_timbre_shell #(parameter PLUCK=0)(
    input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led
);
    reg [5:0] startup=0;
    wire rst=!startup[5];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    assign matrix_row_n=4'bzzzz;
    wire frame_ce;
    wire signed [15:0] sample_left;
    wire signed [15:0] sample_right;
    pt8211_tx tx(sys_clk,rst,sample_left,sample_right,frame_ce,hp_bck,hp_ws,hp_din);
    reg start_cmd;
    always @(posedge sys_clk) begin
        if(rst) start_cmd<=0;
        else if(startup==6'd32) start_cmd<=1;
        else start_cmd<=0;
    end
    wire signed [15:0] samples[0:7];
    wire [7:0] valids;
    wire [7:0] readies;
    wire [7:0] actives;
    wire [31:0] steps[0:7];
    genvar g;
    generate for(g=0;g<8;g=g+1) begin: voices
        wire [6:0] voice_note=7'd60+g;
        note_table note_map(voice_note,steps[g]);
        if(!PLUCK) begin: harmonic_voice
            wire [2:0] env_state;
            clean_voice #(.MODE(1)) voice(sys_clk,rst,frame_ce,start_cmd,1'b0,steps[g],16'd3,
                samples[g],valids[g],env_state);
            assign readies[g]=1'b1;
            assign actives[g]=|env_state;
        end else begin: pluck_voice_gen
            wire rejected;
            pluck_voice #(.LOGIC_SCALE(1)) voice(sys_clk,rst,frame_ce,start_cmd,2'd0,
                voice_note,9'd256,32'h12345678+g,readies[g],rejected,actives[g],
                samples[g],valids[g]);
        end
    end endgenerate
    reg signed [31:0] sum;
    integer i;
    always @* begin
        sum=0;
        for(i=0;i<8;i=i+1) sum=sum+{{16{samples[i][15]}},samples[i]};
    end
    assign sample_left=(sum>32767)?16'sh7fff:(sum< -32768)?-16'sh8000:sum[15:0];
    assign sample_right=sample_left;
    assign pa_en=1'b0;
    assign status_led=PLUCK ? actives[0] : valids[0];
endmodule

module resource_harmonic8_top(input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led);
    resource_timbre_shell #(.PLUCK(0)) u(sys_clk,enc_a,enc_b,button_n,matrix_col_n,
        matrix_row_n,hp_bck,hp_ws,hp_din,pa_en,status_led);
endmodule
module resource_pluck8_top(input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led);
    resource_timbre_shell #(.PLUCK(1)) u(sys_clk,enc_a,enc_b,button_n,matrix_col_n,
        matrix_row_n,hp_bck,hp_ws,hp_din,pa_en,status_led);
endmodule
