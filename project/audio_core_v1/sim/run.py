from pathlib import Path
import argparse
import json
import re
import subprocess
import xml.etree.ElementTree as ET

LAB = Path(__file__).resolve().parents[1]
HERE = LAB / 'sim'
parser = argparse.ArgumentParser()
parser.add_argument('--modelsim', default='E:/QuartusII/modelsim_ase/win32aloem')
parser.add_argument('--test', action='append')
args = parser.parse_args()


def run(tool, options):
    result = subprocess.run([str(Path(args.modelsim) / tool), *options], cwd=HERE,
                            capture_output=True, text=True, errors='replace')
    log = result.stdout + '\n' + result.stderr
    if result.returncode or re.search(r'\*\* (Error|Fatal)', log):
        raise RuntimeError(f'{tool}:\n{log[-6000:]}')
    return log


if not (HERE / 'work_audio_v1').exists():
    run('vlib.exe', ['work_audio_v1'])
sources = [str((LAB / item.attrib['path']).resolve())
           for item in ET.parse(LAB / 'audio_core.gprj').iter('File')
           if item.attrib['type'] == 'file.verilog']
sources += [str(LAB.parent / 'custom_harmonic_lab/src/custom_gallery_bank.v'),
            str(LAB.parent / 'five_timbre_core/src/gallery_slot.v'),
            str(LAB.parent / 'five_timbre_core/src/gallery_tone_state.v')]
sources += [str(path) for path in sorted(HERE.glob('*_tb.v'))]
run('vlog.exe', ['-vlog01compat', '-work', 'work_audio_v1', *sources])
tests = args.test or ['audio_equivalence_tb', 'audio_core_tb', 'audio_board_tb']
record_path=HERE/'validation.json'
passed = json.loads(record_path.read_text()) if record_path.exists() else []
for top in tests:
    marker = top.upper().replace('_TB', '_TB_PASS')
    log = run('vsim.exe', ['-c', '-lib', 'work_audio_v1', top,
                         '-l', f'{top}.log', '-do', 'run -all; quit -f'])
    if marker not in log:
        raise RuntimeError(f'{top} missing PASS marker:\n{log[-6000:]}')
    line = next(line for line in log.splitlines() if marker in line)
    print(line,flush=True)
    passed=[row for row in passed if row['test']!=top]
    passed.append({'test': top, 'result': line})
    record_path.write_text(json.dumps(passed, indent=2)+'\n', encoding='utf-8')
