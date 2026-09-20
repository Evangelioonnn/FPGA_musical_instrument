"""Recreate five seven-pin projects and the perceptual volume table."""
from pathlib import Path
import os

HERE = Path(__file__).resolve().parents[1]
ROOT = HERE.parents[2]
NAMES = ('performance', 'volume', 'timbre', 'release', 'echo')

def sources():
    # Pitch control currently has an independent logic/audio test, no board binding.
    paths = sorted(p for p in (HERE/'src').glob('*.v') if p.name!='knob_pitch.v')
    paths += [ROOT/'project/input/src/ec11_input.v', ROOT/'project/system/src/stream_fifo.v']
    paths += [ROOT/'project/instrument/src'/n for n in
              ('synth_voice.v','adsr_envelope.v','sine_rom.v','note_table.v','pt8211_tx.v')]
    paths += sorted((ROOT/'project/experiments/timbre/fm/src').glob('*.v'))
    paths += sorted((ROOT/'project/experiments/timbre/pluck/src').glob('*.v'))
    paths += [ROOT/'project/experiments/delay/src/feedback_delay.v']
    return paths

def main():
    entries = []
    for index in range(25):
        gain = 0 if index == 0 else round(65536*10**((index-24)*3/20))
        entries.append(f"        5'd{index}: gain=17'd{gain};")
    (HERE/'src/knob_volume_table.v').write_text(
        '// 0=mute; 1..24: -69..0 dB in 3 dB increments. Q16 amplitude.\n'
        'module knob_volume_table(input wire [4:0] index,output reg [16:0] gain);\n'
        '    always @* case(index)\n'+'\n'.join(entries)+
        "\n        default:gain=17'd65536;\n    endcase\nendmodule\n", encoding='utf-8')
    for name in NAMES:
        folder=HERE/'board'/name
        folder.mkdir(parents=True,exist_ok=True)
        paths=sources()+[ROOT/'project/input/ec11_probe/src/ec11_probe.cst',
                         ROOT/'project/input/ec11_probe/src/ec11_probe.sdc']
        files=[]
        for p in paths:
            kind={'.v':'verilog','.cst':'cst','.sdc':'sdc'}[p.suffix]
            rel=Path(os.path.relpath(p,folder)).as_posix()
            files.append(f'    <File path="{rel}" type="file.{kind}" enable="1"/>')
        base='knob_'+name
        (folder/(base+'.gprj')).write_text(
            '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE gowin-fpga-project>\n<Project>\n'
            '  <Template>FPGA</Template><Version>5</Version>\n'
            '  <Device name="GW5AT-60B" pn="GW5AT-LV60PG484AC1/I0">gw5at60b-002</Device>\n'
            '  <FileList>\n'+'\n'.join(files)+'\n  </FileList>\n</Project>\n',encoding='utf-8')
        (folder/'build.tcl').write_text(
            'set project_dir [file dirname [file normalize [info script]]]\n'
            f'open_project [file join $project_dir {base}.gprj]\n'
            f'set_option -top_module {base}_top\nset_option -output_base_name {base}\nrun all\n',encoding='utf-8')
    print('KNOB_PROJECTS_CREATED: '+', '.join(NAMES))

if __name__=='__main__':
    main()
