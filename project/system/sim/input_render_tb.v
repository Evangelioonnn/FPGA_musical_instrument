`timescale 1ns/1ps
// Audition the real input modules with compressed debounce and idle clocks.
// Real-time latency is covered separately by system_input_tb.
module input_render_tb;
    localparam FS=48077;
    reg clk=0,rst=1;reg [3:0] tick=0;wire ce=!rst && tick==0;
    reg [15:0] switches=0;wire [3:0] rows,cols,unused_cols;
    reg ea=0,eb=0;reg [111:0] mapping;
    reg adc_valid=0;reg [11:0] adc=4095;reg pressure_enable=0;
    wire adc_ready;wire [16:0] pressure;
    wire ev,er,cv,cr,fault,blocked,ghost;wire [1:0] kind;wire [6:0] note;wire [8:0] velocity;
    wire [3:0] addr;wire [31:0] data,faults;
    reg hv=0;reg [3:0] ha=0;reg [31:0] hd=0;wire hr,ack,ok;
    wire valid,clip,panic;wire signed [15:0] sample;
    wire [7:0] occupied,held,gated;
    integer i,n=0,f,audible=0,ons=0,offs=0;
    always #10 clk=~clk;
    always @(posedge clk)if(rst)tick<=0;else tick<=tick+1'b1;
    matrix_network model(switches,rows,cols,unused_cols);
    control_surface #(.ROW_CYCLES(4),.DB_FRAMES(2),.ENCODER_CYCLES(4),.ENCODER_AB(2)) surface(
        .clk(clk),.rst(rst),.external_panic(panic),.col_n(cols),.row_low(rows),.enc_a(ea),.enc_b(eb),.enc_button_n(1'b1),
        .note_map(mapping),.velocity(9'd256),.adc_valid(adc_valid),.adc_raw(adc),.cal_low(12'd0),.cal_high(12'd4095),.dead_zone(12'd0),
        .pressure_enable(pressure_enable),.adc_ready(adc_ready),.pressure_gain(pressure),.event_valid(ev),.event_kind(kind),
        .event_note(note),.event_velocity(velocity),.event_ready(er),.cfg_valid(cv),.cfg_addr(addr),.cfg_data(data),.cfg_ready(cr),
        .fault_pulse(fault),.blocked(blocked),.ghost(ghost),.fault_count(faults),
        .pressure_error(),.pressure_stale(),.encoder_button(),.encoder_error(),.keys());
    system_engine engine(.clk(clk),.rst(rst),.sample_ce(ce),.emergency(fault),.event_valid(ev),.event_kind(kind),.event_note(note),
        .event_value(7'd0),.event_velocity(velocity),.event_ready(er),.local_cfg_valid(cv),.local_cfg_addr(addr),.local_cfg_data(data),.local_cfg_ready(cr),
        .host_cfg_valid(hv),.host_cfg_addr(ha),.host_cfg_data(hd),.host_cfg_ready(hr),.pressure_gain(pressure),
        .cfg_ack(ack),.cfg_accepted(ok),.sample(sample),.sample_valid(valid),.clipped(clip),.panic(panic),.occupied(occupied),.held(held),.gated(gated),
        .cfg_applied(),.cfg_source_host(),.snapshot_valid(),.snapshot_data(),.wave_valid(),.wave_sample(),.wave_index(),.gain());
    always @(negedge clk)if(!rst)begin
        hv=0;adc_valid=0;
        if(valid)begin
            if(clip || ghost || faults || ^sample===1'bx)$fatal(1,"render fault");
            $fwrite(f,"%0d\n",sample);if(sample!=0)audible=audible+1;
            if(n%48==0 && adc_ready)adc_valid=1;
            case(n)
                FS/4:switches=1;
                FS:switches=0;
                FS*12/10:switches=7;
                FS*2:begin hv=1;ha=4;hd=1;end
                FS*22/10:switches=0;
                FS*27/10:begin hv=1;ha=4;hd=0;end
                FS*31/10:begin switches=8;pressure_enable=1;adc=800;end
                FS*35/10:adc=2400;
                FS*4:adc=4095;
                FS*45/10:switches=0;
                FS*5:begin switches=2;pressure_enable=0;end
                FS*54/10:switches=0;
            endcase
            n=n+1;
            if(n==FS*6)begin
                if(occupied || held || gated || sample || ons!=6 || offs!=6 || audible<180000)$fatal(1,"render coverage ons=%0d offs=%0d",ons,offs);
                $fclose(f);$display("INPUT_RENDER_TB_PASS samples=%0d on=%0d off=%0d audible=%0d",n,ons,offs,audible);$finish;
            end
        end
    end
    always @(posedge clk)if(!rst)begin
        if(ev&&er)begin if(kind==0)ons=ons+1;else if(kind==1)offs=offs+1;end
        if(ack&&!ok)$fatal(1,"render config");
    end
    initial begin
        f=$fopen("input_samples.txt","w");for(i=0;i<16;i=i+1)mapping[i*7 +:7]=60+i;
        mapping[6:0]=60;mapping[13:7]=64;mapping[20:14]=67;mapping[27:21]=72;
        repeat(6)@(negedge clk);rst=0;
    end
    initial begin #100000000;$fatal(1,"input render timeout");end
endmodule
