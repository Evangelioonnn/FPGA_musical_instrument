`timescale 1ns/1ps
module poly_board_tb #(parameter N=16,parameter SHIFT=1);
    reg clk=0;always #10 clk=~clk;
    reg a=1,b=1;reg [2:0] buttons=3'b111;
    reg [15:0] physical_keys=0;
    wire [3:0] rows;
    reg [3:0] columns;
    wire bck,ws,din,pa,led;
    piano_poly_top #(.N(N),.OUTPUT_SHIFT(SHIFT),.ROW_CYCLES(8),.DEBOUNCE_FRAMES(2),
        .BUTTON_CYCLES(4),.LONG_CYCLES(200),.EC11_CYCLES(2),.EC11_SAMPLES(2)) dut(
        clk,a,b,buttons,columns,rows,bck,ws,din,pa,led);
    integer r,c,samples=0;
    always @* begin
        columns=4'b1111;
        for(r=0;r<4;r=r+1) for(c=0;c<4;c=c+1)
            if(physical_keys[r*4+c] && rows[r]===1'b0) columns[c]=0;
    end
    always @(negedge clk) if(!dut.rst) begin
        if(dut.final_valid) begin
            samples=samples+1;
            if((^dut.final_sample)===1'bx || dut.clip || dut.deadline)$fatal;
        end
    end
    task clocks;input integer n;begin repeat(n) @(negedge clk);end endtask
    task click;input integer index;
        begin buttons[index]=0;clocks(20);buttons[index]=1;clocks(20);end
    endtask
    initial begin
        clocks(3000);if(dut.blocked)$fatal;
        physical_keys=16'h0001;clocks(3000);
        if(dut.bank.occupied!=1 || dut.bank.held!=1 || dut.bank.notes[0]!=48)$fatal;
        physical_keys=16'h0003;clocks(3000);
        if(dut.bank.held!=3 || dut.bank.notes[1]!=50)$fatal;
        click(1);if(!dut.sustain)$fatal;
        physical_keys=0;clocks(3000);
        if(dut.bank.held!=0 || dut.bank.occupied!=3)$fatal;
        physical_keys=16'h0001;clocks(3000);
        if(dut.bank.held!=4 || dut.bank.occupied!=7)$fatal;
        // One physical key can leave independent sustained strikes behind.
        physical_keys=0;clocks(3000);
        click(1);if(dut.sustain)$fatal;
        click(0);if(dut.mode!=1)$fatal;
        // The known EC11 quadrature sequence increments the left octave.
        a=1;b=0;clocks(20);a=0;b=0;clocks(20);a=0;b=1;clocks(20);a=1;b=1;clocks(20);
        if(dut.left_base!=60)$fatal;
        physical_keys=16'h0001;clocks(3000);
        if(dut.bank.notes[3]!=60)$fatal;
        physical_keys=0;clocks(3000);
        click(2);clocks(600000);
        if(dut.bank.occupied!=0 || dut.muting || dut.deadline || pa!==0)$fatal;
        if(samples<500)$fatal;
        $display("POLY_BOARD_TB_PASS N=%0d samples=%0d matrix/restrike/pedal/octave/encoder/panic",N,samples);$finish;
    end
endmodule
