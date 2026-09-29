`timescale 1ns/1ps
module capacity_transport_tb;
    reg clk=0;wire bck,ws,din,pa;
    always #10 clk=~clk;
    capacity_top #(.N(32)) dut(clk,bck,ws,din,pa);
    serial_checker receiver(clk,dut.rst,dut.ce,bck,ws,din,dut.sample,dut.sample);
    integer events=0,i;
    always @(posedge clk)if(!dut.rst)begin
        if(dut.ev)begin if(!dut.ready)$fatal(1,"capacity event lost");events=events+1;end
        if(dut.engine.clipped)$fatal(1,"capacity clipped");
    end
    initial begin
        wait(receiver.frames==2048);
        if(events!=32 || dut.engine.held!==32'hffffffff || pa!==0)$fatal(1,"capacity transport coverage");
        for(i=0;i<32;i=i+1)if(dut.engine.core.notes[i*7 +:7]!==48+i)$fatal(1,"event staging changed order");
        $display("CAPACITY_TRANSPORT_TB_PASS frames=%0d events=%0d active=32 fifo_stage=1",receiver.frames,events);$finish;
    end
    initial begin #45000000;$fatal(1,"capacity transport timeout");end
endmodule
