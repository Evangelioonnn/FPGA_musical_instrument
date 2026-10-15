// Atomic audio-domain snapshot adapter. Format text and 25 key records into
// the inactive display bank; never backpressure AUDIO_CORE_V2.
module av_page_writer #(parameter KEYS=16,SPLIT=8,DIATONIC=1)(
    input wire clk,rst,ready,snapshot_valid,
    input wire [2367:0] snapshot,input wire [255:0] extension,
    input wire [KEYS-1:0] keys,
    output reg wr_en,output reg [10:0] wr_addr,
    output wire [11:0] wr_data,output wire publish);
    localparam IDLE=0,COUNT=1,KEYS_BUILD=2,FORMAT=3;
    reg [1:0] phase=IDLE;
    reg [10:0] address=0;
    reg [319:0] header;
    reg [95:0] adsr;
    reg [KEYS-1:0] physical_keys;
    reg [31:0] occupied,held,gated;
    reg [95:0] presets;
    reg [223:0] notes;
    reg [11:0] key_records[0:24];
    reg [5:0] scan=0,voice_count=0,pluck_count=0;
    reg [4:0] key_index=0;
    reg [11:0] key_accum=0;
    reg [31:0] current_value;
    reg [6:0] gain_percent,mix_percent,gain_bar,mix_bar;
    wire [6:0] display_note=key_index<12 ? header[120:114]+key_index : header[127:121]+(key_index-12);
    function [4:0] note_offset;
        input [5:0] key_number;
        begin
          if(!DIATONIC) note_offset=key_number;
          else case(key_number)
            0:note_offset=0;1:note_offset=2;2:note_offset=4;3:note_offset=5;
            4:note_offset=7;5:note_offset=9;6:note_offset=11;default:note_offset=12;
          endcase
        end
    endfunction
    wire [6:0] physical_note=scan<SPLIT ? header[120:114]+note_offset(scan) : header[127:121]+note_offset(scan-SPLIT);
    wire [4:0] voice_index=scan-KEYS;
    reg [11:0] key_next;
    always @* begin
        key_next=key_accum;
        if(scan<KEYS) begin
            if(physical_note==display_note) begin
                key_next[11]=1;
                if(physical_keys[scan]) key_next[7]=1;
            end
        end else if(occupied[voice_index] && notes[voice_index*7+:7]==display_note) begin
            if(held[voice_index]) key_next[10]=1;
            else if(gated[voice_index]) key_next[8]=1;
            else key_next[9]=1;
        end
    end
    reg [31:0] incoming_value;
    always @* begin
        incoming_value=0;
        if(snapshot[100:98]==5 && snapshot[113:109]>=1 && snapshot[113:109]<=4) begin
            case(snapshot[113:109])
                1:incoming_value={20'd0,extension[107:96]};2:incoming_value={20'd0,extension[119:108]};
                3:incoming_value={20'd0,extension[131:120]};4:incoming_value={20'd0,extension[143:132]};
            endcase
        end else case(snapshot[113:109])
            0:incoming_value={15'd0,snapshot[80:64]};1:incoming_value={25'd0,snapshot[120:114]};
            2:incoming_value={25'd0,snapshot[127:121]};3:incoming_value={29'd0,snapshot[130:128]};
            4:incoming_value={29'd0,snapshot[133:131]};5:incoming_value={{27{snapshot[138]}},snapshot[138:134]};
            6:incoming_value={30'd0,extension[145:144]};7:incoming_value={25'd0,snapshot[145:139]};
            8:incoming_value={29'd0,snapshot[148:146]};9:incoming_value={31'd0,snapshot[105]};
            10:incoming_value={24'd0,snapshot[156:149]};11:incoming_value={16'd0,extension[47:32]};
            12:incoming_value={16'd0,extension[63:48]};13:incoming_value={16'd0,extension[79:64]};
            14:incoming_value={16'd0,extension[95:80]};15:incoming_value={31'd0,snapshot[103]};
            16:incoming_value={31'd0,snapshot[104]};default:incoming_value=0;
        endcase
    end
    wire [4:0] row=address[10:6];
    wire [5:0] col=address[5:0];
    wire [4:0] mode_label=(header[100:98]==5 && header[113:109]>=1 && header[113:109]<=4) ? header[113:109]+5'd17 : header[113:109];
    reg [11:0] label_address;
    always @* begin
        label_address={1'b0,address};
        if(row==12 && col>=20 && col<40) label_address=12'd3072+{4'd0,header[100:98],5'd0}+col-20;
        if(row==15 && col>=19 && col<41) label_address=12'd2048+{2'd0,mode_label,5'd0}+col-19;
    end
    wire [7:0] label_character;
    av_labels labels(clk,label_address,label_character);
    function [7:0] hex_char;
      input [3:0] value;
      begin hex_char=value<10 ? 8'd48+value : 8'd65+value-10;end
    endfunction
    function [7:0] tens;
      input [6:0] value;
      begin tens=value>=100 ? "0" : value>=90 ? "9" : value>=80 ? "8" : value>=70 ? "7" : value>=60 ? "6" : value>=50 ? "5" : value>=40 ? "4" : value>=30 ? "3" : value>=20 ? "2" : value>=10 ? "1" : "0";end
    endfunction
    function [7:0] ones;
      input [6:0] value;
      begin ones=8'd48+(value>=100 ? value-100 : value>=90 ? value-90 : value>=80 ? value-80 : value>=70 ? value-70 : value>=60 ? value-60 : value>=50 ? value-50 : value>=40 ? value-40 : value>=30 ? value-30 : value>=20 ? value-20 : value>=10 ? value-10 : value);end
    endfunction
    reg overlay;
    reg [7:0] character;
    reg [3:0] color;
    reg [31:0] number;
    reg [3:0] digit;
    reg [6:0] decimal_value;
    reg [11:0] packed_record;
    reg metadata;
    always @* begin
        overlay=0;character=" ";color=0;number=0;digit=0;decimal_value=0;metadata=0;packed_record=0;
        if(row==1) color=(col>=12 && col<17) ? 2 : 6;
        if(row==3 || row==12) color=2;
        if(row>=6 && row<=15 && col>=2 && col<14) begin
            if((header[100:98]==0 && (row==6 || row==7)) ||
               (header[100:98]==2 && (row==8 || row==9)) ||
               (header[100:98]==3 && (row==10 || row==11)) ||
               (header[100:98]==4 && (row==12 || row==13)) ||
               (header[100:98]==5 && (row==14 || row==15))) color=2;
        end
        if(row==7 && col>=45 && col<48) begin overlay=1;character=col==45 ? (gain_percent==100 ? "1" : " ") : col==46 ? tens(gain_percent) : ones(gain_percent);color=2;end
        if(row==11 && col>=45 && col<47) begin overlay=1;character=col==45 ? tens(mix_percent) : ones(mix_percent);color=2;end
        if(row==14 && (col==48 || col==49 || col==54 || col==55)) begin overlay=1;decimal_value=col<50 ? voice_count : pluck_count;character=col[0] ? ones(decimal_value) : tens(decimal_value);color=2;end
        if(row==16 && col>=20 && col<28) begin overlay=1;digit=27-col;character=hex_char(current_value>>(digit*4));color=2;end
        if(row==19) begin
            if(col>=4 && col<7) begin overlay=1;character=col==4 ? (gain_percent==100 ? "1" : " ") : col==5 ? tens(gain_percent) : ones(gain_percent);color=2;end
            if(col>=15 && col<18) begin overlay=1;character=col==15 ? (header[101] ? "O" : "O") : col==16 ? (header[101] ? "N" : "F") : (header[101] ? " " : "F");color=header[101] ? 2 : 6;end
            if(col>=28 && col<31) begin overlay=1;character=col==28 ? "O" : col==29 ? (header[102] ? "N" : "F") : (header[102] ? " " : "F");color=header[102] ? 3 : 6;end
            if(col==41) begin overlay=1;character=header[100:98]==2 ? "-" : 8'd48+{5'd0,header[130:128]};color=header[100:98]==2 ? 6 : 2;end
            if(col>=50 && col<53) begin overlay=1;character=col==50 ? "O" : col==51 ? (header[105] ? "N" : "F") : (header[105] ? " " : "F");color=header[105] ? 2 : 6;end
        end
        if(row==22 && (col==13 || col==14 || col==38 || col==39)) begin overlay=1;decimal_value=col<20 ? header[120:114] : header[127:121];character=col[0] ? tens(decimal_value) : ones(decimal_value);if(col>=38)character=col==38 ? tens(decimal_value) : ones(decimal_value);end
        if(row==23 && col>=50 && col<58) begin overlay=1;number=header[31:0];digit=57-col;character=hex_char(number>>(digit*4));color=6;end
        if(row==24) begin
            if(col==48) begin overlay=1;character=header[106] ? "Y" : "N";color=header[106] ? 5 : 6;end
            if(col==56) begin overlay=1;character=header[107] ? "Y" : "N";color=header[107] ? 5 : 6;end
        end
        if(address>=1920 && address<1945) begin metadata=1;packed_record=key_records[address-1920];end
        if(address==1945) begin metadata=1;packed_record={5'd0,gain_bar};end
        if(address==1946) begin metadata=1;packed_record={5'd0,mix_bar};end
    end
    reg overlay_q,metadata_q;
    reg [7:0] character_q;
    reg [3:0] color_q;
    reg [11:0] packed_q;
    assign wr_data=metadata_q ? packed_q : {color_q,overlay_q ? character_q : label_character};
    assign publish=wr_en && (&wr_addr);
    integer i;
    wire [23:0] gain_product=header[97:81]*7'd100;
    wire [23:0] bar_product=header[97:81]*7'd112;
    wire [15:0] mix_product=header[165:157]*7'd100;
    wire [15:0] mix_bar_product=header[165:157]*3'd7;
    always @(posedge clk) begin
        if(rst) begin phase<=IDLE;address<=0;wr_en<=0;wr_addr<=0;scan<=0;key_index<=0;key_accum<=0;
            overlay_q<=0;metadata_q<=0;character_q<=0;color_q<=0;packed_q<=0;voice_count<=0;pluck_count<=0;
            gain_percent<=0;mix_percent<=0;gain_bar<=0;mix_bar<=0;end
        else begin
            wr_en<=phase==FORMAT;wr_addr<=address;overlay_q<=overlay;character_q<=character;color_q<=color;
            metadata_q<=metadata;packed_q<=packed_record;
            case(phase)
            IDLE:if(snapshot_valid && ready && !wr_en) begin
                header<=snapshot[319:0];adsr<=extension[95:0];physical_keys<=keys;current_value<=incoming_value;
                phase<=COUNT;scan<=0;voice_count<=0;pluck_count<=0;
                for(i=0;i<32;i=i+1) begin
                    occupied[i]<=snapshot[362+i*64];held[i]<=snapshot[363+i*64];gated[i]<=snapshot[364+i*64];
                    presets[i*3+:3]<=snapshot[359+i*64+:3];notes[i*7+:7]<=snapshot[352+i*64+:7];
                end
            end
            COUNT:begin
                if(occupied[scan[4:0]]) voice_count<=voice_count+1'b1;
                if(occupied[scan[4:0]] && presets[scan[4:0]*3+:3]==2) pluck_count<=pluck_count+1'b1;
                gain_percent<=gain_product[22:16];gain_bar<=bar_product[22:16];
                mix_percent<=mix_product[14:8];mix_bar<=mix_bar_product[10:4];
                if(scan==31) begin phase<=KEYS_BUILD;scan<=0;key_index<=0;key_accum<=0;end else scan<=scan+1'b1;
            end
            KEYS_BUILD:begin
                if(scan==KEYS+31) begin
                    key_records[key_index]<={key_next[11:7],display_note};scan<=0;key_accum<=0;
                    if(key_index==24) begin phase<=FORMAT;address<=0;end else key_index<=key_index+1'b1;
                end else begin key_accum<=key_next;scan<=scan+1'b1;end
            end
            FORMAT:if(&address)phase<=IDLE;else address<=address+1'b1;
            endcase
        end
    end
endmodule
