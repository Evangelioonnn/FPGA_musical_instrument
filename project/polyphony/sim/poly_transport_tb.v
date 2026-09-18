`timescale 1ns/1ps
module poly_transport_tb;
    reg clk=0;
    wire bck,ws,din,pa;
    always #10 clk=~clk;
    polyphony_top #(.SLOT_SAMPLES(360)) top(clk,bck,ws,din,pa);
    defparam top.core.ATTACK_STEP=1024;
    defparam top.core.DECAY_STEP=1024;
    defparam top.core.RELEASE_STEP=1024;
    serial_checker check(clk,top.rst,top.ce,bck,ws,din,top.sample,top.sample);
    integer four_frames=0,empty_frames=0,audible=0;
    always @(posedge clk) if(!top.rst && top.valid) begin
        if(top.occupied==15) four_frames=four_frames+1;
        if(top.occupied==0) empty_frames=empty_frames+1;
        if(top.sample!=0) audible=audible+1;
        if(top.clipped || top.stolen || top.ignored) $fatal(1,"Unexpected core diagnostic");
    end
    initial begin
        #70001000;
        if(check.frames<3300 || four_frames<350 || empty_frames<350 || audible<1500 || pa!==0)
            $fatal(1,"Insufficient poly transport coverage");
        $display("POLY_TRANSPORT_TB_PASS frames=%0d four_voice_frames=%0d empty_frames=%0d audible=%0d",
            check.frames,four_frames,empty_frames,audible);$finish;
    end
endmodule
