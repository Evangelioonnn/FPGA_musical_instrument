`timescale 1ns/1ps
module custom_harmonic_tb;
    localparam N=8;
    reg clk=0; always #10 clk=~clk;
    reg rst=1,sample_ce=0;
    reg [N*32-1:0] phases=0;
    reg [N*16-1:0] envelopes=0;
    reg [N*16-1:0] brightness={N{16'hffff}};
    reg [N*7-1:0] notes={N{7'd60}};
    reg [N*3-1:0] timbres=0;
    reg [8:0] coeff0=256,coeff1=64,coeff2=32,coeff3=16;
    wire signed [19:0] custom_sample,reference_sample;
    wire [N-1:0] custom_valid,reference_valid;
    wire custom_deadline,reference_deadline;
    custom_harmonic_tone #(.N(N)) custom(
        clk,rst,sample_ce,phases,envelopes,coeff0,coeff1,coeff2,coeff3,
        custom_sample,custom_valid,custom_deadline);
    gallery_shared_tone #(.PROFILE(6),.BALANCE_MODE(0),.N(N)) reference(
        clk,rst,sample_ce,phases,envelopes,brightness,notes,timbres,
        reference_sample,reference_valid,reference_deadline);

    integer i,frame_index,custom_seen,reference_seen,diff_count;
    integer signed actual[0:N-1];
    integer signed expected[0:N-1];
    integer signed accumulator;
    integer signed pcm_bound,max_pcm;
    always @(posedge clk) begin
        if(!rst) begin
            for(i=0;i<N;i=i+1) begin
                if(custom_valid[i]) begin actual[i]=custom_sample;custom_seen=custom_seen+1;end
                if(reference_valid[i]) begin expected[i]=reference_sample;reference_seen=reference_seen+1;end
            end
        end
    end

    task render_frame;
        input integer phase_seed;
        integer v;
        begin
            custom_seen=0;reference_seen=0;
            for(v=0;v<N;v=v+1) begin
                phases[v*32 +: 32]=phase_seed+(v*32'h03210987);
                envelopes[v*16 +: 16]=16'hffff-(v*16'd4051);
            end
            @(negedge clk);sample_ce=1;
            @(negedge clk);sample_ce=0;
            repeat(220) @(negedge clk);
            if(custom_seen!=N || reference_seen!=N)
                $fatal(1,"voice scan incomplete custom=%0d reference=%0d",custom_seen,reference_seen);
            if(custom_deadline || reference_deadline)
                $fatal(1,"audio frame deadline missed");
            for(v=0;v<N;v=v+1)
                if((^actual[v])===1'bx) $fatal(1,"unknown voice sample");
        end
    endtask

    task check_default_equivalence;
        integer v;
        begin
            for(v=0;v<N;v=v+1)
                if(actual[v]!==expected[v])
                    $fatal(1,"default mismatch voice %0d: custom=%0d reference=%0d",
                        v,actual[v],expected[v]);
        end
    endtask

    initial begin
        custom_seen=0;reference_seen=0;max_pcm=0;
        repeat(6) @(negedge clk);rst=0;
        // Multiple phase/envelope patterns verify the accepted piano's
        // default coefficients against its existing shared renderer.
        for(frame_index=0;frame_index<32;frame_index=frame_index+1) begin
            render_frame(32'h017391ab*frame_index);
            check_default_equivalence();
        end

        // Holding a note while changing one harmonic at a time must alter the
        // rendered spectrum without invalid values or deadline misses.
        coeff0=256;coeff1=0;coeff2=0;coeff3=0;
        render_frame(32'h19283746);
        if(actual[0]==expected[0]) $fatal(1,"fundamental-only scan had no effect");
        coeff0=0;coeff1=256;coeff2=0;coeff3=0;
        render_frame(32'h19283746);
        if(actual[0]==expected[0]) $fatal(1,"second-harmonic-only scan had no effect");
        coeff0=0;coeff1=0;coeff2=256;coeff3=0;
        render_frame(32'h19283746);
        if(actual[0]==expected[0]) $fatal(1,"third-harmonic-only scan had no effect");
        coeff0=0;coeff1=0;coeff2=0;coeff3=256;
        render_frame(32'h19283746);
        if(actual[0]==expected[0]) $fatal(1,"fourth-harmonic-only scan had no effect");

        // Eight same-phase voices at normalized full-slider weights must fit
        // the existing mixer headroom. Sweep phase to sample the peak bound.
        coeff0=92;coeff1=92;coeff2=92;coeff3=92;
        for(frame_index=0;frame_index<64;frame_index=frame_index+1) begin
            custom_seen=0;
            for(i=0;i<N;i=i+1) begin
                phases[i*32 +: 32]=frame_index*32'h04000000;
                envelopes[i*16 +: 16]=16'hffff;
            end
            @(negedge clk);sample_ce=1;
            @(negedge clk);sample_ce=0;
            repeat(220) @(negedge clk);
            if(custom_seen!=N || custom_deadline) $fatal(1,"full-input voice scan failed");
            accumulator=0;
            for(i=0;i<N;i=i+1) begin
                if(actual[i]>47110 || actual[i]<-47110)
                    $fatal(1,"voice exceeds normalized coefficient bound: %0d",actual[i]);
                accumulator=accumulator+actual[i];
            end
            pcm_bound=accumulator/16;
            if(pcm_bound>23560 || pcm_bound< -23560)
                $fatal(1,"eight-voice mix exceeds PCM headroom: %0d",pcm_bound);
            if(pcm_bound>max_pcm) max_pcm=pcm_bound;
            if(-pcm_bound>max_pcm) max_pcm=-pcm_bound;
        end
        $display("CUSTOM_HARMONIC_TB_PASS default exact, 4 slider sweeps, 8-voice peak=%0d",max_pcm);
        $finish;
    end
endmodule
