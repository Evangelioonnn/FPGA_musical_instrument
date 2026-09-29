`timescale 1ns/1ps
module v2_core_tb #(parameter P=16);
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,changed=0,ghost=0;
    reg [24:0] keys=0;
    reg [2:0] buttons=7;
    reg step_valid=0;reg signed [1:0] step=1;
    reg host_valid=0;wire host_ready;reg [4:0] host_addr=0;reg [31:0] host_value=0;
    reg adc_valid=0;wire adc_ready;reg [11:0] adc0=4095,adc1=4095,adc2=1024,adc3=512,adc4=256;
    wire ack,source,accepted,applied,final_valid,blocked,rejected,deadline,muting,clip;
    wire [4:0] ack_addr,mode;wire [31:0] ack_value,index;
    wire [2:0] preset;wire sustain,sostenuto;
    wire signed [15:0] left,right;
    wire [31:0] occupied,held,gated;
    wire snap_valid;wire [2367:0] snap;
    audio_v2_core #(.PLUCK_N(P),.KEYS(25),.SPLIT(12),.DIATONIC(0),.BUTTON_CYCLES(2),.LONG_CYCLES(2500)) dut(
        clk,rst,ce,keys,changed,ghost,keys==0,buttons,step_valid,step,
        host_valid,host_ready,host_addr,host_value,adc_valid,adc_ready,adc0,adc1,adc2,adc3,adc4,
        ack,source,accepted,applied,ack_addr,ack_value,
        final_valid,left,right,index,snap_valid,snap,preset,mode,sustain,sostenuto,blocked,rejected,deadline,
        occupied,held,gated,muting,clip);
    integer tick=0,frames=0,nonzero=0,snapshots=0,last_index=-1,i,host_captures=0;
    always @(posedge clk) if(!rst && host_valid && host_ready) host_captures=host_captures+1;
    always @(negedge clk) begin
        if(rst) begin tick=0;ce=0;end
        else begin ce=tick==1039;tick=(tick+1)%1040;end
    end
    always @(posedge clk) begin
        #1;
        if(!rst) begin
            if(deadline||clip||dut.panel_overflow) begin $display("deadline/clip/overflow");$fatal;end
            if(final_valid) begin
                if(^left===1'bx||^right===1'bx||dut.final_right_valid!==final_valid) $fatal;
                frames=frames+1;if(left!=0||right!=0) nonzero=nonzero+1;
                if(last_index>=0 && index<=last_index) $fatal;last_index=index;
            end
            if(snap_valid) begin
                if(snap[100:98]!==preset||snap[80:64]!==dut.master_target) $fatal;
                snapshots=snapshots+1;
            end
        end
    end
    task configure;
        input integer addr;input [31:0] value;input ok;
        integer prior_captures;
        begin
            prior_captures=host_captures;
            @(negedge clk);host_valid=1;host_addr=addr;host_value=value;
            #1;
            while(!host_ready) begin @(negedge clk);#1;end
            @(negedge clk);host_valid=0;
            while(!ack) @(negedge clk);
            if(host_captures!=prior_captures+1) $fatal(1,"host request lost or duplicated");
            if(!source||accepted!==ok||applied!==ok||ack_addr!=addr) begin
                $display("bad ACK addr=%0d accepted=%b applied=%b source=%b",addr,accepted,applied,source);$fatal;
            end
        end
    endtask
    task snapshot_keys;
        input [24:0] value;
        begin @(negedge clk);keys=value;changed=1;@(negedge clk);changed=0;repeat(2500) @(negedge clk);end
    endtask
    task wait_frames;input integer n;integer end_frame;
        begin end_frame=frames+n;while(frames<end_frame) @(negedge clk);end
    endtask
    task scan;
        begin @(negedge clk);while(!adc_ready) @(negedge clk);adc_valid=1;
        @(negedge clk);adc_valid=0;wait_frames(3);end
    endtask
    initial begin
        repeat(10) @(negedge clk);rst=0;wait_frames(550);
        if(blocked||preset!=0||dut.master_target!=8249) $fatal;
        configure(0,1,0);
        configure(4,48,1);snapshot_keys(25'h1001);
        if(held!=3||dut.voice_notes[6:0]!=48||dut.voice_notes[13:7]!=48) $fatal;
        configure(3,72,1);snapshot_keys(25'h1000);
        if(held!=2||dut.voice_notes[13:7]!=48) $fatal;
        configure(6,1,1);snapshot_keys(25'h1001);
        if(dut.voice_notes[20:14]!=72) $fatal;
        snapshot_keys(0);wait_frames(50);
        if(held!=0||dut.sost_latched!=2) $fatal;
        configure(5,1,1);configure(6,0,1);configure(5,0,1);
        configure(30,1,1);wait_frames(100);
        if(occupied!=0||muting||blocked||sustain||sostenuto) $fatal;
        configure(0,5,1);configure(3,48,1);configure(4,60,1);configure(1,65536,1);
        snapshot_keys(25'hff);wait_frames(100);
        for(i=0;i<4;i=i+1) begin
            configure(20+i,4095,1);wait_frames(140);
            if(dut.coeff0+dut.coeff1+dut.coeff2+dut.coeff3>368) $fatal;
        end
        wait_frames(150);if(dut.coeff0!=92||dut.coeff1!=92||dut.coeff2!=92||dut.coeff3!=92) $fatal;
        configure(1,0,1);wait_frames(550);if(left!=0||right!=0) $fatal;
        configure(1,8250,1);wait_frames(100);
        adc0=0;scan();wait_frames(100);if(dut.master_target!=0||left!=0||right!=0) $fatal;
        configure(31,1,1);wait_frames(180);
        if(preset!=0||dut.master_target!=8249||dut.coeff0!=256||dut.coeff1!=64||dut.coeff2!=32||dut.coeff3!=16) $fatal;
        snapshot_keys(0);configure(30,1,1);wait_frames(100);
        configure(0,4,1);configure(11,1024,1);configure(12,64,1);configure(13,40000,1);configure(14,256,1);
        snapshot_keys(1);wait_frames(100);
        if(!dut.bank.override_mask[0]||dut.bank.state_mem[0][174:159]!=1024) $fatal;
        configure(16,24,1);configure(9,8,1);configure(18,1,1);configure(19,64,1);wait_frames(2400);
        if(dut.lead_bend_factor==65536||dut.wet_applied!=64) $fatal;
        snapshot_keys(0);wait_frames(400);configure(18,0,1);wait_frames(100);
        if(dut.wet_applied!=0) $fatal;
        configure(30,1,1);wait_frames(100);
        if(nonzero<100||snapshots<4||occupied!=0||muting) $fatal;
        $display("V2_CORE_TB_PASS %0d frames %0d snapshots; 25 keys, token offs, config/ADC, 8 custom voices, ADSR, bend/vibrato, room",frames,snapshots);$finish;
    end
    initial begin #300000000;$fatal;end
endmodule
