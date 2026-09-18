`timescale 1ns/1ps
module controls_v0_tb;
    reg clk=0,rst=1,ce=0,valid=0;
    reg [3:0] addr;reg [31:0] data;reg [16:0] pressure;
    wire ready,ack,accepted,sustain,sostenuto,panic;wire [31:0] applied;wire [16:0] volume,gain;
    integer f,rv,n=0,accepted_count=0,rejected=0;
    integer wa,wok,wvol,wgain,ws,wt,wp;reg [31:0] wdata;
    always #10 clk=~clk;
    system_controls dut(clk,rst,ce,valid,addr,data,pressure,ready,ack,accepted,applied,volume,gain,sustain,sostenuto,panic);
    initial begin
        f=$fopen("controls_vectors.txt","r");if(!f)$fatal(1,"Control vectors missing");
        while(!$feof(f)) begin
            @(negedge clk);
            rv=$fscanf(f,"%d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",rst,ce,valid,addr,data,pressure,wa,wok,wdata,wvol,wgain,ws,wt,wp);
            if(rv==14)begin
                @(posedge clk);#1;
                if(ack!==wa[0] || accepted!==wok[0] || applied!==wdata || volume!==wvol[16:0] || gain!==wgain[16:0] ||
                    sustain!==ws[0] || sostenuto!==wt[0] || panic!==wp[0]) $fatal(1,"Control numerical mismatch n=%0d",n);
                n=n+1;if(ack)begin if(accepted)accepted_count=accepted_count+1;else rejected=rejected+1;end
            end
        end
        if(n!=10000 || rejected<5000 || accepted_count<200)$fatal(1,"Control coverage");
        $display("CONTROLS_V0_TB_PASS vectors=%0d accepted=%0d rejected=%0d",n,accepted_count,rejected);$finish;
    end
endmodule
