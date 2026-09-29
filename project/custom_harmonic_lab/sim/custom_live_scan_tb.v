`timescale 1ns/1ps
module custom_live_scan_tb;
    localparam N=8;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,sample_ce=0,adc_valid=0;
    reg [11:0] adc_ch0=4095,adc_ch1=4095,adc_ch2=1024,adc_ch3=512,adc_ch4=256;
    reg [N*32-1:0] phases={N{32'h19283746}};
    reg [N*16-1:0] envelopes={N{16'hffff}};
    wire [15:0] volume_gain,volume_target;
    wire [8:0] coeff0,coeff1,coeff2,coeff3;
    wire [8:0] coeff0_target,coeff1_target,coeff2_target,coeff3_target;
    wire params_updated,params_busy,adc_overrun;
    wire signed [19:0] sample;
    wire [N-1:0] valid;
    wire deadline;
    reg sample_seen=0;
    reg signed [19:0] sample_captured=0;
    always @(posedge clk) if(!rst && valid[0]) begin
        sample_seen=1;
        sample_captured=sample;
    end
    custom_harmonic_params params(clk,rst,sample_ce,adc_valid,
        adc_ch0,adc_ch1,adc_ch2,adc_ch3,adc_ch4,
        volume_gain,coeff0,coeff1,coeff2,coeff3,volume_target,
        coeff0_target,coeff1_target,coeff2_target,coeff3_target,params_updated,
        params_busy,adc_overrun);
    custom_harmonic_tone #(.N(N)) tone(clk,rst,sample_ce,phases,envelopes,
        coeff0,coeff1,coeff2,coeff3,sample,valid,deadline);
    integer step_index,frame_index,previous_sample,delta,max_delta,valid_frames;
    task feed_adc;
        input [11:0] value;
        begin
            @(negedge clk);adc_ch3=value;adc_valid=1;
            @(negedge clk);adc_valid=0;
        end
    endtask
    task audio_frame;
        begin
            sample_seen=0;
            @(negedge clk);sample_ce=1;
            @(negedge clk);sample_ce=0;
            repeat(220) @(negedge clk);
            if(!sample_seen || deadline || (^sample_captured)===1'bx)
                $fatal(1,"sustained parameter-scan tone missed its voice sample");
            if(valid_frames!=0) begin
                delta=$signed(sample_captured)-previous_sample;
                if(delta<0) delta=-delta;
                if(delta>1024) $fatal(1,"coefficient scan made an abrupt sample step: %0d",delta);
                if(delta>max_delta) max_delta=delta;
            end
            previous_sample=$signed(sample_captured);
            valid_frames=valid_frames+1;
            repeat(840) @(negedge clk);
        end
    endtask
    initial begin
        valid_frames=0;max_delta=0;previous_sample=0;
        repeat(5) @(negedge clk);rst=0;
        for(step_index=0;step_index<=64;step_index=step_index+1) begin
            feed_adc((step_index*4095)/64);
            for(frame_index=0;frame_index<8;frame_index=frame_index+1) audio_frame();
        end
        for(step_index=64;step_index>=0;step_index=step_index-1) begin
            feed_adc((step_index*4095)/64);
            for(frame_index=0;frame_index<8;frame_index=frame_index+1) audio_frame();
        end
        if(valid_frames!=1040) $fatal(1,"expected 1040 live scan frames, got %0d",valid_frames);
        if(max_delta>1024) $fatal(1,"live scan delta bound failed");
        $display("CUSTOM_LIVE_SCAN_TB_PASS frames=%0d maximum_parameter_step=%0d",valid_frames,max_delta);
        $finish;
    end
endmodule
