`timescale 1ns/1ps
module looper_top_tb;
    reg sys_clk=0;always #10 sys_clk=~sys_clk;
    reg enc_a=0,enc_b=0;reg [2:0] button_n=7;
    reg [3:0] matrix_col_n=15;wire [3:0] matrix_row_n;
    wire hp_bck,hp_ws,hp_din,pa_en,status_led;
    reg [15:0] physical_keys=0;
    looper_session_top #(.ROW_CYCLES(8),.DEBOUNCE_FRAMES(2),.BUTTON_CYCLES(8),
        .ENCODER_CYCLES(8),.LONG_CYCLES(1000)) dut(.*);
    integer row,frames=0,nonzero=0,record_count=0,control_count=0,commits=0,drum_hits=0,max_render=0,render_cycles=0;
    always @* begin
        matrix_col_n=15;
        for(row=0;row<4;row=row+1)
            if(matrix_row_n[row]===1'b0) matrix_col_n=matrix_col_n & ~physical_keys[row*4+:4];
    end
    always @(posedge sys_clk) begin
        if(!dut.platform.rst) begin
            if(dut.platform.tx_sample_ce) begin frames=frames+1;render_cycles=0;end
            else render_cycles=render_cycles+1;
            if(dut.platform.record_event_valid && dut.platform.record_event_ready) begin
                if(dut.platform.record_event_kind==3) control_count=control_count+1;
                else record_count=record_count+1;
            end
            if(dut.platform.record_commit) commits=commits+1;
            if(dut.platform.drum_event_valid && dut.platform.drum_engine_ready) drum_hits=drum_hits+1;
            #1;
            if(dut.platform.final_valid) begin
                if((^dut.platform.audio_left)===1'bx || (^dut.platform.audio_right)===1'bx) $fatal(1,"top PCM has X");
                if(dut.platform.audio_left!=0 || dut.platform.audio_right!=0) nonzero=nonzero+1;
                if(render_cycles>max_render) max_render=render_cycles;
            end
            if(dut.platform.audio_deadline || dut.platform.drum_late!=0 || dut.platform.control_overflow) $fatal(1,"deadline/control overflow audio=%b drum=%0d control=%b",dut.platform.audio_deadline,dut.platform.drum_late,dut.platform.control_overflow);
        end
    end
    task short_key;
        input integer k;
        begin @(negedge sys_clk);button_n[k]=0;repeat(50) @(negedge sys_clk);
            button_n[k]=1;repeat(50) @(negedge sys_clk);play_frames(2);end
    endtask
    task play_frames;
        input integer n;integer target;
        begin target=frames+n;wait(frames>=target);@(negedge sys_clk);end
    endtask
    // Accelerate only the musical transport in this integration test. The
    // scanner, full 32/12 synthesis and PT8211 run at the real 1040-clock cadence.
    // Actual tempo/PCM timing has a separate non-forced metronome test.
    wire fast_tick=dut.platform.tx_sample_ce && dut.platform.transport_run;
    wire fast_beat=fast_tick && frames%96==0;
    wire fast_bar=fast_tick && frames%384==0;
    initial begin
        force dut.platform.tick_pulse=fast_tick;force dut.platform.beat_pulse=fast_beat;force dut.platform.bar_pulse=fast_bar;
        wait(!dut.platform.rst);play_frames(4);
        physical_keys=16'h0001;play_frames(1200);
        if(!dut.platform.held || nonzero<500) $fatal(1,"physical matrix did not produce PCM");
        physical_keys=0;play_frames(130);
        // Iterate all six menu entries, including actual pad input.
        repeat(5) short_key(0);
        if(dut.platform.selected_preset!=6) $fatal(1,"drum menu missing");
        physical_keys=16'h0002;play_frames(20);physical_keys=0;play_frames(10);
        if(drum_hits!=1 || dut.platform.drum_active==0) $fatal(1,"physical pad not sounded exactly once");
        short_key(0);if(dut.platform.selected_preset!=0) $fatal(1,"menu wrap");
        short_key(2);if(dut.platform.page!=1) $fatal(1,"looper page navigation");
        short_key(1);wait(dut.platform.recording);
        physical_keys=16'h0001;play_frames(24);physical_keys=0;play_frames(20);
        wait(commits==1);
        if(record_count!=2 || control_count!=3 || !dut.platform.layer_valid[0] || dut.platform.store.patch_mem[0][2:0]!=0) $fatal(1,"top note pair/patch recording failed count=%0d",record_count);
        play_frames(500);
        if(dut.platform.audio.event_router.route_faults!=0) $fatal(1,"replay route failed");
        short_key(0);wait(!dut.platform.transport_run);wait(!dut.platform.flushing);play_frames(20);
        if(dut.platform.audio.event_router.map_valid!=0 || dut.platform.recording) $fatal(1,"stop left held loop or active recorder");
        repeat(4) short_key(2);repeat(5) short_key(0);short_key(2);
        if(dut.platform.page!=1 || dut.platform.selected_preset!=6) $fatal(1,"drum recording selection");
        short_key(1);wait(dut.platform.recording);physical_keys=16'h0001;play_frames(24);physical_keys=0;play_frames(20);
        wait(commits==2);play_frames(500);
        if(!dut.platform.layer_valid[1] || dut.platform.store.patch_mem[1][2:0]!=6 || drum_hits<3) $fatal(1,"drum layer did not capture/replay kit");
        short_key(0);wait(!dut.platform.transport_run);wait(!dut.platform.flushing);play_frames(20);
        // Standalone metronome is enabled with a deliberate long S3 press.
        button_n[2]=0;repeat(1100) @(negedge sys_clk);button_n[2]=1;
        repeat(50) @(negedge sys_clk);play_frames(5);
        if(!dut.platform.met_enable || dut.platform.transport_run) $fatal(1,"global click cannot run alone");
        $display("LOOPER_TOP_TB_PASS physical_matrix=PCM six_presets=selectable drums=playable record_replay_stop=clean N=32 PLUCK=12 max_render=%0d",max_render);
        $finish;
    end
    initial begin #200000000;$fatal(1,"top watchdog frames=%0d rec=%b commits=%0d",frames,dut.platform.recording,commits);end
endmodule
