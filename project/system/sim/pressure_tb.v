`timescale 1ns/1ps
module pressure_tb;
    reg clk=0,rst=1,valid=0;
    reg [11:0] raw,lo,hi,dead;
    wire ready,updated,error,stale;wire [16:0] gain,normalized;
    integer f,rv,target,want,err,count=0;
    always #10 clk=~clk;
    pressure_expression #(.TIMEOUT_CYCLES(100)) dut(clk,rst,valid,raw,lo,hi,dead,ready,gain,normalized,updated,error,stale);
    initial begin
        f=$fopen("pressure_vectors.txt","r");if(!f) $fatal(1,"Pressure vectors missing");
        repeat(4) @(negedge clk);rst=0;
        while(!$feof(f)) begin
            rv=$fscanf(f,"%d %d %d %d %d %d %d\n",raw,lo,hi,dead,target,want,err);
            if(rv==7) begin
                wait(ready);@(negedge clk);valid=1;@(negedge clk);valid=0;
                wait(updated);#1;
                if(normalized!==target[16:0] || gain!==want[16:0] || error!==err[0] || stale)
                    $fatal(1,"Pressure oracle n=%0d got=%0d/%0d expected=%0d/%0d",count,normalized,gain,target,want);
                count=count+1;@(negedge clk);
            end
        end
        repeat(110) @(negedge clk);if(!stale || gain!=0) $fatal(1,"Pressure timeout failed");
        raw=4095;lo=0;hi=4095;dead=0;valid=1;@(negedge clk);valid=0;
        if(stale || !updated || normalized!=65536) $fatal(1,"Pressure recovery");
        if(count!=1200) $fatal(1,"Pressure coverage");
        $display("PRESSURE_TB_PASS vectors=%0d timeout_and_recovery=1",count);$finish;
    end
    initial begin #2000000;$fatal(1,"Pressure test timeout");end
endmodule
