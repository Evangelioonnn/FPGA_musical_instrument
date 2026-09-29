`timescale 1ns/1ps
module v2_latency_tb #(parameter P=12);
    reg clk=0;always #10 clk=~clk;
    reg pressed=0;
    wire [3:0] rows;
    wire [3:0] cols={3'b111,!(pressed && rows[0]===1'b0)};
    wire bck,ws,din,pa,led;
    audio_v2_top #(.PLUCK_N(P)) dut(clk,1'b1,1'b1,3'b111,cols,rows,bck,ws,din,pa,led);
    integer cycles=0,bit_index=0,scan_at=-1,accepted_at=-1,pcm_at=-1,serial_at=-1;
    integer start_at=0,trial,limit,worst=0;
    reg measuring=0;
    reg [19:0] word=0;
    always @(posedge clk) begin
        cycles=cycles+1;
        if(dut.rst) begin bit_index=0;word=0;end
        if(!dut.rst && measuring) begin
            if(dut.changed && dut.keys[0] && scan_at<0) scan_at=cycles;
            if(dut.core.bank.accepted && accepted_at<0) accepted_at=cycles;
            if(dut.final_valid && (dut.final_left!=0||dut.final_right!=0) && pcm_at<0) pcm_at=cycles;
            if(dut.deadline||dut.clip_seen||dut.blocked) $fatal(1,"latency-chain fault");
        end
    end
    always @(posedge bck) if(!dut.rst) begin
        #1;word={word[18:0],din};
        if(measuring && (bit_index==19||bit_index==39) && word[15:0]!=0 && serial_at<0)
            serial_at=cycles;
        bit_index=(bit_index+1)%40;
    end
    initial begin
        for(trial=0;trial<4;trial=trial+1) begin
            measuring=0;pressed=0;
            // Reinitialise the power-on reset for independent, silent trials.
            force dut.startup=0;repeat(5) @(negedge clk);release dut.startup;
            while(dut.rst) @(negedge clk);
            while(dut.core.gain_left!=8249 || dut.core.gain_right!=8249) @(negedge clk);
            repeat(trial*1831) @(negedge clk);
            scan_at=-1;accepted_at=-1;pcm_at=-1;serial_at=-1;
            @(negedge clk);start_at=cycles;pressed=1;measuring=1;limit=cycles+250000;
            while(serial_at<0) begin @(negedge clk);if(cycles>limit) $fatal(1,"digital path exceeded5ms");end
            if(scan_at<start_at || accepted_at<scan_at || pcm_at<accepted_at || serial_at<pcm_at)
                $fatal(1,"noncausal latency milestones");
            if(serial_at-start_at>worst) worst=serial_at-start_at;
            $display("V2_LATENCY_CASE trial=%0d scan=%0d accept=%0d PCM=%0d serial=%0d clocks",
                trial,scan_at-start_at,accepted_at-start_at,pcm_at-start_at,serial_at-start_at);
        end
        $display("V2_LATENCY_TB_PASS actual2500-row/8-frame debounce,4 press phases; physical closure to first nonzero serial word worst=%0d clocks (%0f ms); not analogue latency",worst,worst/50000.0);
        $finish;
    end
    initial begin #150000000;$fatal(1,"latency test timeout");end
endmodule
