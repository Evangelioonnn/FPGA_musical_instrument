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


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--gowin', default='E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe')
    parser.add_argument('--variants', nargs='+', default=['piano16', 'piano32'])
    args = parser.parse_args()
    for name in args.variants:
        directory = LAB / 'variants' / name
        project, tcl = directory / f'{name}.gprj', directory / 'build.tcl'
        files = [project, tcl, *[(directory / item.attrib['path']).resolve() for item in ET.parse(project).iter('File')]]
        hashes = {str(path.relative_to(ROOT)).replace('\\', '/'): sha(path) for path in files}
        started = time.time()
        result = subprocess.run([args.gowin, str(tcl)], cwd=ROOT, capture_output=True, text=True, errors='replace')
        log = result.stdout + '\n' + result.stderr
        impl = directory / 'impl'
        impl.mkdir(exist_ok=True)
        (impl / 'build_console.log').write_text(log, encoding='utf-8')
        report_path = impl / 'pnr' / f'{name}.rpt.txt'
        timing_path = impl / 'pnr' / f'{name}_tr_content.html'
        bitstream = impl / 'pnr' / f'{name}.fs'
        if result.returncode or re.search(r'ERROR\s*\(', log) or not report_path.exists() or not bitstream.exists():
            raise RuntimeError(f'{name} build failed; see {impl / "build_console.log"}')
        if hashes != {str(path.relative_to(ROOT)).replace('\\', '/'): sha(path) for path in files}:
            raise RuntimeError('Sources changed during build')
        report = report_path.read_text(errors='replace')
        resources = {}
        for field in ('Logic', 'Register', 'BSRAM', 'DSP', 'I/O Port'):
            match = re.search(r'^\s*' + re.escape(field) + r'\s*\|\s*(\d+(?:\.\d+)?)/(\d+)', report, re.M)
            if not match: raise RuntimeError('Missing resource row ' + field)
            resources[field] = float(match[1]) if field == 'DSP' else int(match[1])
        timing = timing_path.read_text(errors='replace')
        violations = {}
        for mode in ('Setup', 'Hold'):
            match = re.search(r'Numbers of ' + mode + r' Violated Endpoints</td>\s*<td[^>]*>(\d+)', timing)
            if not match: raise RuntimeError('Missing timing endpoint count')
            violations[mode.lower()] = int(match[1])
        section = timing.split('Setup Paths Table', 1)[1].split('Hold Paths Table', 1)[0]
        rows = re.findall(r'<tr[^>]*>(.*?)</tr>', section, re.S)
        cells = re.findall(r'<td[^>]*>(.*?)</td>', rows[1], re.S)
        slack = float(re.sub(r'<.*?>', '', cells[1]).strip())
        section = timing.split('Max Frequency Summary:', 1)[1].split('Total Negative Slack', 1)[0]
        rows = re.findall(r'<tr[^>]*>(.*?)</tr>', section, re.S)
        cells = re.findall(r'<td[^>]*>(.*?)</td>', rows[1], re.S)
        fmax = float(re.sub(r'<.*?>', '', cells[3]).split('(')[0])
        budget = {'Logic':29000, 'Register':17000, 'BSRAM':70, 'DSP':78, 'I/O Port':19}
        record = dict(candidate=name, board_tested=False, resources=resources,
            setup_violated_endpoints=violations['setup'], hold_violated_endpoints=violations['hold'],
            minimum_setup_slack_ns=slack, fmax_mhz=fmax,
            budget_pass=all(resources[k]<=v for k,v in budget.items()),
            timing_pass=violations['setup']==0 and violations['hold']==0 and fmax>=50,
            elapsed_seconds=round(time.time()-started,2), bitstream_sha256=sha(bitstream), source_sha256=hashes)
        (impl / 'build_provenance.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
        evidence = LAB / 'results'
        evidence.mkdir(exist_ok=True)
        (evidence / f'{name}_pnr.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
        print(json.dumps({k:v for k,v in record.items() if k!='source_sha256'},indent=2),flush=True)
        if not record['budget_pass'] or not record['timing_pass']:
            raise RuntimeError(f'{name} resource/50MHz timing failed')


if __name__ == '__main__':
    main()
