`timescale 1ns/1ps
// Electrical switch-graph model: undioded switches connect rows back through columns.
module matrix_network(input wire [15:0] switches,input wire [3:0] rows,
    output reg [3:0] cols_n,dioded_cols_n);
    reg [3:0] reached_rows,reached_cols,direct_cols;
    integer pass,r,c;
    always @* begin
        reached_rows=rows;reached_cols=0;direct_cols=0;
        for(r=0;r<4;r=r+1) for(c=0;c<4;c=c+1)
            if(rows[r] && switches[r*4+c]) direct_cols[c]=1;
        for(pass=0;pass<8;pass=pass+1)
            for(r=0;r<4;r=r+1) for(c=0;c<4;c=c+1)
                if(switches[r*4+c] && (reached_rows[r] || reached_cols[c])) begin reached_rows[r]=1;reached_cols[c]=1;end
        cols_n=~reached_cols;dioded_cols_n=~direct_cols;
    end
endmodule
module matrix_tb;
    reg clk=0,rst=1;reg [15:0] physical=0;
    wire [3:0] rows,rows_d,cols,cols_d;
    wire [15:0] keys,keys_d;wire changed,frame,ghost,up,gd,ud,cd,fd;
    integer a,b,checks=0,seed=10,presses=0;
    always #10 clk=~clk;
    matrix_network model(physical,rows,cols,cols_d);
    matrix_scanner #(.ROW_CYCLES(8),.DEBOUNCE_FRAMES(3)) dut(clk,rst,cols,rows,keys,changed,frame,ghost,up);
    matrix_scanner #(.ROW_CYCLES(8),.DEBOUNCE_FRAMES(3),.HAS_DIODES(1)) diode(clk,rst,cols_d,rows_d,keys_d,cd,fd,gd,ud);
    always @(posedge clk) if(!rst && changed && keys!=0) presses=presses+1;
    task settle;begin repeat(180) @(negedge clk);end endtask
    initial begin
        repeat(4) @(negedge clk);rst=0;settle;
        if(!up || keys!=0) $fatal(1,"Matrix startup");
        repeat(10) begin physical=1;repeat(2) @(negedge clk);physical=0;repeat(2) @(negedge clk);end
        settle;if(keys || presses) $fatal(1,"Bounce produced press");
        for(a=0;a<16;a=a+1) begin
            physical=1<<a;settle;
            if(keys!==physical || ghost) $fatal(1,"Matrix single key %0d",a);checks=checks+1;
            for(b=a+1;b<16;b=b+1) begin
                physical=(1<<a)|(1<<b);settle;
                if(keys!==physical || ghost) $fatal(1,"Matrix two-key %0d/%0d",a,b);checks=checks+1;
            end
            physical=0;settle;
        end
        physical=16'h0013;settle;
        if(!ghost || keys!=0 || up || keys_d!==physical || gd) $fatal(1,"Three-switch ghost model");
        physical=0;settle;if(ghost || !up) $fatal(1,"Ghost release");
        for(a=0;a<100;a=a+1) begin
            physical=$random(seed);settle;
            if(keys_d!==physical || gd) $fatal(1,"Diode rollover");checks=checks+1;
        end
        $display("MATRIX_TB_PASS layouts=%0d debounce=1 ghost_graph=1 diode_rollover=100",checks);$finish;
    end
endmodule
