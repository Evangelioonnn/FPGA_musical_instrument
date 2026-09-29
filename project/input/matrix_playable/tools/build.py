"""Full Gowin build with fresh-output, source-fingerprint and timing checks."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,time,xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parents[1]
ROOT=HERE.parents[2]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def hashes():
    files=[HERE/'matrix_playable.gprj',HERE/'build.tcl']
    files += [(HERE/e.attrib['path']).resolve() for e in ET.parse(files[0]).iter('File')]
    return {p.relative_to(ROOT).as_posix():sha(p) for p in files}
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--gowin',default='E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe')
    args=p.parse_args();before=hashes();started=time.time()
    result=subprocess.run([args.gowin,str(HERE/'build.tcl')],cwd=ROOT,capture_output=True,text=True,errors='replace')
    impl=HERE/'impl';impl.mkdir(exist_ok=True)
    log=result.stdout+'\n'+result.stderr;(impl/'build_console.log').write_text(log,encoding='utf-8')
    record={'source_hashes':before,'elapsed_seconds':round(time.time()-started,2),'board_tested':False,'exit_code':result.returncode}
    fs=impl/'pnr/matrix_playable.fs'
    record['build_pass']=result.returncode==0 and not re.search(r'ERROR\s*\(',log) and fs.exists() and fs.stat().st_mtime>=started
    if before!=hashes():raise RuntimeError('Sources changed during build')
    if record['build_pass']:
        record['bitstream_sha256']=sha(fs)
        report=(impl/'pnr/matrix_playable.rpt.txt').read_text(errors='replace')
        record['resources']={}
        for name in ('Logic','Register','BSRAM','DSP','I/O Port'):
            m=re.search(r'^\s*'+name+r'\s*\|\s*(\d+)/(\d+)',report,re.M)
            if not m:raise RuntimeError('Missing resource '+name)
            record['resources'][name]={'used':int(m[1]),'available':int(m[2])}
        html=(impl/'pnr/matrix_playable_tr_content.html').read_text(errors='replace')
        for mode in ('Setup','Hold'):
            record[mode.lower()+'_violated_endpoints']=int(re.search('Numbers of '+mode+r' Violated Endpoints</td>\s*<td[^>]*>(\d+)',html)[1])
            table=html.split(f'<h3><a name="{mode}_Slack_Table">')[1].split('</table>')[0]
            row=re.findall(r'<tr[^>]*>(.*?)</tr>',table,re.S)[1]
            cells=[re.sub('<[^>]*>','',v).strip() for v in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>',row,re.S)]
            record[mode.lower()+'_worst_slack_ns']=float(cells[1])
        record['timing_pass']=not(record['setup_violated_endpoints'] or record['hold_violated_endpoints'])
        record['warnings']=re.findall(r'^.*WARN.*$',log,re.M)
        record['recommended_for_board_test']=record['timing_pass'] and record['resources']['I/O Port']['used']==19
    else:print(log[-6000:])
    (impl/'build_provenance.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in record.items() if k not in ('source_hashes','warnings')},indent=2))
    if not record.get('recommended_for_board_test'):raise SystemExit(1)
if __name__=='__main__':main()
