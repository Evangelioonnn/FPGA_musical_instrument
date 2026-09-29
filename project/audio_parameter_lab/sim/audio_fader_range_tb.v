`timescale 1ns/1ps
module audio_fader_range_tb;
    reg clk=0;
    always #10 clk=~clk;
    reg rst=1,adc_valid=0;
    reg [11:0] adc_ch0=0;
    wire adc_ready,adc_overrun;
    wire [16:0] master_volume_target;
    wire [4:0] fader_acquired;
    wire harmonic_snapshot_valid;
    wire [11:0] ch1,ch2,ch3,ch4;
    audio_parameter_service dut(
        .clk(clk),.rst(rst),.sample_ce(1'b1),
        .local_valid(1'b0),.local_addr(5'd0),.local_value(32'd0),
        .host_valid(1'b0),.host_addr(5'd0),.host_value(32'd0),
        .adc_valid(adc_valid),.adc_ready(adc_ready),.adc_ch0(adc_ch0),
        .adc_ch1(12'd4095),.adc_ch2(12'd1024),.adc_ch3(12'd512),.adc_ch4(12'd256),
        .master_volume_target(master_volume_target),.adc_overrun(adc_overrun),
        .fader_acquired(fader_acquired),.harmonic_snapshot_valid(harmonic_snapshot_valid),
        .harmonic_snapshot_ready(1'b0),.harmonic_snapshot_ch1(ch1),
        .harmonic_snapshot_ch2(ch2),.harmonic_snapshot_ch3(ch3),.harmonic_snapshot_ch4(ch4)
    );
    integer code,expected,previous;
    initial begin
        repeat(3) @(negedge clk);rst=0;previous=0;
        for(code=0;code<4096;code=code+1) begin
            @(negedge clk);
            while(!adc_ready) @(negedge clk);
            adc_ch0=code;adc_valid=1;
            @(negedge clk);adc_valid=0;
            while(!adc_ready) @(negedge clk);
            expected=code==4095 ? 65536 : code*16+code/256;
            if(master_volume_target!==expected || !fader_acquired[0] || adc_overrun)
                $fatal(1,"ADC mapping/pickup code=%0d got=%0d expected=%0d",
                       code,master_volume_target,expected);
            if(master_volume_target<previous || master_volume_target-previous>17)
                $fatal(1,"master fader mapping is not continuous and monotonic");
            if(!harmonic_snapshot_valid || {ch1,ch2,ch3,ch4}!=
               {12'd4095,12'd1024,12'd512,12'd256})
                $fatal(1,"master-only scan changed a backpressured harmonic bundle");
            previous=master_volume_target;
        end
        $display("AUDIO_FADER_RANGE_TB_PASS all4096codes, exact unity/mute, monotonic gain, master-only progress under harmonic backpressure");
        $finish;
    end
    initial begin #2000000;$fatal(1,"fader range bench timed out");end
endmodule
