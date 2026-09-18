"""Record checked artifacts only after required tests and report assertions pass."""
from pathlib import Path
import hashlib,json,re,xml.etree.ElementTree as ET
BASE=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
checks={
    'manager_tb_gN4.log':'MANAGER_TB_PASS N=4 vectors=12011',
    'manager_tb_gN8.log':'MANAGER_TB_PASS N=8 vectors=12015',
    'controls_tb.log':'CONTROLS_TB_PASS vectors=9000',
    'mixer_meter_tb_gN4.log':'MIXER_METER_TB_PASS N=4 vectors=5000',
    'mixer_meter_tb_gN8.log':'MIXER_METER_TB_PASS N=8 vectors=5000',
    'voice_tb.log':'VOICE_TB_PASS',
    'voice_numeric_tb.log':'VOICE_NUMERIC_TB_PASS vectors=6000',
    'core_tb_gN4.log':'CORE_TB_PASS N=4',
    'core_tb_gN8.log':'CORE_TB_PASS N=8',
    'render_tb.log':'RENDER_TB_PASS samples=1153848',
    'integration_tb.log':'INTEGRATION_TB_PASS frames=3557',
}
for name,marker in checks.items():
    body=(BASE/'sim'/name).read_text()
    assert marker in body and not re.search(r'\*\* (Fatal|Error)',body),name
report=json.loads((BASE/'reports/build_summary.json').read_text())
assert report['setup_slack_ns']>0 and report['hold_slack_ns']>0
timing=(BASE/'impl/pnr/expression_tr_content.html').read_text()
assert '61.405(MHz)' in timing
tns=timing.split('name="Total_Negative_Slack_Report"',1)[1].split('</table>',1)[0]
assert re.findall(r'<td[^>]*>(.*?)</td>',tns,re.S)==['sys_clk','Setup','0.000','0','sys_clk','Hold','0.000','0']
pins=(BASE/'impl/pnr/expression.rpt.txt').read_text()
for signal,pin in [('sys_clk','V22'),('hp_bck','Y17'),('hp_ws','AB17'),('hp_din','AA16'),('pa_en','AB16')]:
    assert re.search(r'^'+signal+r'\s+\|[^\n]*'+pin+r'/7[^\n]*LVCMOS33',pins,re.M),signal
analysis=json.loads((BASE/'sim/audio_analysis.json').read_text())
assert analysis['samples']==1153848 and len(analysis['eight_voices'])==8
assert sha(BASE/'impl/pnr/expression.fs')==report['bitstream_sha256']
before=json.loads((BASE/'reports/before_optimization/fingerprints.json').read_text())
for rel in ['sim/expression_samples.txt','audio/00_full_demo_raw.wav']:assert sha(BASE/rel)==before[rel]
baseline={}
for name in ['instrument','audio_quality','audio_format','polyphony']:
    p=BASE.parent/name;m=json.loads((p/'validation_manifest.json').read_text(encoding='utf-8-sig'))
    assert all(sha(p/rel)==expected.lower() for rel,expected in m['sha256'].items()),name
    baseline[name]=len(m['sha256'])
paths=set(['expression.gprj','build.tcl','SPEC.md','README.md','INTERFACES.md','VALIDATION.md','BOARD_TRYOUT.md'])
for f in ET.parse(BASE/'expression.gprj').getroot().findall('./FileList/File'):paths.add(f.attrib['path'])
paths.add('../instrument/sim/transport_tb.v')
for pattern in ['sim/*.v','sim/*.ps1','sim/*.do','sim/*vectors.txt','sim/*.json','audio/*.wav','tools/*.py','reports/*.json','reviews/*.md','reviews/*.json']:
    paths.update(p.relative_to(BASE).as_posix() for p in BASE.glob(pattern))
paths.update('sim/'+p for p in checks)
paths.update(['sim/expression_samples.txt','impl/pnr/expression.fs','impl/pnr/expression.rpt.txt',
              'impl/pnr/expression_tr_content.html','impl/pnr/expression.log','impl/gwsynthesis/expression.log'])
manifest={'date':'2026-09-18','status':'digital verification and Gowin internal timing passed; initial board listening has unresolved audio issues',
          'hardware_test':'user accepts mute, velocity and chord; pedal noise/transients unresolved; prior sharp sound not heard under changed conditions, not proven fixed; see reviews/FIRST_BOARD_REVIEW.md',
          'reference_listening':'user finds effects acceptable; timbres to be reselected, original sine retained; WAV comes from RTL simulation, listening copies use x32 gain',
          'required_test_configurations':len(checks),'baseline_records_unchanged':baseline,
          'build':report,'sha256':{p:sha(BASE/p) for p in sorted(paths)}}
(BASE/'validation_manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n')
print('VALIDATION_RECORDED',len(paths),'hashes;',len(checks),'test configurations; pinout/timing/audio/baselines checked')
