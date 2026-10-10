"""Build and fingerprint the sole board candidate. Preserve PnR evidence."""
from pathlib import Path
import argparse,xml.etree.ElementTree as ET,hashlib,subprocess,json,datetime,re,shutil
lab=Path(__file__).resolve().parent;root=lab.parents[1]
p=argparse.ArgumentParser();p.add_argument('--gowin',default='E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe')
p.add_argument('--stage',default='final');args=p.parse_args()
files=[lab/'looper_session_v2.gprj',lab/'build.tcl']+[(lab/e.attrib['path']).resolve() for e in ET.parse(lab/'looper_session_v2.gprj').findall('.//File')]
def fingerprint():return {str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
before=fingerprint();out=lab/'results'/args.stage;out.mkdir(parents=True,exist_ok=True)
with (out/'build.log').open('w',encoding='utf-8') as log:
    result=subprocess.run([args.gowin,str(lab/'build.tcl')],cwd=root,stdout=log,stderr=subprocess.STDOUT)
if result.returncode:raise RuntimeError('Gowin build failed; read '+str(out/'build.log'))
if before!=fingerprint():raise RuntimeError('Build inputs changed during build; rerun')
for n in ['looper_session_v2.rpt.txt','looper_session_v2_tr_content.html','looper_session_v2.timing_paths']:
    shutil.copy2(lab/'impl/pnr'/n,out/n)
rpt=(out/'looper_session_v2.rpt.txt').read_text(errors='replace')
timing=(out/'looper_session_v2.timing_paths').read_text(errors='replace')
resources={n:int(re.search(r'^  '+re.escape(n)+r'\s*\|\s*(\d+)/',rpt,re.M).group(1)) for n in ['Logic','Register','CLS','BSRAM','DSP','I/O Port'] if n!='DSP'}
resources['DSP']=float(re.search(r'^  DSP\s*\|\s*([\d.]+)/',rpt,re.M).group(1))
html=(out/'looper_session_v2_tr_content.html').read_text(errors='replace')
violations={k:int(re.search('Numbers of '+label+r' Violated Endpoints</td>\s*<td>(\d+)',html).group(1))
    for k,label in [('setup','Setup'),('hold','Hold')]}
fmax=float(re.search(r'Max_Frequency_Report.*?<td>sys_clk</td>\s*<td>[\d.]+\(MHz\)</td>\s*<td[^>]*>([\d.]+)\(MHz\)',html,re.S).group(1))
image=lab/'impl/pnr/looper_session_v2.fs'
data={'time':datetime.datetime.now().astimezone().isoformat(),'top':'looper_session_top','physical_io':19,
    'clock_hz':50000000,'sdc_period_ns':float(re.search(r'-period\s+([\d.]+)',(lab/'src/looper_session_v2.sdc').read_text()).group(1)),'resources':resources,
    'min_setup_slack_ns':float(re.search(r'SETUP\s*\n([\d.-]+)',timing).group(1)),
    'violated_endpoints':violations,'fmax_mhz':fmax,
    'firmware_sha256':hashlib.sha256(image.read_bytes()).hexdigest(),'sources':before}
(out/'BUILD.json').write_text(json.dumps(data,indent=2));print(json.dumps(data|{'sources':'see BUILD.json'},indent=2),flush=True)
if any(violations.values()) or data['min_setup_slack_ns']<0:raise RuntimeError('Timing failed; image is not a deliverable')
