"""Rank vendor synthesis hierarchy; never substitute it for physical PnR."""
from pathlib import Path
import hashlib,json,xml.etree.ElementTree as ET
lab=Path(__file__).resolve().parents[1];root=lab.parents[1]
data={'scope':'Synthesis hierarchy only; Lut+Alu is a ranking proxy, not PnR Logic/CLS or physical BSRAM.'}
for kind,project,report in [
    ('board',lab/'looper_refinement_lab.gprj',lab/'impl/gwsynthesis/looper_refinement_lab_syn_rsc.xml'),
    ('audit',lab/'audit/refinement_audit.gprj',lab/'audit/impl/gwsynthesis/refinement_audit_syn_rsc.xml'),
    ('audit_pll',lab/'audit_pll/refinement_pll_audit.gprj',lab/'audit_pll/impl/gwsynthesis/refinement_pll_audit_syn_rsc.xml')]:
    rows=[]
    def walk(e,path):
        path=path+'/'+e.get('name');rows.append({'path':path,**e.attrib})
        for c in e:walk(c,path)
    tree=ET.parse(report).getroot();walk(tree,'')
    assert sum(int(r.get('Register',0)) for r in rows)==int(tree.get('T_Register').split('(')[0]),'Hierarchy register totals disagree'
    sources=[(project.parent/e.attrib['path']).resolve() for e in ET.parse(project).findall('.//File') if e.attrib['type']=='file.verilog']
    data[kind]={'xml_sha256':hashlib.sha256(report.read_bytes()).hexdigest(),
        'rtl_source_lf_sha256':{p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest() for p in sources},
        'hierarchy':rows}
    ranked=sorted(rows,key=lambda r:int(r.get('Lut',0))+int(r.get('Alu',0)),reverse=True)
    for r in ranked[:5]:print(kind,r['path'],'own Lut+Alu',int(r.get('Lut',0))+int(r.get('Alu',0)))
(lab/'results/SYNTHESIS_PROFILE.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
print('SYNTHESIS_HIERARCHY_REGISTER_TOTALS_PASS board_external_audit_and_pll_audit')
