`timescale 1ns/1ps
module led_tb;
    reg clk=0,rst=1;reg [1:0] tone=0;reg pedal=0,mode=0,blocked=0,rejected=0;
    wire led;integer high_clocks=0,low_clocks=0,bits=0,frames=0;reg previous=0;reg [23:0] decoded=0,last=0;
    always #10 clk=~clk;
    playable_led #(.REFRESH_CYCLES(10000)) dut(clk,rst,tone,pedal,mode,blocked,rejected,led);
    always @(negedge clk)if(!rst)begin
        if(led)begin high_clocks=high_clocks+1;low_clocks=0;end
        else begin
            low_clocks=low_clocks+1;
            if(previous)begin
                if(high_clocks!=18 && high_clocks!=35)$fatal(1,"WS2812 high width %0d",high_clocks);
                decoded={decoded[22:0],high_clocks==35};high_clocks=0;bits=bits+1;
            end
            if(low_clocks==5000 && bits)begin
                if(bits!=24)$fatal(1,"WS2812 word length");
                last=decoded;frames=frames+1;bits=0;
            end
        end
        previous=led;
    end
    task next_frames;input integer n;integer target;begin target=frames+n;wait(frames>=target);@(posedge clk);end endtask
    initial begin
        repeat(5)@(posedge clk);rst=0;next_frames(2);if(last!=24'h000008)$fatal(1,"Default blue");
        tone=1;next_frames(2);if(last!=24'h080000)$fatal(1,"Pluck green");
        tone=2;pedal=1;next_frames(2);if(last!=24'h002020)$fatal(1,"FM pedal brightness");
        blocked=1;next_frames(2);if(last!=24'h001000)$fatal(1,"Fault red");
        $display("LED_TB_PASS words=%0d widths_18_35=1 grb_order=1",frames);$finish;
    end
    initial begin #3000000;$fatal(1,"led timeout");end
endmodule
