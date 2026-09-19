`timescale 1ns/1ps
module pluck_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,sample_ce=0,cmd_valid=0;
    reg [1:0] cmd_kind=0;
    reg [6:0] note=60;
    reg [8:0] velocity=205;
    reg [31:0] seed=2060;
    wire cmd_ready,cmd_rejected,active,sample_valid;
    wire signed [15:0] sample;
    pluck_voice dut(clk,rst,sample_ce,cmd_valid,cmd_kind,note,velocity,seed,
        cmd_ready,cmd_rejected,active,sample,sample_valid);
    integer count=0,latency,max_latency=0,fd,i,j,n,k,init_clocks,tokens=0;
    integer notes[0:9];integer velocities[0:9];
    integer saved[0:63];
    // Every sample_ce owns one response token; reset may discard outstanding work.
    always @(posedge clk) begin
        if(rst) tokens=0;
        else begin
            if(sample_ce) tokens=tokens+1;
            #2;
            if(sample_valid) tokens=tokens-1;
            if(tokens<0 || tokens>1) fail("sample response duplicated or lost");
        end
    end
    task fail;
        input [511:0] message;
        begin $display("FAIL: %0s",message);$fatal(1);end
    endtask
    task command;
        input [1:0] kind;input [6:0] pitch;input [8:0] vel;input [31:0] noise_seed;
        input expected_reject;
        begin
            @(negedge clk);cmd_kind=kind;note=pitch;velocity=vel;seed=noise_seed;cmd_valid=1;
            while(!cmd_ready) @(negedge clk);
            @(posedge clk);#1;
            if(cmd_rejected!==expected_reject) fail("command reject mismatch");
            @(negedge clk);cmd_valid=0;
        end
    endtask
    task take_sample;
        begin
            @(negedge clk);sample_ce=1;
            @(posedge clk);#1;latency=0;
            while(!sample_valid) begin
                @(negedge clk);sample_ce=0;
                @(posedge clk);#1;latency=latency+1;
                if(latency>64) fail("sample exceeded 64 cycles");
            end
            if(^sample===1'bx) fail("unknown sample");
            if(latency>max_latency) max_latency=latency;
            @(negedge clk);sample_ce=0;
            count=count+1;
        end
    endtask
    task initialize_voice;
        input [6:0] pitch;input [8:0] vel;input [31:0] noise_seed;
        begin
            command(0,pitch,vel,noise_seed,0);
            init_clocks=0;
            while(dut.state!=0) begin
                @(posedge clk);#1;init_clocks=init_clocks+1;
                if(init_clocks>3000) fail("initialization exceeded 60us");
            end
        end
    endtask
    initial begin
        repeat(5) @(posedge clk);
        @(negedge clk);rst=0;
        repeat(5) begin take_sample;if(sample!==0) fail("reset not silent");end
        command(0,35,100,1,1);if(active) fail("illegal low note activated");
        command(0,85,100,1,1);if(active) fail("illegal high note activated");
        command(3,60,100,1,1);if(active) fail("reserved activated");
        command(0,36,256,0,0);
        repeat(3) begin take_sample;if(sample!==0) fail("init leaked uninitialized memory");end
        command(2,0,0,0,0);take_sample;if(active || sample!==0) fail("init panic");
        command(0,36,256,1,0);command(1,0,0,0,0);
        take_sample;if(active || sample!==0) fail("off during init");
        command(0,36,256,1,0);command(0,84,256,2,0);
        repeat(3000) @(posedge clk);
        if(!active || dut.length!=47) fail("init retrigger");
        command(3,0,0,0,1);if(!active) fail("rejection damaged voice");
        command(0,60,0,0,0);
        for(i=0;i<7213;i=i+1) take_sample;
        if(active || sample!==0) fail("zero velocity did not release");
        initialize_voice(60,511,2060);
        if(dut.held_velocity!=256) fail("velocity clamp");
        @(negedge clk);sample_ce=1;
        @(posedge clk);#1;
        @(negedge clk);sample_ce=0;cmd_valid=1;cmd_kind=2;
        @(posedge clk);#1;
        if(!sample_valid || sample!==0 || active) fail("pipeline panic must close sample token");
        @(negedge clk);cmd_valid=0;
        repeat(20) begin @(posedge clk);#1;if(sample_valid) fail("panic duplicated sample");end
        initialize_voice(36,256,2036);take_sample;
        @(negedge clk);rst=1;@(posedge clk);@(negedge clk);rst=0;
        take_sample;if(sample!==0 || active) fail("reset stale RAM");
        // Identical seed/note reproduces the excitation even after another voice.
        initialize_voice(60,256,2060);
        for(i=0;i<64;i=i+1) begin take_sample;saved[i]=sample;end
        initialize_voice(36,256,3456);repeat(8) take_sample;
        initialize_voice(60,256,2060);
        for(i=0;i<64;i=i+1) begin take_sample;if(sample!==saved[i]) fail("retrigger nondeterministic");end
        initialize_voice(60,256,0);
        for(i=0;i<64;i=i+1) begin take_sample;saved[i]=sample;end
        initialize_voice(60,256,1);
        for(i=0;i<64;i=i+1) begin take_sample;if(sample!==saved[i]) fail("seed zero lockup");end
        // Repeated offs must not restart the release envelope or make it louder.
        command(1,0,0,0,0);repeat(100) take_sample;
        k=dut.release_left;command(1,0,0,0,0);
        if(dut.release_left!=k) fail("repeated off restarted release");
        command(0,60,0,0,0);
        if(dut.release_left!=k) fail("zero velocity restarted release");
        for(i=0;i<7113;i=i+1) take_sample;
        if(active || sample!==0) fail("repeated off release duration");
        // A legal command concurrent with a sample owns a silent response.
        @(negedge clk);cmd_valid=1;cmd_kind=0;note=60;velocity=256;seed=2060;sample_ce=1;
        @(posedge clk);#1;
        if(!sample_valid || sample!==0) fail("on/sample priority lost token");
        @(negedge clk);cmd_valid=0;sample_ce=0;
        repeat(3000) @(posedge clk);
        @(negedge clk);cmd_valid=1;cmd_kind=1;sample_ce=1;
        @(posedge clk);#1;
        if(sample_valid || !dut.pending) fail("off/sample inserted silent sample");
        @(negedge clk);cmd_valid=0;sample_ce=0;
        latency=0;
        while(!sample_valid) begin @(posedge clk);#1;latency=latency+1;if(latency>64) fail("off/sample lost token");end
        // Independent physical/model checks consume these raw captures.
        for(j=0;j<3;j=j+1) begin
            if(j==0) begin n=36;fd=$fopen("pitch36.txt","w");end
            else if(j==1) begin n=60;fd=$fopen("pitch60.txt","w");end
            else begin n=84;fd=$fopen("pitch84.txt","w");end
            initialize_voice(n,256,2000+n);
            for(i=0;i<120000;i=i+1) begin take_sample;$fdisplay(fd,"%0d",sample);end
            $fclose(fd);
            command(1,0,0,0,0);
            for(i=0;i<7213;i=i+1) take_sample;
            if(active || sample!==0) fail("release not silent");
        end
        // Same note/seed at four velocities; final two must be identical.
        fd=$fopen("velocity.txt","w");
        for(j=0;j<4;j=j+1) begin
            if(j==0) k=64;else if(j==1) k=128;else if(j==2) k=256;else k=511;
            initialize_voice(60,k,2060);
            for(i=0;i<4096;i=i+1) begin take_sample;$fdisplay(fd,"%0d",sample);end
        end
        $fclose(fd);
        // Exact retrigger and panic determinism, and 150ms release shape.
        fd=$fopen("release.txt","w");initialize_voice(60,256,2060);
        for(i=0;i<5000;i=i+1) take_sample;
        command(1,0,0,0,0);
        for(i=0;i<7300;i=i+1) begin take_sample;$fdisplay(fd,"%0d",sample);end
        $fclose(fd);
        notes[0]=48;notes[1]=55;notes[2]=60;notes[3]=64;notes[4]=67;
        notes[5]=72;notes[6]=60;notes[7]=60;notes[8]=60;notes[9]=60;
        for(j=0;j<6;j=j+1) velocities[j]=205;
        velocities[6]=154;velocities[7]=64;velocities[8]=128;velocities[9]=230;
        fd=$fopen("audition.txt","w");
        for(j=0;j<10;j=j+1) begin
            initialize_voice(notes[j],velocities[j],2000+notes[j]+j);
            for(i=0;i<36058;i=i+1) begin
                if(i==25481) command(1,0,0,0,0);
                take_sample;$fdisplay(fd,"%0d",sample);
            end
        end
        $fclose(fd);
        $display("PLUCK_TB_PASS samples=%0d max_latency=%0d",count,max_latency);
        $finish;
    end
    initial begin #1000000000;fail("watchdog");end
endmodule
