`timescale 1ns/1ps
// A separate fixed-point switch conduction network, independent of the union-find oracle.
module playable_matrix_network(input wire [15:0] switches,input wire [3:0] row_low,output reg [3:0] col_n);
    reg [7:0] low;
    integer pass,k;
    always @* begin
        low={4'd0,row_low};
        for(pass=0;pass<8;pass=pass+1)for(k=0;k<16;k=k+1)
            if(switches[k] && (low[k/4] || low[4+k%4]))begin low[k/4]=1;low[4+k%4]=1;end
        col_n=~low[7:4];
    end
endmodule
module matrix_all_tb;
    reg clk=0,rst=1;reg [15:0] switches=0;wire [3:0] rows,cols;wire [15:0] keys;
    wire changed,frame,ghost,up;reg [16:0] expected[0:65535];integer mask,changes=0;
    always #10 clk=~clk;
    playable_matrix_network electrical(switches,rows,cols);
    matrix_scanner #(.ROW_CYCLES(8),.DEBOUNCE_FRAMES(3)) dut(clk,rst,cols,rows,keys,changed,frame,ghost,up);
    always @(posedge clk)if(!rst && changed)changes=changes+1;
    initial begin
        $readmemh("matrix_oracle.txt",expected);
        repeat(5)@(negedge clk);rst=0;
        for(mask=0;mask<65536;mask=mask+1)begin
            switches=mask;repeat(160)@(negedge clk);
            if({ghost,keys}!==expected[mask] || up!==(mask==0))$fatal(1,"Matrix oracle mask=%h actual=%h expected=%h",switches,{ghost,keys},expected[mask]);
            if((rows&(rows-1))!=0)$fatal(1,"Multiple active row drivers");
        end
        switches=0;repeat(160)@(negedge clk);
        if(keys || ghost || !up)$fatal(1,"Full release recovery");
        $display("MATRIX_ALL_TB_PASS electrical_states=65536 changes=%0d",changes);$finish;
    end
    initial begin #300000000;$fatal(1,"matrix exhaustive timeout");end
endmodule
