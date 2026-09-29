`timescale 1ns/1ps
module gallery_math_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0;
    reg [31:0] phase=0;reg [15:0] env=0,bright=0;reg [2:0] preset=0;
    wire signed [19:0] sample;wire valid,deadline;
    gallery_shared_tone #(.N(1)) dut(clk,rst,ce,phase,env,bright,preset,sample,valid,deadline);
    integer fd,i,p,n,count=0;reg [31:0] rng=32'h81d539a7;
    initial begin
        fd=$fopen("gallery_math.txt","w");repeat(4) @(negedge clk);rst=0;
        for(p=0;p<8;p=p+1) for(n=0;n<1536;n=n+1) begin
            rng=rng^(rng<<13);rng=rng^(rng>>17);rng=rng^(rng<<5);
            phase=rng;env=n%4==0 ? 0 : n%4==1 ? 65535 : rng[15:0];
            bright=n%3==0 ? 65535 : n%3==1 ? 0 : rng[31:16];preset=p;
            ce=1;@(negedge clk);ce=0;repeat(18) @(negedge clk);
            if(deadline || (^sample)===1'bx) $fatal;
            $fwrite(fd,"%0d %0d %0d %0d %0d\n",p,phase,env,bright,$signed(sample));count=count+1;
        end
        $fclose(fd);$display("GALLERY_MATH_TB_PASS %0d preset/phase/envelope/modulation vectors",count);$finish;
    end
endmodule
