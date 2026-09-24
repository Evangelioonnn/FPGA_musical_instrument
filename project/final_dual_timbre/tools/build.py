from pathlib import Path
import argparse, hashlib, json, re, subprocess, time, xml.etree.ElementTree as ET

HERE=Path(__file__).resolve().parents[1]
ROOT=HERE.parents[1]
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def source_files():
    g=HERE/'final_dual_timbre.gprj'
    return [g,HERE/'build.tcl']+[(HERE/e.attrib['path']).resolve() for e in ET.parse(g).iter('File')]
def main():
    p=argparse.ArgumentParser(); p.add_argument('--gowin',default='E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe'); a=p.parse_args()
    before={x.relative_to(ROOT).as_posix():sha(x) for x in source_files()}; started=time.time()
    r=subprocess.run([a.gowin,str(HERE/'build.tcl')],cwd=ROOT,capture_output=True,text=True,errors='replace')
    impl=HERE/'impl'; impl.mkdir(exist_ok=True); log=r.stdout+'\n'+r.stderr
    (impl/'build_console.log').write_text(log,encoding='utf-8')
    fs=impl/'pnr/final_dual_timbre.fs'
    rec={'top':'final_dual_top','board_tested':False,'exit_code':r.returncode,'elapsed_seconds':round(time.time()-started,2),'source_hashes':before,
         'build_pass':r.returncode==0 and not re.search(r'ERROR\s*\(',log) and fs.exists() and fs.stat().st_mtime>=started}
    if before != {x.relative_to(ROOT).as_posix():sha(x) for x in source_files()}: raise RuntimeError('sources changed during build')
    if rec['build_pass']:
        report=(impl/'pnr/final_dual_timbre.rpt.txt').read_text(errors='replace'); rec['resources']={}
        for name in ('Logic','Register','BSRAM','DSP','I/O Port'):
            m=re.search(r'^\s*'+re.escape(name)+r'\s*\|\s*(\d+)/(\d+)',report,re.M)
            if not m: raise RuntimeError('missing '+name)
            rec['resources'][name]={'used':int(m[1]),'available':int(m[2])}
        html=(impl/'pnr/final_dual_timbre_tr_content.html').read_text(errors='replace')
        for mode in ('Setup','Hold'):
            m=re.search(r'Numbers of '+mode+r' Violated Endpoints</td>\s*<td[^>]*>(\d+)',html)
            rec[mode.lower()+'_violated_endpoints']=int(m[1]) if m else None
        rec['timing_pass']=rec['setup_violated_endpoints']==0 and rec['hold_violated_endpoints']==0
        rec['bitstream_sha256']=sha(fs)
    else: print(log[-8000:])
    (impl/'build_provenance.json').write_text(json.dumps(rec,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in rec.items() if k!='source_hashes'},indent=2))
    if not rec.get('build_pass') or not rec.get('timing_pass'): raise SystemExit(1)
if __name__=='__main__': main()
