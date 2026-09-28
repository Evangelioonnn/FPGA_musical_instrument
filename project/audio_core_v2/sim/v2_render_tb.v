`timescale 1ns/1ps
module v2_render_tb #(parameter P=12,SCENE=0);
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,hv=0,changed=0;
    reg [24:0] keys=0;
    reg [4:0] ha=0;reg [31:0] hd=0;
    wire hr,ack,accepted,valid,clip,deadline;
    wire signed [15:0] left,right;
    audio_v2_core #(.PLUCK_N(P),.KEYS(25),.SPLIT(12),.DIATONIC(0)) dut(
        .clk(clk),.rst(rst),.sample_ce(ce),.keys(keys),.changed(changed),
        .ghost(1'b0),.all_released(keys==0),.button_n(3'b111),.step_valid(1'b0),.step(2'sd0),
        .host_valid(hv),.host_ready(hr),.host_addr(ha),.host_value(hd),
        .adc_valid(1'b0),.adc_ch0(12'd0),.adc_ch1(12'd0),.adc_ch2(12'd0),.adc_ch3(12'd0),.adc_ch4(12'd0),
        .ack_valid(ack),.ack_accepted(accepted),.final_valid(valid),.final_left(left),.final_right(right),
        .deadline_missed(deadline),.clip_seen(clip));
    integer tick=0,frames=0,fd,k,outputs=0;
    reg capture=0;reg [1023:0] filename;
    always @(negedge clk) begin
        if(rst) begin tick=0;ce=0;end else begin ce=tick==1039;tick=(tick+1)%1040;end
    end
    always @(posedge clk) begin
        #1;
        if(!rst) begin
            if(deadline||clip||(^left)===1'bx||(^right)===1'bx) $fatal(1,"render fault");
            if(ce) begin if(frames>0 && outputs!=1) $fatal(1,"missing PCM in preview");outputs=0;end
            if(valid) begin
                frames=frames+1;outputs=outputs+1;
                if(capture) $fwrite(fd,"%0d %0d\n",left,right);
            end
        end
    end
    task wait_frames;input integer n;integer last;
        begin last=frames+n;while(frames<last) @(negedge clk);end
    endtask
    task configure;input [4:0] address;input [31:0] value;
        begin
            @(negedge clk);hv=1;ha=address;hd=value;#1;
            while(!hr) begin @(negedge clk);#1;end
            @(negedge clk);hv=0;while(!ack) @(negedge clk);if(!accepted) $fatal;
        end
    endtask
    task set_keys;input [24:0] value;
        begin @(negedge clk);keys=value;changed=1;@(negedge clk);changed=0;wait_frames(4);end
    endtask
    initial begin
        $sformat(filename,"v2_preview_p%0d_scene%0d.txt",P,SCENE);fd=$fopen(filename,"w");
        repeat(10) @(negedge clk);rst=0;wait_frames(550);
        // Explicit unity master, fixed per-timbre note gains retained. No WAV normalisation.
        configure(1,65536);wait_frames(550);
        if(SCENE<5) begin
            configure(0,SCENE==0 ? 0 : SCENE+1);capture=1;
            set_keys(25'h15);wait_frames(8000);set_keys(0);wait_frames(16000);
        end else if(SCENE==5) begin
            configure(5,1);capture=1;
            for(k=0;k<32;k=k+1) begin set_keys(1);wait_frames(128);set_keys(0);end
            if(dut.occupied!==32'hffffffff) $fatal(1,"preview did not retain32 voices");
            wait_frames(8000);configure(7,0);configure(5,0);wait_frames(1000);
        end else begin
            configure(0,4);configure(18,1);configure(19,64);configure(16,24);capture=1;
            set_keys(25'h15);wait_frames(16000);set_keys(0);wait_frames(8000);
        end
        capture=0;$fclose(fd);
        $display("V2_RENDER_TB_PASS P=%0d SCENE=%0d actual1040-clock PCM frames=%0d",P,SCENE,frames);$finish;
    end
    initial begin #1000000000;$fatal(1,"render timeout");end
endmodule
