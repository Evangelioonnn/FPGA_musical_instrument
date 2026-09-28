`timescale 1ns/1ps
module audio_board_tb;
    reg clk=0;
    always #10 clk=~clk;
    reg [15:0] physical=0;
    reg [3:0] cols=15;
    wire [3:0] rows;
    // S4/S2/S1 use button_n[0]/[1]/[2], respectively.
    reg [2:0] buttons=7;
    reg a=1,b=1;
    wire bck,ws,din,pa,led;
    audio_top #(.ROW_CYCLES(20),.DEBOUNCE_FRAMES(2),
        .BUTTON_CYCLES(2),.LONG_CYCLES(5000),
        .EC11_CYCLES(2),.EC11_SAMPLES(2)) dut(
        clk,a,b,buttons,cols,rows,bck,ws,din,pa,led);

    integer r,c,pass;
    reg [3:0] low_rows,low_cols;
    always @* begin
        // Floating rows conduct through other closed undioded switches.
        low_rows=0;low_cols=0;
        for(r=0;r<4;r=r+1) if(rows[r]===1'b0) low_rows[r]=1;
        for(pass=0;pass<8;pass=pass+1)
            for(r=0;r<4;r=r+1) for(c=0;c<4;c=c+1)
                if(physical[r*4+c] && (low_rows[r] || low_cols[c])) begin
                    low_rows[r]=1;low_cols[c]=1;
                end
        cols=~low_cols;
    end

    integer bit_index=0,words=0,nonzero=0,cycles=0,last_ce=0,frame_valids=0;
    integer frames=0,stereo_frames=0,stereo_words=0;
    reg [19:0] word=0;
    reg signed [15:0] expected_left=0,expected_right=0;
    always @(posedge clk) if(!dut.rst) begin
        cycles=cycles+1;
        if(dut.sample_ce) begin
            frames=frames+1;
            if(last_ce!=0 && (cycles-last_ce!=1040 ||
                (frame_valids!=1 && !(frame_valids==0 && dut.core.reset_gap_pending))))
                $fatal(1,"audio frame cadence/deadline mismatch period=%0d outputs=%0d",
                       cycles-last_ce,frame_valids);
            last_ce=cycles;frame_valids=0;
            // PT8211 latches these previously completed samples on this edge.
            expected_left=dut.final_left;expected_right=dut.final_right;
        end
        if(dut.final_valid) begin
            frame_valids=frame_valids+1;
            if(dut.final_left!=dut.final_right) stereo_frames=stereo_frames+1;
        end
        if(dut.deadline || pa!==0)
            $fatal(1,"deadline flag or speaker enable polarity mismatch");
    end
    always @(posedge bck) if(!dut.rst) begin
        #1;
        if(ws!==(bit_index>=20)) $fatal(1,"PT8211 WS phase mismatch");
        word={word[18:0],din};
        if(bit_index==19 || bit_index==39) begin
            if(word[19:16]!=0 || word[15:0]!==
                (bit_index==19 ? expected_right : expected_left))
                $fatal(1,"PT8211 PCM mismatch bit=%0d got=%h L=%h R=%h",
                       bit_index,word,expected_left,expected_right);
            words=words+1;
            if(word[15:0]!=0) nonzero=nonzero+1;
            if(expected_left!=expected_right) stereo_words=stereo_words+1;
        end
        bit_index=(bit_index+1)%40;
    end

    task check;
        input condition;
        input [2047:0] message;
        begin if(condition !== 1'b1) $fatal(1,"%0s",message); end
    endtask
    task click;
        input integer button;
        begin
            @(negedge clk);buttons[button]=0;
            repeat(20) @(negedge clk);
            buttons[button]=1;
            // Allow event debounce, request capture and a 1040-clock commit.
            repeat(2200) @(negedge clk);
        end
    endtask
    task hold_button;
        input integer button;
        begin
            @(negedge clk);buttons[button]=0;
            repeat(7400) @(negedge clk);
            buttons[button]=1;
            repeat(2200) @(negedge clk);
        end
    endtask
    task turn;
        input positive;
        begin
            @(negedge clk);{a,b}=positive ? 2'b10 : 2'b01;
            repeat(20) @(negedge clk);
            {a,b}=2'b00;repeat(20) @(negedge clk);
            {a,b}=positive ? 2'b01 : 2'b10;repeat(20) @(negedge clk);
            {a,b}=2'b11;repeat(2200) @(negedge clk);
        end
    endtask

    integer k,fx_end_frame,prior_stereo_frames,prior_stereo_words;
    reg [7:0] left_mask,right_mask;
    initial begin
        repeat(1500) @(negedge clk);
        check(dut.timbre==0 && dut.core.master_target==8249 && dut.control_mode==0,
              "board default differs from accepted reference");
        while(dut.core.gain_left!=8249 || dut.core.gain_right!=8249)
            @(negedge clk);
        physical=16'h0180;
        repeat(14000) @(negedge clk);
        check(dut.held==8'h03 && dut.core.voice_notes[6:0]==60 &&
              dut.core.voice_notes[13:7]==60,
              "two physical zones did not allocate independent same-note instances");
        left_mask=0;right_mask=0;
        for(k=0;k<8;k=k+1) begin
            if(dut.core.voice_tokens[k*32+:32]==dut.core.key_events.tokens[7]) left_mask[k]=1;
            if(dut.core.voice_tokens[k*32+:32]==dut.core.key_events.tokens[8]) right_mask[k]=1;
        end
        check(left_mask!=0 && right_mask!=0 && (left_mask&right_mask)==0,
              "physical keys did not receive distinct strike identities");
        turn(1);
        check(dut.core.master_target==11653,"volume encoder did not increment authoritative gain");
        turn(0);
        check(dut.core.master_target==8249,"volume encoder did not restore accepted default");
        click(0);
        check(dut.control_mode==1,"S4 did not enter left-zone control");
        turn(1);
        check(dut.core.left_base==60 && dut.core.voice_notes[6:0]==60,
              "zone change retuned an existing held instance");
        click(0);turn(1);
        check(dut.core.right_base==72,"right-zone encoder route failed");

        click(2);check(dut.timbre==2 && dut.control_mode==0,"menu did not skip legacy ID1");
        click(2);check(dut.timbre==3,"menu order expected Metallic bell");
        click(2);check(dut.timbre==4,"menu order expected Drive lead");
        click(2);check(dut.timbre==5,"menu order expected editable harmonics");
        for(k=1;k<=4;k=k+1) begin
            click(0);
            check(dut.control_mode==k,"custom harmonic mode ordering mismatch");
            turn(k!=1);
        end
        check(dut.core.raw1==4031 && dut.core.raw2==1088 &&
              dut.core.raw3==576 && dut.core.raw4==320,
              "EC11 did not independently edit all four harmonic targets");
        check(dut.core.master_target==8249,"harmonic adjustment changed master volume");
        click(0);check(dut.control_mode==0,"custom harmonic mode did not wrap");
        click(2);check(dut.timbre==0,"five-item menu did not return to piano");

        hold_button(2);
        check(dut.timbre==0 && dut.core.left_base==48 && dut.core.right_base==60 &&
              dut.core.raw1==4095 && dut.core.raw2==1024 && dut.core.raw3==512 &&
              dut.core.raw4==256 && dut.core.master_target==8249 && dut.control_mode==0,
              "S1 long press did not coherently restore defaults");
        check(dut.held==3,"parameter restore unexpectedly cleared held voices");
        // PT8211 selects right with WS low and left with WS high. Exercise
        // unequal channels so serial checking cannot pass on mono alone.
        for(k=0;k<9;k=k+1) click(0);
        check(dut.control_mode==9,"S4 did not select room enable control");
        turn(1);
        check(dut.core.effect_enable,"EC11 did not enable room effect");
        prior_stereo_frames=stereo_frames;prior_stereo_words=stereo_words;
        fx_end_frame=frames+1100;
        while(frames<fx_end_frame) @(negedge clk);
        check(dut.core.wet_applied==32 && stereo_frames>prior_stereo_frames &&
              stereo_words>prior_stereo_words,
              "physical room controls did not exercise nonidentical serial channels");
        $display("AUDIO_STEREO_SERIAL_TB_PASS WS low=right high=left; %0d nonidentical PCM frames, %0d checked serial words",
                 stereo_frames-prior_stereo_frames,stereo_words-prior_stereo_words);
        hold_button(2);
        check(!dut.core.effect_enable && dut.control_mode==0 && dut.held==3,
              "room test restore changed held voices or retained effect enable");
        click(1);check(dut.sustain,"ordinary sustain short press failed");
        click(1);check(!dut.sustain,"ordinary sustain did not toggle off");
        hold_button(1);
        check(dut.sostenuto && !dut.sustain,"selective sustain long press leaked short action");
        click(1);check(dut.sustain && dut.sostenuto,"two sustain controls cannot overlap");
        physical=16'h0100;
        repeat(4000) @(negedge clk);
        $display("SUSTAIN_CHECK held=%h gated=%h sustain=%b sost=%b latch=%h env=%h",dut.held,dut.gated,dut.sustain,dut.sostenuto,dut.core.sost_latched,dut.core.voice_envelopes);
        check(dut.held==right_mask && dut.gated==3,"released same-note instance lost sustain or identity");
        click(1);
        check(!dut.sustain && dut.sostenuto && dut.gated==3,
              "ordinary sustain removal released selectively held voice");
        hold_button(1);
        check(!dut.sostenuto && !dut.sustain && dut.held==right_mask && dut.gated==right_mask,
              "selective sustain did not release only eligible key-up voice");

        hold_button(0);
        physical=0;
        repeat(70000) @(negedge clk);
        check(!dut.muting && dut.occupied==0 && !dut.sustain && !dut.sostenuto,
              "S4 panic did not drain voices and hold controls");
        physical=16'h0013;
        repeat(4000) @(negedge clk);
        check(dut.blocked,"undioded three-corner ghost did not fault/block input");
        physical=0;
        repeat(100000) @(negedge clk);
        check(!dut.blocked && !dut.muting && dut.occupied==0,
              "physical ghost did not recover on full release");
        physical=16'h0001;
        repeat(20000) @(negedge clk);
        check(dut.held!=0 && !dut.blocked,"physical key could not play after ghost recovery");
        physical=0;
        hold_button(0);
        repeat(70000) @(negedge clk);
        check(!dut.blocked && !dut.muting && dut.occupied==0 && nonzero>10 &&
              !dut.core.panel_overflow && !dut.core.adc_overrun,
              "board final state or physical-input transport invalid");
        $display("AUDIO_BOARD_TB_PASS five-preset menu, four harmonic edits, physical keys/buttons/EC11, ghost recovery, %0d stereo words %0d nonzero",words,nonzero);
        $finish;
    end
    initial begin #80000000;$fatal(1,"physical board bench timed out");end
endmodule
