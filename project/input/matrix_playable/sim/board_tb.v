`timescale 1ns/1ps
module board_tb;
    reg clk=0,a=1,b=1;reg [2:0] buttons=7;reg [15:0] physical=0;
    wire [3:0] rows,cols;wire bck,ws,din,pa,led;
    reg [3:0] low;
    integer r,frames=0,serial_clocks=0,cycle=0,frame_start=0,publish_at=-1,nonzero=0,detents=0;
    reg [15:0] bits=0;reg signed [15:0] expected=0,right=0;
    time last_bck=0,press_time=0,latency=0;
    always #10 clk=~clk;
    always @*for(r=0;r<4;r=r+1)low[r]=rows[r]===1'b0;
    playable_matrix_network switches(physical,low,cols);
    matrix_playable_top #(.BUTTON_CYCLES(16),.LONG_CYCLES(3000),.EC11_CYCLES(10)) dut(
        clk,a,b,buttons,cols,rows,bck,ws,din,pa,led);
    always @(posedge clk)if(!dut.rst)begin
        cycle=cycle+1;
        if(dut.step_valid)detents=detents+1;
        if(dut.sample_ce)begin
            if(frame_start && cycle-frame_start!=1040)$fatal(1,"Changed sampling cadence");
            if(frame_start && publish_at!=frame_start)$fatal(1,"Missing completed audio frame");
            frame_start=cycle;
        end
        if(dut.final_valid)begin
            if(cycle-frame_start>100 || publish_at==frame_start)$fatal(1,"Sample deadline/repeated output");
            publish_at=frame_start;
        end
        if(dut.deadline)$fatal(1,"Deadline flag");
        for(r=0;r<4;r=r+1)if(rows[r]===1'b1)$fatal(1,"Inactive matrix row driven high");
    end
    always @(bck)if($time>2000)begin
        if(last_bck && $time-last_bck!=260)$fatal(1,"BCK period");last_bck=$time;
    end
    always @(din or ws)if($time>2000 && bck!==0)$fatal(1,"Serial data changed at high clock");
    always @(posedge bck)begin bits={bits[14:0],din};serial_clocks=serial_clocks+1;end
    always @(ws)if($time>2000)begin
        if(serial_clocks!=20)$fatal(1,"Serial slot clocks");
        if(ws)right=bits;
        else begin
            if($signed(bits)!==expected || right!==expected)$fatal(1,"Serial PCM frame=%0d got=%0d expected=%0d",frames,$signed(bits),expected);
            if(expected!=0)begin
                nonzero=nonzero+1;
                if(!latency && press_time)latency=$time-press_time;
            end
            expected=dut.final_sample;frames=frames+1;
        end
        serial_clocks=0;
    end
    task pause;input integer cycles;begin repeat(cycles)@(negedge clk);end endtask
    task click;input integer key;begin buttons[key]=0;pause(50);buttons[key]=1;pause(50);end endtask
    task detent_down;begin
        {a,b}=2'b01;pause(50);{a,b}=2'b00;pause(50);{a,b}=2'b10;pause(50);{a,b}=2'b11;pause(50);
    end endtask
    initial begin
        pause(100000);if(dut.blocked)$fatal(1,"Startup not armed");
        press_time=$time;physical=1;pause(150000);
        if(dut.occupied!=1 || !latency || latency>10000000)$fatal(1,"Input-to-digital audio latency %0t",latency);
        click(2);physical=3;pause(150000);
        if(dut.engine.bank.slots[1].slot.held_timbre!=1)$fatal(1,"Physical button/pluck");
        click(2);physical=7;pause(150000);
        if(dut.engine.bank.slots[2].slot.held_timbre!=2)$fatal(1,"Physical button/FM");
        detent_down;detent_down;
        if(dut.volume_index!=22 || detents!=2)$fatal(1,"Encoder coupling");
        click(1);physical=0;pause(150000);
        if(!dut.sustain || dut.engine.bank.held!=0 || dut.occupied[2:0]!=7)$fatal(1,"Physical key release/sustain");
        buttons[0]=0;pause(4000);buttons[0]=1;pause(800000);
        if(dut.occupied || dut.final_sample || dut.sustain || dut.release_mode)$fatal(1,"Panic failed to clear at silence");
        physical=16'h0013;pause(700000);if(!dut.blocked || dut.occupied)$fatal(1,"Ghost not blocked");
        physical=1;pause(150000);if(!dut.blocked || dut.occupied)$fatal(1,"Held recovery phantom note");
        physical=0;pause(150000);if(dut.blocked)$fatal(1,"All-up recovery");
        physical=1;pause(150000);if(!dut.occupied || nonzero<100)$fatal(1,"Post-fault note missing");
        $display("BOARD_TB_PASS serial_frames=%0d nonzero=%0d detents=%0d digital_input_latency_ns=%0d real_scan_timing=1",frames,nonzero,detents,latency);$finish;
    end
    initial begin #100000000;$fatal(1,"board timeout");end
endmodule
