`timescale 1ns/1ps
module gallery_equivalence_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,ev=0,off=0,pedal=0;
    reg [31:0] token=0;reg [6:0] note=60;reg [2:0] timbre=0;
    wire old_ready,new_ready,old_valid,new_valid,old_dead,new_dead;
    wire signed [15:0] old_pcm,new_pcm;
    wire [7:0] old_occupied,new_occupied;
    wire old_accept,new_accept,old_reject,new_reject;
    wire [31:0] old_rejected,new_rejected,old_unmatched,new_unmatched;
    output_bank #(.PROFILE(6)) old_bank(clk,rst,ce,ev,old_ready,off,token,note,timbre[1:0],
        pedal,16'd24,old_accept,old_reject,old_rejected,old_unmatched,
        old_occupied,,old_valid,old_pcm,,old_dead);
    gallery_bank new_bank(clk,rst,ce,ev,new_ready,off,token,note,timbre,
        pedal,16'd24,3'd0,new_accept,new_reject,new_rejected,new_unmatched,
        new_occupied,,new_valid,new_pcm,,new_dead);
    integer cycle=0,frame=0,count0=0,count1=0,j;
    reg signed [15:0] last0,last1;
    always @(negedge clk) if(rst) begin ce=0;cycle=0;end
        else begin ce=(cycle==0);cycle=(cycle+1)%1040;end
    always @(posedge clk) if(!rst) begin
        #1;
        if(old_valid) begin last0=old_pcm;count0=count0+1;end
        if(new_valid) begin last1=new_pcm;count1=count1+1;end
        if(cycle==180) begin
            if(count0!=1 || count1!=1 || last0!==last1 || old_occupied!==new_occupied ||
               old_dead || new_dead || old_rejected!=new_rejected || old_unmatched!=new_unmatched) begin
                $display("equivalence failed frame %0d PCM %0d/%0d count %0d/%0d",frame,last0,last1,count0,count1);$fatal;
            end
            count0=0;count1=0;frame=frame+1;
        end
    end
    task frames;input integer n;integer target;begin target=frame+n;wait(frame>=target);end endtask
    task command;input kind;input integer id,pitch,preset;
        begin wait(cycle==220);@(negedge clk);while(!old_ready || !new_ready) @(negedge clk);
            ev=1;off=kind;token=id;note=pitch;timbre=preset;@(negedge clk);ev=0;
        end
    endtask
    initial begin
        repeat(8) @(negedge clk);rst=0;frames(2);
        command(0,1,48,0);command(0,2,50,0);command(0,3,60,1);
        frames(420);pedal=1;command(1,1,0,0);command(1,2,0,0);frames(120);
        pedal=0;frames(760);command(1,3,0,0);
        for(j=0;j<5;j=j+1) command(0,10+j,55+j*3,j%2);
        frames(2400);
        for(j=0;j<5;j=j+1) command(1,10+j,0,0);
        frames(220);
        $display("GALLERY_EQUIVALENCE_TB_PASS %0d exact piano/pluck mixed frames",frame);$finish;
    end
    initial begin #110000000;$fatal;end
endmodule
