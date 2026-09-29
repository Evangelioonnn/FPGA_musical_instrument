`timescale 1ns/1ps
module resource_sine_tb;
    reg clk=0,rst=1,sample_ce=0;
    reg [7:0] active=8'hff;
    reg [255:0] steps={32'd77454108,32'd73192711,32'd69148468,32'd65301915,
                        32'd61647784,32'd58178948,32'd54898533,32'd51899744};
    wire sv,dv; wire signed [31:0] sm,dm;
    shared_sine8_probe shared(clk,rst,sample_ce,active,steps,sv,sm);
    duplicated_sine8_probe duplicate(clk,rst,sample_ce,active,steps,dv,dm);
    reg signed [31:0] expected[0:15];
    integer wr=0,rd=0,frames=0,errors=0,cycles=0;
    always #5 clk=~clk;
    always @(posedge clk) begin
        if(dv) begin expected[wr]<=dm;wr<=wr+1;end
        if(sv) begin
            if(rd>=wr) begin $display("shared output arrived before duplicate");errors=errors+1;end
            else if(sm!==expected[rd]) begin
                $display("MISMATCH frame=%0d shared=%0d duplicated=%0d",rd,sm,expected[rd]);errors=errors+1;
            end
            rd<=rd+1;frames<=frames+1;
        end
    end
    always @(posedge clk) begin
        cycles<=cycles+1;
        if(!rst && cycles>20 && cycles%100==0) sample_ce<=1;
        else sample_ce<=0;
        if(cycles==650) begin
            if(frames<5 || errors!=0) begin
                $display("RESOURCE_SHARED_SINE_TB_FAIL frames=%0d errors=%0d",frames,errors);
                $finish(1);
            end
            $display("RESOURCE_SHARED_SINE_TB_PASS frames=%0d",frames);
            $finish;
        end
        if(cycles==5) rst<=0;
    end
endmodule
