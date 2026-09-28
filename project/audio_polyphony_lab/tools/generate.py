"""Generate deterministic Gowin projects; no source HDL is generated."""
from pathlib import Path
import xml.etree.ElementTree as ET

LAB = Path(__file__).resolve().parents[1]
ROOT = LAB.parents[1]
SOURCES = [
    LAB / 'src/piano_poly_core.v', LAB / 'src/poly_controls.v', LAB / 'src/piano_poly_top.v',
    ROOT / 'project/final_dual_timbre/src/note_table.v',
    ROOT / 'project/audio_palette_lab/src/palette_sine.v',
    ROOT / 'project/final_dual_timbre/src/matrix_scanner.v',
    ROOT / 'project/final_dual_timbre/src/ec11_input.v',
    ROOT / 'project/final_dual_timbre/src/playable_button.v',
    ROOT / 'project/final_dual_timbre/src/stream_fifo.v',
    ROOT / 'project/final_dual_timbre/src/knob_volume_table.v',
    ROOT / 'project/final_dual_timbre/src/knob_gain.v',
    ROOT / 'project/final_dual_timbre/src/pt8211_tx.v',
    ROOT / 'project/five_timbre_core/src/gallery_keys.v',
    ROOT / 'project/five_timbre_core/src/gallery_led.v',
]


def main():
    import os
    constraints = LAB / 'src/poly.cst'
    constraints.write_text((ROOT / 'project/five_timbre_core/src/gallery.cst').read_text(), encoding='ascii')
    timing = LAB / 'src/poly.sdc'
    timing.write_text((ROOT / 'project/five_timbre_core/src/gallery.sdc').read_text(), encoding='ascii')
    for name, voices, shift in [('piano16', 16, 1), ('piano32', 32, 2),
                                ('piano16_full', 16, 0), ('piano32_full', 32, 0)]:
        directory = LAB / 'variants' / name
        directory.mkdir(parents=True, exist_ok=True)
        top = directory / 'top.v'
        top.write_text(f'''module {name}_top(
    input wire sys_clk,enc_a,enc_b,input wire [2:0] button_n,
    input wire [3:0] matrix_col_n,output wire [3:0] matrix_row_n,
    output wire hp_bck,hp_ws,hp_din,pa_en,status_led
);
    piano_poly_top #(.N({voices}),.OUTPUT_SHIFT({shift})) instrument(
        sys_clk,enc_a,enc_b,button_n,matrix_col_n,matrix_row_n,
        hp_bck,hp_ws,hp_din,pa_en,status_led);
endmodule
''', encoding='ascii')
        project = ET.Element('Project')
        ET.SubElement(project, 'Template').text = 'FPGA'
        ET.SubElement(project, 'Version').text = '5'
        ET.SubElement(project, 'Device', name='GW5AT-60B', pn='GW5AT-LV60PG484AC1/I0').text = 'gw5at60b-002'
        files = ET.SubElement(project, 'FileList')
        for source, kind in [(top, 'file.verilog'), *[(p, 'file.verilog') for p in SOURCES],
                             (constraints, 'file.cst'), (timing, 'file.sdc')]:
            ET.SubElement(files, 'File', path=os.path.relpath(source, directory).replace('\\', '/'), type=kind, enable='1')
        ET.indent(project, space='  ')
        (directory / f'{name}.gprj').write_text('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE gowin-fpga-project>\n' +
            ET.tostring(project, encoding='unicode') + '\n', encoding='ascii')
        (directory / 'build.tcl').write_text(f'''set project_dir [file dirname [file normalize [info script]]]
open_project [file join $project_dir {name}.gprj]
set_option -top_module {name}_top
set_option -output_base_name {name}
run all
''', encoding='ascii')
    print('Generated 16/32 safe and full-level diagnostic projects.')


if __name__ == '__main__':
    main()
