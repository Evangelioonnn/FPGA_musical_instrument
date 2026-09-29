// Four ROM read channels and one amplitude multiplier service all N voices.
// Result is signed Q4 PCM. PROFILE 0 is numerically the legacy MODE 1.
// Other profiles preserve weighted fractional bits and use a 4096-point sine.
module palette_shared_tone #(parameter PROFILE=0,parameter N=8,
    parameter IW=(N>1?$clog2(N):1))(
    input wire clk,rst,sample_ce,
    input wire [N*32-1:0] phases,
    input wire [N*16-1:0] envelopes,brightness,
    output reg signed [19:0] sample,
    output reg [N-1:0] valid,output reg deadline_missed
);
    reg [3:0] state;
    reg [IW-1:0] index;
    reg [N*32-1:0] phase_frame;
    reg [N*16-1:0] env_frame,bright_frame;
    reg [31:0] address_phase;
    wire [31:0] phase2=address_phase<<1,phase3=address_phase+(address_phase<<1),phase4=address_phase<<2;
    wire signed [15:0] a,b,c,d;
    generate if(PROFILE==0) begin: original_rom
        sine_rom r0(clk,address_phase[31:22],a);
        sine_rom r1(clk,phase2[31:22],b);
        sine_rom r2(clk,phase3[31:22],c);
        sine_rom r3(clk,phase4[31:22],d);
    end else begin: precision_rom
        palette_sine r0(clk,address_phase[31:20],a);
        palette_sine r1(clk,phase2[31:20],b);
        palette_sine r2(clk,phase3[31:20],c);
        palette_sine r3(clk,phase4[31:20],d);
    end endgenerate
    wire signed [15:0] legacy_shape=(a>>>1)+(b>>>3)+(c>>>4)+(d>>>5);
    wire signed [25:0] wa={{10{a[15]}},a},wb={{10{b[15]}},b},wc={{10{c[15]}},c},wd={{10{d[15]}},d};
    reg signed [25:0] fundamental,upper,shape;
    reg signed [42:0] bright_product,product;
    wire [15:0] current_env=env_frame[index*16+:16];
    wire [15:0] current_bright=bright_frame[index*16+:16];
    wire signed [42:0] rounded=product<0 ? -(((-product)+43'sd4194304)>>>23) : (product+43'sd4194304)>>>23;
    always @(posedge clk) begin
        if(rst) begin
            state<=0;index<=0;phase_frame<=0;env_frame<=0;bright_frame<=0;
            address_phase<=0;fundamental<=0;upper<=0;shape<=0;
            bright_product<=0;product<=0;sample<=0;valid<=0;deadline_missed<=0;
        end else begin
            valid<=0;
            if(sample_ce) begin
                // Deliberately outside the idle test: a short/overrun frame
                // must assert the sticky diagnostic rather than hide it.
                if(state!=0) deadline_missed<=1;
                state<=1;index<=0;
            end else case(state)
                1:begin
                    // Envelopes and phases have advanced at sample_ce.
                    phase_frame<=phases;env_frame<=envelopes;bright_frame<=brightness;
                    state<=2;
                end
                2:begin address_phase<=phase_frame[index*32+:32];state<=3;end
                3:state<=4; // synchronous ROM read
                4:begin
                    if(PROFILE==0) begin fundamental<=$signed(legacy_shape)<<<8;upper<=0;end
                    else if(PROFILE==2) begin fundamental<=(wa<<<7)+(wa<<<5);upper<=(wb<<<5)+(wc<<<3);end
                    else if(PROFILE==3) begin fundamental<=wa<<<7;upper<=(wb<<<6)+(wc<<<5)+(wd<<<4);end
                    else if(PROFILE==4) begin fundamental<=(wa<<<7)+(wa<<<4);upper<=(wc<<<4)+(wc<<<3);end
                    else begin fundamental<=wa<<<7;upper<=(wb<<<5)+(wc<<<4)+(wd<<<3);end
                    state<=5;
                end
                5:begin bright_product<=upper*$signed({1'b0,current_bright});state<=6;end
                6:begin
                    shape<=fundamental+((PROFILE==2 || PROFILE==3) ? (bright_product>>>16) : upper);
                    state<=7;
                end
                7:begin product<=shape*$signed({1'b0,current_env});state<=8;end
                8:begin
                    if(PROFILE==0) sample<=(product>>>27)<<<4;
                    else sample<=rounded[19:0];
                    valid[index]<=1;
                    if(index==N-1) state<=0;
                    else begin index<=index+1'b1;state<=2;end
                end
                default:state<=0;
            endcase
        end
    end
endmodule
