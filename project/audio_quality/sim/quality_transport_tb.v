`timescale 1ns/1ps
module quality_transport_tb;
    reg clk=0;
    wire bck,ws,din,pa;
    always #10 clk=~clk;
    audio_quality_top #(.SLOT_SAMPLES(240),.GATE_SAMPLES(100)) top(clk,bck,ws,din,pa);
    defparam top.original.ATTACK_STEP=1024;
    defparam top.original.DECAY_STEP=1024;
    defparam top.original.RELEASE_STEP=1024;
    defparam top.candidate.ATTACK_STEP=1024;
    defparam top.candidate.DECAY_STEP=1024;
    defparam top.candidate.RELEASE_STEP=1024;
    serial_checker check(clk,top.rst,top.ce,bck,ws,din,top.selected_sample,top.selected_sample);
    integer frames=0,switches=0,audible_a=0,audible_b=0;
    reg last_mode=0;
    always @(posedge clk) if(!top.rst) begin
        if(top.ce) begin
            frames=frames+1;
            #1;
            if(top.mode!==((frames/1440)%2)) $fatal(1,"Wrong A/B group order");
        end
        if(top.mode!=last_mode) begin
            if(top.old_sample!==0 || top.new_sample!==0) $fatal(1,"Switch during sound");
            switches=switches+1;
            last_mode=top.mode;
        end
        if(top.new_valid) begin
            if(top.old_env!==top.new_env) $fatal(1,"Envelope mismatch");
            if(!top.mode && top.old_sample!=0) audible_a=audible_a+1;
            if(top.mode && top.new_sample!=0) audible_b=audible_b+1;
        end
    end
    initial begin
        #65001000;
        if(check.frames<3000 || switches!=2 || audible_a<400 || audible_b<400 || pa!==0)
            $fatal(1,"Insufficient A/B transport coverage %0d %0d %0d",switches,audible_a,audible_b);
        $display("QUALITY_TRANSPORT_TB_PASS frames=%0d switches=%0d audible_A=%0d audible_B=%0d",
            check.frames,switches,audible_a,audible_b);
        $finish;
    end
endmodule
