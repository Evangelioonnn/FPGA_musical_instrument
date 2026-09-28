`timescale 1ns/1ps
module vibrato_tb;
    reg clk=0;
    always #10 clk=~clk;
    reg rst=1,sample_ce=0,enable=0;
    reg [7:0] depth=0;
    reg [2:0] speed_index=0;
    wire [16:0] factor_q16;
    wire [6:0] depth_applied;
    vibrato_factor dut(clk,rst,sample_ce,enable,depth,speed_index,factor_q16,depth_applied);
    integer output_file,n,previous=65536;
    initial begin
        output_file=$fopen("vibrato_output.txt","w");
        repeat(4) @(negedge clk);
        rst=0;
        for(n=0;n<200000;n=n+1) begin
            enable=(n>=200 && n<175000);
            depth=n<25000 ? 16 : (n<50000 ? 32 : 255);
            speed_index=(n/25000)%8;
            sample_ce=1;
            @(negedge clk);
            if(factor_q16<63488 || factor_q16>67568 ||
                (factor_q16>previous && factor_q16-previous>16) ||
                (factor_q16<previous && previous-factor_q16>16)) begin
                $display("VIBRATO_FAIL bounds/slew");$finish;
            end
            $fwrite(output_file,"%0d %0d %0d %0d %0d %0d\n",
                n,enable,depth,speed_index,factor_q16,depth_applied);
            previous=factor_q16;
            sample_ce=0;
            repeat(2) @(negedge clk);
        end
        if(factor_q16 != 65536 || depth_applied != 0) begin
            $display("VIBRATO_FAIL return-to-center");$finish;
        end
        $fclose(output_file);
        $display("VIBRATO_TB_PASS frames=200000 bound/slew/off-center");
        $finish;
    end
endmodule
