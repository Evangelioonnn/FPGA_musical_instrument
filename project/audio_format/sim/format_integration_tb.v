`timescale 1ns/1ps
module format_integration_tb;
    reg clk=0;
    wire bck,ws,din,pa,old_bck,old_ws,old_din,old_pa;
    always #10 clk=~clk;
    audio_format_top #(.SLOT_SAMPLES(240),.GATE_SAMPLES(100)) top(clk,bck,ws,din,pa);
    instrument_top reference(clk,old_bck,old_ws,old_din,old_pa);
    defparam reference.demo.SLOT_SAMPLES=240;
    defparam reference.demo.GATE_SAMPLES=100;
    defparam top.voice.ATTACK_STEP=1024;
    defparam top.voice.DECAY_STEP=1024;
    defparam top.voice.RELEASE_STEP=1024;
    defparam reference.voice.ATTACK_STEP=1024;
    defparam reference.voice.DECAY_STEP=1024;
    defparam reference.voice.RELEASE_STEP=1024;
    format_checker check(clk,top.rst,top.sample_ce,bck,ws,din,top.format16_active,top.sample,top.sample);
    integer frames=0,switches=0,audible_a=0,audible_b=0;
    reg last_mode=0;
    always @(posedge clk) begin
        if(!top.rst && top.sample_ce) frames=frames+1;
        #1;
        if({top.sample_ce,top.sample,top.sample_valid,top.envelope,ws,din,pa} !==
           {reference.sample_ce,reference.sample,reference.sample_valid,reference.envelope,old_ws,old_din,old_pa})
            $fatal(1,"Audio samples or serial data changed relative to original");
        if(!top.rst) begin
            if(top.format16_request!==((frames/1440)%2)) $fatal(1,"Wrong A/B request order");
            if(top.format16_active!==((frames==0) ? 0 : (((frames-1)/1440)%2)))
                $fatal(1,"Wrong frame-boundary application");
            if(!top.format16_active && bck!==old_bck) $fatal(1,"A BCK mismatch");
            if(top.format16_active!=last_mode) begin
                if(top.sample!==0) $fatal(1,"Mode changed during sound");
                switches=switches+1; last_mode=top.format16_active;
            end
            if(top.sample_valid && top.sample!=0) begin
                if(top.format16_active) audible_b=audible_b+1;
                else audible_a=audible_a+1;
            end
        end
    end
    initial begin
        #65001000;
        if(check.frames<3000 || switches!=2 || audible_a<400 || audible_b<400 || pa!==0)
            $fatal(1,"Insufficient complete-loop coverage");
        $display("FORMAT_INTEGRATION_TB_PASS frames=%0d words16=%0d words20=%0d switches=%0d audible_A=%0d audible_B=%0d",
            check.frames,check.words16,check.words20,switches,audible_a,audible_b);
        $finish;
    end
endmodule
