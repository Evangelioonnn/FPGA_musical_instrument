from pathlib import Path
import argparse,hashlib,json,re,subprocess,time,xml.etree.ElementTree as ET
from generate import HERE,VARIANTS
ROOT=HERE.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def build(name,gowin):
    p=HERE/'variants'/name; g=p/(name+'.gprj')
    sources=[g,p/'build.tcl']+[(p/x.attrib['path']).resolve() for x in ET.parse(g).iter('File')]
    before={s.relative_to(ROOT).as_posix():sha(s) for s in sources}
    start=time.time()
    r=subprocess.run([gowin,str(p/'build.tcl')],cwd=ROOT,capture_output=True,text=True,errors='replace')
    log=r.stdout+'\n'+r.stderr; impl=p/'impl';impl.mkdir(exist_ok=True)
    (impl/'build_console.log').write_text(log,encoding='utf-8')
    fs=impl/'pnr'/(name+'.fs')
    rec={'variant':name,'board_tested':False,'source_hashes':before,'exit_code':r.returncode,
         'elapsed_seconds':round(time.time()-start,2),
         'build_pass':r.returncode==0 and not re.search(r'ERROR\s*\(',log) and fs.exists() and fs.stat().st_mtime>=start}
    if before!={s.relative_to(ROOT).as_posix():sha(s) for s in sources}:raise RuntimeError('source changed during '+name)
    if rec['build_pass']:
        report=(impl/'pnr'/(name+'.rpt.txt')).read_text(errors='replace');rec['resources']={}
        for field in ('Logic','Register','BSRAM','DSP','I/O Port'):
            m=re.search(r'^\s*'+re.escape(field)+r'\s*\|\s*(\d+)/(\d+)',report,re.M)
            if not m:raise RuntimeError('missing '+field)
            rec['resources'][field]={'used':int(m[1]),'available':int(m[2])}
        timing=(impl/'pnr'/(name+'_tr_content.html')).read_text(errors='replace')
        for mode in ('Setup','Hold'):
            m=re.search(r'Numbers of '+mode+r' Violated Endpoints</td>\s*<td[^>]*>(\d+)',timing)
            rec[mode.lower()+'_violated_endpoints']=int(m[1]) if m else None
        rec['timing_pass']=rec['setup_violated_endpoints']==0 and rec['hold_violated_endpoints']==0
        rec['budget_pass']=all(rec['resources'][key]['used']<=lim for key,lim in {'Logic':29000,'Register':17000,'BSRAM':70,'DSP':78,'I/O Port':19}.items())
        rec['bitstream_sha256']=sha(fs)
    (impl/'build_provenance.json').write_text(json.dumps(rec,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in rec.items() if k!='source_hashes'},indent=2),flush=True)
    if not all(rec.get(k) for k in ('build_pass','timing_pass','budget_pass')):
        print(log[-5000:]);raise RuntimeError(name+' failed')
    return rec
def main():
    a=argparse.ArgumentParser();a.add_argument('--variant',default='all',choices=['all']+VARIANTS)
    a.add_argument('--gowin',default='E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe');args=a.parse_args()
    for n in (VARIANTS if args.variant=='all' else [args.variant]):build(n,args.gowin)
if __name__=='__main__':main()
