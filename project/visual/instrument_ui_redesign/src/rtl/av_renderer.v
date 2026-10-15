// Eight pixel stages: geometry -> address -> state RAM -> state register ->
// character/palette -> font ROM -> glyph -> RGB.
// A single state bank provides text, meters and 25 key records for each frame.
module av_renderer(input wire clk,rst,input wire [10:0] x,y,
    input wire de,hs,vs,text_valid,scope_valid,text_changed,frame_start,
    output reg [10:0] text_address,input wire [11:0] text_data,
    output wire [8:0] scope_address,input wire [17:0] scope_data,
    output reg [23:0] rgb,output reg out_de,out_hs,out_vs);
    function [4:0] white_note;
      input [3:0] w;
      begin case(w)
        0:white_note=0;1:white_note=2;2:white_note=4;3:white_note=5;4:white_note=7;5:white_note=9;6:white_note=11;
        7:white_note=12;8:white_note=14;9:white_note=16;10:white_note=17;11:white_note=19;12:white_note=21;13:white_note=23;
        default:white_note=24;
      endcase end
    endfunction
    function black_after;
      input [3:0] w;
      begin case(w)0,1,3,4,5,7,8,10,11,12:black_after=1;default:black_after=0;endcase end
    endfunction
    function [7:0] note_letter;
      input [4:0] k;
      begin case(k)
        0,1,12,13,24:note_letter="C";2,3,14,15:note_letter="D";
        4,16:note_letter="E";5,6,17,18:note_letter="F";
        7,8,19,20:note_letter="G";9,10,21,22:note_letter="A";default:note_letter="B";
      endcase end
    endfunction
    function [23:0] palette;
      input [3:0] c;
      begin case(c)
        2:palette=24'hD7BA7C;3:palette=24'hBEB5DE;4:palette=24'h78BEA1;5:palette=24'hEF8086;
        6:palette=24'h929B9D;default:palette=24'hE8E9E2;
      endcase end
    endfunction
    wire keyboard=y>=800 && y<1016;
    wire [3:0] white_index=x[10:7];
    wire black_right=y<928 && x[6:0]>=88 && black_after(white_index);
    wire black_left=y<928 && x[6:0]<40 && white_index!=0 && black_after(white_index-1'b1);
    wire black_key=black_right || black_left;
    wire [4:0] key_index=black_right ? white_note(white_index)+1'b1 : black_left ? white_note(white_index-1'b1)+1'b1 : white_note(white_index);
    wire [7:0] key_local=black_right ? {1'b0,x[6:0]}-8'd88 : black_left ? {1'b0,x[6:0]}+8'd40 : {1'b0,x[6:0]};
    wire gain_meter=x>=1344 && x<1792 && y>=256 && y<272;
    wire mix_meter=x>=1344 && x<1792 && y>=384 && y<400;
    assign scope_address=0;
    reg [23:0] base;
    wire menu=x>=64 && x<448 && y>=192 && y<512;
    wire key_note=keyboard && (black_key ? (y>=880 && y<912 && key_local>=8 && key_local<72) : (y>=976 && y<1008 && key_local>=32 && key_local<96));
    wire key_mark=keyboard && (black_key ? (y>=832 && y<864 && key_local>=24 && key_local<56) : (y>=936 && y<968 && key_local>=48 && key_local<80));
    wire [7:0] label_x=key_note ? key_local-(black_key ? 8'd8 : 8'd32) : key_local-(black_key ? 8'd24 : 8'd48);
    // The second note glyph never depends on the marker row selection.
    wire [7:0] note_label_x=key_local-(black_key ? 8'd8 : 8'd32);
    wire [3:0] label_row=key_note ? (black_key ? (y-880)>>1 : (y-976)>>1) : (black_key ? (y-832)>>1 : (y-936)>>1);
    wire [3:0] label_col=label_x[4:1];
    // Register geometry flags before the background priority/palette mux.
    reg [12:0] base_flags_a;
    always @* begin
        base=24'h151719;
        if(base_flags_a[0])base=24'h242729;
        if(base_flags_a[1])base=24'h242729;
        if(base_flags_a[2])base=24'h202325;
        if(base_flags_a[3])base=base_flags_a[4] ? 24'h262A2C : 24'h2A2E30;
        if(base_flags_a[5])base=24'h292D2F;
        if(base_flags_a[6])base=24'hD7BA7C;
        if(base_flags_a[7])base=24'h42474A;
        if(base_flags_a[8])base=24'h111415;
        if(base_flags_a[9])base=24'h8A9395;
        if(base_flags_a[10])base=24'hD7BA7C;
        if(base_flags_a[11])base=base_flags_a[12] ? 24'h33383B : 24'hDCE0D8;
    end
    // Metadata travels alongside the state RAM request, then the font request.
    // Datapath registers need no reset: the reset control pipeline blanks them.
    reg [56:0] meta_a,meta_b,meta_c,meta_state;
    reg [11:0] state_data;
    reg [10:0] tile_a;
    reg [4:0] key_a;
    reg keyboard_a,gain_a,mix_a;
    reg [7:0] de_pipe=0,hs_pipe=0,vs_pipe=0;
    reg [7:0] age=255;
    wire [23:0] base_c;
    wire key_c,black_c,menu_c,edge_c,note_c,mark_c,second_c,label_c,text_c;
    wire [4:0] index_c;
    wire [3:0] row_c,col_c;
    wire meter_c,badge_c,stale_c,valid_c;
    wire [6:0] meter_x_c;
    assign {base_c,key_c,black_c,menu_c,edge_c,note_c,mark_c,second_c,label_c,text_c,
        index_c,row_c,col_c,meter_c,meter_x_c,badge_c,stale_c,valid_c}=meta_state;
    wire key_edge=keyboard && (black_key ? (key_local<2 || key_local>=78 || y>=923) :
        (x[6:0]<2 || x[6:0]>=126 || y>=1012));
    wire [6:0] meter_position=(x-11'd1344)>>2;
    reg [7:0] character_next,character_d;
    reg [23:0] background_next,foreground_next;
    reg [23:0] background_d,background_e,background_f,foreground_d,foreground_e,foreground_f;
    reg [3:0] row_d,col_d,col_e;
    reg label_d,label_e,glyph_f,badge_d,badge_e,badge_f,stale_d,stale_e,stale_f;
    wire [15:0] font_bits;
    av_font font(clk,{character_d,row_d},font_bits);
    always @* begin
        character_next=state_data[7:0];
        if(key_c)begin
            character_next=" ";
            if(note_c)begin
                if(!second_c)character_next=note_letter(index_c);
                else if(black_c)character_next="#";
                else character_next=state_data[6:0]<48 ? "2" : state_data[6:0]<60 ? "3" :
                    state_data[6:0]<72 ? "4" : state_data[6:0]<84 ? "5" : "6";
            end
            if(mark_c)character_next=(state_data[7] || state_data[10]) ? "H" : state_data[8] ? "S" : state_data[9] ? "R" : " ";
        end
        background_next=base_c;foreground_next=palette(state_data[11:8]);
        if(menu_c && state_data[11:8]==2)background_next=24'h3C3930;
        if(meter_c)background_next=valid_c && meter_x_c<state_data[6:0] ? 24'hD7BA7C : 24'h373B3D;
        if(key_c)begin
            foreground_next=black_c ? 24'hE6E8E2 : 24'h383D40;
            background_next=black_c ? 24'h171B1D : 24'hE2E3DB;
            if(!state_data[11] && !(|state_data[10:7]))begin
                foreground_next=black_c ? 24'h7E888A : 24'h727C7E;
                background_next=black_c ? 24'h202527 : 24'hC7CECA;
            end
            if(state_data[9])background_next=black_c ? 24'h53636E : 24'h98A5AC;
            if(state_data[8])background_next=black_c ? 24'h67577F : 24'hBEB5DE;
            if(state_data[7] || state_data[10])background_next=black_c ? 24'h897044 : 24'hD7BA7C;
            if(edge_c)background_next=24'h151719;
        end
    end
    always @(posedge clk)begin
        // A: geometry, independent of RAM timing.
        base_flags_a<={x[4:0]==0,x>=704 && x<1056 && y>=304 && y<336,
            x>=704 && x<1056 && y>=224 && y<284 && x[4:0]==0,
            (x==672 || x==1087 || y==208) && x>=672 && x<1088 && y>=208 && y<336,
            x>=672 && x<1088 && y>=208 && y<336,
            (y==159 || y==543) && x>=48 && x<1872,
            y>=550 && y<554 && x>=48 && x<1872,y>=560 && y<672 && x>=48 && x<1872,
            y[5],menu,x>=480 && x<1248 && y>=176 && y<528,
            x>=48 && x<1872 && y>=160 && y<544,y<80 || y>=1032};
        meta_a<={24'd0,keyboard && text_valid,black_key,menu,key_edge,key_note,key_mark,note_label_x[5],
            (key_note || key_mark) && text_valid,y<800 && text_valid && !gain_meter && !mix_meter,
            key_index,keyboard ? label_row : y[4:1],keyboard ? label_col : x[4:1],
            gain_meter || mix_meter,meter_position,
            x>=1792 && x<1856 && y>=112 && y<144,!text_valid || age>=120,text_valid};
        tile_a<={y[9:5],x[10:5]};key_a<=key_index;
        keyboard_a<=keyboard;gain_a<=gain_meter;mix_a<=mix_meter;
        // B: register the final address before the BSRAM setup path.
        text_address<=keyboard_a ? {6'd60,key_a} : gain_a ? 11'd1945 : mix_a ? 11'd1946 : tile_a;
        meta_b<={base,meta_a[32:0]};
        // C: external text RAM reads the registered address here.
        meta_c<=meta_b;
        // D: isolate BSRAM clock-to-output from character/color calculation.
        state_data<=text_data;meta_state<=meta_c;
        // E: decode characters/colors into registers before the font BSRAM.
        character_d<=character_next;row_d<=row_c;col_d<=col_c;
        label_d<=key_c ? label_c : text_c;
        background_d<=background_next;foreground_d<=foreground_next;
        badge_d<=badge_c;stale_d<=stale_c;
        // F: font RAM reads registered character/row; carry the color metadata.
        col_e<=col_d;label_e<=label_d;
        background_e<=background_d;foreground_e<=foreground_d;badge_e<=badge_d;stale_e<=stale_d;
        // G: select the glyph pixel separately from the final RGB mux.
        glyph_f<=label_e && font_bits[15-col_e];
        background_f<=background_e;foreground_f<=foreground_e;badge_f<=badge_e;stale_f<=stale_e;
        // H: RGB and sync are delayed by eight clocks together.
        if(rst)begin
            de_pipe<=0;hs_pipe<=0;vs_pipe<=0;out_de<=0;out_hs<=0;out_vs<=0;rgb<=0;age<=255;
        end else begin
            de_pipe<={de_pipe[6:0],de};hs_pipe<={hs_pipe[6:0],hs};vs_pipe<={vs_pipe[6:0],vs};
            out_de<=de_pipe[6];out_hs<=hs_pipe[6];out_vs<=vs_pipe[6];
            if(text_changed)age<=0;else if(frame_start && age!=255)age<=age+1'b1;
            if(!de_pipe[6])rgb<=0;
            else if(badge_f)rgb<=stale_f ? 24'hEF8086 : 24'h78BEA1;
            else rgb<=glyph_f ? foreground_f : background_f;
        end
    end
endmodule
