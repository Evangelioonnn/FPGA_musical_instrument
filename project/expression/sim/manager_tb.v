`timescale 1ns/1ps
module manager_tb;
    parameter N=8;
    reg clk=0,rst,valid,sus,sos,panic;
    reg [1:0] kind;
    reg [6:0] note,value;
    reg [8:0] velocity;
    reg [N-1:0] idle;
    wire ready,stolen,ignored;
    wire [N-1:0] ons,offs,fresh,occ,held,gate,sost;
    wire [N*7-1:0] notes,pitches;
    wire [N*9-1:0] velocities;
    reg [N+29:0] stimulus;
    reg [30*N+1:0] expected;
    wire [30*N+1:0] observed={ons,offs,fresh,occ,held,gate,sost,notes,pitches,velocities,stolen,ignored};
    integer f,rc,count=0;
    always #10 clk=~clk;
    performance_manager #(.N(N)) dut(clk,rst,valid,kind,note,value,velocity,sus,sos,panic,idle,
        ready,ons,offs,fresh,occ,held,gate,sost,notes,pitches,velocities,stolen,ignored);
    initial begin
        f=N==8 ? $fopen("manager8_vectors.txt","r") : $fopen("manager4_vectors.txt","r");
        if(!f) $fatal(1,"Cannot open vectors");
        while(!$feof(f)) begin
            rc=$fscanf(f,"%h %h\n",stimulus,expected);
            if(rc==2) begin
                @(negedge clk);{rst,valid,kind,note,value,velocity,sus,sos,panic,idle}=stimulus;
                @(posedge clk);#1;
                if(observed!==expected) $fatal(1,"Manager N=%0d vector=%0d input=%h got=%h expected=%h",N,count,stimulus,observed,expected);
                if(ready!==(!rst&&!panic)) $fatal(1,"Ready mismatch");
                count=count+1;
            end
        end
        if(count<12000) $fatal(1,"Insufficient vectors");
        $display("MANAGER_TB_PASS N=%0d vectors=%0d",N,count);$finish;
    end
endmodule
