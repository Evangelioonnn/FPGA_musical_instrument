`timescale 1ns/1ps
// Frozen packet oracle, copy restart, owned-bank drop, stall, reset/session.
module snapshot_copy_tb;
    reg src_clk=0,dst_clk=0;
    always #10 src_clk=~src_clk;always #3.333 dst_clk=~dst_clk;
    reg arst=1,src_snapshot_valid=0,dst_ready=0;
    reg [2879:0] src_snapshot_data=0;
    reg [255:0] src_snapshot_extension=0;
    reg [15:0] src_snapshot_keys=0;
    reg [127:0] src_capabilities=128'h9fa10c3312345678fefdefcdab987654;
    wire src_busy,dst_valid,dst_first,dst_last,dst_session_start;
    wire [31:0] src_drop_count;wire [63:0] dst_data;wire [5:0] dst_word_index;
    refinement_snapshot_bridge #(.SNAPSHOT_W(2880),.KEYS(16)) dut(.*);
    reg [3455:0] expected;
    reg [63:0] held_word;
    reg was_held=0,check_enabled=0,random_ready=0;
    reg [31:0] rng=32'h130fee32;
    integer words=0,packets=0,session_packets=0,i;
    always @(negedge dst_clk) if(random_ready) begin
        rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};dst_ready=rng[0];
    end
    always @(posedge dst_clk) begin
        if(arst) was_held=0;
        else begin
            if(was_held && (!dst_valid || dst_data!==held_word)) $fatal(1,"stall data changed");
            was_held=dst_valid&&!dst_ready;held_word=dst_data;
            if(dst_valid && dst_ready && check_enabled) begin
                if(dst_word_index!=words || dst_data!==expected[words*64+:64])
                    $fatal(1,"packet word=%0d actual=%h expected=%h",words,dst_data,expected[words*64+:64]);
                if(dst_first!=(words==0) || dst_last!=(words==53)) $fatal(1,"packet framing");
                if(dst_session_start) begin if(words!=0) $fatal(1,"session position");session_packets=session_packets+1;end
                if(words==53) begin words=0;packets=packets+1;end else words=words+1;
            end
        end
    end
    task publish;
        input [31:0] salt;
        begin
            @(negedge src_clk);
            for(i=0;i<90;i=i+1) src_snapshot_data[i*32+:32]=salt^(32'h813dea14*i);
            for(i=0;i<8;i=i+1) src_snapshot_extension[i*32+:32]=salt+32'h91fe37a5*i;
            src_snapshot_keys=salt[15:0];src_snapshot_valid=1;
            @(negedge src_clk);src_snapshot_valid=0;
        end
    endtask
    task capture;
        input [31:0] seq,drops;
        begin expected={48'd0,src_snapshot_keys,src_snapshot_extension,src_snapshot_data,
            src_capabilities,drops,seq,64'h4c5201362d041000};end
    endtask
    initial begin
        repeat(8) @(negedge src_clk);arst=0;repeat(8) @(negedge src_clk);
        publish(32'h1);repeat(4) @(negedge src_clk);
        publish(32'h2);capture(1,1);check_enabled=1;
        wait(dst_valid);repeat(30) @(negedge dst_clk);
        // Complete source fields change but an owned frozen RAM is immutable.
        publish(32'h3);if(src_drop_count!=2) $fatal(1,"owned drop count");
        random_ready=1;wait(packets==1);wait(!src_busy);
        random_ready=0;dst_ready=0;publish(32'h4);capture(3,2);
        wait(dst_valid);repeat(12) @(negedge dst_clk);
        // Abort a partly published epoch; next packet must be session first.
        arst=1;check_enabled=0;words=0;repeat(8) @(negedge src_clk);
        arst=0;repeat(8) @(negedge src_clk);publish(32'h5);capture(0,0);
        check_enabled=1;random_ready=1;wait(packets==2);wait(!src_busy);
        if(src_drop_count!=0 || session_packets!=2) $fatal(1,"reset/session");
        $display("SNAPSHOT_COPY_TB_PASS complete54word restart owned_drop random_stall reset session");$finish;
    end
    initial begin #1000000;$fatal(1,"snapshot watchdog");end
endmodule
