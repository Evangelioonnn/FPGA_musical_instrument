module piano_poly_top #(parameter N=16,parameter OUTPUT_SHIFT=1,
    parameter ROW_CYCLES=2500,parameter DEBOUNCE_FRAMES=8,
    parameter BUTTON_CYCLES=150000,parameter LONG_CYCLES=50000000,
    parameter EC11_CYCLES=2500,parameter EC11_SAMPLES=2)(
    input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led
);
    reg [5:0] startup=0;
    wire rst=!startup[5];
    always @(posedge sys_clk) if(rst) startup<=startup+1'b1;
    wire [3:0] row_low;
    genvar g;generate for(g=0;g<4;g=g+1) begin: rows
        assign matrix_row_n[g]=row_low[g]?1'b0:1'bz;
    end endgenerate
    wire [15:0] keys;
    wire changed,frame,ghost,all_released;
    matrix_scanner #(.ROW_CYCLES(ROW_CYCLES),.DEBOUNCE_FRAMES(DEBOUNCE_FRAMES)) scanner(
        sys_clk,rst,matrix_col_n,row_low,keys,changed,frame,ghost,all_released);
    wire step_valid;
    wire signed [1:0] step;
    ec11_input #(.SAMPLE_CYCLES(EC11_CYCLES),.AB_SAMPLES(EC11_SAMPLES)) encoder(
        sys_clk,rst,enc_a,enc_b,1'b1,step_valid,step,,,);
    wire sample_ce,bank_valid,final_valid;
    wire signed [15:0] bank_sample,final_sample;
    wire sustain,sostenuto,panic,fault;
    wire [1:0] mode;
    wire [6:0] left_base,right_base;
    wire [4:0] volume_index;
    wire [2:0] release_index;
    wire [16:0] volume_target,gain;
    wire [15:0] release_step;
    poly_controls #(.BUTTON_CYCLES(BUTTON_CYCLES),.LONG_CYCLES(LONG_CYCLES)) controls(
        sys_clk,rst,button_n,step_valid,step,fault,sustain,sostenuto,panic,
        mode,left_base,right_base,volume_index,release_index,volume_target,release_step);
    wire event_valid,event_ready,event_off,bank_ready;
    wire [31:0] event_token;
    wire [6:0] event_note;
    wire blocked,rejected,deadline,clip;
    wire [N-1:0] occupied;
    reg muting,clear_bank;
    gallery_keys #(.KEYS(16),.SPLIT(8),.DIATONIC(1)) key_events(
        sys_clk,rst,panic||muting,changed,ghost,all_released,keys,3'd0,left_base,right_base,
        event_valid,event_ready,event_off,event_token,event_note,,fault,blocked,,,);
    assign event_ready=bank_ready && !muting && !panic && !fault;
    piano_poly_core #(.N(N),.OUTPUT_SHIFT(OUTPUT_SHIFT)) bank(
        sys_clk,rst||clear_bank,sample_ce,event_valid&&!muting&&!panic&&!fault,bank_ready,
        event_off,event_token,event_note,16'd68,16'd6,16'd32768,release_step,
        sustain,sostenuto,,rejected,,,occupied,,,bank_valid,bank_sample,,clip,deadline);
    knob_gain master_gain(sys_clk,rst,bank_valid,bank_sample,
        muting?17'd0:volume_target,final_valid,final_sample,gain);
    always @(posedge sys_clk) begin
        if(rst) begin muting<=0;clear_bank<=0;end
        else begin
            clear_bank<=0;
            if(panic||fault) muting<=1;
            else if(muting && gain==0 && bank_valid) begin clear_bank<=1;muting<=0;end
        end
    end
    pt8211_tx transport(sys_clk,rst,final_sample,final_sample,sample_ce,hp_bck,hp_ws,hp_din);
    gallery_led indicator(sys_clk,rst,3'd0,sustain,{1'b0,mode},
        blocked||muting||deadline,rejected,status_led);
    assign pa_en=1'b0;
endmodule
