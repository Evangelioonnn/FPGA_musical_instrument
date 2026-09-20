`timescale 1ns/1ps
module pedal_render_tb;
    reg clk=0,rst=1,ce=0,valid=0,sustain=0,sostenuto=0;
    reg [6:0] note=60;
    wire ready,accepted,rejected,ov,clip,deadline;wire [1:0] slot;
    wire [31:0] rejects;wire [3:0] occupied,gated,captured;
    wire signed [15:0] sample;
    integer n,file,outputs=0;
    always #10 clk=~clk;
    knob_bank #(.N(4)) dut(clk,rst,ce,valid,ready,note,2'd0,24'd31250,
        16'd68,16'd6,16'd32768,16'd3,sustain,sostenuto,1'b0,accepted,rejected,slot,rejects,
        occupied,gated,captured,ov,sample,clip,deadline);
    always @(posedge clk)if(!rst)begin
        if(rejected || clip || deadline)$fatal(1,"Pedal audio source fault");
        if(ov)begin $fwrite(file,"%0d\n",sample);outputs=outputs+1;end
    end
    initial begin
        file=$fopen("pedals_samples.txt","w");repeat(5)@(negedge clk);rst=0;
        for(n=0;n<384616;n=n+1)begin
            if(n==4807 || n==72115 || n==192308 || n==206731)begin
                note=n==206731?67:60;valid=1;@(negedge clk);valid=0;
            end
            if(n==86538)sustain=1;
            if(n==144231)sustain=0;
            if(n==197115)sostenuto=1;
            if(n==288462)sostenuto=0;
            ce=1;@(negedge clk);ce=0;repeat(79)@(negedge clk);
            if(n==130000 && occupied!=1)$fatal(1,"Sustain segment not held");
            if(n==270000 && (occupied!=1 || captured!=1))$fatal(1,"Selective sustain wrong notes");
        end
        if(sample || occupied || outputs!=384616)$fatal(1,"Pedal tail incomplete");
        $fclose(file);$display("PEDAL_RENDER_TB_PASS samples=%0d normal_sustain_sostenuto=1",outputs);$finish;
    end
endmodule
