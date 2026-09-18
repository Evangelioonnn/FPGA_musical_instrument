`timescale 1ns/1ps
`include "../../instrument/sim/transport_tb.v"
module baseline_tb;
    // Keep the regression short; the real board uses SLOT=48077 (one audio
    // second per demo slot). All event positions still exercise every case.
    localparam SLOT=128;
    reg clk=0;
    wire bck,ws,din,pa;
    integer events=0,commands=0,audible=0,max_occ=0,occ=0,i,peak_abs=0;
    always #10 clk=~clk;
    expression_baseline_top #(.SLOT(SLOT)) top(clk,bck,ws,din,pa);
    serial_checker check_serial(clk,top.rst,top.ce,bck,ws,din,top.sample,top.sample);
    always @(posedge clk) if(!top.rst) begin
        if(top.event_valid) begin
            if(!top.event_ready) $fatal(1,"baseline event dropped");
            events=events+1;
        end
        if(top.cfg_valid) begin
            if(!top.cfg_ready) $fatal(1,"baseline configuration dropped");
            commands=commands+1;
        end
        if(top.cfg_ack && !top.cfg_accepted) $fatal(1,"baseline config rejected");
        if(top.valid && top.sample!=0) audible=audible+1;
        if(top.valid && (top.sample > peak_abs || top.sample < -peak_abs))
            peak_abs = top.sample < 0 ? -top.sample : top.sample;
        occ=0;
        for(i=0;i<8;i=i+1) occ=occ+top.core.occupied[i];
        if(occ>max_occ) max_occ=occ;
        if(top.clipped) $fatal(1,"Unexpected clipping");
        if(top.pa_en!==1'b0) $fatal(1,"PA disabled level wrong");
    end
    initial begin
        wait(check_serial.frames==16*SLOT);
        if(events!=48 || commands!=17 || audible<100 || max_occ!=8)
            $fatal(1,"baseline coverage events=%0d commands=%0d audible=%0d max_occ=%0d frames=%0d",
                events,commands,audible,max_occ,check_serial.frames);
        if(peak_abs < 100) $fatal(1,"baseline output still too quiet peak=%0d",peak_abs);
        $display("BASELINE_TB_PASS events=%0d commands=%0d audible=%0d max_occ=%0d peak=%0d frames=%0d",events,commands,audible,max_occ,peak_abs,check_serial.frames);
        $finish;
    end
    initial begin #45000000; $fatal(1,"Transport timeout");end
endmodule
