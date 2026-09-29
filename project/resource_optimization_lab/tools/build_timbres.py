from pathlib import Path
import argparse, hashlib, json, os, re, subprocess, time

HERE=Path(__file__).resolve().parents[1]
ROOT=HERE.parents[2]
VARIANTS=('harmonic','pluck')
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def sources():
    g=HERE/'resource_timbre.gprj'
    import xml.etree.ElementTree as ET
    return [g,HERE/'resource_timbre.tcl']+[(HERE/e.attrib['path']).resolve() for e in ET.parse(g).iter('File')]
def build(v,gowin):
    before={p.relative_to(ROOT).as_posix():sha(p) for p in sources()}; started=time.time()
    env=os.environ.copy(); env['RESOURCE_TIMBRE_VARIANT']=v
    r=subprocess.run([gowin,str(HERE/'resource_timbre.tcl')],cwd=ROOT,env=env,capture_output=True,text=True,errors='replace')
    impl=HERE/'impl'; impl.mkdir(exist_ok=True); log=r.stdout+'\n'+r.stderr
    (impl/f'resource_{v}8_build_console.log').write_text(log,encoding='utf-8')
    fs=impl/'pnr'/f'resource_{v}8.fs'
    rec={'variant':v,'board_tested':False,'exit_code':r.returncode,'elapsed_seconds':round(time.time()-started,2),
         'source_hashes':before,'build_pass':r.returncode==0 and not re.search(r'ERROR\s*\(',log) and fs.exists() and fs.stat().st_mtime>=started}
    if before != {p.relative_to(ROOT).as_posix():sha(p) for p in sources()}: raise RuntimeError('sources changed during build')
    if rec['build_pass']:
        rpt=(impl/'pnr'/f'resource_{v}8.rpt.txt').read_text(errors='replace'); rec['resources']={}
        for n in ('Logic','Register','BSRAM','DSP','I/O Port'):
            m=re.search(r'^\s*'+re.escape(n)+r'\s*\|\s*(\d+)/(\d+)',rpt,re.M)
            if not m: raise RuntimeError('missing '+n)
            rec['resources'][n]={'used':int(m[1]),'available':int(m[2])}
        html=(impl/'pnr'/f'resource_{v}8_tr_content.html').read_text(errors='replace')
        for mode in ('Setup','Hold'):
            m=re.search(r'Numbers of '+mode+r' Violated Endpoints</td>\s*<td[^>]*>(\d+)',html)
            rec[mode.lower()+'_violated_endpoints']=int(m[1]) if m else None
        rec['timing_pass']=rec['setup_violated_endpoints']==0 and rec['hold_violated_endpoints']==0
        rec['bitstream_sha256']=sha(fs)
    (impl/f'resource_{v}8_provenance.json').write_text(json.dumps(rec,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:x for k,x in rec.items() if k!='source_hashes'},indent=2))
    return rec.get('build_pass') and rec.get('timing_pass')
def main():
    p=argparse.ArgumentParser(); p.add_argument('--gowin',default='E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe'); p.add_argument('--variant',choices=('all',)+VARIANTS,default='all'); a=p.parse_args()
    chosen=VARIANTS if a.variant=='all' else (a.variant,)
    if not all(build(v,a.gowin) for v in chosen): raise SystemExit(1)
if __name__=='__main__': main()
