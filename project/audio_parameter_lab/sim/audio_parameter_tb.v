`timescale 1ns/1ps
module audio_parameter_tb;
    reg clk=0;
    always #10 clk=~clk;
    reg rst=1,frame_run=1;
    reg [4:0] frame_count=0;
    wire sample_ce=frame_run && frame_count==31;
    always @(posedge clk) if(rst || !frame_run) frame_count<=0;
                         else frame_count<=frame_count+1'b1;
    reg local_valid=0,host_valid=0;
    reg [4:0] local_addr=0,host_addr=0;
    reg [31:0] local_value=0,host_value=0;
    wire local_ready,host_ready;
    wire ack_valid,ack_source,ack_accepted,ack_applied;
    wire [4:0] ack_addr;
    wire [31:0] ack_value;
    reg adc_valid=0;
    reg [11:0] adc_ch0=0,adc_ch1=4095,adc_ch2=1024,adc_ch3=512,adc_ch4=256;
    wire adc_ready,adc_overrun;
    wire [4:0] fader_acquired;
    wire [1:0] master_owner;
    wire [16:0] master_volume_target;
    wire [2:0] selected_preset,release_index,glide_index,vibrato_speed;
    wire [6:0] zone_left,zone_right,vibrato_depth;
    wire ordinary_sustain,selective_sustain,envelope_override,custom_hold;
    wire signed [4:0] bend_index;
    wire [1:0] lead_attack_index;
    wire [15:0] adsr_attack,adsr_decay,adsr_sustain,adsr_release;
    wire effect_enable;
    wire [7:0] effect_mix;
    wire [11:0] raw_ch1,raw_ch2,raw_ch3,raw_ch4;
    wire harmonic_snapshot_valid;
    reg harmonic_snapshot_ready=1;
    wire [11:0] harmonic_snapshot_ch1,harmonic_snapshot_ch2;
    wire [11:0] harmonic_snapshot_ch3,harmonic_snapshot_ch4;
    wire panic_pulse,params_updated;
    wire [31:0] parameter_revision;
    audio_parameter_service dut(
        .clk(clk),.rst(rst),.sample_ce(sample_ce),
        .local_valid(local_valid),.local_ready(local_ready),
        .local_addr(local_addr),.local_value(local_value),
        .host_valid(host_valid),.host_ready(host_ready),
        .host_addr(host_addr),.host_value(host_value),
        .ack_valid(ack_valid),.ack_source(ack_source),.ack_addr(ack_addr),
        .ack_value(ack_value),.ack_accepted(ack_accepted),.ack_applied(ack_applied),
        .adc_valid(adc_valid),.adc_ready(adc_ready),.adc_ch0(adc_ch0),
        .adc_ch1(adc_ch1),.adc_ch2(adc_ch2),.adc_ch3(adc_ch3),.adc_ch4(adc_ch4),
        .adc_overrun(adc_overrun),.fader_acquired(fader_acquired),
        .master_owner(master_owner),.master_volume_target(master_volume_target),
        .selected_preset(selected_preset),.zone_left(zone_left),.zone_right(zone_right),
        .ordinary_sustain(ordinary_sustain),.selective_sustain(selective_sustain),
        .release_index(release_index),.glide_index(glide_index),.bend_index(bend_index),
        .lead_attack_index(lead_attack_index),.adsr_attack(adsr_attack),
        .adsr_decay(adsr_decay),.adsr_sustain(adsr_sustain),.adsr_release(adsr_release),
        .envelope_override(envelope_override),.custom_hold(custom_hold),
        .vibrato_depth(vibrato_depth),.vibrato_speed(vibrato_speed),
        .effect_enable(effect_enable),.effect_mix(effect_mix),
        .raw_ch1(raw_ch1),.raw_ch2(raw_ch2),.raw_ch3(raw_ch3),.raw_ch4(raw_ch4),
        .harmonic_snapshot_valid(harmonic_snapshot_valid),
        .harmonic_snapshot_ready(harmonic_snapshot_ready),
        .harmonic_snapshot_ch1(harmonic_snapshot_ch1),
        .harmonic_snapshot_ch2(harmonic_snapshot_ch2),
        .harmonic_snapshot_ch3(harmonic_snapshot_ch3),
        .harmonic_snapshot_ch4(harmonic_snapshot_ch4),
        .panic_pulse(panic_pulse),.params_updated(params_updated),
        .parameter_revision(parameter_revision)
    );
    integer age,ack_total=0;
    reg [31:0] saved_revision;
    reg [47:0] held_bundle;
    always @(posedge clk) begin
        #1;
        if(!rst && ack_valid) ack_total=ack_total+1;
    end
    initial begin
        #2000000;
        $fatal(1,"parameter bench timed out");
    end

    task check;
        input condition;
        input [2047:0] message;
        begin if(condition !== 1'b1) $fatal(1,"%0s",message); end
    endtask

    task reset_service;
        begin
            @(negedge clk);rst=1;local_valid=0;host_valid=0;adc_valid=0;
            frame_run=1;harmonic_snapshot_ready=1;
            repeat(3) @(negedge clk);
            rst=0;repeat(2) @(negedge clk);
        end
    endtask

    task queue_cfg;
        input source;
        input [4:0] address;
        input [31:0] value;
        begin
            @(negedge clk);
            if(source) begin host_valid=1;host_addr=address;host_value=value; end
            else begin local_valid=1;local_addr=address;local_value=value; end
            #1;
            age=0;
            while(!(source ? host_ready : local_ready)) begin
                @(negedge clk);age=age+1;
                if(age>200) $fatal(1,"configuration capture stalled");
            end
            @(posedge clk);#1;
            @(negedge clk);
            if(source) host_valid=0;else local_valid=0;
        end
    endtask

    task await_ack;
        input source;
        input [4:0] address;
        input accepted;
        begin
            age=0;
            while(!ack_valid) begin
                @(negedge clk);age=age+1;
                if(age>200) $fatal(1,"configuration response stalled addr=%0d src=%0d pending=%0d bundle=%0d ready=%0d",address,source,dut.pending_cfg,harmonic_snapshot_valid,harmonic_snapshot_ready);
            end
            check(ack_source==source && ack_addr==address,"ack source/address mismatch");
            check(ack_accepted==accepted && ack_applied==accepted,"ack result mismatch");
            check(params_updated==accepted,"request applied/update discrepancy");
            @(negedge clk);
        end
    endtask

    task configure;
        input source;
        input [4:0] address;
        input [31:0] value;
        input accepted;
        begin queue_cfg(source,address,value);await_ack(source,address,accepted); end
    endtask

    task publish_scan;
        input [11:0] c0,c1,c2,c3,c4;
        begin
            @(negedge clk);
            while(!adc_ready) @(negedge clk);
            adc_ch0=c0;adc_ch1=c1;adc_ch2=c2;adc_ch3=c3;adc_ch4=c4;adc_valid=1;
            @(negedge clk);adc_valid=0;
            age=0;
            while(!adc_ready) begin
                @(negedge clk);age=age+1;
                if(age>200) $fatal(1,"ADC scan commit stalled");
            end
            @(negedge clk);
        end
    endtask

    integer k;
    reg expected_source;
    initial begin
        reset_service;
        check(master_volume_target==8249 && selected_preset==0 &&
              zone_left==48 && zone_right==60,"default control baseline mismatch");
        check(raw_ch1==4095 && raw_ch2==1024 && raw_ch3==512 && raw_ch4==256,
              "default harmonic vector mismatch");
        check(adsr_attack==68 && adsr_decay==6 && adsr_sustain==32768 &&
              adsr_release==3 && !envelope_override,"default ADSR mismatch");
        saved_revision=parameter_revision;
        configure(1,0,1,0);
        check(selected_preset==0 && parameter_revision==saved_revision,"legacy ID1 accepted");
        configure(0,1,65537,0);
        configure(1,29,123,0);
        configure(0,0,7,0);
        check(master_volume_target==8249,"illegal volume changed target");

        // The pending payload, rather than a live bus, must determine the commit.
        @(negedge clk);frame_run=0;
        queue_cfg(0,3,72);
        local_addr=1;local_value=65536;
        repeat(8) @(negedge clk);
        check(!ack_valid && zone_left==48,"state changed away from sample boundary");
        frame_run=1;
        await_ack(0,3,1);
        check(zone_left==72 && master_volume_target==8249,"captured payload changed under stall");

        reset_service;
        @(negedge clk);local_valid=1;host_valid=1;
        local_addr=1;host_addr=1;local_value=100;host_value=200;
        expected_source=0;
        for(k=0;k<8;k=k+1) begin
            while(!ack_valid) @(negedge clk);
            check(ack_source==expected_source && ack_accepted && ack_applied,
                  "continuously competing sources did not alternate");
            check(master_volume_target==(expected_source ? 200 : 100),
                  "fairness response does not match state");
            expected_source=!expected_source;
            @(negedge clk);
        end
        local_valid=0;host_valid=0;
        repeat(40) @(negedge clk);
        configure(1,1,65000,1);
        configure(0,2,1000,1);
        check(master_volume_target==65536,"relative gain upper clamp failed");
        configure(1,2,-70000,0);
        check(master_volume_target==65536,"invalid relative range changed state");
        configure(1,2,-65536,1);
        check(master_volume_target==0,"relative gain decrement failed");
        configure(0,2,-1,1);
        check(master_volume_target==0,"relative gain lower clamp failed");
        configure(0,9,-8,1);
        check(bend_index==-8,"signed bend minimum failed");
        configure(1,9,9,0);
        configure(1,11,0,0);
        configure(1,11,1024,1);
        configure(0,12,512,1);
        configure(1,13,12345,1);
        configure(0,14,64,1);
        check(envelope_override && adsr_attack==1024 && adsr_decay==512 &&
              adsr_sustain==12345 && adsr_release==64,"ADSR did not apply/enable override");
        configure(1,24,0,1);
        check(!envelope_override,"preset envelope restoration failed");
        configure(0,5,1,1);configure(1,6,1,1);
        queue_cfg(1,30,1);
        while(!ack_valid) @(negedge clk);
        check(panic_pulse && !ordinary_sustain && !selective_sustain && bend_index==0,
              "panic did not clear held controls");
        @(negedge clk);
        check(!panic_pulse,"panic was not a one-clock pulse");
        configure(0,16,64,1);configure(1,17,7,1);
        configure(1,18,1,1);configure(0,19,128,1);
        configure(1,15,1,1);
        check(vibrato_depth==64 && vibrato_speed==7 && effect_enable &&
              effect_mix==128 && custom_hold,"expression/effect parameters did not apply");
        configure(1,16,65,0);configure(0,19,129,0);

        configure(0,31,1,1);
        check(master_volume_target==8249 && selected_preset==0 && zone_left==48 &&
              !ordinary_sustain && !selective_sustain && !custom_hold &&
              !envelope_override && vibrato_depth==0 && !effect_enable &&
              effect_mix==32 && fader_acquired==0,"coherent restore defaults failed");

        // Pickup must not overwrite a host target until crossing or touching it.
        configure(1,1,32000,1);
        publish_scan(1000,4095,1024,512,256);
        publish_scan(1200,4095,1024,512,256);
        check(master_volume_target==32000 && !fader_acquired[0],"pickup moved before crossing");
        publish_scan(2100,4095,1024,512,256);
        check(master_volume_target==33608 && fader_acquired[0] && master_owner==3,
              "master crossing did not engage");
        configure(1,1,40000,1);
        publish_scan(2200,4095,1024,512,256);
        check(master_volume_target==40000 && !fader_acquired[0],"host change did not rearm pickup");
        publish_scan(2600,4095,1024,512,256);
        check(master_volume_target==41610,"master pickup after host change failed");
        configure(1,1,45000,1);
        publish_scan(0,4095,1024,512,256);
        check(master_volume_target==0 && fader_acquired[0],"unacquired zero did not mute");
        publish_scan(4095,4095,1024,512,256);
        check(master_volume_target==65536,"ADC full-scale endpoint is not unity");

        configure(0,31,1,1);
        publish_scan(2000,1000,1024,100,256);
        check(raw_ch1==4095 && raw_ch3==512,"harmonics changed outside editable preset");
        configure(0,0,5,1);
        publish_scan(2100,1100,1024,100,256);
        check(raw_ch1==4095 && raw_ch2==1024 && raw_ch3==512 && raw_ch4==256,
              "independent pickup did not retain unacquired harmonics");
        check(!fader_acquired[1] && fader_acquired[2] && !fader_acquired[3] &&
              fader_acquired[4],"independent harmonic pickup flags mismatch");
        publish_scan(2200,4095,1300,600,300);
        check(raw_ch1==4095 && raw_ch2==1300 && raw_ch3==600 && raw_ch4==300,
              "harmonic channels did not independently cross/track");
        configure(1,21,2000,1);
        publish_scan(2300,4000,1400,600,300);
        check(raw_ch1==4000 && raw_ch2==2000 && !fader_acquired[2],
              "explicit harmonic write did not independently rearm");
        publish_scan(2400,3900,2100,600,300);
        check(raw_ch2==2100 && fader_acquired[2],"harmonic pickup crossing failed");

        // A coherent harmonic bundle must survive a slow downstream consumer.
        repeat(3) @(negedge clk);
        harmonic_snapshot_ready=0;
        configure(1,20,3000,1);
        held_bundle={harmonic_snapshot_ch1,harmonic_snapshot_ch2,
                     harmonic_snapshot_ch3,harmonic_snapshot_ch4};
        check(harmonic_snapshot_valid && harmonic_snapshot_ch1==3000,
              "harmonic bundle was not published");
        queue_cfg(1,21,2500);
        host_addr=21;host_value=1;
        repeat(80) begin
            @(negedge clk);
            check(!ack_valid && raw_ch2==2100 && harmonic_snapshot_valid &&
                {harmonic_snapshot_ch1,harmonic_snapshot_ch2,
                 harmonic_snapshot_ch3,harmonic_snapshot_ch4}==held_bundle,
                "backpressured harmonic bundle/payload was altered");
        end
        harmonic_snapshot_ready=1;
        await_ack(1,21,1);
        check(raw_ch2==2500,"harmonic transaction reread a live bus");
        repeat(3) @(negedge clk);

        // An overrun must reject the whole second scan, retaining the first.
        harmonic_snapshot_ready=0;
        configure(1,22,2000,1);
        @(negedge clk);
        adc_ch0=0;adc_ch1=4095;adc_ch2=1024;adc_ch3=512;adc_ch4=256;adc_valid=1;
        @(negedge clk);adc_valid=0;
        check(!adc_ready,"pending ADC scan was not retained");
        @(negedge clk);
        adc_ch0=4095;adc_ch1=0;adc_ch2=0;adc_ch3=0;adc_ch4=0;adc_valid=1;
        @(negedge clk);adc_valid=0;
        check(adc_overrun,"blocked ADC pulse did not report overrun");
        harmonic_snapshot_ready=1;
        while(!adc_ready) @(negedge clk);
        check(master_volume_target==0,"overrun substituted the second master scan");
        repeat(3) @(negedge clk);
        configure(0,31,1,1);
        check(raw_ch1==4095 && raw_ch2==1024 && raw_ch3==512 && raw_ch4==256 &&
              master_volume_target==8249,"final restoration was not coherent");
        $display("AUDIO_PARAMETER_TB_PASS fairness, payload retention, range rejection, pickup, coherent restore, overrun");
        $finish;
    end
endmodule
