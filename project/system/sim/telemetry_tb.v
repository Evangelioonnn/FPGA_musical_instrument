`timescale 1ns/1ps
module telemetry_tb;
    reg clk=0,dclk=0,rst=1,valid=0;reg [63:0] data=0;
    wire ready,dvalid;wire [63:0] output_data;wire [31:0] drops;
    reg [63:0] expected[0:20000];integer w=0,r=0,attempts=0,seed=54,n;
    always #10 clk=~clk;
    always begin #17 dclk=1;#23 dclk=0;end
    snapshot_cdc #(.WIDTH(64)) link(clk,rst,valid,data,ready,drops,dclk,rst,dvalid,output_data);
    always @(posedge clk) if(!rst && valid) begin
        attempts=attempts+1;if(ready)begin expected[w]=data;w=w+1;end
    end
    always @(posedge dclk) begin #1;
        if(!rst && dvalid) begin
            if(r>=w || output_data!==expected[r] || output_data[63:32]!==~output_data[31:0]) $fatal(1,"CDC torn or reordered snapshot");
            r=r+1;
        end
    end
    initial begin
        repeat(5) @(negedge clk);rst=0;
        for(n=0;n<10000;n=n+1) begin @(negedge clk);data={~n,n};valid=($random(seed)&3)!=0;end
        @(negedge clk);valid=0;repeat(30) @(negedge clk);
        if(r!=w || r<500 || drops!=attempts-w) $fatal(1,"CDC accounting");
        $display("TELEMETRY_TB_PASS accepted=%0d delivered=%0d dropped=%0d",w,r,drops);$finish;
    end
endmodule
