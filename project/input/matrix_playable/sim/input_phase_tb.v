`timescale 1ns/1ps
// Real scan timing and contact bounce, all physical keys at varying scan phases.
module input_phase_tb;
    reg clk=0,rst=1;reg [15:0] physical=0;
    wire [3:0] rows,cols;wire [15:0] keys;wire changed,frame,ghost,up;
    integer k,phase,transitions=0,start_count,min_latency=2147483647,max_latency=0,latency,cycle=0;
    always #10 clk=~clk;
    always @(posedge clk)begin cycle=cycle+1;if(!rst && changed)transitions=transitions+1;end
    playable_matrix_network network(physical,rows,cols);
    matrix_scanner dut(clk,rst,cols,rows,keys,changed,frame,ghost,up);
    task clocks;input integer n;begin repeat(n)@(negedge clk);end endtask
    initial begin
        clocks(5);rst=0;clocks(100000);
        // Less than the debounce window, including a closure spanning a scan.
        physical=1;clocks(15000);physical=0;clocks(100000);
        if(keys || transitions)$fatal(1,"Short contact pulse escaped debounce");
        for(k=0;k<16;k=k+1)begin
            phase=(k*1733)%10000;clocks(phase);start_count=cycle;physical=1<<k;
            wait(keys!=0);@(negedge clk);latency=(cycle-start_count)*20;
            if(keys!==(16'b1<<k) || ghost || latency>2000000)$fatal(1,"Scan phase latency key=%0d ns=%0d",k,latency);
            if(latency<min_latency)min_latency=latency;if(latency>max_latency)max_latency=latency;
            physical=0;clocks(100000);if(keys)$fatal(1,"Stuck key on release");
        end
        if(transitions!=32)$fatal(1,"Bounce/duplicate transitions %0d",transitions);
        $display("INPUT_PHASE_TB_PASS physical_keys=16 transitions=32 scan_latency_ns_min=%0d max=%0d debounce_pulse_rejected=1",min_latency,max_latency);$finish;
    end
    initial begin #100000000;$fatal(1,"scan phase timeout");end
endmodule
