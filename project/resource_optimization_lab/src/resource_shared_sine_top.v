module resource_shared_sine_top(
    input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led
);
    reg [5:0] startup=0; wire rst=!startup[5];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    wire [3:0] row_low;
    genvar row;
    generate for(row=0;row<4;row=row+1) begin: row_drivers
        assign matrix_row_n[row]=row_low[row]?1'b0:1'bz;
    end endgenerate
    wire [15:0] keys; wire changed,frame,ghost,all_released;
    matrix_scanner scanner(sys_clk,rst,matrix_col_n,row_low,keys,changed,frame,ghost,all_released);
    wire step_valid; wire signed [1:0] step;
    ec11_input encoder(sys_clk,rst,enc_a,enc_b,1'b1,step_valid,step,/*unused*/ , , );
    wire sample_ce,final_valid; wire signed [15:0] final_sample;
    wire [1:0] timbre; wire sustain,release_mode,blocked,rejected,fault,deadline; reg muting;
    wire [4:0] volume_index; wire [2:0] reference_release_index,fm_release_index; wire [7:0] occupied;
    // This candidate is intentionally default-sine only; nonzero timbre
    // requests are rejected and remain visible through the status LED.
    wire bank_ready,bank_valid,accepted,clip; wire signed [15:0] bank_sample; wire [7:0] held;
    wire panic,overflow_seen,token_exhausted; wire [31:0] fault_count,rejected_count,unmatched_off_count;
    wire [16:0] volume_target,gain; wire [15:0] reference_release;
    playable_controls controls(sys_clk,rst,button_n,step_valid,step,fault,timbre,sustain,release_mode,panic,
        volume_index,reference_release_index,fm_release_index,volume_target,reference_release);
    wire event_valid,event_off; wire [31:0] event_token; wire [6:0] event_note; wire [1:0] event_timbre;
    playable_keys keys_adapter(sys_clk,rst,panic||muting,changed,ghost,all_released,keys,timbre,event_valid,
        bank_ready,event_off,event_token,event_note,event_timbre,fault,blocked,overflow_seen,token_exhausted,fault_count);
    resource_shared_sine_bank bank(sys_clk,rst,sample_ce,event_valid&&!muting&&!panic&&!fault,bank_ready,
        event_off,event_token,event_note,event_timbre,sustain,reference_release,fm_release_index,accepted,
        rejected,rejected_count,unmatched_off_count,occupied,held,bank_valid,bank_sample,clip,deadline);
    knob_gain volume(sys_clk,rst,bank_valid,bank_sample,muting?17'd0:volume_target,final_valid,final_sample,gain);
    always @(posedge sys_clk) begin
        if(rst) muting<=0;
        else if(panic||fault) muting<=1;
        else if(muting && gain==0 && bank_valid) muting<=0;
    end
    pt8211_tx tx(sys_clk,rst,final_sample,final_sample,sample_ce,hp_bck,hp_ws,hp_din);
    playable_led indicator(sys_clk,rst,timbre,sustain,release_mode,blocked||muting||deadline,rejected,status_led);
    assign pa_en=1'b0;
endmodule
