`timescale 1ns/1ps
module poly_core_tb #(parameter N=16,parameter SHIFT=1);
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,ev=0,off=0,pedal=0,sost=0;
    reg [31:0] token=0;reg [6:0] note=60;
    reg [15:0] attack=68,decay=6,sustain_level=32768,release_step=3;
    wire ready,accepted,rejected,valid,clip,deadline;
    wire [31:0] rejects,unmatched;
    wire [N-1:0] occupied,held,gated;
    wire signed [15:0] sample;
    wire signed [31:0] raw;
    piano_poly_core #(.N(N),.OUTPUT_SHIFT(SHIFT)) dut(
        clk,rst,ce,ev,ready,off,token,note,attack,decay,sustain_level,release_step,
        pedal,sost,accepted,rejected,rejects,unmatched,occupied,held,gated,
        valid,sample,raw,clip,deadline);
    reg [31:0] m_phase[0:N-1],m_step[0:N-1],m_token[0:N-1];
    integer m_level[0:N-1],m_state[0:N-1],m_attack[0:N-1],m_decay[0:N-1];
    integer m_sustain[0:N-1],m_release[0:N-1];
    reg [N-1:0] m_used,m_held,m_sost;
    integer fd,frames_written=0,max_latency=0,clip_frames=0,peak=0;
    integer i,j,k,slot,expect_rejected,latency;
    reg [1023:0] filename;
    reg signed [63:0] expected_raw,expected_pcm,p;
    reg [31:0] ph2,ph3,ph4;
    function integer sine;
        input [31:0] phase;
        real value;
        begin
            value=32767.0*$sin(6.2831853071795864769*phase[31:20]/4096.0);
            sine=$rtoi(value+(value<0?-0.5:0.5));
        end
    endfunction
    function [31:0] frequency_step;
        input integer pitch;
        real f;
        begin
            f=440.0*(2.0**((pitch-69)/12.0));
            frequency_step=$rtoi(f*4294967296.0/(50000000.0/1040.0)+0.5);
        end
    endfunction
    function signed [63:0] rounded;
        input signed [63:0] value;input integer bits;
        begin rounded=value<0 ? -(((-value)+(64'sd1<<(bits-1)))>>>bits) :
                                (value+(64'sd1<<(bits-1)))>>>bits;end
    endfunction
    task model_reset;
        begin
            m_used=0;m_held=0;m_sost=0;
            for(j=0;j<N;j=j+1) begin
                m_phase[j]=0;m_step[j]=0;m_token[j]=0;m_level[j]=0;m_state[j]=0;
                m_attack[j]=68;m_decay[j]=6;m_sustain[j]=32768;m_release[j]=3;
            end
        end
    endtask
    task reset_all;
        begin rst=1;ce=0;ev=0;pedal=0;sost=0;repeat(5) @(negedge clk);
            rst=0;model_reset;repeat(3) @(negedge clk);end
    endtask
    task command;
        input kind;input [31:0] id;input [6:0] pitch;
        begin
            while(!ready) @(negedge clk);
            off=kind;token=id;note=pitch;ev=1;@(negedge clk);ev=0;
            repeat(N+4) @(negedge clk);
            slot=-1;
            if(kind) begin
                for(j=0;j<N;j=j+1) if(m_used[j] && m_token[j]==id) slot=j;
                if(slot>=0 && id!=0) begin
                    m_held[slot]=0;
                    if(!(pedal || (sost && m_sost[slot]))) begin m_state[slot]=4;m_release[slot]=release_step;end
                end
            end else begin
                expect_rejected=(id==0 || pitch<36 || pitch>84);
                for(j=0;j<N;j=j+1) if(m_used[j] && m_token[j]==id) expect_rejected=1;
                for(j=N-1;j>=0;j=j-1) if(!m_used[j]) slot=j;
                if(slot<0) expect_rejected=1;
                if(!expect_rejected) begin
                    m_used[slot]=1;m_held[slot]=1;m_token[slot]=id;
                    m_phase[slot]=0;m_step[slot]=frequency_step(pitch);
                    m_level[slot]=0;m_state[slot]=1;
                    m_attack[slot]=attack;m_decay[slot]=decay;
                    m_sustain[slot]=sustain_level;m_release[slot]=release_step;
                end
            end
            if(occupied!==m_used || held!==m_held) begin $display("event identity mismatch N=%0d used=%h expected=%h",N,occupied,m_used);$fatal;end
        end
    endtask
    task set_sostenuto;
        input value;
        begin
            sost=value;
            if(value) m_sost=m_held&m_used;else m_sost=0;
            repeat(4) @(negedge clk);
        end
    endtask
    task one_frame;
        begin
            expected_raw=0;
            for(j=0;j<N;j=j+1) begin
                m_phase[j]=m_phase[j]+m_step[j];
                if(!m_held[j] && !(pedal || (sost && m_sost[j])) && m_state[j]!=0 && m_state[j]!=4)
                    begin m_state[j]=4;m_release[j]=release_step;end
                else case(m_state[j])
                    0:m_level[j]=0;
                    1:if(m_level[j]+(m_attack[j]==0?1:m_attack[j])>=65535) begin m_level[j]=65535;m_state[j]=2;end
                      else m_level[j]=m_level[j]+(m_attack[j]==0?1:m_attack[j]);
                    2:if(m_level[j]<=m_sustain[j]+(m_decay[j]==0?1:m_decay[j])) begin m_level[j]=m_sustain[j];m_state[j]=3;end
                      else m_level[j]=m_level[j]-(m_decay[j]==0?1:m_decay[j]);
                    3:m_level[j]=m_sustain[j];
                    4:if(m_level[j]<=(m_release[j]==0?1:m_release[j])) begin m_level[j]=0;m_state[j]=0;end
                      else m_level[j]=m_level[j]-(m_release[j]==0?1:m_release[j]);
                endcase
                if(m_state[j]==0) begin m_used[j]=0;m_held[j]=0;m_sost[j]=0;end
                ph2=m_phase[j]<<1;ph3=m_phase[j]+(m_phase[j]<<1);ph4=m_phase[j]<<2;
                p=sine(m_phase[j])*64'sd128+sine(ph2)*64'sd32+sine(ph3)*64'sd16+sine(ph4)*64'sd8;
                expected_raw=expected_raw+rounded(p*m_level[j],23);
            end
            expected_pcm=rounded(expected_raw,4+SHIFT);
            ce=1;@(negedge clk);ce=0;latency=1;
            while(!valid && latency<1040) begin @(negedge clk);latency=latency+1;end
            if(!valid || deadline || raw!==expected_raw[31:0]) begin
                $display("raw/deadline N=%0d frame=%0d got=%0d expected=%0d latency=%0d",N,frames_written,raw,expected_raw,latency);$fatal;
            end
            if(expected_pcm>32767) begin expected_pcm=32767;if(!clip)$fatal;end
            else if(expected_pcm< -32768) begin expected_pcm=-32768;if(!clip)$fatal;end
            else if(clip) $fatal;
            if(sample!==expected_pcm[15:0] || occupied!==m_used || held!==m_held) begin
                $display("PCM/state N=%0d frame=%0d got=%0d expected=%0d",N,frames_written,sample,expected_pcm);$fatal;
            end
            if(latency>max_latency) max_latency=latency;
            if(clip) clip_frames=clip_frames+1;
            if(sample<0 && -sample>peak) peak=-sample;
            if(sample>=0 && sample>peak) peak=sample;
            $fwrite(fd,"%0d\n",sample);frames_written=frames_written+1;
            repeat(1040-latency) @(negedge clk);
        end
    endtask
    task frames;input integer count;
        begin for(k=0;k<count;k=k+1) one_frame;end
    endtask
    initial begin
        $sformat(filename,"poly_%0d_shift%0d.txt",N,SHIFT);fd=$fopen(filename,"w");
        reset_all;frames(5);command(0,1,60);frames(1200);
        command(0,1,64);if(rejects!=1)$fatal;
        command(1,99,0);if(unmatched!=1)$fatal;
        command(1,1,0);release_step=65535;frames(8);
        reset_all;attack=65535;decay=1;sustain_level=65535;release_step=65535;
        // Different tokens at equal pitches remain independent instances.
        for(i=0;i<N;i=i+1) command(0,i+1,48);
        command(0,N+1,50);if(rejects!=1)$fatal;
        frames(400);command(1,1,0);frames(2);
        if(occupied[0] || !occupied[1]) $fatal;
        reset_all;attack=68;decay=6;sustain_level=32768;release_step=24;
        pedal=1;
        for(i=0;i<N;i=i+1) begin command(0,i+1,48+(i%25));command(1,i+1,0);end
        frames(1200);if(held!=0 || occupied!={N{1'b1}}) $fatal;
        pedal=0;frames(3000);if(occupied!=0)$fatal;
        reset_all;attack=65535;decay=1;sustain_level=65535;release_step=65535;
        command(0,1,60);command(0,2,64);frames(3);set_sostenuto(1);
        command(0,3,67);command(1,1,0);command(1,2,0);command(1,3,0);frames(3);
        if(occupied[2:0]!=3'b011 || held!=0)$fatal;
        pedal=1;set_sostenuto(0);frames(3);if(occupied[1:0]!=2'b11)$fatal;
        pedal=0;frames(3);if(occupied!=0)$fatal;
        // Events arriving just before a frame must survive scan preemption.
        while(!ready) @(negedge clk);
        ev=1;off=0;token=77;note=72;@(negedge clk);ev=0;
        ce=1;@(negedge clk);ce=0;repeat(1040+N+8) @(negedge clk);
        if(dut.tokens[0]!=77 || !occupied[0] || deadline)$fatal;
        // A deliberately too-early sample must report the deadline fault.
        ce=1;@(negedge clk);ce=0;repeat(2) @(negedge clk);
        ce=1;@(negedge clk);ce=0;@(negedge clk);if(!deadline)$fatal;
        $fclose(fd);
        $display("POLY_CORE_TB_PASS N=%0d shift=%0d frames=%0d maximum-latency=%0d peak=%0d clipping-frames=%0d",N,SHIFT,frames_written,max_latency,peak,clip_frames);$finish;
    end
endmodule
