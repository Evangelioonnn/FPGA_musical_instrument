`timescale 1ns/1ps
module render_tb #(parameter FULL_POOLS=0,IDLE_CYCLES=96);
    reg clk=0,rst=1,ce=0;
    reg [4:0] step_valid=0;
    reg signed [1:0] steps[0:4];
    wire [4:0] valid;
    wire signed [15:0] samples[0:4];
    wire [7:0] initializing;
    integer files[0:4],counts[0:4],peaks[0:4];
    integer n,j,k,extra_cycles,total=384616;
    always #10 clk=~clk;
    genvar g;
    generate for(g=0;g<5;g=g+1)begin: modes
        // Constant demo scores need at most four simultaneous voices outside
        // performance/timbre. Full-size physical tops are separately checked
        // by transport_tb; FULL_POOLS=1 retains every physical slot for comparison.
        knob_engine #(.MODE(g),.N(FULL_POOLS ? (g==2?8:16) : (g==0?16:g==1?4:g==2?8:2)))
            dut(clk,rst,ce,step_valid[g],steps[g],valid[g],samples[g]);
        always @(posedge clk)if(!rst)begin
            if(dut.deadline_missed || dut.bank_clip || dut.rejected_count || dut.queue_overflows)
                $fatal(1,"Render fault mode=%0d",g);
            if(valid[g])begin
                $fwrite(files[g],"%0d\n",samples[g]);counts[g]=counts[g]+1;
                if(samples[g]>peaks[g])peaks[g]=samples[g];
                if(-samples[g]>peaks[g])peaks[g]=-samples[g];
            end
        end
    end endgenerate
    generate for(g=0;g<8;g=g+1)begin: init_watch
        assign initializing[g]=modes[2].dut.bank.slots[g].slot.extra.pluck.initializing;
    end endgenerate
    initial begin
        files[0]=$fopen("performance_samples.txt","w");files[1]=$fopen("volume_samples.txt","w");
        files[2]=$fopen("timbre_samples.txt","w");files[3]=$fopen("release_samples.txt","w");
        files[4]=$fopen("echo_samples.txt","w");
        for(j=0;j<5;j=j+1)begin counts[j]=0;peaks[j]=0;steps[j]=0;end
        repeat(5)@(negedge clk);rst=0;
        for(n=0;n<total;n=n+1)begin
            // A deterministic human-like score: isolated steps, rapid ascending
            // run, reverse/repeated pitches, then complete silence after tails.
            step_valid=0;for(j=0;j<5;j=j+1)steps[j]=0;
            if(n==4807 || n==48077 || (n>=96154 && n<153846 && (n-96154)%4808==0))begin
                step_valid[0]=1;steps[0]=1;
            end
            if(n>=168269 && n<196154 && (n-168269)%4808==0)begin step_valid[0]=1;steps[0]=-1;end
            if(n>=48077 && n<50477 && (n-48077)%100==0)begin step_valid[1]=1;steps[1]=-1;end
            if(n>=144231 && n<146631 && (n-144231)%100==0)begin step_valid[1]=1;steps[1]=1;end
            if(n==96150 || n==192304 || n==288458)begin step_valid[2]=1;steps[2]=1;end
            if(n>=48000 && n<48500 && n%100==0)begin step_valid[3]=1;steps[3]=-1;end
            if(n>=144000 && n<144700 && n%100==0)begin step_valid[3]=1;steps[3]=1;end
            if(n>=96100 && n<97700 && n%100==0)begin step_valid[4]=1;steps[4]=1;end
            if(n>=288400 && n<290000 && n%100==0)begin step_valid[4]=1;steps[4]=-1;end
            ce=1;@(negedge clk);ce=0;step_valid=0;
            // Skip idle clock cycles only. Any frame containing pluck RAM
            // initialization retains the real 1040-cycle sample interval.
            repeat(23)@(negedge clk);
            extra_cycles=(|initializing)?1016:IDLE_CYCLES-24;
            repeat(extra_cycles)@(negedge clk);
        end
        repeat(120)@(negedge clk);
        for(j=0;j<5;j=j+1)begin
            if(counts[j]!=total)$fatal(1,"Render missing samples mode=%0d got=%0d",j,counts[j]);
            $fclose(files[j]);$display("RENDER mode=%0d samples=%0d peak=%0d",j,counts[j],peaks[j]);
        end
        if(samples[0]!=0 || modes[0].dut.occupied!=0)$fatal(1,"Performance tail did not finish");
        $display("RENDER_TB_PASS modes=5 samples_each=%0d full_pools=%0d idle_cycles=%0d stereo_mono_source=1",total,FULL_POOLS,IDLE_CYCLES);$finish;
    end
endmodule
