`timescale 1ns/1ps
module pcm_transport_tb;
    reg src_clk=0,dst_clk=0,arst=1;
    always #10 src_clk=!src_clk;
    always #7 dst_clk=!dst_clk;
    reg source_valid=0;
    reg signed [15:0] source_left=0,source_right=0;
    reg [31:0] source_index=0;
    wire [31:0] drops;
    wire overflow,valid,gap,session;
    reg ready=0;
    wire signed [15:0] left,right;
    wire [31:0] index;
    audio_pcm_bridge #(.ADDR_W(3)) bridge(src_clk,dst_clk,arst,source_valid,
        source_left,source_right,source_index,drops,overflow,valid,ready,left,right,index,gap,session);
    reg [31:0] expected_indices[0:2047];
    integer head=0,tail=0,delivered=0,stalled=0,gaps=0,firsts=0;
    reg previous_stall=0,seen_session=0;
    reg [65:0] previous_payload=0;
    reg [31:0] previous_index=0;
    function [15:0] left_pattern;
        input [31:0] seq;
        begin left_pattern=(seq*16'h0311)^16'h7f00;end
    endfunction
    function [15:0] right_pattern;
        input [31:0] seq;
        begin right_pattern=(seq*16'h0a51)^16'h805a;end
    endfunction
    task fail;
        input [8*140-1:0] message;
        begin $display("PCM_TRANSPORT_TB_FAIL %0s time=%0t head=%0d tail=%0d index=%0d drops=%0d",message,$time,head,tail,index,drops);$stop;end
    endtask
    task publish;
        input [31:0] seq;
        input expect_delivery;
        input integer interval;
        begin
            @(negedge src_clk);
            if(expect_delivery) begin expected_indices[tail]=seq;tail=tail+1;end
            source_left=left_pattern(seq);source_right=right_pattern(seq);source_index=seq;source_valid=1;
            @(negedge src_clk);source_valid=0;
            if(interval>1) repeat(interval-1) @(negedge src_clk);
        end
    endtask
    task reset_link;
        begin
            ready=0;source_valid=0;head=tail;arst=1;#53;arst=0;
            repeat(5) @(negedge src_clk);
        end
    endtask
    always @(posedge dst_clk or posedge arst) begin
        if(arst) begin previous_stall=0;seen_session=0;previous_index=0;end
        else begin
            if(previous_stall&&(!valid||{gap,session,index,right,left}!==previous_payload)) fail("stalled PCM changed");
            previous_stall=valid&&!ready;
            previous_payload={gap,session,index,right,left};
            if(valid&&!ready) stalled=stalled+1;
            if(valid&&ready) begin
                if(head==tail) fail("unexpected output frame");
                if(index!==expected_indices[head]||left!==left_pattern(expected_indices[head])||right!==right_pattern(expected_indices[head])) fail("bit-exact independent PCM comparison");
                if(session!==!seen_session||gap!==(!seen_session||index!=previous_index+32'd1)) fail("continuity flag");
                if(gap) gaps=gaps+1;
                if(session) firsts=firsts+1;
                seen_session=1;previous_index=index;head=head+1;delivered=delivered+1;
            end
        end
    end
    integer i;
    initial begin
        #53;arst=0;repeat(5) @(negedge src_clk);
        for(i=0;i<18;i=i+1) publish(100+i,i<8,8);
        if(drops!=10||!overflow) fail("FIFO-full frames not dropped whole");
        ready=1;wait(head==tail);repeat(10) @(negedge src_clk);
        publish(200,1,8);publish(201,1,8);
        publish(32'hfffffffe,1,8);publish(32'hffffffff,1,8);publish(0,1,8);publish(0,1,8);publish(1,1,8);
        wait(head==tail);repeat(10) @(negedge src_clk);
        publish(300,1,1);publish(301,0,8);
        wait(head==tail);if(drops!=11) fail("busy serializer drop");
        for(i=0;i<240;i=i+1) begin
            if(i%7==0) ready=0;else ready=1;
            publish(1000+i,1,9);
        end
        ready=1;wait(head==tail);
        if(drops!=11) fail("unexpected regular-stream drops");
        ready=0;for(i=0;i<4;i=i+1) publish(2000+i,1,8);
        publish(2004,1,1);reset_link;
        if(drops!=0||overflow) fail("reset diagnostics not cleared");
        publish(0,1,8);ready=1;publish(1,1,8);
        wait(head==tail);repeat(20) @(negedge src_clk);
        if(firsts!=2||gaps<6||stalled<20) fail("insufficient session/gap/stall coverage");
        $display("PCM_TRANSPORT_TB_PASS delivered=%0d full_drops=10 busy_drops=1 gaps=%0d sessions=%0d stalled=%0d pointer_wrap=30 reset_queued_and_serializer=1",delivered,gaps,firsts,stalled);
        $finish;
    end
    initial begin #500000;fail("timeout");end
endmodule
