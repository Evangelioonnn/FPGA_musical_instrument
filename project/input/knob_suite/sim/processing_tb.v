`timescale 1ns/1ps
module processing_tb;
    reg clk=0,rst=1,valid=0;
    reg signed [15:0] input_sample=0;
    reg [16:0] target=65536;
    reg [15:0] wet_target=0;
    wire gain_valid,echo_valid,echo_ready,echo_clip;
    wire signed [15:0] gain_sample,echo_sample;
    wire [16:0] actual_gain;
    integer n,k,gain_model=65536,wet_model=0,inner_wet=0,history[0:4095];
    integer delayed,full_echo,write_value,echo_expected,gain_expected,amount,delta;
    integer gain_checks=0,echo_checks=0;
    reg signed [63:0] product;
    reg expected_clip;
    always #10 clk=~clk;
    knob_gain volume(clk,rst,valid,input_sample,target,gain_valid,gain_sample,actual_gain);
    knob_effect echo(clk,rst,valid,input_sample,wet_target,echo_ready,echo_valid,echo_sample,echo_clip);
    function integer sat;input integer x;begin sat=x>32767?32767:x< -32768?-32768:x;end endfunction
    always @(posedge clk) if(!rst) begin
        if(gain_valid)begin
            if(gain_sample!==gain_expected || actual_gain!==gain_model)$fatal(1,"Gain arithmetic mismatch");
            gain_checks=gain_checks+1;
        end
        if(echo_valid)begin
            if(echo_sample!==echo_expected || echo_clip!==expected_clip)
                $fatal(1,"Echo recurrence mismatch n=%0d got=%0d expected=%0d clip=%b",n,echo_sample,echo_expected,echo_clip);
            echo_checks=echo_checks+1;
        end
    end
    initial begin
        for(k=0;k<4096;k=k+1)history[k]=0;
        repeat(5)@(negedge clk);rst=0;
        for(n=0;n<75000;n=n+1)begin
            @(negedge clk);
            if(n<200)input_sample=(n%2)?8191:-8192;
            else if(n==500 || n==1000)input_sample=8000;
            else input_sample=0;
            target=n<200?65536:n<1000?0:n<1600?16384:65536;
            wet_target=n<100?0:n<30000?16384:0;
            delta=target-gain_model;
            gain_model=gain_model+(delta>128?128:delta< -128?-128:delta);
            product=$signed(input_sample)*gain_model;
            gain_expected=product/65536;
            delta=wet_target-wet_model;
            wet_model=wet_model+(delta>256?256:delta< -256?-256:delta);
            inner_wet=inner_wet+256;if(inner_wet>32768)inner_wet=32768;
            delayed=history[n%4096];
            write_value=$signed(input_sample)+delayed/2;
            history[n%4096]=sat(write_value);
            full_echo=$signed(input_sample)+(delayed*inner_wet)/32768;
            expected_clip=full_echo>32767 || full_echo< -32768;
            full_echo=sat(full_echo);
            echo_expected=$signed(input_sample)+((full_echo-$signed(input_sample))*wet_model)/32768;
            expected_clip=expected_clip || echo_expected>32767 || echo_expected< -32768;
            echo_expected=sat(echo_expected);
            if(!echo_ready)$fatal(1,"Effect backpressure at normal cadence");
            valid=1;@(negedge clk);valid=0;repeat(7)@(negedge clk);
        end
        if(gain_checks!=75000 || echo_checks!=75000 || echo_sample!=0)$fatal(1,"Lost sample or stuck tail");
        $display("PROCESSING_TB_PASS gain=%0d echo=%0d independent_recurrence=1 bypass_exact=1",gain_checks,echo_checks);$finish;
    end
endmodule
