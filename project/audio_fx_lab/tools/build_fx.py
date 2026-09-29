from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess
import xml.etree.ElementTree as ET

LAB=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--gowin',default='E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe')
parser.add_argument('--report-only',action='store_true')
args=parser.parse_args()
project=LAB/'audio_fx_lab.gprj'
files=[project,LAB/'build.tcl']
files.extend((LAB/item.attrib['path']).resolve() for item in ET.parse(project).iter('File'))
hashes={path.name:hashlib.sha256(path.read_bytes()).hexdigest() for path in files}
if not args.report_only:
    result=subprocess.run([args.gowin,str(LAB/'build.tcl')],cwd=LAB,capture_output=True,
                          text=True,errors='replace')
    log=result.stdout+'\n'+result.stderr
    (LAB/'impl/build_console.log').write_text(log,encoding='utf-8')
    if result.returncode or re.search(r'ERROR\s*\(',log):
        raise RuntimeError('Gowin failed; see impl/build_console.log')
else:
    report_time=(LAB/'impl/pnr/audio_fx_lab.rpt.txt').stat().st_mtime
    if any(path.stat().st_mtime>report_time for path in files):
        raise RuntimeError('Source newer than existing PnR result')
if hashes!={path.name:hashlib.sha256(path.read_bytes()).hexdigest() for path in files}:
    raise RuntimeError('Source changed during implementation')
report=(LAB/'impl/pnr/audio_fx_lab.rpt.txt').read_text(errors='replace')
timing=(LAB/'impl/pnr/audio_fx_lab_tr_content.html').read_text(errors='replace')
resources={}
for field in ('Logic','Register','BSRAM','DSP','I/O Port'):
    match=re.search(r'^\s*'+re.escape(field)+r'\s*\|\s*(\d+(?:\.\d+)?)/(\d+)',report,re.M)
    if not match:raise RuntimeError(f'Missing resource {field}')
    resources[field]=float(match[1]) if field=='DSP' else int(match[1])
violations={}
for mode in ('Setup','Hold'):
    match=re.search(r'Numbers of '+mode+r' Violated Endpoints</td>\s*<td[^>]*>(\d+)',timing)
    if not match:raise RuntimeError(f'Missing {mode} endpoint count')
    violations[mode.lower()]=int(match[1])
section=timing.split('Setup Paths Table',1)[1].split('Hold Paths Table',1)[0]
rows=re.findall(r'<tr[^>]*>(.*?)</tr>',section,re.S)
cells=re.findall(r'<td[^>]*>(.*?)</td>',rows[1],re.S)
slack=float(re.sub(r'<.*?>','',cells[1]).strip())
section=timing.split('Max Frequency Summary:',1)[1].split('Total Negative Slack',1)[0]
rows=re.findall(r'<tr[^>]*>(.*?)</tr>',section,re.S)
cells=re.findall(r'<td[^>]*>(.*?)</td>',rows[1],re.S)
fmax=float(re.sub(r'<.*?>','',cells[3]).split('(')[0])
record={'candidate':'fx_resource_top','board_tested':False,'resources':resources,
        'setup_violated_endpoints':violations['setup'],'hold_violated_endpoints':violations['hold'],
        'minimum_setup_slack_ns':slack,'fmax_mhz':fmax,
        'timing_pass':not any(violations.values()) and fmax>=50,
        'standalone_only':True,'source_sha256':hashes,
        'bitstream_sha256':hashlib.sha256((LAB/'impl/pnr/audio_fx_lab.fs').read_bytes()).hexdigest()}
(LAB/'pnr_validation.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print(json.dumps(record,indent=2))
if not record['timing_pass']:raise RuntimeError('50MHz timing failed')
