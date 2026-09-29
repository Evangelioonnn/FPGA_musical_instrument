"""Recreate the portable Gowin project, including every handwritten dependency."""
from pathlib import Path
import os
import xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parents[1]
ROOT=HERE.parents[2]
sources=list(sorted((HERE/'src').glob('*.v')))
sources += [ROOT/p for p in [
 'project/input/src/matrix_scanner.v','project/input/src/ec11_input.v',
 'project/system/src/stream_fifo.v',
 'project/input/knob_suite/src/knob_reference_voice.v',
 'project/input/knob_suite/src/knob_gain.v','project/input/knob_suite/src/knob_volume_table.v',
 'project/instrument/src/synth_voice.v','project/instrument/src/adsr_envelope.v',
 'project/instrument/src/sine_rom.v','project/instrument/src/note_table.v',
 'project/instrument/src/pt8211_tx.v',
 'project/experiments/timbre/fm/src/fm_note_table.v',
 'project/experiments/timbre/fm/src/fm_sine_interp.v','project/experiments/timbre/fm/src/fm_sine_rom.v',
 'project/experiments/timbre/pluck/src/pluck_voice.v','project/experiments/timbre/pluck/src/pluck_note_table.v']]
project=ET.Element('Project')
ET.SubElement(project,'Template').text='FPGA'
ET.SubElement(project,'Version').text='5'
ET.SubElement(project,'Device',name='GW5AT-60B',pn='GW5AT-LV60PG484AC1/I0').text='gw5at60b-002'
files=ET.SubElement(project,'FileList')
for path in sources+[HERE/'src/matrix_playable.cst',HERE/'src/matrix_playable.sdc']:
    if not path.exists():raise FileNotFoundError(path)
    ET.SubElement(files,'File',path=Path(os.path.relpath(path,HERE)).as_posix(),
                  type='file.'+{'v':'verilog','cst':'cst','sdc':'sdc'}[path.suffix[1:]],enable='1')
ET.indent(project,space='  ')
(HERE/'matrix_playable.gprj').write_text('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE gowin-fpga-project>\n'+ET.tostring(project,encoding='unicode')+'\n')
print('Created matrix_playable.gprj with',len(sources),'Verilog sources')
