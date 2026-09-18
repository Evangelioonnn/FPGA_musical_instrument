`timescale 1ns/1ps
module manager_tb;
    reg clk=0,rst=1,valid=0,on=0,panic=0;
    reg [6:0] note=0;
    reg [3:0] idle=0;
    wire ready,stolen,ignored;
    wire [3:0] ons,offs,busy,held;
    wire [27:0] notes;
    reg er,es,ei;
    reg [3:0] eb,eh,eon,eoff;
    reg [27:0] en;
    integer fd,result,count=0;
    always #10 clk=~clk;
    voice_manager4 dut(clk,rst,valid,on,note,panic,idle,ready,ons,offs,busy,held,notes,stolen,ignored);
    initial begin
        fd=$fopen("manager_vectors.txt","r");
        if(!fd) $fatal(1,"Missing manager vectors");
        while(!$feof(fd)) begin
            @(negedge clk);
            result=$fscanf(fd,"%h %h %h %h %h %h %h %h %h %h %h %h %h %h\n",
                rst,panic,valid,on,note,idle,er,eb,eh,en,eon,eoff,es,ei);
            if(result==14) begin
                @(posedge clk); #1;
                if({ready,busy,held,notes,ons,offs,stolen,ignored}!=={er,eb,eh,en,eon,eoff,es,ei})
                    $fatal(1,"Manager vector=%0d note=%0d on=%0d got=%h expected=%h",count,note,on,
                        {ready,busy,held,notes,ons,offs,stolen,ignored},{er,eb,eh,en,eon,eoff,es,ei});
                count=count+1;
            end else if(result!=-1) $fatal(1,"Malformed vector");
        end
        $fclose(fd);
        if(count<6000) $fatal(1,"Insufficient manager coverage");
        $display("MANAGER_TB_PASS vectors=%0d",count); $finish;
    end
endmodule
