`timescale 1ns/1ps
module output_math_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0;
    reg [31:0] phase=0;reg [15:0] env=0,bright=0;
    wire [1:0] valid,deadline;wire [39:0] samples;
    genvar p;generate for(p=0;p<2;p=p+1) begin: profiles
        output_shared_tone #(.PROFILE(6),.TONE_SHIFT(p*3),.N(1)) dut(clk,rst,ce,phase,env,bright,samples[p*20+:20],valid[p],deadline[p]);
    end endgenerate
    integer fd,n,i;reg [31:0] rng=32'h38ac79de;
    initial begin
        fd=$fopen("math_vectors.txt","w");repeat(4) @(negedge clk);rst=0;
        for(n=0;n<2048;n=n+1) begin
            rng=rng^(rng<<13);rng=rng^(rng>>17);rng=rng^(rng<<5);phase=rng;
            env=(n%4==0 ? 0 : n%4==1 ? 65535 : rng[15:0]);bright=rng[31:16];
            ce=1;@(negedge clk);ce=0;repeat(10) @(negedge clk);
            for(i=0;i<2;i=i+1) $fwrite(fd,"%0d %0d %0d %0d %0d\n",i,phase,env,bright,$signed(samples[i*20+:20]));
            if(deadline) $fatal;
        end
        $fclose(fd);$display("OUTPUT_MATH_TB_PASS 4096 phase/envelope/scaling vectors");$finish;
    end
endmodule
