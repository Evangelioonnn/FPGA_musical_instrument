"""Measure the 16-voice core; this unpinned target is never board firmware."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parents[1]
ROOT = HERE.parents[1]
NAME = 'five_capacity16'
PROJECT = HERE / 'experiments/capacity16'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--gowin', default='E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe')
    args = parser.parse_args()
    gprj = PROJECT / (NAME+'.gprj')
    sources = [gprj, PROJECT/'build.tcl']
    sources += [(PROJECT / element.attrib['path']).resolve()
                for element in ET.parse(gprj).iter('File')]
    before = {str(path.relative_to(ROOT)): digest(path) for path in sources}
    start = time.time()
    proc = subprocess.run([args.gowin, str(PROJECT/'build.tcl')], cwd=ROOT,
                          capture_output=True, text=True, errors='replace')
    impl = PROJECT/'impl'
    impl.mkdir(exist_ok=True)
    (impl/'build_console.log').write_text(proc.stdout+'\n'+proc.stderr)
    if before != {str(path.relative_to(ROOT)): digest(path) for path in sources}:
        raise RuntimeError('sources changed during capacity build')
    rec = {'variant':NAME, 'synthesis_only_capacity_probe':True,
           'board_programmable':False, 'board_tested':False,
           'elapsed_seconds':round(time.time()-start,2),
           'exit_code':proc.returncode, 'source_hashes':before}
    report = impl/'pnr'/(NAME+'.rpt.txt')
    if report.exists() and report.stat().st_mtime>=start:
        content = report.read_text(errors='replace')
        rec['resources'] = {}
        for field in ('Logic','Register','BSRAM','DSP','I/O Port'):
            match = re.search(r'^\s*'+re.escape(field)+r'\s*\|\s*(\d+(?:\.\d+)?)/(\d+)',content,re.M)
            if match:
                rec['resources'][field] = {'used':float(match[1]) if field=='DSP' else int(match[1]),
                                           'available':int(match[2])}
        timing = (impl/'pnr'/(NAME+'_tr_content.html'))
        if timing.exists():
            html = timing.read_text(errors='replace')
            for mode in ('Setup','Hold'):
                match = re.search(r'Numbers of '+mode+r' Violated Endpoints</td>\s*<td[^>]*>(\d+)',html)
                rec[mode.lower()+'_violated_endpoints'] = int(match[1]) if match else None
        if all(field in rec['resources'] for field in ('BSRAM','DSP')):
            rec['within_audio_input_budget'] = (rec['resources']['BSRAM']['used']<=70 and
                                                  rec['resources']['DSP']['used']<=78)
    (impl/'capacity_result.json').write_text(json.dumps(rec,indent=2)+'\n')
    print(json.dumps({key:value for key,value in rec.items() if key!='source_hashes'},indent=2))
    if proc.returncode:
        print((proc.stdout+'\n'+proc.stderr)[-3000:])
        raise RuntimeError('capacity build failed')


if __name__=='__main__':
    main()
