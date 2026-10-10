"""Exercise the actual PLL audit wrapper with behavioral clock/lock stimulus."""
from pathlib import Path
import argparse,subprocess,xml.etree.ElementTree as ET,importlib.util,json,hashlib
sim=Path(__file__).resolve().parent;audit=sim.parent;lab=audit.parent;root=lab.parents[1]
p=argparse.ArgumentParser();p.add_argument('--modelsim',default='E:/QuartusII/modelsim_ase/win32aloem');a=p.parse_args()
sources=[(audit/e.attrib['path']).resolve() for e in ET.parse(audit/'refinement_pll_audit.gprj').findall('.//File')
    if e.attrib['type']=='file.verilog' and Path(e.attrib['path']).name not in ['gowin_pll.v','gowin_pll_mod.v','pll_init.v']]
sources.append(sim/'pll_clock_model_tb.v');tracked=sources+[Path(__file__).resolve()]
spec=importlib.util.spec_from_file_location('compact_sim',lab/'tools/sim_compact_rom.py')
helper=importlib.util.module_from_spec(spec);spec.loader.exec_module(helper)
rom=helper.prepare(lab,a.modelsim)
tracked+=[root/n for n in rom['source_sha256'] if root/n not in tracked]
sources=[Path(rom['replacement_source']) if f.name=='refinement_sine.v' else f for f in sources]
hashes={str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in tracked}
work=sim/'work_wrapper'
def command(name,args):
    r=subprocess.run([str(Path(a.modelsim)/name),*args],cwd=sim,capture_output=True,text=True,errors='replace',timeout=600)
    if r.returncode or '** Error' in r.stdout or '** Fatal' in r.stdout:raise RuntimeError(r.stdout[-4000:]+r.stderr[-1000:])
    return r.stdout+r.stderr
if work.exists() and not any(work.iterdir()):work.rmdir()
if not work.exists():command('vlib.exe',[str(work)])
command('vlog.exe',['-vlog01compat','-work',str(work),*map(str,sources)])
log=command('vsim.exe',['-c','-lib',str(work),'pll_clock_model_tb','-do','onerror {quit -code 1 -f}; onbreak {quit -code 1 -f}; run -all; quit -f'])
marker=[s.removeprefix('# ').strip() for s in log.splitlines() if 'PLL_CLOCK_MODEL_TB_PASS' in s]
assert marker and all(hashlib.sha256((root/f).read_bytes()).hexdigest()==h for f,h in hashes.items())
out=audit/'results';out.mkdir(exist_ok=True)
(out/'CLOCK_MODEL.json').write_text(json.dumps({'pass':True,'sources':hashes,'markers':marker,
    'scope':'Actual audit wrapper, behavioral clock/lock only; not vendor PLL primitive or physical lock validation'},indent=2),encoding='utf-8')
print(*marker,sep='\n')
