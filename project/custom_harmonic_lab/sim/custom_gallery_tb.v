`timescale 1ns/1ps
module custom_gallery_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,event_valid=0,event_off=0,pedal=0,sostenuto=0;
    reg [31:0] event_token=0;
    reg [6:0] event_note=60;
    reg [2:0] event_timbre=0,glide=0;
    reg [1:0] attack=2;
    reg [16:0] bend_factor=65536;
    reg [8:0] coeff0=256,coeff1=64,coeff2=32,coeff3=16;
    wire ready,accepted,rejected,valid,clip,deadline;
    wire [7:0] occupied,held;
    wire [31:0] rejected_count,unmatched;
    wire signed [15:0] sample;
    custom_gallery_bank #(.N(8)) dut(clk,rst,ce,event_valid,ready,event_off,event_token,
        event_note,event_timbre,pedal,sostenuto,16'd24,glide,attack,bend_factor,
        coeff0,coeff1,coeff2,coeff3,accepted,rejected,rejected_count,unmatched,
        occupied,held,valid,sample,clip,deadline);
    integer output_count=0;
    integer signed captured[0:63];
    integer signed reference_capture[0:63];
    integer signed max_abs=0,i;
    always @(posedge clk) if(!rst) begin
        #1;
        if(valid) begin
            if(output_count<64) captured[output_count]=sample;
            output_count=output_count+1;
            if(clip || deadline || (^sample)===1'bx)
                $fatal(1,"bad custom gallery output frame");
            if(occupied==8'hff) begin
                if(sample>23560 || sample< -23560)
                    $fatal(1,"eight-voice output exceeded normalized PCM bound: %0d",sample);
                if(sample>max_abs) max_abs=sample;
                if(-sample>max_abs) max_abs=-sample;
            end
        end
    end
    task reset_bank;
        begin rst=1;repeat(8) @(negedge clk);rst=0;output_count=0; end
    endtask
    task command;
        input off;
        input [31:0] id;
        input [6:0] pitch;
        input [2:0] preset;
        begin
            while(!ready) @(negedge clk);
            event_valid=1;event_off=off;event_token=id;event_note=pitch;event_timbre=preset;
            @(negedge clk);event_valid=0;repeat(8) @(negedge clk);
        end
    endtask
    task audio_frame;
        begin
            @(negedge clk);ce=1;@(negedge clk);ce=0;
            repeat(1040) @(negedge clk);
        end
    endtask
    initial begin
        reset_bank();
        command(0,100,60,0);
        for(i=0;i<64;i=i+1) audio_frame();
        if(output_count!=64) $fatal(1,"reference bank did not complete 64 frames");
        for(i=0;i<64;i=i+1) reference_capture[i]=captured[i];
        reset_bank();
        command(0,100,60,5);
        for(i=0;i<64;i=i+1) audio_frame();
        if(output_count!=64) $fatal(1,"custom bank did not complete 64 frames");
        for(i=0;i<64;i=i+1)
            if(captured[i]!==reference_capture[i])
                $fatal(1,"custom default differs at frame %0d: %0d vs %0d",
                    i,captured[i],reference_capture[i]);

        reset_bank();coeff0=92;coeff1=92;coeff2=92;coeff3=92;
        max_abs=0;
        for(i=0;i<8;i=i+1) command(0,200+i,60,5);
        if(occupied!=8'hff || rejected_count!=0) $fatal(1,"eight custom voices not accepted");
        for(i=0;i<512;i=i+1) audio_frame();
        if(output_count!=512) $fatal(1,"eight-voice output frame count mismatch");
        if(max_abs<1000) $fatal(1,"eight-voice peak test did not reach an audible level: %0d",max_abs);
        $display("CUSTOM_GALLERY_TB_PASS default exact, eight voices, mixer peak=%0d",max_abs);
        $finish;
    end
endmodule
