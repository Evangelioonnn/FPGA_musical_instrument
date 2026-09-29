`timescale 1ns/1ps
module transport_v0_tb;
    reg clk=0;wire bck,ws,din,pa;
    always #10 clk=~clk;
    system_top #(.SLOT(128)) dut(clk,bck,ws,din,pa);
    serial_checker serial(clk,dut.rst,dut.ce,bck,ws,din,dut.sample,dut.sample);
    integer events=0,configs=0;
    always @(posedge clk)if(!dut.rst)begin
        if(dut.ev)begin if(!dut.er)$fatal(1,"Demo event loss");events=events+1;end
        if(dut.cv)begin if(!dut.cr)$fatal(1,"Demo config loss");configs=configs+1;end
        if(dut.clip || pa!==0)$fatal(1,"Demo clipping or amp state");
    end
    initial begin
        wait(serial.frames==2048);
        if(events!=48 || configs!=10)$fatal(1,"Transport coverage events=%0d configs=%0d",events,configs);
        $display("TRANSPORT_V0_TB_PASS frames=%0d events=%0d configs=%0d",serial.frames,events,configs);$finish;
    end
    initial begin #45000000;$fatal(1,"Transport timeout");end
endmodule
