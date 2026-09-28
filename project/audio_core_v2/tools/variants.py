"""Create isolated physical build projects using structured GPRJ XML."""
from pathlib import Path
import os
import xml.etree.ElementTree as ET

LAB = Path(__file__).resolve().parents[1]
for name, capacity, bank in [('ram8', 8, 'ram'), ('pool8', 8, 'pool'),
                              ('pool12', 12, 'pool'), ('pool16', 16, 'pool'),
                              ('compact12', 12, 'compact'), ('compact16', 16, 'compact'),
                              ('stream12', 12, 'stream'), ('stream16', 16, 'stream')]:
    directory = LAB / 'variants' / name
    directory.mkdir(parents=True, exist_ok=True)
    tree = ET.parse(LAB / 'audio_v2.gprj')
    listing = tree.find('FileList')
    for item in listing:
        source = (LAB / item.attrib['path']).resolve()
        if source.name in ('audio_v2_bank.v','audio_v2_bank_stream.v'):
            source = LAB / f'src/audio_v2_bank_{bank}.v'
        item.attrib['path'] = Path(os.path.relpath(source, directory)).as_posix()
    if bank in ('pool', 'compact', 'stream'):
        for source in ['audio_v2_pluck.v', 'audio_v2_pool_slot.v']:
            path=f'../../src/{source}'
            if not any(x.attrib['path']==path for x in listing):
                ET.SubElement(listing, 'File', {'path': path, 'type': 'file.verilog', 'enable': '1'})
    if bank in ('compact', 'stream'):
        if not any(x.attrib['path']=='../../src/audio_v2_tone.v' for x in listing):
            ET.SubElement(listing, 'File', {'path': '../../src/audio_v2_tone.v', 'type': 'file.verilog', 'enable': '1'})
    ET.SubElement(listing, 'File', {'path': 'top.v', 'type': 'file.verilog', 'enable': '1'})
    ET.indent(tree)
    tree.write(directory / f'{name}.gprj', encoding='UTF-8', xml_declaration=True)
    (directory / 'top.v').write_text(f'''module {name}_top(
    input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led
);
    audio_v2_top #(.PLUCK_N({capacity})) instrument(
        sys_clk,enc_a,enc_b,button_n,matrix_col_n,matrix_row_n,
        hp_bck,hp_ws,hp_din,pa_en,status_led);
endmodule
''', encoding='ascii')
    (directory / 'build.tcl').write_text(f'''set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir {name}.gprj]
set_option -top_module {name}_top
set_option -output_base_name {name}
run all
''', encoding='ascii')
    print(directory.relative_to(LAB))
