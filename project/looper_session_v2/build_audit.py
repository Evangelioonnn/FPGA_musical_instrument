"""Build an interface audit; preserve positive and negative PnR evidence."""
from pathlib import Path
import argparse,xml.etree.ElementTree as ET,hashlib,subprocess,json,datetime,re,shutil,time
base=Path(__file__).resolve().parent;root=base.parents[1]
p=argparse.ArgumentParser();p.add_argument('--gowin',default='E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe')
p.add_argument('--stage',default='final');p.add_argument('--variant',choices=['external'],default='external');args=p.parse_args()
lab=base/('audit_pll' if args.variant=='pll' else 'audit')
stem='session_audit'
if not re.fullmatch(r'[A-Za-z0-9_-]+',args.stage):raise RuntimeError('Invalid stage name')
files=[lab/(stem+'.gprj'),lab/'build.tcl']+[(lab/e.attrib['path']).resolve() for e in ET.parse(lab/(stem+'.gprj')).findall('.//File')]
def fingerprint():return {str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
before=fingerprint();out=lab/'results'/args.stage;out.mkdir(parents=True,exist_ok=True);started=time.time()
with (out/'build.log').open('w',encoding='utf-8') as log:
    result=subprocess.run([args.gowin,str(lab/'build.tcl')],cwd=root,stdout=log,stderr=subprocess.STDOUT)
if result.returncode:
    failure={'downloadable':False,'pnr_pass':False,'returncode':result.returncode,'sources':before,
             'sta_pass':False,'firmware_available':False,'inputs_unchanged':before==fingerprint(),
             'variant':args.variant,'sdc_period_ns':float(re.search(r'-period\s+([\d.]+)',(lab/(stem+'.sdc')).read_text()).group(1)),
             'time':datetime.datetime.now().astimezone().isoformat(),'log_tail':(out/'build.log').read_text(encoding='utf-8')[-3000:]}
    report=lab/('impl/pnr/'+stem+'.rpt.txt')
    if report.exists() and report.stat().st_mtime>=started:
        shutil.copy2(report,out/report.name);body=report.read_text(errors='replace')
        unrouted=re.search(r'total (\d+) unrouted nets',body)
        if unrouted:failure.update(phase='routing',unrouted_nets=int(unrouted.group(1)))
        failure['resources']={n:int(m.group(1)) for n in ['Logic','Register','CLS','BSRAM','I/O Port']
            if (m:=re.search(r'^  '+re.escape(n)+r'\s*\|\s*(\d+)/',body,re.M))}
        dsp=re.search(r'^  DSP\s*\|\s*([\d.]+)/',body,re.M)
        if dsp:failure['resources']['DSP']=float(dsp.group(1))
        for n in ['PLLA','PLLB']:
            m=re.search(r'^  '+n+r'\s*\|\s*(\d+)/',body,re.M)
            if m:failure['resources'][n]=int(m.group(1))
        failure['resources']['PLL']=sum(failure['resources'].get(n,0) for n in ['PLLA','PLLB'])
        failure['clock_resources']={n:int(v) for n,v in re.findall(r'^  (PRIMARY|LW|GCLK_PIN)\s*\|\s*(\d+)/',body,re.M)}
    (out/'FAILURE.json').write_text(json.dumps(failure,indent=2),encoding='utf-8')
    raise RuntimeError('Gowin build failed; read '+str(out/'build.log'))
if before!=fingerprint():raise RuntimeError('Build inputs changed during build; rerun')
for n in [stem+'.rpt.txt',stem+'_tr_content.html',stem+'.timing_paths']:
    shutil.copy2(lab/'impl/pnr'/n,out/n)
rpt=(out/(stem+'.rpt.txt')).read_text(errors='replace')
timing=(out/(stem+'.timing_paths')).read_text(errors='replace')
resources={n:int(re.search(r'^  '+re.escape(n)+r'\s*\|\s*(\d+)/',rpt,re.M).group(1)) for n in ['Logic','Register','CLS','BSRAM','DSP','I/O Port'] if n!='DSP'}
resources['DSP']=float(re.search(r'^  DSP\s*\|\s*([\d.]+)/',rpt,re.M).group(1))
for n in ['PLLA','PLLB']:
    m=re.search(r'^  '+n+r'\s*\|\s*(\d+)/',rpt,re.M)
    if m:resources[n]=int(m.group(1))
resources['PLL']=sum(resources.get(n,0) for n in ['PLLA','PLLB'])
html=(out/(stem+'_tr_content.html')).read_text(errors='replace')
violations={k:int(re.search('Numbers of '+label+r' Violated Endpoints</td>\s*<td>(\d+)',html).group(1))
    for k,label in [('setup','Setup'),('hold','Hold')]}
fmax=float(re.search(r'Max_Frequency_Report.*?<td>audio_clk</td>\s*<td>[\d.]+\(MHz\)</td>\s*<td[^>]*>([\d.]+)\(MHz\)',html,re.S).group(1))
image=lab/('impl/pnr/'+stem+'.fs')
data={'time':datetime.datetime.now().astimezone().isoformat(),'top':stem+'_top','physical_io':26 if args.variant=='pll' else 27,'variant':args.variant,'downloadable':False,'observer_clock_hz':150000000,
    'clock_hz':50000000,'pnr_pass':True,'sdc_period_ns':float(re.search(r'-period\s+([\d.]+)',(lab/(stem+'.sdc')).read_text()).group(1)),'resources':resources,
    'min_setup_slack_ns':float(re.search(r'SETUP\s*\n([\d.-]+)',timing).group(1)),
    'violated_endpoints':violations,'fmax_mhz':fmax,
    'firmware_sha256':hashlib.sha256(image.read_bytes()).hexdigest(),'sources':before,
    'clock_fmax_mhz':{n:float(v) for n,v in re.findall(r'<td>(audio_clk|observer_clk)</td>\s*<td>[\d.]+\(MHz\)</td>\s*<td[^>]*>([\d.]+)\(MHz\)',html)}}
(out/'BUILD.json').write_text(json.dumps(data,indent=2));print(json.dumps(data|{'sources':'see BUILD.json'},indent=2),flush=True)
if any(violations.values()) or data['min_setup_slack_ns']<0:raise RuntimeError('Timing failed; image is not a deliverable')
