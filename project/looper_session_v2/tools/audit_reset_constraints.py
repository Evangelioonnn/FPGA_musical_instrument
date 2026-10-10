"""Derive all twelve physical pluck reset aliases from mapped synthesis.

Changes only audit placement hints, not board pins or timing exceptions.
"""
from pathlib import Path
import re,hashlib,json,argparse,xml.etree.ElementTree as ET
lab=Path(__file__).resolve().parents[1];root=lab.parents[1];d=lab/'audit'
p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');a=p.parse_args()
vg=d/'impl/gwsynthesis/session_audit.vg';body=vg.read_text()
bank=re.search(r'\bmodule audio_v2_bank\s*\(.*?\bendmodule',body,re.S)
if not bank:raise RuntimeError('Missing mapped bank')
slots=[]
for m in re.finditer(r'\baudio_v2_pool_slot\w*\s+\\plucks\[(\d+)\]\.slot\s*\((.*?)\);',bank.group(),re.S):
    net=re.search(r'\.voice_rst\((voice_rst(?:_\d+)?)\)',m[2])
    if not net:raise RuntimeError('Missing mapped reset '+m[1])
    slots.append({'slot':int(m[1]),'net':'link/platform/audio/bank/'+net[1]})
if [x['slot'] for x in slots]!=list(range(12)) or len({x['net'] for x in slots})!=12:raise RuntimeError('Twelve unique resets required')
src=[(d/e.attrib['path']).resolve() for e in ET.parse(d/'session_audit.gprj').findall('.//File') if e.attrib['type']=='file.verilog']
if max(x.stat().st_mtime for x in src)>vg.stat().st_mtime:raise RuntimeError('RTL newer than mapped netlist')
data={'mapped_netlist_sha256':hashlib.sha256(vg.read_bytes()).hexdigest(),'slots':slots,'no_STA_exceptions_added':True,
    'sources':{x.relative_to(root).as_posix():hashlib.sha256(x.read_bytes()).hexdigest() for x in src}}
if a.apply:
    f=d/'session_audit.cst';s=f.read_text();s=re.sub(r'// BEGIN MAPPED RESET HINTS.*?// END MAPPED RESET HINTS\s*','',s,flags=re.S)
    s+='\n// BEGIN MAPPED RESET HINTS\n// SUG1018 2.7: non-clock reset local routing; all data STA retained.\n'
    s+='\n'.join('CLOCK_LOC "'+x['net']+'" LOCAL_CLOCK;' for x in slots)+'\n// END MAPPED RESET HINTS\n'
    f.write_text(s);(lab/'results/AUDIT_RESET_MAPPING.json').write_text(json.dumps(data,indent=2))
print('AUDIT_RESET_MAPPING '+str(len(slots))+' verified aliases; applied='+str(a.apply))
