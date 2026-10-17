"""Collect successful numerical, interface and PnR evidence, never board claims."""
from pathlib import Path
import hashlib
import json
import re
import shutil
from build import source_hashes

HERE=Path(__file__).resolve().parents[1]
ROOT=HERE.parents[2]
OUT=ROOT/'evidence/timbre_rtl_2026-09-19'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def sanitized(path):
    body=path.read_text(errors='replace').replace(str(ROOT),'$REPO').replace(ROOT.as_posix(),'$REPO')
    return '\n'.join(line.rstrip() for line in body.splitlines()).rstrip()+'\n'

def timing(text):
    result={}
    for mode in ('Setup','Hold'):
        result[mode.lower()+'_violated_endpoints']=int(re.search(
            'Numbers of '+mode+r' Violated Endpoints</td>\s*<td[^>]*>(\d+)',text)[1])
        body=text.split(f'<h3><a name="{mode}_Slack_Table">')[1].split('</table>')[0]
        row=re.findall(r'<tr[^>]*>(.*?)</tr>',body,re.S)[1]
        cells=[re.sub('<[^>]*>','',x).strip() for x in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>',row,re.S)]
        result[mode.lower()+'_worst_slack_ns']=float(cells[1])
    result['internal_50mhz_pass']=result['setup_violated_endpoints']==0 and result['hold_violated_endpoints']==0
    return result

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    result={'branch':'feat/fm-pluck-rtl','base_commit':'cac8fe0c7789e09731c7c62ca947c84bf7e96930',
            'board_tested':False,'builds':{},'simulation':{},'audio':{}}
    for voice in ('fm','pluck'):
        name=voice+'_probe';folder=HERE/'board'/voice;pnr=folder/'impl/pnr'
        record=json.loads((folder/'impl/build_provenance.json').read_text())
        if record['sources']!=source_hashes(folder,name):
            raise SystemExit(name+': sources changed since build')
        if record['bitstream_sha256']!=sha(pnr/(name+'.fs')):
            raise SystemExit(name+': bitstream changed since build')
        report=(pnr/(name+'.rpt.txt')).read_text(errors='replace')
        record.update(timing((pnr/(name+'_tr_content.html')).read_text(errors='replace')))
        if not record['internal_50mhz_pass']:
            raise SystemExit(name+': internal timing did not pass')
        record['resources']={}
        for key in ('Logic','Register','BSRAM','DSP','I/O Port'):
            item=re.search(r'^\s*'+key+r'\s*\|\s*(\d+)/(\d+)',report,re.M)
            if not item: raise SystemExit('Resource missing: '+key)
            record['resources'][key]=dict(used=int(item[1]),available=int(item[2]))
        assert record['resources']['I/O Port']['used']==5
        record['warnings']={}
        for stage in ('gwsynthesis','pnr'):
            log=sanitized(folder/'impl'/stage/(name+'.log'))
            record['warnings'][stage]=re.findall(r'^.*WARN.*$',log,re.M)
        record['bitstream_local_path']=(pnr/(name+'.fs')).relative_to(ROOT).as_posix()
        result['builds'][name]=record
        for suffix in ('.rpt.txt','_tr_content.html','.log'):
            (OUT/(name+suffix)).write_text(sanitized(pnr/(name+suffix)),encoding='utf-8')
    for rel in ('fm/sim/fm_control_tb.log','fm/sim/fm_numeric_tb.log',
                'pluck/sim/pluck_tb.log','sim/demo_tb.log','sim/probe_tb.log'):
        path=HERE/rel;body=sanitized(path)
        markers=re.findall(r'^# ([A-Z0-9_]+_PASS[^\r\n]*)',body,re.M)
        if not markers or re.search(r'\*\* (Fatal|Error)|^# FAIL',body,re.M):
            raise SystemExit('Missing passing simulation: '+rel)
        result['simulation'][rel]=markers
        (OUT/path.name).write_text(body,encoding='utf-8')
    for voice,report,audio in (('fm','fm_validation.json','fm_rtl_audition.wav'),
                               ('pluck','analysis.json','pluck_rtl_raw.wav')):
        folder=HERE/voice/'sim'
        shutil.copyfile(folder/report,OUT/(voice+'_analysis.json'))
        dest=ROOT/'evidence/audio'/('candidate_'+voice+'_rtl.wav')
        shutil.copyfile(folder/audio,dest)
        result['audio'][voice]={'file':dest.relative_to(ROOT).as_posix(),'sha256':sha(dest),
            'normalization':'none; signed16 RTL algorithm output; board probe uses fixed divide by 32'}
    (OUT/'builds.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print('TIMBRE_EVIDENCE_RECORDED 2 builds; 5 benches; 2 RTL auditions; board_tested=false')

if __name__=='__main__':
    main()
