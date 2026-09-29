`timescale 1ns/1ps
module five_original_pluck_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,ev=0,off=0,pedal=0;
    reg [31:0] token=0;reg [6:0] note=60;
    wire old_ready,new_ready,old_valid,new_valid,old_deadline,new_deadline;
    wire signed [15:0] old_sample,new_sample;
    wire [7:0] old_occupied,new_occupied;
    final_bank original(.clk(clk),.rst(rst),.sample_ce(ce),.event_valid(ev),
        .event_ready(old_ready),.event_off(off),.event_token(token),
        .event_note(note),.event_timbre(2'd1),.pedal(pedal),
        .reference_release(16'd24),.occupied(old_occupied),
        .out_valid(old_valid),.out_sample(old_sample),.deadline_missed(old_deadline));
    gallery_bank #(.N(8)) replacement(.clk(clk),.rst(rst),.sample_ce(ce),
        .event_valid(ev),.event_ready(new_ready),.event_off(off),
        .event_token(token),.event_note(note),.event_timbre(3'd1),
        .pedal(pedal),.sostenuto(1'b0),.reference_release(16'd24),
        .glide_index(3'd0),.lead_attack_index(2'd2),.bend_factor(17'd65536),.occupied(new_occupied),
        .out_valid(new_valid),.out_sample(new_sample),.deadline_missed(new_deadline));
    integer cycle=0,frame=0,compared=0;
    integer old_count=0,new_count=0;
    reg signed [15:0] old_pcm,new_pcm;
    always @(negedge clk) begin
        if(rst) begin cycle=0;ce=0;end
        else begin ce=(cycle==0);cycle=(cycle+1)%1040;end
    end
    always @(posedge clk) if(!rst) begin
        #1;
        if(old_valid) begin old_pcm=old_sample;old_count=old_count+1;end
        if(new_valid) begin new_pcm=new_sample;new_count=new_count+1;end
        if(cycle==220) begin
            if(old_count!=1 || new_count!=1 || old_pcm!==new_pcm ||
                old_occupied!==new_occupied || old_deadline || new_deadline) begin
                $display("old/new frame %0d pcm %0d/%0d occupancy %h/%h",frame,
                    old_pcm,new_pcm,old_occupied,new_occupied);$fatal;
            end
            compared=compared+1;old_count=0;new_count=0;frame=frame+1;
        end
    end
    task command;input kind;input [31:0] id;input [6:0] pitch;begin
        wait(cycle==250);@(negedge clk);
        while(!old_ready || !new_ready) @(negedge clk);
        off=kind;token=id;note=pitch;ev=1;@(negedge clk);ev=0;
    end endtask
    task frames;input integer count;integer goal;begin goal=frame+count;wait(frame>=goal);end endtask
    initial begin
        repeat(8) @(negedge clk);rst=0;frames(5);
        command(0,1,48);command(0,2,60);command(0,3,72);
        frames(900);
        command(1,1,0);command(1,2,0);command(1,3,0);
        frames(300);
        $display("FIVE_ORIGINAL_PLUCK_TB_PASS %0d exact old/new frames",compared);
        $finish;
    end
endmodule
