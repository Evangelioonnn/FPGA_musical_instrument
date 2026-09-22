`timescale 1ns/1ps
// Audio-rate arithmetic is unchanged; only idle clocks are shortened after
// initialization. board_tb separately uses the actual 1040 clocks/frame.
module render_tb;
    parameter FULL_RATE=0,FRAME_COUNT=769232,SECTION_FIRST=0,SECTION_COUNT=3,
        CHECK_TAILS=1,OUTPUT_PREFIX="",PASS_NAME="RENDER_TB_PASS";
    reg clk=0,rst=1,ce=0,valid=0,off=0,pedal=0;
    reg [31:0] token=1;reg [6:0] note=60;reg [1:0] tone=0;
    reg [15:0] release_step=3;reg [2:0] fm_r=3;reg [16:0] volume=65536;
    wire ready,accepted,rejected,ov,clip,deadline,gv;
    wire [31:0] rejects,unmatched;wire [7:0] occupied,held;
    wire signed [15:0] mixed,sample;wire [16:0] gain;
    integer frame=0,section=0,fd,events,hold_full=0,total=0;
    integer section_nonzero=0,max_active=0,active_count=0,i,last_nonzero=0;
    playable_bank bank(clk,rst,ce,valid,ready,off,token,note,tone,pedal,release_step,fm_r,
        accepted,rejected,rejects,unmatched,occupied,held,ov,mixed,clip,deadline);
    knob_gain master(clk,rst,ov,mixed,volume,gv,sample,gain);
    task clocks;input integer count;integer c;begin
        for(c=0;c<count;c=c+1)begin #10;clk=1;#10;clk=0;end
    end endtask
    task send;input integer is_off,id,key;begin
        if(!ready)$fatal(1,"render source unexpectedly blocked");
        off=is_off;token=id;note=key;valid=1;clocks(1);valid=0;clocks(12);
        if(!is_off)hold_full=5;
    end endtask
    genvar g;
    generate for(g=0;g<8;g=g+1)begin: journal
        always @(posedge clk)if(!rst && section==0)begin
            if(bank.slots[g].slot.on_cmd && bank.slots[g].slot.ready)
                $fwrite(events,"ON %0d %0d %0d\n",frame,g,bank.slots[g].slot.held_note);
            if(bank.slots[g].slot.off_cmd && bank.slots[g].slot.ready)
                $fwrite(events,"OFF %0d %0d %0d\n",frame,g,bank.slots[g].slot.r);
        end
    end endgenerate
    always @(posedge clk)if(!rst && (rejected || clip || deadline))$fatal(1,"render overload/clip/deadline frame=%0d tone=%0d",frame,section);
    initial begin
        if(SECTION_FIRST==0)begin
            events=$fopen({OUTPUT_PREFIX,"reference_events.txt"},"w");
            if(!events)$fatal(1,"Cannot open event journal");
        end
        for(section=SECTION_FIRST;section<SECTION_FIRST+SECTION_COUNT;section=section+1)begin
            rst=1;ce=0;valid=0;pedal=0;volume=65536;release_step=3;fm_r=3;tone=section;
            clocks(8);rst=0;clocks(8);
            case(section)
                0:fd=$fopen({OUTPUT_PREFIX,"reference_samples.txt"},"w");
                1:fd=$fopen({OUTPUT_PREFIX,"pluck_samples.txt"},"w");
                2:fd=$fopen({OUTPUT_PREFIX,"fm_samples.txt"},"w");
            endcase
            if(!fd)$fatal(1,"Cannot open PCM output");
            section_nonzero=0;max_active=0;last_nonzero=0;
            for(frame=0;frame<FRAME_COUNT;frame=frame+1)begin
                case(frame)
                    2404:send(0,1,60);
                    33654:send(1,1,60);
                    72115:send(0,2,64);
                    103365:begin release_step=24;fm_r=0;send(1,2,64);end
                    144231:begin release_step=3;fm_r=3;send(0,3,67);end
                    175481:begin release_step=1;fm_r=7;send(1,3,67);end
                    206731:begin release_step=3;fm_r=3;pedal=1;send(0,4,60);end
                    211538:send(0,5,64);
                    216346:send(0,6,67);
                    221154:begin send(1,4,60);send(1,5,64);send(1,6,67);end
                    259615:begin pedal=0;clocks(20);end
                    307692:begin volume=32768;send(0,7,72);end
                    319712:send(1,7,72);
                    346154:begin volume=0;send(0,8,72);end
                    365385:volume=65536;
                    377404:send(1,8,72);
                endcase
                ce=1;clocks(1);ce=0;
                // 64 guard + 8 mixer + 2 gain clocks, with six spare clocks.
                clocks((FULL_RATE || hold_full>0)?1039:79);
                if(hold_full>0)hold_full=hold_full-1;
                $fwrite(fd,"%0d\n",sample);
                if(sample!=0)begin section_nonzero=section_nonzero+1;last_nonzero=frame;end
                active_count=0;for(i=0;i<8;i=i+1)active_count=active_count+occupied[i];
                if(active_count>max_active)max_active=active_count;
                total=total+1;
                if(frame%48077==0)begin $fflush(fd);if(SECTION_FIRST==0)$fflush(events);$display("RENDER_PROGRESS tone=%0d frame=%0d",section,frame);end
            end
            if(CHECK_TAILS && (occupied || sample || section_nonzero<100000))$fatal(1,"Natural tails did not end tone=%0d occupied=%h last=%0d",section,occupied,last_nonzero);
            $fclose(fd);
            $display("RENDER_SECTION tone=%0d samples=%0d nonzero=%0d max_active=%0d last_nonzero=%0d",section,frame,section_nonzero,max_active,last_nonzero);
        end
        if(SECTION_FIRST==0)$fclose(events);
        $display("%0s samples=%0d first=%0d sections=%0d tails_checked=%0d full_rate=%0d",PASS_NAME,total,SECTION_FIRST,SECTION_COUNT,CHECK_TAILS,FULL_RATE);$finish;
    end
endmodule
