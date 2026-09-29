"""Write structured Gowin project manifests for the unified audio candidate."""
from pathlib import Path
import xml.etree.ElementTree as ET

LAB = Path(__file__).resolve().parents[1]
PROJECT = LAB.parent


def main():
    original = ET.parse(PROJECT / 'custom_harmonic_lab/custom_harmonic.gprj')
    paths = []
    omit = {'custom_gallery_top.v', 'custom_gallery_bank.v', 'custom_gallery_controls.v',
            'custom_gallery_engine.v', 'custom_fader_emulator.v', 'gallery_slot.v', 'gallery_tone_state.v'}
    for item in original.iter('File'):
        source = (PROJECT / 'custom_harmonic_lab' / item.attrib['path']).resolve()
        if item.attrib['type'] == 'file.verilog' and source.name not in omit:
            paths.append(source)
    paths += sorted((LAB / 'src').glob('*.v'))
    paths += [PROJECT / 'audio_parameter_lab/src/audio_parameter_service.v',
              PROJECT / 'audio_fx_lab/src/short_room_reverb.v',
              PROJECT / 'audio_fx_lab/src/vibrato_factor.v']
    project = ET.Element('Project')
    ET.SubElement(project, 'Template').text = 'FPGA'
    ET.SubElement(project, 'Version').text = '5'
    ET.SubElement(project, 'Device', {'name': 'GW5AT-60B', 'pn': 'GW5AT-LV60PG484AC1/I0'}).text = 'gw5at60b-002'
    files = ET.SubElement(project, 'FileList')
    from os.path import relpath
    for path in paths:
        ET.SubElement(files, 'File', {'path': Path(relpath(path, LAB)).as_posix(),
                                     'type': 'file.verilog', 'enable': '1'})
    for extension in ('cst', 'sdc'):
        ET.SubElement(files, 'File', {'path': f'src/audio_core.{extension}',
                                     'type': f'file.{extension}', 'enable': '1'})
    ET.indent(project)
    ET.ElementTree(project).write(LAB / 'audio_core.gprj', encoding='UTF-8', xml_declaration=True)


if __name__ == '__main__':
    main()
