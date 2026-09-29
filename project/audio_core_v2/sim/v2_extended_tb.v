`timescale 1ns/1ps
module v2_extended_tb #(parameter P=16);
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,changed=0,hv=0;
    reg [24:0] keys=0;
    reg [4:0] ha=0;reg [31:0] hd=0;
    wire hr,ack,accepted,valid,sv,deadline,clip;
    wire [31:0] occupied,held,index;
    wire [127:0] cap;wire [2367:0] snap;wire [255:0] ext;wire [24:0] skeys;
    wire signed [15:0] left,right;
    audio_v2_core #(.PLUCK_N(P),.KEYS(25),.SPLIT(12),.DIATONIC(0)) dut(
        .clk(clk),.rst(rst),.sample_ce(ce),.keys(keys),.changed(changed),
        .ghost(1'b0),.all_released(keys==0),.button_n(3'b111),.step_valid(1'b0),.step(2'sd0),
        .host_valid(hv),.host_ready(hr),.host_addr(ha),.host_value(hd),
        .adc_valid(1'b0),.adc_ch0(12'd0),.adc_ch1(12'd0),.adc_ch2(12'd0),.adc_ch3(12'd0),.adc_ch4(12'd0),
        .ack_valid(ack),.ack_accepted(accepted),.final_valid(valid),.final_left(left),.final_right(right),
        .sample_index(index),.snapshot_valid(sv),.snapshot_data(snap),.capabilities(cap),
        .snapshot_extension(ext),.snapshot_keys(skeys),.occupied(occupied),.held(held),
        .deadline_missed(deadline),.clip_seen(clip));
    integer tick=0,frames=0,snapshots=0,cycles=0,i,j,worst_onset=0,start_cycle,limit;
    always @(negedge clk) begin
        if(rst) begin ce=0;tick=0;end
        else begin ce=tick==1039;tick=(tick+1)%1040;end
    end
    always @(posedge clk) begin
        #1;
        if(!rst) begin
            cycles=cycles+1;
            if(deadline||clip||dut.adc_overrun||dut.harmonic_overrun||dut.panel_overflow) $fatal(1,"extended fault");
            if(valid) begin frames=frames+1;if((^left)===1'bx || (^right)===1'bx) $fatal;end
            if(sv) begin
                snapshots=snapshots+1;
                if(ext[31:0]!==index || ext[197:190]!=2 || ext[183:178]!=32 ||
                   ext[189:184]!=P || skeys!==keys) $fatal(1,"incoherent V2 bundle");
            end
        end
    end
    task wait_frames;input integer n;integer stop;
        begin stop=frames+n;while(frames<stop) @(negedge clk);end
    endtask
    task configure;input [4:0] addr;input [31:0] value;
        begin
            @(negedge clk);hv=1;ha=addr;hd=value;#1;
            while(!hr) begin @(negedge clk);#1;end
            @(negedge clk);hv=0;while(!ack) @(negedge clk);if(!accepted) $fatal;
        end
    endtask
    task set_keys;input [24:0] value;
        begin @(negedge clk);keys=value;changed=1;@(negedge clk);changed=0;wait_frames(4);end
    endtask
    initial begin
        repeat(10) @(negedge clk);rst=0;wait_frames(550);
        if(cap[15:0]!=2 || cap[31:16]!=32 || cap[47:32]!=P || cap[63:48]!=25 ||
           cap[71:64]!=8'h3d || cap[79:72]!=2 || cap[111:96]!=2368) $fatal(1,"capability mismatch");
        configure(1,65536);configure(11,65535);configure(12,1);configure(13,65535);configure(14,65535);
        for(j=0;j<8;j=j+1) begin
            while(tick!=j*129) @(negedge clk);
            start_cycle=cycles;keys=1;changed=1;@(negedge clk);changed=0;
            limit=cycles+10000;
            while(!(valid && (left!=0 || right!=0))) begin
                @(negedge clk);if(cycles>limit) $fatal(1,"onset timed out");
            end
            if(cycles-start_cycle>worst_onset) worst_onset=cycles-start_cycle;
            set_keys(0);wait_frames(20);
            if(occupied!=0) $fatal(1,"extreme release did not free piano");
        end
        configure(31,1);configure(5,1);
        for(i=0;i<32;i=i+1) begin set_keys(1);set_keys(0);end
        if(occupied!==32'hffffffff || held!=0) $fatal(1,"32 repeated strikes not retained");
        set_keys(1);
        if(dut.rejected_count!=1 || occupied!==32'hffffffff) $fatal(1,"full limit altered old voices");
        wait_frames(1100);
        if(skeys!=1 || ext[47:32]!=68 || ext[63:48]!=6 || ext[79:64]!=32768 || ext[95:80]!=3 ||
           ext[107:96]!=4095 || ext[119:108]!=1024 || ext[131:120]!=512 || ext[143:132]!=256)
            $fatal(1,"target or physical key extension missing");
        for(i=0;i<32;i=i+1)
            if(!snap[362+i*64] || snap[363+i*64] || snap[359+i*64+:3]!=0 || snap[320+i*64+:32]==0)
                $fatal(1,"32 voice snapshot decode");
        set_keys(0);configure(7,0);configure(5,0);wait_frames(800);
        if(occupied!=0) $fatal(1,"full sustained bank did not release");
        $display("V2_EXTENDED_TB_PASS 32 retained strikes, rejection, coherent V2 state, 8 onset phases worst=%0d clocks (%0f us)",worst_onset,worst_onset/50.0);
        $finish;
    end
    initial begin #200000000;$fatal(1,"extended timeout");end
endmodule
