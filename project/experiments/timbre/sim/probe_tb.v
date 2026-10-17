`timescale 1ns/1ps
// Real 50MHz / 1040 cadence and pin-level last-16-bit LSBJ receiver.
module probe_tb;
    reg clk=0;
    always #10 clk=~clk;
    wire fb,fw,fd,fp,pb,pw,pd,pp;
    fm_probe_top fm(clk,fb,fw,fd,fp);
    pluck_probe_top pluck(clk,pb,pw,pd,pp);
    defparam fm.probe.demo.SLOT_SAMPLES=512;
    defparam fm.probe.demo.GATE_SAMPLES=300;
    defparam pluck.probe.demo.SLOT_SAMPLES=512;
    defparam pluck.probe.demo.GATE_SAMPLES=300;
    serial_checker fc(clk,fm.probe.rst,fm.probe.sample_ce,fb,fw,fd,
        fm.probe.monitor_sample,fm.probe.monitor_sample);
    serial_checker pc(clk,pluck.probe.rst,pluck.probe.sample_ce,pb,pw,pd,
        pluck.probe.monitor_sample,pluck.probe.monitor_sample);
    integer f_requests=0,p_requests=0,f_results=0,p_results=0;
    integer f_audible=0,p_audible=0,f_latency=0,p_latency=0;
    integer f_max_latency=0,p_max_latency=0,f_commands=0,p_commands=0;
    reg f_pending=0,p_pending=0;
    always @(posedge clk) begin
        if(!fm.probe.rst) begin
            if(fm.probe.sample_ce) begin
                if(f_pending) $fatal(1,"FM missed deadline");
                f_requests=f_requests+1; f_pending=1; f_latency=0;
            end
            if(f_pending) f_latency=f_latency+1;
            if(f_latency>65 && f_pending) $fatal(1,"FM >64 cycle result latency");
            if(fm.probe.sample_valid) begin
                if(!f_pending) $fatal(1,"FM unsolicited result");
                f_pending=0; f_results=f_results+1;
                if(f_latency>f_max_latency) f_max_latency=f_latency;
                if(fm.probe.raw_sample!=0) f_audible=f_audible+1;
                if(^fm.probe.raw_sample===1'bx) $fatal(1,"FM unknown output");
            end
            if(fm.probe.cmd_valid && fm.probe.cmd_ready) f_commands=f_commands+1;
            if(fm.probe.cmd_rejected) $fatal(1,"FM demo command rejected");
            if(fm.probe.monitor_sample>511 || fm.probe.monitor_sample< -512)
                $fatal(1,"FM monitor bounds");
        end
        if(!pluck.probe.rst) begin
            if(pluck.probe.sample_ce) begin
                if(p_pending) $fatal(1,"Pluck missed deadline");
                p_requests=p_requests+1; p_pending=1; p_latency=0;
            end
            if(p_pending) p_latency=p_latency+1;
            if(p_latency>65 && p_pending) $fatal(1,"Pluck >64 cycle result latency");
            if(pluck.probe.sample_valid) begin
                if(!p_pending) $fatal(1,"Pluck unsolicited result");
                p_pending=0; p_results=p_results+1;
                if(p_latency>p_max_latency) p_max_latency=p_latency;
                if(pluck.probe.raw_sample!=0) p_audible=p_audible+1;
                if(^pluck.probe.raw_sample===1'bx) $fatal(1,"Pluck unknown output");
            end
            if(pluck.probe.cmd_valid && pluck.probe.cmd_ready) p_commands=p_commands+1;
            if(pluck.probe.cmd_rejected) $fatal(1,"Pluck demo command rejected");
            if(pluck.probe.monitor_sample>511 || pluck.probe.monitor_sample< -512)
                $fatal(1,"Pluck monitor bounds");
        end
    end
    initial begin
        #65000000;
        if(fc.frames<3000 || pc.frames<3000 || f_audible<2000 || p_audible<2000)
            $fatal(1,"Insufficient serial integration coverage");
        if(f_results!=f_requests || p_results!=p_requests || fp!==0 || pp!==0)
            $fatal(1,"Sample accounting or PA enable failure");
        if(f_commands<12 || p_commands<12) $fatal(1,"Insufficient command coverage");
        $display("PROBE_TB_PASS fm_frames=%0d pluck_frames=%0d fm_valid=%0d pluck_valid=%0d fm_latency=%0d pluck_latency=%0d fm_commands=%0d pluck_commands=%0d",
            fc.frames,pc.frames,f_results,p_results,f_max_latency-1,p_max_latency-1,f_commands,p_commands);
        $finish;
    end
endmodule
