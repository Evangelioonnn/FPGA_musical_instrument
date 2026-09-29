`timescale 1ns/1ps
module snapshot_transport_tb;
    reg src_clk=0,dst_clk=0,arst=1;
    always #10 src_clk=!src_clk;
    always #7 dst_clk=!dst_clk;
    reg source_valid=0;
    reg [2367:0] source_data=0;
    reg [255:0] source_extension=0;
    reg [24:0] source_keys=0;
    reg [127:0] source_capabilities=128'h89abcdef01234567_fedcba9876543210;
    wire source_busy;
    wire [31:0] source_drops;
    wire valid,first,last,session;
    reg ready=0;
    wire [63:0] data;
    wire [5:0] word_index;
    audio_snapshot_bridge bridge(src_clk,dst_clk,arst,source_valid,source_data,
        source_extension,source_keys,source_capabilities,source_busy,source_drops,
        valid,ready,data,word_index,first,last,session);
    integer generation=0,expected_sequence=0,expected_drops=0;
    integer received_records=0,received_words=0,expected_index=0,stall_cycles=0;
    reg seen_session=0,previous_stall=0;
    reg [72:0] previous_payload=0;
    function [63:0] pattern;
        input integer gen,word;
        begin pattern={32'h92340000^(gen*32'h00110223)^word,
                       32'habcd0000^(gen*32'h00070151)^(word*32'h00012341)};end
    endfunction
    function [63:0] expected_word;
        input integer position;
        begin
            if(position==0) expected_word=64'h4132_012e_2504_1900;
            else if(position==1) expected_word={expected_drops[31:0],expected_sequence[31:0]};
            else if(position==2) expected_word=64'hfedcba9876543210;
            else if(position==3) expected_word=64'h89abcdef01234567;
            else if(position<41) expected_word=pattern(generation,position-4);
            else if(position<45) expected_word=pattern(generation,position+59);
            else expected_word={39'd0,(generation[24:0]^25'h1234567)};
        end
    endfunction
    task fail;
        input [8*140-1:0] message;
        begin $display("SNAPSHOT_TRANSPORT_TB_FAIL %0s time=%0t index=%0d actual=%h expected=%h",message,$time,word_index,data,expected_word(expected_index));$stop;end
    endtask
    task publish;
        input integer gen;
        integer i;
        begin
            @(negedge src_clk);
            for(i=0;i<37;i=i+1) source_data[i*64+:64]=pattern(gen,i);
            for(i=0;i<4;i=i+1) source_extension[i*64+:64]=pattern(gen,100+i);
            source_keys=gen^25'h1234567;source_valid=1;
            @(negedge src_clk);source_valid=0;
        end
    endtask
    task reset_link;
        begin
            ready=0;source_valid=0;arst=1;#53;arst=0;
            repeat(5) @(negedge src_clk);
        end
    endtask
    always @(posedge dst_clk or posedge arst) begin
        if(arst) begin expected_index=0;seen_session=0;previous_stall=0;end
        else begin
            if(previous_stall&&(!valid||{session,last,first,word_index,data}!==previous_payload)) fail("payload changed during ready stall");
            previous_stall=valid&&!ready;
            previous_payload={session,last,first,word_index,data};
            if(valid&&!ready) stall_cycles=stall_cycles+1;
            if(valid&&ready) begin
                if(word_index!==expected_index[5:0]||data!==expected_word(expected_index)) fail("independent record comparison");
                if(first!==(expected_index==0)||last!==(expected_index==45)) fail("record boundary");
                if(session!==(!seen_session&&expected_index==0)) fail("reset session flag");
                if(first) seen_session=1;
                received_words=received_words+1;
                if(last) begin received_records=received_records+1;expected_index=0;end
                else expected_index=expected_index+1;
            end
        end
    end
    initial begin
        #53;arst=0;repeat(5) @(negedge src_clk);
        generation=10;expected_sequence=0;expected_drops=0;publish(10);
        repeat(210) @(negedge src_clk);
        publish(11);publish(12);
        if(source_drops!=2) fail("busy publications not counted");
        ready=1;wait(received_records==1);wait(!source_busy);
        generation=13;expected_sequence=3;expected_drops=2;publish(13);
        wait(valid);repeat(18) @(negedge dst_clk);
        ready=0;repeat(30) @(negedge dst_clk);ready=1;
        wait(received_records==2);wait(!source_busy);
        ready=0;publish(20);repeat(20) @(negedge src_clk);
        generation=21;expected_sequence=5;expected_drops=3;publish(21);
        repeat(210) @(negedge src_clk);
        if(source_drops!=3) fail("copy restart not counted");
        ready=1;wait(received_records==3);wait(!source_busy);
        publish(22);repeat(30) @(negedge src_clk);reset_link;
        if(source_drops!=0) fail("reset did not clear drops");
        generation=23;expected_sequence=0;expected_drops=0;publish(23);ready=1;
        wait(expected_index==8);reset_link;
        generation=24;expected_sequence=0;expected_drops=0;publish(24);ready=1;
        wait(received_records==4);wait(!source_busy);
        generation=25;expected_sequence=1;expected_drops=0;publish(25);
        wait(received_records==5);wait(!source_busy);
        if(stall_cycles<20) fail("insufficient stalled-consumer coverage");
        $display("SNAPSHOT_TRANSPORT_TB_PASS records=%0d words=%0d stalled=%0d busy_drop=2 copy_restart_drop=1 reset_copy_and_partial=1",received_records,received_words,stall_cycles);
        $finish;
    end
    initial begin #500000;fail("timeout");end
endmodule
