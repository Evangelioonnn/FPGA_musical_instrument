"""Derive every pluck reset alias from the actual mapped netlist, never guess it.

Run only after synthesis/build has finished. --apply updates local CST for the
next physical build; changes RTL then requires a new netlist and re-generation.
"""
from pathlib import Path
import argparse,re,json,hashlib,xml.etree.ElementTree as ET

lab=Path(__file__).resolve().parents[1];root=lab.parents[1]
p=argparse.ArgumentParser();p.add_argument('--profile',choices=['board','pll'],required=True)
p.add_argument('--apply',action='store_true');p.add_argument('--verify',action='store_true');a=p.parse_args()
if a.profile=='board':
    directory=lab;stem='looper_convergence_lab';cst=lab/'src'/f'{stem}.cst'
    parent='platform/audio/bank'
else:
    directory=lab/'audit_pll';stem='refinement_pll_audit';cst=directory/f'{stem}.cst'
    parent='harness/link/platform/audio/bank'
vg=directory/'impl/gwsynthesis'/f'{stem}.vg'
body=vg.read_text(encoding='utf-8')
bank=re.search(r'\bmodule audio_v2_bank\s*\(.*?\bendmodule',body,re.S)
if not bank:raise RuntimeError('Mapped audio_v2_bank absent')
slots=[]
for m in re.finditer(r'\baudio_v2_pool_slot\w*\s+\\plucks\[(\d+)\]\.slot\s*\((.*?)\);',bank.group(),re.S):
    n=int(m[1]);net=re.search(r'\.voice_rst\((voice_rst(?:_\d+)?)\)',m[2])
    if not net:raise RuntimeError('Reset output not exported for pluck '+str(n))
    slots.append({'slot':n,'net':parent+'/'+net[1]})
if [s['slot'] for s in slots]!=list(range(12)) or len({s['net'] for s in slots})!=12:
    raise RuntimeError('Expected twelve distinct physical pluck resets')
project=directory/(stem+'.gprj')
sources=[(directory/e.attrib['path']).resolve() for e in ET.parse(project).findall('.//File') if e.attrib['type']=='file.verilog']
if max(f.stat().st_mtime for f in sources)>vg.stat().st_mtime:
    raise RuntimeError('RTL newer than netlist; finish synthesis before deriving aliases')
begin='// BEGIN MAPPED PLUCK RESET CONSTRAINTS'
end='// END MAPPED PLUCK RESET CONSTRAINTS'
section=begin+'\n// Twelve separate per-voice resets, SUG1018 2.7; no timing exceptions.\n'
section+='\n'.join(f'CLOCK_LOC "{s["net"]}" LOCAL_CLOCK; // pluck{s["slot"]}' for s in slots)+'\n'+end+'\n'
data={'profile':a.profile,'netlist_sha256':hashlib.sha256(vg.read_bytes()).hexdigest(),'slots':slots,
    'rtl_sources':{f.relative_to(root).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in sources},
    'applied':a.apply}
if a.verify:
    declared=re.findall(r'CLOCK_LOC "('+re.escape(parent)+r'/voice_rst(?:_\d+)?)" LOCAL_CLOCK;',cst.read_text(encoding='utf-8'))
    if declared!=[s['net'] for s in slots]:raise RuntimeError('CST does not cover the current twelve mapped resets')
    print('MAPPED_PLUCK_RESETS_CST_ALL12_MATCH '+a.profile)
if a.apply:
    original=cst.read_text(encoding='utf-8')
    original=re.sub(re.escape(begin)+r'.*?'+re.escape(end)+r'\s*','',original,flags=re.S)
    original='\n'.join(line for line in original.splitlines()
        if not ((line.startswith('CLOCK_LOC ') or line.startswith('NET_NO_REP ')) and parent+'/voice_rst' in line))
    cst.write_text(original.rstrip()+'\n\n'+section,encoding='utf-8')
    (lab/'results'/f'RESET_MAPPING_{a.profile}.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
print(json.dumps(data|{'rtl_sources':'recorded in mapping JSON when applied'},indent=2))
