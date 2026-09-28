`timescale 1ns/1ps
module audio_equivalence_tb;
    reg clk=0;always #10 clk=~clk;
    reg rst=1,ce=0,valid=0,off=0;
    reg [31:0] token=1;
    reg [6:0] note=48;
    reg [2:0] preset=0;
    wire ready0,ready1,out0,out1,clip0,clip1,dead0,dead1;
    wire signed [15:0] pcm0,pcm1;
    wire [7:0] occ0,occ1,held0,held1;
    custom_gallery_bank baseline(.clk(clk),.rst(rst),.sample_ce(ce),.event_valid(valid),
        .event_ready(ready0),.event_off(off),.event_token(token),.event_note(note),.event_timbre(preset),
        .pedal(1'b0),.sostenuto(1'b0),.reference_release(16'd3),.glide_index(3'd0),
        .lead_attack_index(2'd2),.bend_factor(17'd65536),
        .coeff0(9'd256),.coeff1(9'd64),.coeff2(9'd32),.coeff3(9'd16),
        .occupied(occ0),.held(held0),.out_valid(out0),.out_sample(pcm0),.clipped(clip0),.deadline_missed(dead0));
    audio_voice_bank candidate(.clk(clk),.rst(rst),.sample_ce(ce),.event_valid(valid),
        .event_ready(ready1),.event_off(off),.event_token(token),.event_note(note),.event_timbre(preset),
        .pedal(1'b0),.sostenuto(1'b0),.reference_release(16'd3),.glide_index(3'd0),
        .lead_attack_index(2'd2),.bend_factor(17'd65536),.lead_bend_factor(17'd65536),
        .envelope_override(1'b0),.custom_hold(1'b0),.adsr_attack(16'd68),.adsr_decay(16'd6),
        .adsr_sustain(16'd32768),.adsr_release(16'd3),
        .coeff0(9'd256),.coeff1(9'd64),.coeff2(9'd32),.coeff3(9'd16),
        .occupied(occ1),.held(held1),.out_valid(out1),.out_sample(pcm1),.clipped(clip1),.deadline_missed(dead1));
    integer tick=0,frames=0,total=0,which,k;
    always @(negedge clk) begin
        if(rst) begin tick=0;ce=0;end
        else begin ce=tick==1039;tick=(tick+1)%1040;end
    end
    always @(posedge clk) begin
        #1;
        if(!rst) begin
            if(out0!==out1||ready0!==ready1||occ0!==occ1||held0!==held1||dead0||dead1) begin
                $display("handshake/state mismatch preset=%0d",preset);$fatal;
            end
            if(out0) begin
                if(pcm0!==pcm1||clip0||clip1) begin
                    $display("PCM mismatch preset=%0d frame=%0d old=%0d new=%0d",preset,frames,pcm0,pcm1);$fatal;
                end
                frames=frames+1;total=total+1;
            end
        end
    end
    task send_event;
        input integer id,key,stop;
        begin
            @(negedge clk);while(!ready0||!ready1) @(negedge clk);
            valid=1;off=stop;token=id;note=key;
            @(negedge clk);valid=0;
            repeat(12) @(negedge clk);
        end
    endtask
    initial begin
        for(which=0;which<5;which=which+1) begin
            rst=1;valid=0;repeat(5) @(negedge clk);
            case(which) 0:preset=0;1:preset=2;2:preset=3;3:preset=4;4:preset=5;endcase
            rst=0;frames=0;
            send_event(1,36,0);send_event(2,60,0);send_event(3,84,0);
            while(frames<1100) @(negedge clk);
            send_event(1,36,1);send_event(2,60,1);send_event(3,84,1);
            while(frames<1800) @(negedge clk);
        end
        $display("AUDIO_EQUIVALENCE_TB_PASS %0d default bank frames across five presets",total);$finish;
    end
    initial begin #250000000;$fatal;end
endmodule
