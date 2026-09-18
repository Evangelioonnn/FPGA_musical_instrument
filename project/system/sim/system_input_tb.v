`timescale 1ns/1ps
`include "../../instrument/sim/transport_tb.v"
module system_input_tb;
    reg clk=0,rst=1;reg [15:0] switches=0;wire [3:0] rows,cols,unused_cols;
    reg ea=0,eb=0,button=1;reg [111:0] mapping;
    reg adc_valid=0;reg [11:0] adc=4095;reg pressure_enable=0;
    wire adc_ready;wire [16:0] pressure;
    wire ev,er,cv,cr,fault,blocked,ghost,pe,ps,button_state,ee;wire [1:0] kind;wire [6:0] note;wire [8:0] velocity;
    wire [3:0] addr;wire [31:0] data,faults;wire [15:0] keys;
    reg hv=0;reg [3:0] ha=0;reg [31:0] hd=0;wire hr,ack,ok,source;
    wire ce,valid,clip,panic,bck,ws,din;wire signed [15:0] sample;
    wire [7:0] occupied,held,gated;wire [16:0] gain;
    integer i,adc_tick=0,samples=0,on_count=0,off_count=0,snapshots=0;
    wire sv;wire [228:0] sd;
    time first_press=0,first_event=0,first_serial=0;
    always #10 clk=~clk;
    matrix_network model(switches,rows,cols,unused_cols);
    control_surface surface(clk,rst,panic,cols,rows,ea,eb,button,mapping,9'd256,
        adc_valid,adc,12'd0,12'd4095,12'd0,pressure_enable,adc_ready,pressure,
        ev,kind,note,velocity,er,cv,addr,data,cr,fault,blocked,ghost,pe,ps,button_state,ee,keys,faults);
    system_engine engine(.clk(clk),.rst(rst),.sample_ce(ce),.emergency(fault),.event_valid(ev),.event_kind(kind),.event_note(note),
        .event_value(7'd0),.event_velocity(velocity),.event_ready(er),.local_cfg_valid(cv),.local_cfg_addr(addr),.local_cfg_data(data),.local_cfg_ready(cr),
        .host_cfg_valid(hv),.host_cfg_addr(ha),.host_cfg_data(hd),.host_cfg_ready(hr),.pressure_gain(pressure),
        .cfg_ack(ack),.cfg_accepted(ok),.cfg_applied(),.cfg_source_host(source),.sample(sample),.sample_valid(valid),.clipped(clip),.panic(panic),
        .snapshot_valid(sv),.snapshot_data(sd),.wave_valid(),.wave_sample(),.wave_index(),.occupied(occupied),.held(held),.gated(gated),.gain(gain));
    pt8211_tx tx(clk,rst,sample,sample,ce,bck,ws,din);
    serial_checker serial(clk,rst,ce,bck,ws,din,sample,sample);
    always @(posedge clk) if(!rst) begin
        adc_valid<=0;
        if(adc_tick==49999)begin adc_tick<=0;adc_valid<=adc_ready;end else adc_tick<=adc_tick+1;
        if(ev && er)begin
            if(kind==0)begin on_count=on_count+1;if(first_event==0)first_event=$time;end
            if(kind==1)off_count=off_count+1;
        end
        if(valid)begin samples=samples+1;if(clip || ^sample===1'bx)$fatal(1,"Input integration audio invalid");end
        if(sv)snapshots=snapshots+1;
        if(ack && !ok)$fatal(1,"Control rejected unexpectedly");
    end
    always @(ws)if(!rst)begin #2;
        if(first_serial==0 && serial.expected!=0)first_serial=$time;
    end
    task host_write;input [3:0] a;input [31:0] d;begin
        @(negedge clk);hv=1;ha=a;hd=d;@(posedge clk);while(!hr)@(posedge clk);
        @(negedge clk);hv=0;
    end endtask
    task enc_position;input [1:0] p;begin {ea,eb}=p;#300000;end endtask
    initial begin
        for(i=0;i<16;i=i+1)mapping[i*7 +:7]=60+i;
        repeat(16)@(negedge clk);rst=0;#3000000;
        if(blocked)$fatal(1,"Surface not armed");first_press=$time;switches=1;
        #3000000;if(held!=1 || on_count!=1)$fatal(1,"Physical press not routed");
        // Change mapping while held; original identity must still receive note_off.
        mapping[6:0]=72;switches=3;#3000000;if(held!=3)$fatal(1,"Two-key chord");
        enc_position(2);enc_position(3);enc_position(1);enc_position(0);
        #3000000;if(engine.core.master_volume!=61440)$fatal(1,"Encoder volume not applied");
        pressure_enable=1;adc=1024;#12000000;
        if(gain>=45000 || pe || ps)$fatal(1,"Pressure did not control expression");
        host_write(4,1);#100000;switches=0;#3000000;
        if(held!=0 || gated!=3 || off_count!=2)$fatal(1,"Held transpose off/sustain");
        host_write(6,1);#100000;
        if(held || gated || engine.core.sustain || engine.core.sostenuto)$fatal(1,"Panic failed");
        #3000000;switches=1;#3000000;
        if(on_count!=3 || engine.core.notes[6:0]!=72 && engine.core.notes[13:7]!=72 && engine.core.notes[20:14]!=72)
            $fatal(1,"New mapping not used after release");
        switches=16'h0013;#3000000;if(!ghost || !blocked || gated!=0 || faults!=1)$fatal(1,"Ghost did not silence core");
        switches=0;#3000000;
        if(blocked || ghost)$fatal(1,"Physical all-up recovery");
        if(first_event-first_press>2000000 || first_serial-first_press>10000000 || first_serial==0 || snapshots<1 || serial.frames<1500)
            $fatal(1,"Latency/coverage");
        $display("SYSTEM_INPUT_TB_PASS on=%0d off=%0d frames=%0d control_to_event_ns=%0d control_to_serial_ns=%0d snapshots=%0d ghost_release=1",
            on_count,off_count,serial.frames,first_event-first_press,first_serial-first_press,snapshots);$finish;
    end
    initial begin #75000000;$fatal(1,"Input integration timeout");end
endmodule
