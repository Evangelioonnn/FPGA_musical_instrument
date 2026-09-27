"""Three comparable five-preset builds with the same controls and pins."""
from pathlib import Path
HERE=Path(__file__).resolve().parents[1]
VARIANTS=['five_00_reference','five_01_balance','five_02_spectral']
FINAL=['playable_button','matrix_scanner','ec11_input','stream_fifo','knob_gain',
       'knob_volume_table','adsr_envelope','sine_rom','note_table','pluck_note_table','pt8211_tx']
PALETTE=['palette_pluck','palette_sine']

def main():
    for mode,name in enumerate(VARIANTS):
        p=HERE/'variants'/name;p.mkdir(parents=True,exist_ok=True)
        (p/'top.v').write_text(f'''module {name}(
    input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led);
    gallery_top #(.BALANCE_MODE({mode})) dut(sys_clk,enc_a,enc_b,button_n,matrix_col_n,matrix_row_n,
        hp_bck,hp_ws,hp_din,pa_en,status_led);
endmodule
''')
        sources=['top.v']+sorted(f'../../src/{q.name}' for q in (HERE/'src').glob('*.v'))
        sources += [f'../../../final_dual_timbre/src/{s}.v' for s in FINAL]
        sources += [f'../../../audio_palette_lab/src/{s}.v' for s in PALETTE]
        sources += ['../../../audio_output_lab/src/output_tx.v','../../../audio_output_lab/src/output_polarity.v']
        files=[(s,'verilog') for s in sources]+[('../../src/gallery.cst','cst'),('../../src/gallery.sdc','sdc')]
        xml='\n'.join(f'    <File path="{s}" type="file.{kind}" enable="1" />' for s,kind in files)
        (p/(name+'.gprj')).write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE gowin-fpga-project>
<Project><Template>FPGA</Template><Version>5</Version>
  <Device name="GW5AT-60B" pn="GW5AT-LV60PG484AC1/I0">gw5at60b-002</Device>
  <FileList>
{xml}
  </FileList>
</Project>
''')
        (p/'build.tcl').write_text(f'''set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir {name}.gprj]
set_option -top_module {name}
set_option -output_base_name {name}
run all
''')
    print('Generated three five-timbre Designer projects.')
if __name__=='__main__':main()
