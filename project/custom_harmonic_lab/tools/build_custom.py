from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET

LAB = Path(__file__).resolve().parents[1]
ROOT = LAB.parents[1]
DEFAULT_GOWIN = 'E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--gowin', default=DEFAULT_GOWIN)
    args = parser.parse_args()
    project = LAB / 'custom_harmonic.gprj'
    tcl = LAB / 'build.tcl'
    files = [project, tcl]
    files.extend((LAB / item.attrib['path']).resolve()
                 for item in ET.parse(project).iter('File'))
    hashes = {path.relative_to(ROOT).as_posix(): sha(path) for path in files}
    started = time.time()
    result = subprocess.run([args.gowin, str(tcl)], cwd=ROOT,
                            capture_output=True, text=True, errors='replace')
    log = result.stdout + '\n' + result.stderr
    impl = LAB / 'impl'
    impl.mkdir(exist_ok=True)
    (impl / 'build_console.log').write_text(log, encoding='utf-8')
    pnr = impl / 'pnr'
    report_path = pnr / 'custom_harmonic.rpt.txt'
    timing_path = pnr / 'custom_harmonic_tr_content.html'
    fs = pnr / 'custom_harmonic.fs'
    if result.returncode or re.search(r'ERROR\s*\(', log) or not report_path.exists() or not fs.exists():
        raise RuntimeError('Gowin build failed. See impl/build_console.log')
    if hashes != {path.relative_to(ROOT).as_posix(): sha(path) for path in files}:
        raise RuntimeError('A source file changed while the build was running')

    report = report_path.read_text(errors='replace')
    resources = {}
    for field in ('Logic', 'Register', 'BSRAM', 'DSP', 'I/O Port'):
        match = re.search(r'^\s*' + re.escape(field) + r'\s*\|\s*(\d+(?:\.\d+)?)/(\d+)', report, re.M)
        if not match:
            raise RuntimeError(f'Missing resource row: {field}')
        resources[field] = {'used': float(match[1]) if field == 'DSP' else int(match[1]),
                            'available': int(match[2])}

    timing = timing_path.read_text(errors='replace')
    violations = {}
    for mode in ('Setup', 'Hold'):
        match = re.search(r'Numbers of ' + mode + r' Violated Endpoints</td>\s*<td[^>]*>(\d+)', timing)
        violations[mode.lower()] = int(match[1]) if match else None
    setup_section = timing.split('Setup Paths Table', 1)[1].split('Hold Paths Table', 1)[0]
    rows = re.findall(r'<tr[^>]*>(.*?)</tr>', setup_section, re.S)
    cells = re.findall(r'<td[^>]*>(.*?)</td>', rows[1], re.S) if len(rows) > 1 else []
    min_setup_slack = float(re.sub(r'<.*?>', '', cells[1]).strip()) if len(cells) > 1 else None
    fmax_section = timing.split('Max Frequency Summary:', 1)[1].split('Total Negative Slack', 1)[0]
    fmax_rows = re.findall(r'<tr[^>]*>(.*?)</tr>', fmax_section, re.S)
    fmax_cells = re.findall(r'<td[^>]*>(.*?)</td>', fmax_rows[1], re.S) if len(fmax_rows) > 1 else []
    fmax = float(re.sub(r'<.*?>', '', fmax_cells[3]).split('(')[0]) if len(fmax_cells) > 3 else None
    if any(value is None for value in violations.values()):
        raise RuntimeError('Could not parse setup/hold violation counts from PnR timing report')
    if min_setup_slack is None or fmax is None:
        raise RuntimeError('Could not parse setup slack or Fmax from PnR timing report')
    budget = {'Logic': 29000, 'Register': 17000, 'BSRAM': 70, 'DSP': 78, 'I/O Port': 19}
    record = {
        'candidate': 'custom_harmonic',
        'board_tested': False,
        'build_pass': True,
        'resources': resources,
        'setup_violated_endpoints': violations['setup'],
        'hold_violated_endpoints': violations['hold'],
        'minimum_setup_slack_ns': min_setup_slack,
        'fmax_mhz': fmax,
        'budget': budget,
        'budget_pass': all(resources[key]['used'] <= limit for key, limit in budget.items()),
        'timing_pass': violations['setup'] == 0 and violations['hold'] == 0 and fmax is not None and fmax >= 50,
        'elapsed_seconds': round(time.time() - started, 2),
        'bitstream_sha256': sha(fs),
        'source_sha256': hashes,
    }
    (impl / 'build_provenance.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: value for key, value in record.items() if key != 'source_sha256'}, indent=2))
    if not record['budget_pass'] or not record['timing_pass']:
        raise RuntimeError('Build completed but resource budget or 50 MHz timing failed')


if __name__ == '__main__':
    main()
