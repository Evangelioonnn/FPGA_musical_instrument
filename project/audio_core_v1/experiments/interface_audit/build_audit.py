"""Synthesis-only audit retaining all future host/ADC/observation ports."""
from pathlib import Path
from html.parser import HTMLParser
import argparse
import hashlib
import json
import os
import re
import subprocess
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parent
LAB = HERE.parents[1]
ROOT = LAB.parents[1]


class Rows(HTMLParser):
    def __init__(self):
        super().__init__(); self.rows=[]; self.row=None; self.cell=None
    def handle_starttag(self, tag, attrs):
        if tag=='tr': self.row=[]
        if tag in ('td','th') and self.row is not None: self.cell=[]
    def handle_data(self, text):
        if self.cell is not None: self.cell.append(text)
    def handle_endtag(self, tag):
        if tag in ('td','th') and self.cell is not None:
            self.row.append(''.join(self.cell).strip()); self.cell=None
        if tag=='tr' and self.row is not None:
            self.rows.append(self.row); self.row=None


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--gowin',default='E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe')
    parser.add_argument('--parse-only',action='store_true')
    args=parser.parse_args()
    tree=ET.parse(LAB/'audio_core.gprj')
    listing=tree.find('FileList')
    for item in list(listing):
        if item.attrib['type']!='file.verilog': listing.remove(item)
        else: item.attrib['path']=Path(os.path.relpath((LAB/item.attrib['path']).resolve(), HERE)).as_posix()
    ET.SubElement(listing,'File',{'path':'audit.sdc','type':'file.sdc','enable':'1'})
    ET.indent(tree)
    project=HERE/'interface_audit.gprj'
    tree.write(project,encoding='UTF-8',xml_declaration=True)
    files=[project,HERE/'build.tcl',HERE/'audit.sdc']
    files += [(HERE/x.attrib['path']).resolve() for x in tree.iter('File') if x.attrib['type']=='file.verilog']
    hashes={p.relative_to(ROOT).as_posix():digest(p) for p in files}
    if args.parse_only:
        if json.loads((HERE/'result.json').read_text())['source_sha256']!=hashes:
            raise RuntimeError('Cannot reparse a report for changed sources')
    else:
        result=subprocess.run([args.gowin,str(HERE/'build.tcl')],cwd=ROOT,capture_output=True,text=True,errors='replace')
        log=result.stdout+'\n'+result.stderr
        (HERE/'impl').mkdir(exist_ok=True)
        (HERE/'impl/audit_console.log').write_text(log,encoding='utf-8')
        if result.returncode or re.search(r'ERROR\s*\(',log): raise RuntimeError('Audit synthesis failed')
    if hashes!={p.relative_to(ROOT).as_posix():digest(p) for p in files}: raise RuntimeError('Audit source changed during synthesis')
    rows=Rows(); rows.feed((HERE/'impl/gwsynthesis/interface_audit_syn.rpt.html').read_text(errors='replace'))
    totals={}
    primitives={}
    in_dsp=False
    for row in rows.rows:
        if len(row)<2: continue
        key=row[0].replace('\xa0','').strip()
        if key=='DSP': in_dsp=True
        elif key=='BSRAM': in_dsp=False
        if key in ('Logic','Register','BSRAM') and '/' in row[1]:
            totals[key]=int(re.match(r'\d+',row[1])[0])
        if in_dsp and key.startswith(('MULT','ALU','PADD')) and row[1].isdigit(): primitives[key]=int(row[1])
    weights={'MULTALU27X18':1,'MULT27X36':2,'MULT12X12':0.5}
    unknown=set(primitives)-set(weights)
    estimate=None if unknown else sum(weights[k]*v for k,v in primitives.items())
    budgets={'Logic':29000,'Register':17000,'BSRAM':70,'DSP':78}
    if set(totals)!=set(('Logic','Register','BSRAM')): raise RuntimeError('Missing synthesis resource totals')
    totals['DSP_unit_estimate']=estimate
    record={'scope':'full audio_core interface, synthesis only, no physical PnR',
            'resources':totals,'DSP_primitives':primitives,'unknown_DSP_primitives':sorted(unknown),
            'budget':budgets,'budget_estimate_pass':estimate is not None and estimate<=78 and
             all(totals[k]<=budgets[k] for k in ('Logic','Register','BSRAM')),'source_sha256':hashes}
    (HERE/'result.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in record.items() if k!='source_sha256'},indent=2))
    if not record['budget_estimate_pass']: raise RuntimeError('Full-interface synthesis capacity exceeds budget')


if __name__=='__main__': main()
