from pathlib import Path
import argparse
import re
import subprocess
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parent
LAB = HERE.parent
FIVE = LAB.parent / 'five_timbre_core'
DEFAULT_MODELSIM = 'E:/QuartusII/modelsim_ase/win32aloem'

parser = argparse.ArgumentParser()
parser.add_argument('--modelsim', default=DEFAULT_MODELSIM)
args = parser.parse_args()


def run(tool, options):
    result = subprocess.run(
        [str(Path(args.modelsim) / tool), *options], cwd=HERE,
        capture_output=True, text=True, errors='replace')
    log = result.stdout + '\n' + result.stderr
    if result.returncode or re.search(r'\*\* (Error|Fatal)', log):
        raise RuntimeError(f'{tool} failed:\n{log[-6000:]}')
    return log


library = HERE / 'work_custom'
if not library.exists():
    run('vlib.exe', ['work_custom'])
project = ET.parse(LAB / 'custom_harmonic.gprj')
sources = [str((LAB / item.attrib['path']).resolve())
           for item in project.iter('File')
           if item.attrib['type'] == 'file.verilog']
sources += [str(HERE.parent / 'src' / 'custom_harmonic_tone.v')]
sources += [str(HERE / name) for name in
            ('custom_params_tb.v', 'custom_harmonic_tb.v', 'custom_gallery_tb.v',
             'custom_volume_audio_tb.v', 'custom_live_scan_tb.v', 'custom_fader_tb.v')]
run('vlog.exe', ['-vlog01compat', '-work', 'work_custom', *sources])
for top, marker in (
    ('custom_params_tb', 'CUSTOM_PARAMS_TB_PASS'),
    ('custom_harmonic_tb', 'CUSTOM_HARMONIC_TB_PASS'),
    ('custom_gallery_tb', 'CUSTOM_GALLERY_TB_PASS'),
    ('custom_volume_audio_tb', 'CUSTOM_VOLUME_AUDIO_TB_PASS'),
    ('custom_live_scan_tb', 'CUSTOM_LIVE_SCAN_TB_PASS'),
    ('custom_fader_tb', 'CUSTOM_FADER_TB_PASS'),
):
    log = run('vsim.exe', ['-c', '-lib', 'work_custom', top,
                           '-l', f'{top}_transcript.log',
                           '-do', 'run -all; quit -f'])
    if marker not in log:
        raise RuntimeError(f'{top} did not report its PASS marker:\n{log[-6000:]}')
    print(next(line for line in log.splitlines() if marker in line))
