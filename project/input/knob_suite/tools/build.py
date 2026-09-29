"""Build selected board variants and bind source hashes to timing results."""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess
import time
import xml.etree.ElementTree as ET
from create_projects import HERE, ROOT, NAMES

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def hashes(folder, name):
    paths=[folder/(name+'.gprj'),folder/'build.tcl']
    paths += [(folder/e.attrib['path']).resolve() for e in ET.parse(paths[0]).iter('File')]
    return {p.relative_to(ROOT).as_posix():sha(p) for p in paths}

def timing(body):
    result={}
    for mode in ('Setup','Hold'):
        result[mode.lower()+'_violated_endpoints']=int(re.search(
            'Numbers of '+mode+r' Violated Endpoints</td>\s*<td[^>]*>(\d+)',body)[1])
        section=body.split(f'<h3><a name="{mode}_Slack_Table">')[1].split('</table>')[0]
        row=re.findall(r'<tr[^>]*>(.*?)</tr>',section,re.S)[1]
        cells=[re.sub('<[^>]*>','',v).strip() for v in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>',row,re.S)]
        result[mode.lower()+'_worst_slack_ns']=float(cells[1])
    result['timing_pass']=not(result['setup_violated_endpoints'] or result['hold_violated_endpoints'])
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--names',default=','.join(NAMES))
    parser.add_argument('--gowin',default='E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe')
    args=parser.parse_args()
    failures=[]
    for item in args.names.split(','):
        if item not in NAMES: raise ValueError(item)
        name='knob_'+item;folder=HERE/'board'/item
        before=hashes(folder,name);started=time.time()
        result=subprocess.run([args.gowin,str(folder/'build.tcl')],cwd=ROOT,
                              capture_output=True,text=True,errors='replace')
        log=result.stdout+'\n'+result.stderr
        print(f'{name}: Gowin finished; full console in local impl/build_console.log',flush=True)
        record={'variant':item,'source_hashes':before,'board_tested':False,
                'elapsed_seconds':round(time.time()-started,2),'tool_exit_code':result.returncode}
        impl=folder/'impl';impl.mkdir(exist_ok=True)
        (impl/'build_console.log').write_text(log,encoding='utf-8')
        fs=impl/'pnr'/(name+'.fs')
        if result.returncode or re.search(r'ERROR\s*\(',log) or not fs.exists() or fs.stat().st_mtime<started:
            print(log[-5000:],flush=True)
            record['build_pass']=False;failures.append(item)
        else:
            record['build_pass']=True
            if before!=hashes(folder,name):raise RuntimeError('Source changed during build: '+item)
            report=(impl/'pnr'/(name+'.rpt.txt')).read_text(errors='replace')
            record.update(timing((impl/'pnr'/(name+'_tr_content.html')).read_text(errors='replace')))
            record['bitstream_sha256']=sha(fs)
            record['resources']={}
            for key in ('Logic','Register','BSRAM','DSP','I/O Port'):
                match=re.search(r'^\s*'+key+r'\s*\|\s*(\d+)/(\d+)',report,re.M)
                if not match:raise RuntimeError('Missing resource '+key)
                record['resources'][key]={'used':int(match[1]),'available':int(match[2])}
            record['warnings']={}
            for stage in ('gwsynthesis','pnr'):
                stage_body=(impl/stage/(name+'.log')).read_text(errors='replace')
                record['warnings'][stage]=re.findall(r'^.*WARN.*$',stage_body,re.M)
            record['recommended_for_board_test']=record['timing_pass'] and record['resources']['I/O Port']['used']==7
            if not record['recommended_for_board_test']:failures.append(item)
        (impl/'build_provenance.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
        print('KNOB_BUILD_RESULT '+json.dumps({k:v for k,v in record.items() if k not in ('source_hashes','warnings')}),flush=True)
    if failures:raise SystemExit('Builds needing work: '+','.join(failures))

if __name__=='__main__':
    main()
