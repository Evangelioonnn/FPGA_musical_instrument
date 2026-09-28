`timescale 1ns/1ps
module audio_render_tb #(parameter FAST=1,SHORT=0,ROM_FAST=0,SCENE=-1);
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,changed=0;
    reg [15:0] keys=0;
    reg hv=0;wire hr;reg [4:0] ha=0;reg [31:0] hd=0;
    wire valid,deadline,clip,ack,ack_source,ack_accepted,ack_applied;
    wire signed [15:0] left,right;
    audio_core dut(.clk(clk),.rst(rst),.sample_ce(ce),.keys(keys),.changed(changed),
        .ghost(1'b0),.all_released(keys==0),.button_n(3'b111),.step_valid(1'b0),.step(2'sd0),
        .host_valid(hv),.host_ready(hr),.host_addr(ha),.host_value(hd),
        .ack_valid(ack),.ack_source(ack_source),.ack_accepted(ack_accepted),.ack_applied(ack_applied),
        .adc_valid(1'b0),.adc_ch0(12'd0),.adc_ch1(12'd0),.adc_ch2(12'd0),.adc_ch3(12'd0),.adc_ch4(12'd0),
        .final_valid(valid),.final_left(left),.final_right(right),.deadline_missed(deadline),.clip_seen(clip));
    integer fd,frames=0,outputs=0,k,n,ticks,acks=0;
    reg [1023:0] filename;
    always @(posedge clk) begin
        #1;
        if(!rst) begin
            if(valid) outputs=outputs+1;
            if(ack) begin
                if(!ack_source || !ack_accepted || !ack_applied) $fatal;
                acks=acks+1;
            end
            if(deadline||clip||(^left)===1'bx||(^right)===1'bx) $fatal;
        end
    end
    task render_frames;
        input integer count;
        begin
            ticks=FAST ? 256 : 1040;
            for(n=0;n<count;n=n+1) begin
                outputs=0;ce=1;@(negedge clk);ce=0;
                repeat(ticks-1) @(negedge clk);
                if(outputs!=1 && !(outputs==0 && dut.reset_gap_pending)) $fatal;
                $fwrite(fd,"%0d %0d\n",left,right);frames=frames+1;
            end
        end
    endtask
    task configure;
        input [4:0] address;input [31:0] value;
        integer previous_acks;
        begin
            previous_acks=acks;
            @(negedge clk);hv=1;ha=address;hd=value;
            // Ready depends on valid through arbitration. Let the request
            // settle before checking it, then capture on the next posedge.
            #1;
            if(!hr) $fatal(1,"preview configuration unexpectedly backpressured");
            @(negedge clk);hv=0;render_frames(2);
            if(acks!=previous_acks+1) $fatal(1,"preview request was lost or duplicated");
        end
    endtask
    task set_keys;
        input [15:0] value;
        begin
            keys=value;changed=1;@(negedge clk);changed=0;
            repeat(2000) @(negedge clk);
        end
    endtask
    initial begin
        if(!SHORT && (SCENE < -1 || SCENE > 5)) $fatal(1,"invalid preview scene");
        if(SCENE>=0) begin
            if(ROM_FAST) $sformat(filename,"audio_preview_%0d_%0d_fastrom_scene%0d.txt",FAST,SHORT,SCENE);
            else $sformat(filename,"audio_preview_%0d_%0d_scene%0d.txt",FAST,SHORT,SCENE);
        end else begin
            if(ROM_FAST) $sformat(filename,"audio_preview_%0d_%0d_fastrom.txt",FAST,SHORT);
            else $sformat(filename,"audio_preview_%0d_%0d.txt",FAST,SHORT);
        end
        fd=$fopen(filename,"w");repeat(5) @(negedge clk);rst=0;
        render_frames(550);
        if(SHORT) begin
            set_keys(1);render_frames(300);set_keys(0);render_frames(100);
        end else begin
            for(k=0;k<5;k=k+1) begin
                if(SCENE<0 || SCENE==k) begin
                    $display("AUDIO_RENDER_PROGRESS preset slot=%0d frames=%0d",k,frames);
                    case(k) 0:configure(0,0);1:configure(0,2);2:configure(0,3);
                        3:configure(0,4);4:configure(0,5);endcase
                    set_keys(16'h15);render_frames(16000);
                    set_keys(0);render_frames(8000);
                    configure(30,1);render_frames(100);
                    if(dut.occupied!=0) $fatal;
                end
            end
            if(SCENE<0 || SCENE==5) begin
                $display("AUDIO_RENDER_PROGRESS lead effects frames=%0d",frames);
                configure(0,4);configure(18,1);configure(19,64);configure(16,24);
                set_keys(1);render_frames(16000);set_keys(0);render_frames(8000);
                configure(18,0);configure(16,0);render_frames(150);
            end
        end
        $fclose(fd);$display("AUDIO_RENDER_TB_PASS FAST=%0d SHORT=%0d SCENE=%0d %0d actual RTL stereo frames",FAST,SHORT,SCENE,frames);$finish;
    end
    initial begin #2000000000;$fatal(1,"audio preview timed out");end
endmodule
