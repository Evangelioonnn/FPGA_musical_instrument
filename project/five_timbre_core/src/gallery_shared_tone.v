// Local playable-gallery fork; baseline sources remain unchanged.
// Isolated fork of palette module at db653ef; see SPEC.md.
// Four ROM read channels and one amplitude multiplier service all N voices.
// Result is signed Q4 PCM. PROFILE 0 is numerically the legacy MODE 1.
// Other profiles preserve weighted fractional bits and use a 4096-point sine.
module gallery_shared_tone #(parameter PROFILE=6,parameter TONE_SHIFT=0,parameter BALANCE_MODE=0,parameter N=8,
    parameter IW=(N>1?$clog2(N):1))(
    input wire clk,rst,sample_ce,
    input wire [N*32-1:0] phases,
    input wire [N*16-1:0] envelopes,brightness,
    input wire [N*7-1:0] notes,
    input wire [N*3-1:0] voice_timbres,
    output reg signed [19:0] sample,
    output reg [N-1:0] valid,output reg deadline_missed
);
    reg [3:0] state;
    reg [IW-1:0] index;
    reg [N*32-1:0] phase_frame;
    reg [N*16-1:0] env_frame,bright_frame;
    reg [N*7-1:0] note_frame;
    reg [N*3-1:0] timbre_frame;
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
    wire signed [25:0] wa={{10{a[15]}},a},wb={{10{b[15]}},b},wc={{10{c[15]}},c},wd={{10{d[15]}},d};
    reg signed [25:0] fundamental,upper,shape;
    reg signed [42:0] bright_product,product;
    reg signed [51:0] balance_product;
    reg signed [33:0] mod_product;
    reg signed [15:0] original_b,original_c;
    wire [15:0] current_env=env_frame[index*16+:16];
    wire [15:0] current_bright=bright_frame[index*16+:16];
    wire [6:0] current_note=note_frame[index*7+:7];
    wire [6:0] upper_note=current_note>48 ? current_note-7'd48 : 7'd0;
    wire [6:0] upper_span=upper_note>36 ? 7'd36 : upper_note;
    wire [8:0] balance_gain=9'd256-({2'b0,upper_span}<<1);
    wire [2:0] current_timbre=timbre_frame[index*3+:3];
    wire [8:0] applied_gain=current_timbre==3 ? 9'd256 : balance_gain;
    wire [15:0] note_brightness=16'd65535-({9'd0,upper_span}*16'd384);
    wire signed [31:0] mod_offset=mod_product >>> 1;
    wire signed [26:0] drive_in=$signed({shape[25],shape})<<<1;
    wire signed [26:0] drive_shape=drive_in>27'sd3000000 ?
        27'sd3000000+((drive_in-27'sd3000000)>>>2) :
        drive_in< -27'sd3000000 ?
        -27'sd3000000+((drive_in+27'sd3000000)>>>2) : drive_in;
    wire signed [42:0] rounded=product<0 ? -(((-product)+(43'sd4194304 << TONE_SHIFT))>>>(23+TONE_SHIFT)) : (product+(43'sd4194304 << TONE_SHIFT))>>>(23+TONE_SHIFT);
    wire signed [51:0] balanced=balance_product<0 ?
        -(((-balance_product)+52'sd128)>>>8) : (balance_product+52'sd128)>>>8;
    always @(posedge clk) begin
        if(rst) begin
            state<=0;index<=0;phase_frame<=0;env_frame<=0;bright_frame<=0;note_frame<=0;timbre_frame<=0;
            address_phase<=0;fundamental<=0;upper<=0;shape<=0;
            bright_product<=0;product<=0;balance_product<=0;mod_product<=0;original_b<=0;original_c<=0;
            sample<=0;valid<=0;deadline_missed<=0;
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
                    phase_frame<=phases;env_frame<=envelopes;bright_frame<=brightness;note_frame<=notes;
                    timbre_frame<=voice_timbres;
                    state<=2;
                end
                2:begin address_phase<=phase_frame[index*32+:32];state<=3;end
                3:state<=4; // synchronous ROM read
                4:begin
                    case(current_timbre)
                        4:begin fundamental<=wa<<<7;
                            upper<=(wb<<<4)+(wc<<<6)+(wd<<<4);state<=5;end
                        3:begin original_b<=b;original_c<=c;
                            mod_product<=$signed(c)*$signed({1'b0,current_bright});
                            state<=9;end
                        default:begin fundamental<=wa<<<7;
                            upper<=(wb<<<5)+(wc<<<4)+(wd<<<3);state<=5;end
                    endcase
                end
                5:begin bright_product<=upper*$signed({1'b0,BALANCE_MODE==2 && current_timbre!=3 ? note_brightness : current_bright});state<=6;end
                6:begin
                    shape<=fundamental+((current_timbre==3 || BALANCE_MODE==2) ? (bright_product>>>16) : upper);
                    state<=7;
                end
                7:begin product<=(current_timbre==4 ? drive_shape : $signed({shape[25],shape}))*
                    $signed({1'b0,current_env});state<=8;end
                8:begin
                    if(BALANCE_MODE==0) begin
                        if(PROFILE==0) sample<=(product>>>27)<<<4;
                        else sample<=rounded[19:0];
                        valid[index]<=1;
                        if(index==N-1) state<=0;
                        else begin index<=index+1'b1;state<=2;end
                    end else begin balance_product<=rounded*$signed({1'b0,applied_gain});state<=12;end
                end
                9:begin
                    address_phase<=phase_frame[index*32+:32]+mod_offset;
                    state<=10;
                end
                10:state<=11;
                11:begin
                    begin fundamental<=(wa<<<6)+(wa<<<5);
                        upper<=($signed(original_b)<<<4)+($signed(original_c)<<<4);end
                    state<=5;
                end
                12:begin
                    sample<=balanced[19:0];valid[index]<=1;
                    if(index==N-1) state<=0;
                    else begin index<=index+1'b1;state<=2;end
                end
                default:state<=0;
            endcase
        end
    end
endmodule
