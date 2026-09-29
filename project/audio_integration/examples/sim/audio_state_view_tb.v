`timescale 1ns/1ps
module audio_state_view_tb;
    reg clk=0,rst=1,in_valid=0;
    always #10 clk=~clk;
    wire in_ready,view_valid,view_gap,view_session_start;
    reg [63:0] in_data=0;
    reg [5:0] in_word_index=0;
    reg in_first=0,in_last=0,in_session_start=0;
    wire [31:0] transport_sequence,source_drops,snapshot_sequence,parameter_revision,pcm_index;
    wire [16:0] master_target,master_applied;
    wire [2:0] selected_preset;
    wire sustain,sostenuto,clip_seen,deadline_seen,blocked;
    wire [15:0] peak,stream_reset_count;
    wire [24:0] keys;
    wire [31:0] occupied,held,gated,malformed_records;
    wire [223:0] notes;
    wire [95:0] presets;
    audio_state_view view(.*);
    reg [63:0] words[0:45];
    integer commits=0,i;
    always @(posedge clk) begin #1;if(view_valid) commits=commits+1;end
    task require;
        input condition;
        input [767:0] reason;
        begin if(condition!==1'b1) begin $display("STATE_VIEW_FAIL %0s",reason);$stop;end end
    endtask
    task make_record;
        input [31:0] seq,drops;
        begin
            for(i=0;i<46;i=i+1) words[i]=0;
            words[0]={16'h4132,8'd1,8'd46,8'd37,8'd4,8'd25,8'd0};
            words[1]={drops,seq};
            words[2]={16'd25,16'd12,16'd32,16'd2};
            words[3]={16'd320,16'd2368,8'd64,8'd0,8'd2,8'h3d};
            words[4]={32'h12abcd98,seq+32'd100};
            words[5][16:0]=65536;words[5][33:17]=54321;words[5][36:34]=4;
            words[5][37]=1;words[5][38]=0;words[5][42]=1;words[5][43]=0;words[5][44]=1;
            words[8][25:10]=30001;words[8][54:39]=7;
            for(i=0;i<32;i=i+1) begin
                words[9+i][31:0]=i+99;
                words[9+i][38:32]=36+i;words[9+i][41:39]=i%2==0 ? 3'd2 : 3'd5;
                words[9+i][42]=i<5;words[9+i][43]=i<3;words[9+i][44]=i<4;
                words[9+i][61:46]=1234+i;
            end
            words[41][31:0]=32'h23456789;
            words[45]=25'h10003;
        end
    endtask
    task word;
        input integer index;
        input first,last,session;
        begin
            @(negedge clk);in_valid=1;in_data=words[index];in_word_index=index;
            in_first=first;in_last=last;in_session_start=session;
            @(posedge clk);#2;
            @(negedge clk);in_valid=0;in_first=0;in_last=0;in_session_start=0;
        end
    endtask
    task packet;
        input session;
        integer j;
        begin for(j=0;j<46;j=j+1) word(j,j==0,j==45,session&&j==0);end
    endtask
    task check_fields;
        input [31:0] seq,drops;
        input gap,session;
        integer j;
        begin
            require(transport_sequence==seq && source_drops==drops,"transport metadata");
            require(snapshot_sequence==seq+100 && parameter_revision==32'h12abcd98,"snapshot header");
            require(master_target==65536 && master_applied==54321 && selected_preset==4,"Q16/selected fields");
            require(sustain && !sostenuto && clip_seen && !deadline_seen && blocked,"flags");
            require(peak==30001 && stream_reset_count==7 && pcm_index==32'h23456789,"peak/reset/index");
            require(keys==25'h10003 && occupied==31 && held==7 && gated==15,"held versus input keys");
            require(view_gap==gap && view_session_start==session,"gap/session boundary");
            for(j=0;j<32;j=j+1) begin
                require(notes[j*7+:7]==36+j,"independent voice MIDI");
                require(presets[j*3+:3]==(j%2==0 ? 2 : 5),"per-voice timbre");
            end
        end
    endtask
    initial begin
        repeat(3) @(negedge clk);rst=0;
        make_record(10,0);
        for(i=0;i<45;i=i+1) begin word(i,i==0,0,i==0);require(commits==0 && master_target==0,"no partial commit");end
        word(45,0,1,0);require(commits==1,"complete record commits once");check_fields(10,0,1,1);
        make_record(11,0);packet(0);require(commits==2,"second commit");check_fields(11,0,0,0);
        make_record(12,0);for(i=0;i<8;i=i+1) word(i,i==0,0,0);
        require(transport_sequence==11,"truncated record cannot replace previous view");
        make_record(13,2);packet(0);require(malformed_records==1,"replacement rejects truncated record");check_fields(13,2,1,0);
        make_record(14,2);words[0][63:48]=16'hdead;packet(0);
        require(commits==3 && malformed_records==2,"invalid header rejected");
        make_record(15,2);words[3][15:8]=1;packet(0);
        require(commits==3 && malformed_records==3,"wrong gain capability rejected");
        make_record(16,2);for(i=0;i<5;i=i+1) word(i,i==0,0,0);word(6,0,0,0);
        require(commits==3 && malformed_records==4,"out-of-order word rejected");
        make_record(17,2);for(i=0;i<10;i=i+1) word(i,i==0,i==9,0);
        require(commits==3 && malformed_records==5,"early last rejected");
        make_record(18,2);for(i=0;i<46;i=i+1) begin
            if(i%3==0) repeat(5) @(negedge clk);
            word(i,i==0,i==45,0);
        end
        require(commits==4,"arbitrary input bubbles preserve record");check_fields(18,2,1,0);
        make_record(0,0);packet(1);require(commits==5,"new transport reset session");check_fields(0,0,1,1);
        make_record(1,0);for(i=0;i<9;i=i+1) word(i,i==0,0,0);
        @(negedge clk);rst=1;@(negedge clk);rst=0;
        for(i=9;i<46;i=i+1) word(i,0,i==45,0);
        require(commits==5 && occupied==0,"reset discards unfinished tail");
        make_record(2,0);packet(0);require(commits==6,"resynchronizes at next valid first");check_fields(2,0,1,1);
        $display("AUDIO_STATE_VIEW_TB_PASS commits=%0d malformed_reset_cases=6 atomic_and_session_verified",commits);
        $finish;
    end
    initial begin #1000000;$display("STATE_VIEW_FAIL timeout");$stop;end
endmodule
