"""Build the entire current board candidate and enforce timing/resource gates."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET

LAB = Path(__file__).resolve().parents[1]
ROOT = LAB.parents[1]
helper = importlib.util.spec_from_file_location('v1_build', LAB.parent / 'audio_core_v1/tools/build.py')
v1 = importlib.util.module_from_spec(helper)
helper.loader.exec_module(v1)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--gowin', default='E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe')
    parser.add_argument('--variant', choices=['ram8', 'pool8', 'pool12', 'pool16','compact12','compact16','stream12','stream16'])
    args = parser.parse_args()
    directory = LAB / 'variants' / args.variant if args.variant else LAB
    stem = args.variant or 'audio_v2'
    project = directory / f'{stem}.gprj'
    files = [project, directory / 'build.tcl'] + [
        (directory / item.attrib['path']).resolve() for item in ET.parse(project).iter('File')]
    hashes = {p.relative_to(ROOT).as_posix(): sha(p) for p in files}
    start = time.time()
    result = subprocess.run([args.gowin, str(directory / 'build.tcl')], cwd=ROOT,
                            capture_output=True, text=True, errors='replace')
    log = result.stdout + '\n' + result.stderr
    impl = directory / 'impl'
    impl.mkdir(exist_ok=True)
    (impl / 'build_console.log').write_text(log, encoding='utf-8')
    fs = impl / f'pnr/{stem}.fs'
    if result.returncode or re.search(r'ERROR\s*\(', log) or not fs.exists():
        raise RuntimeError('Gowin failed; see impl/build_console.log')
    if hashes != {p.relative_to(ROOT).as_posix(): sha(p) for p in files}:
        raise RuntimeError('Source changed during build; reject this bitstream')
    report = (impl / f'pnr/{stem}.rpt.txt').read_text(errors='replace')
    resources = {}
    for field in ('Logic', 'Register', 'BSRAM', 'DSP', 'I/O Port'):
        match = re.search(r'^\s*' + re.escape(field) + r'\s*\|\s*(\d+(?:\.\d+)?)/(\d+)', report, re.M)
        if not match:
            raise RuntimeError(f'Missing resource row {field}')
        resources[field] = {'used': float(match[1]) if field == 'DSP' else int(match[1]),
                            'available': int(match[2])}
    violations, slack, fmax = v1.timing_fields((impl / f'pnr/{stem}_tr_content.html').read_text(errors='replace'))
    budget = {'Logic': 29000, 'Register': 17000, 'BSRAM': 70, 'DSP': 78, 'I/O Port': 19}
    record = {'candidate': stem, 'board_tested': False,
              'build_pass': True, 'resources': resources,
              'setup_violated_endpoints': violations['setup'], 'hold_violated_endpoints': violations['hold'],
              'minimum_setup_slack_ns': slack, 'fmax_mhz': fmax, 'budget': budget,
              'budget_pass': all(resources[k]['used'] <= cap for k, cap in budget.items()),
              'timing_pass': violations['setup'] == 0 and violations['hold'] == 0 and fmax >= 50,
              'elapsed_seconds': round(time.time() - start, 2), 'bitstream_sha256': sha(fs),
              'source_sha256': hashes}
    (impl / 'build_provenance.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: v for k, v in record.items() if k != 'source_sha256'}, indent=2), flush=True)
    if not record['timing_pass'] or not record['budget_pass']:
        raise RuntimeError('Current whole-audio build exceeds timing or resource budget')


if __name__ == '__main__':
    main()
