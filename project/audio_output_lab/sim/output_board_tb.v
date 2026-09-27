`timescale 1ns/1ps
module output_board_tb #(parameter SHIFT=0,parameter EDGE=0,parameter INV=0);
    reg clk=0;always #10 clk=~clk;
    reg [15:0] physical=0;reg [3:0] cols=15;wire [3:0] rows;
    reg [2:0] buttons=7;reg a=1,b=1;
    wire bck,ws,din,pa,led;
    output_top #(.TONE_SHIFT(SHIFT),.EDGE_SPACING(EDGE),.INVERT(INV),.ROW_CYCLES(20),.DEBOUNCE_FRAMES(2),
        .BUTTON_CYCLES(2),.LONG_CYCLES(500),.EC11_CYCLES(2),.EC11_SAMPLES(2)) dut(
        clk,a,b,buttons,cols,rows,bck,ws,din,pa,led);
    integer r,c,pass;
    reg [3:0] low_rows,low_cols;
    always @* begin
        // Undioded switch graph, including propagation through floating rows.
        // A simple selected-row lookup would incorrectly model diode keys.
        low_rows=0;low_cols=0;
        for(r=0;r<4;r=r+1) if(rows[r]===1'b0) low_rows[r]=1;
        for(pass=0;pass<8;pass=pass+1)
            for(r=0;r<4;r=r+1) for(c=0;c<4;c=c+1)
                if(physical[r*4+c] && (low_rows[r] || low_cols[c])) begin low_rows[r]=1;low_cols[c]=1;end
        cols=~low_cols;
    end
    integer bit_index=0,words=0,nonzero=0,cycles=0,last_ce=0,frame_valids=0;
    reg [19:0] word=0;reg signed [15:0] expected=0;
    always @(posedge clk) if(!dut.rst) begin
        cycles=cycles+1;
        if(dut.sample_ce) begin
            if(last_ce!=0 && (cycles-last_ce!=1040 || frame_valids!=1)) $fatal;
            last_ce=cycles;frame_valids=0;expected=dut.dac_sample;
        end
        if(dut.final_valid) frame_valids=frame_valids+1;
        if(dut.deadline || pa!==0) $fatal;
    end
    always @(posedge bck) if(!dut.rst) begin
        #1;
        if(ws!==(bit_index>=20)) $fatal;
        word={word[18:0],din};
        if(bit_index==19 || bit_index==39) begin
            if(word[19:16]!=0 || word[15:0]!==expected) begin
                $display("serial mismatch bit=%0d got=%h expected=%h",bit_index,word,expected);$fatal;
            end
            words=words+1;if(expected!=0) nonzero=nonzero+1;
        end
        bit_index=(bit_index+1)%40;
    end
    task click;input integer k;begin buttons[k]=0;repeat(12) @(negedge clk);buttons[k]=1;repeat(12) @(negedge clk);end endtask
    task turn;
        begin {a,b}=2'b10;repeat(20) @(negedge clk);
        {a,b}=2'b00;repeat(20) @(negedge clk);
        {a,b}=2'b01;repeat(20) @(negedge clk);
        {a,b}=2'b11;repeat(20) @(negedge clk);end
    endtask
    reg [6:0] old_base;integer n,held_count;
    initial begin
        repeat(1000) @(negedge clk);if(dut.volume_index!=18 || dut.timbre!=0) $fatal;physical=16'h0180;
        repeat(12000) @(negedge clk);
        if(dut.engine.bank.slots[0].slot.held_note!=60 || dut.engine.bank.slots[1].slot.held_note!=60 || dut.engine.bank.held!=3) $fatal;
        click(0);old_base=dut.engine.left_base;turn;
        repeat(100) @(negedge clk);
        if(dut.engine.left_base==old_base || dut.engine.bank.slots[0].slot.held_note!=60) $fatal;
        physical=16'h0100;repeat(2000) @(negedge clk);
        if(dut.engine.bank.held!=2) $fatal;
        // Switch while an old voice is still releasing, then start pluck.
        click(2);physical=16'h0101;repeat(6000) @(negedge clk);
        if(dut.timbre!=1 || dut.engine.bank.slots[2].slot.held_timbre!=1 || dut.deadline) $fatal;
        physical=16'h0013;repeat(3000) @(negedge clk);
        if(!dut.blocked) $fatal;
        physical=0;repeat(650000) @(negedge clk);
        if(dut.blocked || dut.muting || dut.occupied!=0 || nonzero<10) begin $display("end blocked=%b muting=%b occupied=%h nonzero=%0d gain=%0d fault=%b",dut.blocked,dut.muting,dut.occupied,nonzero,dut.engine.gain,dut.fault);$fatal;end
        $display("OUTPUT_BOARD_TB_PASS physical matrix/buttons/encoder, two-zone identity, ghost recovery, %0d stereo words %0d nonzero",words,nonzero);$finish;
    end
    initial begin #20000000;$fatal;end
endmodule
