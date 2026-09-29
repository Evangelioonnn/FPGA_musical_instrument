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


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def timing_fields(text):
    violations = {}
    for mode in ('Setup', 'Hold'):
        match = re.search(r'Numbers of ' + mode + r' Violated Endpoints</td>\s*<td[^>]*>(\d+)', text)
        if not match:
            raise RuntimeError(f'Missing {mode} violation count')
        violations[mode.lower()] = int(match[1])
    section = text.split('Setup Paths Table', 1)[1].split('Hold Paths Table', 1)[0]
    rows = re.findall(r'<tr[^>]*>(.*?)</tr>', section, re.S)
    cells = re.findall(r'<td[^>]*>(.*?)</td>', rows[1], re.S)
    slack = float(re.sub(r'<.*?>', '', cells[1]).strip())
    section = text.split('Max Frequency Summary:', 1)[1].split('Total Negative Slack', 1)[0]
    rows = re.findall(r'<tr[^>]*>(.*?)</tr>', section, re.S)
    cells = re.findall(r'<td[^>]*>(.*?)</td>', rows[1], re.S)
    fmax = float(re.sub(r'<.*?>', '', cells[3]).split('(')[0])
    return violations, slack, fmax


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--gowin', default='E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe')
    args = parser.parse_args()
    project = LAB / 'audio_core.gprj'
    files = [project, LAB / 'build.tcl']
    files += [(LAB / item.attrib['path']).resolve() for item in ET.parse(project).iter('File')]
    source_hashes = {p.relative_to(ROOT).as_posix(): sha(p) for p in files}
    started = time.time()
    result = subprocess.run([args.gowin, str(LAB / 'build.tcl')], cwd=ROOT,
                            capture_output=True, text=True, errors='replace')
    log = result.stdout + '\n' + result.stderr
    impl = LAB / 'impl'
    impl.mkdir(exist_ok=True)
    (impl / 'build_console.log').write_text(log, encoding='utf-8')
    pnr = impl / 'pnr'
    fs = pnr / 'audio_core.fs'
    if result.returncode or re.search(r'ERROR\s*\(', log) or not fs.exists():
        raise RuntimeError('Gowin failed; see impl/build_console.log')
    if source_hashes != {p.relative_to(ROOT).as_posix(): sha(p) for p in files}:
        raise RuntimeError('Source changed during build; bitstream is not approved')
    report = (pnr / 'audio_core.rpt.txt').read_text(errors='replace')
    resources = {}
    for field in ('Logic', 'Register', 'BSRAM', 'DSP', 'I/O Port'):
        match = re.search(r'^\s*' + re.escape(field) + r'\s*\|\s*(\d+(?:\.\d+)?)/(\d+)', report, re.M)
        if not match:
            raise RuntimeError(f'Missing resource row {field}')
        resources[field] = {'used': float(match[1]) if field == 'DSP' else int(match[1]),
                            'available': int(match[2])}
    violations, slack, fmax = timing_fields((pnr / 'audio_core_tr_content.html').read_text(errors='replace'))
    budget = {'Logic': 29000, 'Register': 17000, 'BSRAM': 70, 'DSP': 78, 'I/O Port': 19}
    record = {
        'candidate': 'audio_core', 'board_tested': False,
        'scope': 'physical matrix/EC11/button top; external host/ADC tied idle; observations not consumed',
        'build_pass': True, 'resources': resources,
        'setup_violated_endpoints': violations['setup'], 'hold_violated_endpoints': violations['hold'],
        'minimum_setup_slack_ns': slack, 'fmax_mhz': fmax, 'budget': budget,
        'budget_pass': all(resources[k]['used'] <= limit for k, limit in budget.items()),
        'timing_pass': violations['setup']==0 and violations['hold']==0 and fmax>=50,
        'elapsed_seconds': round(time.time()-started, 2), 'bitstream_sha256': sha(fs),
        'source_sha256': source_hashes,
    }
    (impl / 'build_provenance.json').write_text(json.dumps(record, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k:v for k,v in record.items() if k!='source_sha256'}, indent=2))
    if not record['budget_pass'] or not record['timing_pass']:
        raise RuntimeError('Resource budget or 50 MHz timing gate failed')


if __name__ == '__main__':
    main()
