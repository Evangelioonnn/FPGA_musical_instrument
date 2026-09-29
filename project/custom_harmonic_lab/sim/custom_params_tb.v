`timescale 1ns/1ps
module custom_params_tb;
    reg clk=0; always #10 clk=~clk;
    reg rst=1, sample_ce=0, adc_valid=0;
    reg [11:0] adc_ch0=0,adc_ch1=0,adc_ch2=0,adc_ch3=0,adc_ch4=0;
    wire [15:0] volume_gain,volume_target;
    wire [8:0] coeff0,coeff1,coeff2,coeff3;
    wire [8:0] coeff0_target,coeff1_target,coeff2_target,coeff3_target;
    wire params_updated,params_busy,adc_overrun;
    custom_harmonic_params dut(clk,rst,sample_ce,adc_valid,
        adc_ch0,adc_ch1,adc_ch2,adc_ch3,adc_ch4,
        volume_gain,coeff0,coeff1,coeff2,coeff3,volume_target,
        coeff0_target,coeff1_target,coeff2_target,coeff3_target,params_updated,
        params_busy,adc_overrun);
    integer i,previous,previous_volume,wait_cycles,q8_expected,volume_expected;
    task tick_sample;
        begin @(negedge clk); sample_ce=1; @(negedge clk); sample_ce=0;
              repeat(8) @(negedge clk); end
    endtask
    task latch_adc;
        input [11:0] c0,c1,c2,c3,c4;
        begin
            @(negedge clk);
            adc_ch0=c0;adc_ch1=c1;adc_ch2=c2;adc_ch3=c3;adc_ch4=c4;adc_valid=1;
            @(negedge clk);adc_valid=0;
            wait_cycles=0;
            while(!params_updated && wait_cycles<100) begin
                @(negedge clk);
                wait_cycles=wait_cycles+1;
            end
            if(!params_updated) $fatal(1,"valid scan was not acknowledged");
            if(wait_cycles>80) $fatal(1,"parameter normalization exceeded 80 clocks");
        end
    endtask
    task check_no_x;
        begin
            if ((^{volume_gain,coeff0,coeff1,coeff2,coeff3})===1'bx)
                $fatal(1,"unknown parameter output");
        end
    endtask
    initial begin
        repeat(4) @(negedge clk); rst=0; tick_sample();
        if(volume_gain!=16'hffff || coeff0!=256 || coeff1!=64 || coeff2!=32 || coeff3!=16)
            $fatal(1,"reset must load the accepted piano default");

        // Exhaust all ADC codes against the documented rounded mappings.
        for(i=0;i<=4095;i=i+1) begin
            latch_adc(i,i,0,0,0);
            q8_expected=(i*256+2047)/4095;
            volume_expected=i*16+(i/256);
            if(coeff0_target!=q8_expected)
                $fatal(1,"Q8 mapping mismatch at ADC=%0d: got %0d expected %0d",i,coeff0_target,q8_expected);
            if(volume_target!=volume_expected)
                $fatal(1,"volume mapping mismatch at ADC=%0d: got %0d expected %0d",i,volume_target,volume_expected);
        end

        latch_adc(4095,4095,1024,512,256);
        if(volume_target!=16'hffff || coeff0_target!=256 || coeff1_target!=64 ||
           coeff2_target!=32 || coeff3_target!=16)
            $fatal(1,"ADC mapping changed the default weights");
        repeat(4) tick_sample();
        if(coeff0!=256 || coeff1!=64 || coeff2!=32 || coeff3!=16)
            $fatal(1,"default weights should be stable at their targets");

        // All four harmonics at maximum must normalize to the preserved sum.
        @(negedge clk);
        adc_ch0=4095;adc_ch1=4095;adc_ch2=4095;adc_ch3=4095;adc_ch4=4095;adc_valid=1;
        @(negedge clk);adc_valid=0;
        if(!params_busy) $fatal(1,"over-limit scan did not enter sequential normalization");
        // A new snapshot during normalization must be rejected as a whole.
        @(negedge clk);adc_ch0=0;adc_ch1=0;adc_ch2=0;adc_ch3=0;adc_ch4=0;adc_valid=1;
        @(negedge clk);adc_valid=0;
        wait_cycles=0;
        while(!params_updated && wait_cycles<100) begin
            @(negedge clk);
            wait_cycles=wait_cycles+1;
        end
        if(!params_updated || params_busy || !adc_overrun)
            $fatal(1,"normalization completion or overrun reporting failed");
        if(coeff0_target+coeff1_target+coeff2_target+coeff3_target>368)
            $fatal(1,"normalized target exceeded the default headroom");
        if(coeff0_target!=92 || coeff1_target!=92 || coeff2_target!=92 || coeff3_target!=92)
            $fatal(1,"four full-scale sliders should normalize symmetrically");
        previous=coeff0;
        for(i=0;i<128;i=i+1) begin
            tick_sample(); check_no_x();
            if(coeff0>previous || previous-coeff0>2)
                $fatal(1,"coefficient slew was not monotonic/bounded");
            previous=coeff0;
        end
        if(coeff0!=92 || coeff1!=92 || coeff2!=92 || coeff3!=92)
            $fatal(1,"coefficient slew failed to reach full-scale normalized target");

        // A single slider sweep is captured atomically; invalid scans hold it.
        latch_adc(2048,0,4095,4095,4095);
        if(coeff0_target!=0 || coeff0_target+coeff1_target+coeff2_target+coeff3_target>368)
            $fatal(1,"single-slider target or normalization failed");
        repeat(40) tick_sample();
        previous=coeff1_target;
        latch_adc(0,0,0,0,0);
        if(volume_target!=0 || coeff0_target!=0 || coeff1_target!=0 || coeff2_target!=0 || coeff3_target!=0)
            $fatal(1,"zero scan did not map to zero targets");
        previous_volume=volume_gain;
        repeat(80) begin
            tick_sample(); check_no_x();
            if(volume_gain>previous_volume || previous_volume-volume_gain>1024)
                $fatal(1,"volume did not slew down monotonically");
            previous_volume=volume_gain;
        end
        if(volume_gain!=0) $fatal(1,"volume slew failed to reach mute");
        if(coeff0!=0 || coeff1!=0 || coeff2!=0 || coeff3!=0)
            $fatal(1,"coefficient slew failed to reach silence");

        // A crossfade between two legal vectors must remain inside the cap.
        latch_adc(4095,4095,1792,0,0);
        repeat(140) tick_sample();
        if(coeff0!=256 || coeff1!=112 || coeff2!=0 || coeff3!=0)
            $fatal(1,"crossfade start vector was not reached");
        latch_adc(4095,0,1952,1968,1968);
        repeat(140) begin
            tick_sample();
            if(coeff0+coeff1+coeff2+coeff3>368)
                $fatal(1,"live coefficient slew exceeded headroom cap");
        end
        if(coeff0!=0 || coeff1!=122 || coeff2!=123 || coeff3!=123)
            $fatal(1,"crossfade failed to converge to its legal target");

        // Invalid ADC frames must not replace the last valid targets.
        latch_adc(4095,4095,1024,512,256);
        adc_ch0=0;adc_ch1=0;adc_ch2=0;adc_ch3=0;adc_ch4=0;
        repeat(2) @(negedge clk);
        if(volume_target!=16'hffff || coeff0_target!=256 || coeff1_target!=64 ||
           coeff2_target!=32 || coeff3_target!=16)
            $fatal(1,"invalid scan changed the retained target");
        $display("CUSTOM_PARAMS_TB_PASS default mapping, sequential normalization, overrun, slew, retention");
        $finish;
    end
endmodule
