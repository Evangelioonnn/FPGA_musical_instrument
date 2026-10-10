"""Portable, small C UI example validation; no Gowin libraries needed."""
from pathlib import Path
import argparse,subprocess,hashlib,json,re,datetime
lab=Path(__file__).resolve().parents[1];root=lab.parents[1]
p=argparse.ArgumentParser();p.add_argument('--modelsim',default='E:/QuartusII/modelsim_ase/win32aloem');a=p.parse_args()
src=[lab/'rtl/session_ui_unpacker.v',lab/'examples/session_ui_view.v',lab/'examples/session_ui_mock.v',lab/'sim/session_examples_tb.v']
files=src+[Path(__file__).resolve()]
fingerprint=lambda:{f.relative_to(root).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
before=fingerprint();work=lab/'sim/work_session_examples'
def run(t,args):
    r=subprocess.run([str(Path(a.modelsim)/t),*args],cwd=lab/'sim',capture_output=True,text=True,errors='replace',timeout=120)
    s=r.stdout+r.stderr
    if r.returncode or re.search(r'\*\* (Error|Fatal)',s):raise RuntimeError(s)
    return s
if not work.exists():run('vlib.exe',[str(work)])
run('vlog.exe',['-vlog01compat','-work',str(work),*map(str,src)])
s=run('vsim.exe',['-c','-lib',str(work),'session_examples_tb','-do','onerror {quit -code 1 -f}; onbreak {quit -code 1 -f}; run -all; quit -f'])
assert 'SESSION_EXAMPLES_TB_PASS' in s and before==fingerprint()
(lab/'results/UI_EXAMPLES.json').write_text(json.dumps({'pass':True,'sources':before,'time':datetime.datetime.now().astimezone().isoformat(),'log':s},indent=2))
print('SESSION_EXAMPLES_TB_PASS mock_stream named_field_offsets frames8')
