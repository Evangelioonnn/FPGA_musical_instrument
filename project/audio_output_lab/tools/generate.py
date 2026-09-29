"""Generate explicit Designer wrappers; checked-in RTL remains hand-maintained."""
from pathlib import Path
HERE=Path(__file__).resolve().parents[1]
VARIANTS=['00_control','01_piano_headroom','02_edge_spacing','03_polarity']
SUPPORT=['playable_button','playable_led','matrix_scanner','ec11_input','stream_fifo',
         'knob_gain','knob_volume_table','adsr_envelope','sine_rom','note_table',
         'pluck_note_table','pt8211_tx']
PALETTE=['palette_slot','palette_tone_state','palette_pluck','palette_sine','palette_keys']

def main():
    sources=sorted(f'../../src/{p.name}' for p in (HERE/'src').glob('*.v'))
    sources += [f'../../../final_dual_timbre/src/{n}.v' for n in SUPPORT]
    sources += [f'../../../audio_palette_lab/src/{n}.v' for n in PALETTE]
    for i,name in enumerate(VARIANTS):
        p=HERE/'variants'/name;p.mkdir(parents=True,exist_ok=True);top='output_'+name
        (p/'top.v').write_text(f'''module {top}(input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led);
    output_top #(.TONE_SHIFT({3 if i==1 else 0}),.EDGE_SPACING({int(i==2)}),.INVERT({int(i==3)})) dut(
        sys_clk,enc_a,enc_b,button_n,matrix_col_n,matrix_row_n,hp_bck,hp_ws,hp_din,pa_en,status_led);
endmodule
''')
        files=[(s,'verilog') for s in ['top.v']+sources]+[('../../src/output.cst','cst'),('../../src/output.sdc','sdc')]
        xml='\n'.join(f'    <File path="{s}" type="file.{t}" enable="1" />' for s,t in files)
        (p/(name+'.gprj')).write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE gowin-fpga-project>
<Project><Template>FPGA</Template><Version>5</Version>
<Device name="GW5AT-60B" pn="GW5AT-LV60PG484AC1/I0">gw5at60b-002</Device>
<FileList>
{xml}
</FileList></Project>
''')
        (p/'build.tcl').write_text(f'''set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir {name}.gprj]
set_option -top_module {top}
set_option -output_base_name {name}
run all
''')
    print('Generated four independent Designer projects.')
if __name__=='__main__':main()
