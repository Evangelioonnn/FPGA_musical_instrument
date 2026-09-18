"""Collect a reviewable local evidence bundle after builds and simulation.

No board operation. Retains timing failures as failures instead of treating a
successfully generated .fs as proof of timing closure.
"""
from pathlib import Path
import re,json,hashlib,xml.etree.ElementTree as ET,subprocess
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'evidence/system_v0_2026-09-19'
OUT.mkdir(exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def plain(x):return re.sub('<[^>]*>','',x).strip()
def cells(row):return [plain(x) for x in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>',row,re.S)]
def timing(text):
    result={}
    for mode in ('Setup','Hold'):
        result[mode.lower()+'_violated_endpoints']=int(re.search('Numbers of '+mode+r' Violated Endpoints</td>\s*<td[^>]*>(\d+)',text).group(1))
        body=text.split(f'<h3><a name="{mode}_Slack_Table">')[1].split('</table>')[0]
        row=re.findall(r'<tr[^>]*>(.*?)</tr>',body,re.S)[1]
        result[mode.lower()+'_worst_slack_ns']=float(cells(row)[1])
    body=text.split('<h2><a name="Max_Frequency_Report">')[1].split('</table>')[0]
    row=re.findall(r'<tr[^>]*>(.*?)</tr>',body,re.S)[1]
    result['fmax_mhz']=float(cells(row)[3].split('(')[0])
    result['internal_50mhz_pass']=result['setup_violated_endpoints']==0 and result['hold_violated_endpoints']==0
    return result
result={'branch':subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip(),
        'base_commit':'4ada74edd085fd3adeb5a4272704de9fd1035f65','tool':'Gowin V1.9.12.03','board_tested':False,'builds':{},'simulation':{}}
for folder,name in [('system','system'),('experiments/capacity16','capacity16'),('experiments/capacity32','capacity32'),
                    ('experiments/delay','delay'),('lab/c4','lab_c4'),('lab/a4','lab_a4'),('lab/silent','lab_silent')]:
    p=ROOT/'project'/folder;pnr=p/'impl/pnr';report=(pnr/(name+'.rpt.txt')).read_text(errors='replace')
    tr=(pnr/(name+'_tr_content.html')).read_text(errors='replace')
    item=timing(tr);item['resources']={}
    for key in ('Logic','Register','BSRAM','DSP','I/O Port'):
        match=re.search(r'^\s*'+key+r'\s*\|\s*(\d+)/(\d+)',report,re.M)
        item['resources'][key]={'used':int(match[1]),'available':int(match[2])} if match else None
    item['bitstream_sha256']=sha(pnr/(name+'.fs'));item['bitstream_local_path']=(pnr/(name+'.fs')).relative_to(ROOT).as_posix()
    item['sources']={}
    for element in ET.fromstring((p/(name+'.gprj')).read_text(encoding='utf-8')).iter('File'):
        source=(p/element.attrib['path']).resolve()
        item['sources'][source.relative_to(ROOT).as_posix()]=sha(source)
    item['build_tcl_sha256']=sha(p/'build.tcl')
    result['builds'][name]=item
    for suffix in ('.rpt.txt','_tr_content.html','.log'):
        source=pnr/(name+suffix)
        body=source.read_text(errors='replace').replace(str(ROOT),'$REPO').replace(ROOT.as_posix(),'$REPO')
        (OUT/(name+suffix)).write_text(body,encoding='utf-8')
for folder in ['project/system/sim','project/experiments/delay/sim']:
    for p in sorted((ROOT/folder).glob('*.log')):
        body=p.read_text(errors='replace')
        markers=re.findall(r'^# ([A-Z0-9_]+_PASS[^\r\n]*)',body,re.M)
        if not markers or re.search(r'\*\* (Fatal|Error)',body):continue
        # Do not retain obsolete early delay smoke evidence.
        if p.name=='feedback_delay_tb.log':continue
        result['simulation'][p.name]=markers
        (OUT/p.name).write_text(body.replace(str(ROOT),'$REPO').replace(ROOT.as_posix(),'$REPO'),encoding='utf-8')
audit=ROOT/'project/input/impl/gwsynthesis/input_audit_syn.rpt.html'
(OUT/'input_audit_syn.rpt.html').write_text(audit.read_text(errors='replace').replace(str(ROOT),'$REPO'),encoding='utf-8')
result['input_audit']={'type':'synthesis only; unbound logical ports; no PnR or physical timing signoff',
    'report_sha256':sha(audit),'source_hashes':{p.relative_to(ROOT).as_posix():sha(p) for p in sorted((ROOT/'project/input/src').glob('*.v'))}}
required=['streams_tb','arbiter_tb','keys_tb','matrix_tb','encoder_tb','pressure_tb','failsafe_tb',
    'controls_v0_tb','observability_tb','telemetry_tb','core_features_tb_N16','core_features_tb_N32',
    'system_input_tb','transport_v0_tb','capacity_transport_tb','input_render_tb','lab_tb','equivalence_tb',
    'delay8','delay4096','delay_render']
missing=[name for name in required if name+'.log' not in result['simulation']]
if missing:raise SystemExit('Evidence incomplete or tests still running: '+','.join(missing))
(OUT/'builds.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
for name,row in result['builds'].items():print(name,row['resources']['Logic'],row['setup_worst_slack_ns'],row['internal_50mhz_pass'])
print('EVIDENCE_RECORDED simulations='+str(len(result['simulation'])))
