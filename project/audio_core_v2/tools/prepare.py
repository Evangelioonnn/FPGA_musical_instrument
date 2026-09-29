"""Mechanically fork the accepted integration shell into the V2 directory."""
from pathlib import Path
import xml.etree.ElementTree as ET
from os.path import relpath

LAB = Path(__file__).resolve().parents[1]
OLD = LAB.parent / 'audio_core_v1'


def main():
    (LAB / 'src').mkdir(parents=True, exist_ok=True)
    for name, target, changes in (
        ('audio_core.v', 'audio_v2_core.v', {'module audio_core ': 'module audio_v2_core ',
         'DIATONIC=1,N=8': 'DIATONIC=1,N=32,PLUCK_N=8',
         'audio_voice_bank #(.PROFILE(6),.N(N))': 'audio_v2_bank #(.N(N),.PLUCK_N(PLUCK_N))'}),
        ('audio_top.v', 'audio_v2_top.v', {'module audio_top ': 'module audio_v2_top ',
         'parameter ROW_CYCLES=2500': 'parameter PLUCK_N=8,ROW_CYCLES=2500',
         'wire [7:0] occupied,held,gated': 'wire [31:0] occupied,held,gated',
         'audio_core #(': 'audio_v2_core #(.PLUCK_N(PLUCK_N),'}),
    ):
        dest = LAB / 'src' / target
        if dest.exists():
            raise RuntimeError(f'Refusing to overwrite {dest}')
        text = (OLD / 'src' / name).read_text(encoding='utf-8')
        for before, after in changes.items():
            text = text.replace(before, after)
        dest.write_text(text, encoding='utf-8', newline='\n')
    for ext in ('cst', 'sdc'):
        (LAB / 'src' / f'audio_v2.{ext}').write_bytes((OLD / 'src' / f'audio_core.{ext}').read_bytes())

    state = (OLD / 'src/audio_voice_state.v').read_text(encoding='utf-8')
    state = state.replace('module audio_voice_state', 'module audio_v2_state')
    state = state.replace('output reg [31:0] current_step',
        'output reg [31:0] current_step, input wire [48:0] shared_bend_product,\n'
        '    output wire [16:0] current_slew')
    state = state.replace('wire [48:0] bend_product=current_step*bend_slewed;',
        'wire [48:0] bend_product=shared_bend_product;\n    assign current_slew=bend_slewed;')
    (LAB / 'src/audio_v2_state.v').write_text(state, encoding='utf-8', newline='\n')
    slot = (OLD / 'src/audio_voice_slot.v').read_text(encoding='utf-8')
    slot = slot.replace('module audio_voice_slot #(parameter PROFILE=0,',
        'module audio_v2_slot #(parameter PROFILE=6, parameter PLUCK_ONLY=0,')
    slot = slot.replace('output reg signed [19:0] sample',
        'output reg signed [19:0] sample, input wire proc_ce,\n'
        '    input wire [48:0] shared_bend_product, output wire [16:0] current_slew')
    slot = slot.replace('wire selected_pluck=held_timbre==1 || held_timbre==2;',
        'wire selected_pluck=PLUCK_ONLY!=0;')
    start = slot.index('    audio_voice_state #')
    finish = slot.index('\n    always @(posedge clk)', start)
    slot = slot[:start] + '''    generate if(!PLUCK_ONLY) begin: harmonic_path
    audio_v2_state #(.PROFILE(PROFILE)) harmonic(clk,voice_rst,proc_ce,
        on_cmd,off_cmd,phase_step,glide_source_step,held_glide_index,held_timbre,release_step,
        held_timbre==4 ? lead_bend_factor : bend_factor,held_attack_index,
        held_override,held_custom_hold,held_attack,held_decay,held_sustain,
        tone_phase,tone_envelope,tone_brightness,harmonic_state,current_step,
        shared_bend_product,current_slew);
    assign pluck_sample=0;assign pluck_valid=0;assign pluck_ready=1;assign pluck_active=0;
    end else begin: pluck_path
    assign tone_phase=0;assign tone_envelope=0;assign tone_brightness=0;
    assign harmonic_state=0;assign current_step=0;assign current_slew=65536;
    palette_pluck #(.LOGIC_SCALE(1)) pluck(clk,voice_rst,sample_ce,
        (on_cmd||off_cmd),off_cmd ? 2'd1 : 2'd0,
        held_note,9'd256,32'h12345678,length,fraction,reciprocal,pluck_ready,,pluck_active,
        pluck_sample,pluck_valid);
    end endgenerate
''' + slot[finish:]
    (LAB / 'src/audio_v2_slot.v').write_text(slot, encoding='utf-8', newline='\n')

    original = ET.parse(OLD / 'audio_core.gprj')
    omit = {'audio_core.v', 'audio_top.v', 'audio_voice_bank.v', 'audio_voice_slot.v',
            'audio_voice_state.v'}
    dependencies = [(OLD / item.attrib['path']).resolve() for item in original.iter('File')
                    if item.attrib['type'] == 'file.verilog'
                    and Path(item.attrib['path']).name not in omit]
    dependencies += sorted((LAB / 'src').glob('*.v'))
    project = ET.Element('Project')
    ET.SubElement(project, 'Template').text = 'FPGA'
    ET.SubElement(project, 'Version').text = '5'
    ET.SubElement(project, 'Device', {'name': 'GW5AT-60B', 'pn': 'GW5AT-LV60PG484AC1/I0'}).text = 'gw5at60b-002'
    files = ET.SubElement(project, 'FileList')
    for path in dependencies:
        ET.SubElement(files, 'File', {'path': Path(relpath(path, LAB)).as_posix(),
                                    'type': 'file.verilog', 'enable': '1'})
    for ext in ('cst', 'sdc'):
        ET.SubElement(files, 'File', {'path': f'src/audio_v2.{ext}', 'type': f'file.{ext}', 'enable': '1'})
    ET.indent(project)
    ET.ElementTree(project).write(LAB / 'audio_v2.gprj', encoding='UTF-8', xml_declaration=True)


if __name__ == '__main__':
    main()
