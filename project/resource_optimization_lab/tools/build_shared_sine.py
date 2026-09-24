"""Build the complete shared eight-voice sine candidate."""
from pathlib import Path
import argparse, hashlib, json, re, subprocess, time, xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parents[1]; ROOT=HERE.parents[2]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    p=argparse.ArgumentParser();p.add_argument('--gowin',default='E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe');a=p.parse_args()
    project=HERE/'resource_shared_sine.gprj'; tcl=HERE/'resource_shared_sine.tcl'
    files=[project,tcl,*(HERE/f.attrib['path'] for f in ET.parse(project).iter('File'))]
    before={str(x.resolve().relative_to(ROOT)):sha(x) for x in files};started=time.time()
    r=subprocess.run([a.gowin,str(tcl)],cwd=ROOT,capture_output=True,text=True,errors='replace');log=r.stdout+'\n'+r.stderr
    impl=HERE/'impl';impl.mkdir(exist_ok=True);(impl/'shared_sine_build_console.log').write_text(log,encoding='utf-8')
    fs=impl/'pnr'/'resource_shared_sine.fs';rec={'variant':'shared_sine8_complete','board_tested':False,'exit_code':r.returncode,'elapsed_seconds':round(time.time()-started,2),'source_hashes':before}
    rec['build_pass']=r.returncode==0 and not re.search(r'ERROR\s*\(',log) and fs.exists() and fs.stat().st_mtime>=started
    after={str(x.resolve().relative_to(ROOT)):sha(x) for x in files}
    if before!=after:raise RuntimeError('Sources changed during build')
    if rec['build_pass']:
        report=(impl/'pnr'/'resource_shared_sine.rpt.txt').read_text(errors='replace');rec['resources']={}
        for name in ('Logic','Register','BSRAM','DSP','I/O Port'):
            m=re.search(r'^\s*'+re.escape(name)+r'\s*\|\s*(\d+)/(\d+)',report,re.M)
            if not m: raise RuntimeError('Missing resource '+name)
            rec['resources'][name]={'used':int(m[1]),'available':int(m[2])}
        html=(impl/'pnr'/'resource_shared_sine_tr_content.html').read_text(errors='replace')
        for mode in ('Setup','Hold'):
            m=re.search(r'Numbers of '+mode+r' Violated Endpoints</td>\s*<td[^>]*>(\d+)',html);rec[mode.lower()+'_violated_endpoints']=int(m[1]) if m else None
            section=re.search(r'<h3><a name="'+mode+r'_Slack_Table">.*?</h3>(.*?)(?:<h3>|</body>)',html,re.S)
            sm=re.search(r'<td>1</td>\s*<td>([-+0-9.]+)</td>',section.group(1) if section else '')
            rec[mode.lower()+'_worst_slack_ns']=float(sm[1]) if sm else None
        rec['timing_pass']=rec['setup_violated_endpoints']==0 and rec['hold_violated_endpoints']==0;rec['bitstream_sha256']=sha(fs);rec['warnings']=re.findall(r'^.*WARN.*$',log,re.M)
    else:print(log[-8000:])
    (impl/'shared_sine8_complete_build_provenance.json').write_text(json.dumps(rec,indent=2)+'\n',encoding='utf-8');print(json.dumps({k:v for k,v in rec.items() if k not in ('source_hashes','warnings')},indent=2))
    if not rec.get('build_pass') or not rec.get('timing_pass'):raise SystemExit(1)
if __name__=='__main__':main()
