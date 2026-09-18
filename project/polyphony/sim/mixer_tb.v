`timescale 1ns/1ps
module mixer_tb;
    reg clk=0,rst=1,valid=0;
    reg signed [15:0] a=0,b=0,c=0,d=0;
    wire signed [15:0] out0,out2;
    wire v0,v2,clip0,clip2;
    wire signed [17:0] wide;
    integer i,seed=1873,ia,ib,ic,id,total,scaled,expect0=0,expect2=0,clip_count=0;
    reg ec0,ec2;
    always #10 clk=~clk;
    mixer4 #(.OUTPUT_SHIFT(0)) unscaled(clk,rst,valid,a,b,c,d,out0,v0,clip0,wide);
    mixer4 divided(clk,rst,valid,a,b,c,d,out2,v2,clip2,);
    initial begin
        repeat(3) @(negedge clk); rst=0;
        for(i=0;i<5008;i=i+1) begin
            @(negedge clk); valid=(i%7!=6);
            case(i)
                0: begin a=0;b=0;c=0;d=0; end
                1: begin a=32767;b=32767;c=32767;d=32767; end
                2: begin a=-32768;b=-32768;c=-32768;d=-32768; end
                3: begin a=32767;b=-32767;c=12345;d=-12345; end
                4: begin a=32767;b=0;c=0;d=0; end
                5: begin a=-32768;b=0;c=0;d=0; end
                6: begin a=32767;b=32767;c=32767;d=32767; end
                7: begin a=-1;b=0;c=0;d=0; end
                default: begin a=$random(seed);b=$random(seed);c=$random(seed);d=$random(seed); end
            endcase
            ia=a;ib=b;ic=c;id=d;total=ia+ib+ic+id;
            // Independent integer division with explicit negative floor.
            if(total>=0) scaled=total/4; else scaled=-((-total+3)/4);
            ec0=0;ec2=0;
            if(valid) begin
                expect0=total;
                if(expect0>32767) begin expect0=32767;ec0=1;end
                if(expect0 < -32768) begin expect0=-32768;ec0=1;end
                expect2=scaled;
                if(expect2>32767) begin expect2=32767;ec2=1;end
                if(expect2 < -32768) begin expect2=-32768;ec2=1;end
                if(ec0) clip_count=clip_count+1;
            end
            @(posedge clk); #1;
            if(out0!=expect0 || out2!=expect2 || v0!==valid || v2!==valid || clip0!==ec0 || clip2!==ec2 || wide!=total)
                $fatal(1,"Mixer mismatch case=%0d sum=%0d out0=%0d expected=%0d out2=%0d expected2=%0d",i,total,out0,expect0,out2,expect2);
        end
        @(negedge clk); rst=1;
        @(posedge clk); #1;
        if(out0!==0 || out2!==0 || v0!==0 || clip0!==0) $fatal(1,"Mixer reset");
        if(clip_count<500) $fatal(1,"Clipping coverage");
        $display("MIXER_TB_PASS vectors=%0d saturation_cases=%0d",i,clip_count); $finish;
    end
endmodule
