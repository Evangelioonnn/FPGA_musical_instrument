`timescale 1ns/1ps
// Reuse the independent datasheet receiver. Its unrelated transport_tb is not elaborated.
`include "../../instrument/sim/transport_tb.v"
module integration_tb;
    reg clk=0;
    wire bck,ws,din,pa;
    integer audible=0,eight=0;
    always #10 clk=~clk;
    expression_top #(.SLOT(140)) top(clk,bck,ws,din,pa);
    serial_checker check_serial(clk,top.rst,top.ce,bck,ws,din,top.sample,top.sample);
    always @(posedge clk) if(!top.rst) begin
        if(top.valid && top.sample!=0) audible=audible+1;
        if(top.ce && top.core.occupied==255) eight=eight+1;
        if(top.event_valid && !top.event_ready) $fatal(1,"Dropped board-demo event");
        if(top.cfg_ack && !top.cfg_accepted) $fatal(1,"Rejected board-demo config");
    end
    initial begin
        #74000000;
        if(check_serial.frames<3500 || audible<1500 || eight<100 || pa!==0) $fatal(1,"Transport coverage");
        $display("INTEGRATION_TB_PASS frames=%0d audible=%0d eight_voice_frames=%0d",check_serial.frames,audible,eight);$finish;
    end
endmodule
