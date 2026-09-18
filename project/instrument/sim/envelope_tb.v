`timescale 1ns/1ps
module envelope_tb;
    reg clk=0,rst=1,ce=0,on=0,off=0;
    reg [15:0] a=10000,d=10000,s=23456,r=7000;
    wire [15:0] level;
    wire [2:0] state;
    integer i,held;
    always #10 clk=~clk;
    adsr_envelope dut(clk,rst,ce,on,off,a,d,s,r,level,state);
    task tick;
        begin @(negedge clk); ce=1; @(negedge clk); ce=0; end
    endtask
    task event_on;
        begin @(negedge clk); on=1; @(negedge clk); on=0; end
    endtask
    task event_off;
        begin @(negedge clk); off=1; @(negedge clk); off=0; end
    endtask
    task expect;
        input integer lev,st;
        begin if(level!==lev || state!==st) $fatal(1,"ADSR got %0d/%0d expected %0d/%0d",level,state,lev,st); end
    endtask
    initial begin
        repeat(3) @(negedge clk); rst=0; expect(0,0);
        event_off; tick; expect(0,0);
        event_on; expect(0,1);
        repeat(8) @(negedge clk); expect(0,1);
        for(i=1;i<=6;i=i+1) begin tick; expect(i*10000,1); end
        tick; expect(65535,2);
        for(i=1;i<=4;i=i+1) begin tick; expect(65535-i*10000,2); end
        tick; expect(23456,3);
        repeat(20) begin tick; expect(23456,3); end
        event_off; expect(23456,4);
        for(i=1;i<=3;i=i+1) begin tick; expect(23456-i*7000,4); end
        tick; expect(0,0);
        // Short press and an attack retrigger retain the current level.
        event_on; tick; tick; expect(20000,1);
        event_on; expect(20000,1); tick; expect(30000,1);
        event_off; expect(30000,4); tick; expect(23000,4);
        event_on; expect(23000,1); tick; expect(33000,1);
        event_off; repeat(5) tick; expect(0,0);
        // Release during decay and sustain endpoints 0 / full scale.
        a=65535; d=65535; s=0; r=65535;
        event_on; tick; expect(65535,2); event_off; tick; expect(0,0);
        event_on; tick; tick; expect(0,3); event_off; tick; expect(0,0);
        s=65535; event_on; tick; tick; expect(65535,3);
        event_off; tick; expect(0,0);
        // Zero steps have explicit progress semantics rather than hanging.
        a=0; d=0; s=23456; r=0;
        event_on; tick; expect(1,1); event_off; tick; expect(0,0);
        a=65535; event_on; tick; tick; expect(65534,2);
        // Simultaneous on/off, even on a sample edge: on wins, no level jump.
        @(negedge clk); on=1; off=1; ce=1;
        @(negedge clk); on=0; off=0; ce=0; expect(65534,1);
        r=65535; event_off; tick; expect(0,0);
        rst=1; tick; expect(0,0); rst=0;
        // Actual production parameters: exact sample counts, including the
        // final partial increment/decrement at each saturating boundary.
        a=68; d=6; s=32768; r=3;
        event_on;
        for(i=1;i<964;i=i+1) begin tick; expect(i*68,1); end
        tick; expect(65535,2);
        for(i=1;i<5462;i=i+1) begin tick; expect(65535-i*6,2); end
        tick; expect(32768,3);
        event_off;
        for(i=1;i<10923;i=i+1) begin tick; expect(32768-i*3,4); end
        tick; expect(0,0);
        $display("ENVELOPE_TB_PASS"); $finish;
    end
    initial begin #1000000; $fatal(1,"Envelope timeout"); end
endmodule
