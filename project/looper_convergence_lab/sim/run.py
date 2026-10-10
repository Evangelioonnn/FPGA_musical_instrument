from pathlib import Path
import argparse
import re
import subprocess
import xml.etree.ElementTree as ET
import hashlib,json,datetime,importlib.util

LAB = Path(__file__).resolve().parents[1]
SIM = LAB / "sim"
(SIM/"audio").mkdir(exist_ok=True)
ROOT = LAB.parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--modelsim", default="E:/QuartusII/modelsim_ase/win32aloem")
parser.add_argument("--test", default="looper_clock_tb")
parser.add_argument("--generic", action="append",default=[])
parser.add_argument("--timeout",type=int,default=600)
parser.add_argument('--case-rom',action='store_true',help='Use literal Gowin case ROM instead of independently verified simulation array')
args = parser.parse_args()
key=args.test+''.join('__'+re.sub(r'[^A-Za-z0-9_=]','_',x) for x in args.generic)
work = SIM / ("work_"+key)


def run(executable, arguments):
    result = subprocess.run(
        [str(Path(args.modelsim) / executable), *arguments],
        cwd=SIM,
        capture_output=True,
        text=True,
        errors="replace",
        timeout=args.timeout,
    )
    log = result.stdout + "\n" + result.stderr
    if result.returncode or re.search(r"\*\* (?:Error|Fatal)", log):
        raise RuntimeError(log[-5000:])
    return log


if not work.exists():
    run("vlib.exe", [str(work)])
sources = [(LAB / e.attrib['path']).resolve() for e in ET.parse(LAB / 'looper_convergence_lab.gprj').findall('.//File') if e.attrib['type']=='file.verilog']
tests = args.test
sources.append(SIM / f"{tests}.v")
tracked_sources=list(sources)+[Path(__file__).resolve()]
if tests=='looper_v2_equivalence_tb':
    sources.append(ROOT/'project/audio_palette_lab/src/palette_sine.v')
    renames={'audio_v2_bank':'reference_v2_bank','audio_v2_tone':'reference_v2_tone',
             'audio_v2_pluck':'reference_v2_pluck','audio_v2_pool_slot':'reference_v2_pool_slot'}
    for filename in ['audio_v2_bank_stream.v','audio_v2_tone.v','audio_v2_pluck.v','audio_v2_pool_slot.v']:
        original=ROOT/'project/audio_core_v2/src'/filename
        body=original.read_text()
        for old,new in renames.items():body=re.sub(r'\b'+old+r'\b',new,body)
        oracle=work/('reference_'+filename);oracle.write_text(body)
        sources.append(oracle);tracked_sources.append(original)
if tests=='sine_compact_tb':
    sources.append(ROOT/'project/audio_palette_lab/src/palette_sine.v');tracked_sources.append(sources[-1])
rom=None
compact_rom=None
if not args.case_rom:
    helper=ROOT/'project/audio_core_v1/tools/sim_rom.py'
    spec=importlib.util.spec_from_file_location('looper_sim_rom',helper)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    rom=module.prepare_and_verify(args.modelsim)
    tracked_sources += [ROOT/p for p in rom['source_sha256'] if ROOT/p not in tracked_sources]
    sources=[Path(rom['replacement_source']) if p.name=='palette_sine.v' else p for p in sources]
    if tests!='sine_compact_tb':
        spec2=importlib.util.spec_from_file_location('compact_sim',LAB/'tools/sim_compact_rom.py')
        compact_module=importlib.util.module_from_spec(spec2);spec2.loader.exec_module(compact_module)
        compact_rom=compact_module.prepare(LAB,args.modelsim)
        tracked_sources += [ROOT/p for p in compact_rom['source_sha256'] if ROOT/p not in tracked_sources]
        sources=[Path(compact_rom['replacement_source']) if p.name=='refinement_sine.v' else p for p in sources]
fingerprint={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in tracked_sources}
run("vlog.exe", ["-vlog01compat", "-work", str(work), *map(str, sources)])
log = run(
    "vsim.exe",
    [
        "-c",
        "-lib",
        str(work),
        tests,
        *["-g"+v for v in args.generic],
        "-l",
        f"{key}.log",
        "-do",
        "onerror {quit -code 1 -f}; onbreak {quit -code 1 -f}; run -all; quit -f",
    ],
)
markers = [line.strip().removeprefix('# ') for line in log.splitlines() if '_PASS' in line and 'Missing' not in line]
if tests == 'metronome_delivery_audit_tb':
    markers = [line for line in log.splitlines() if 'KNOWN_DEFECT_REPRODUCED' in line]
if not markers:
    raise RuntimeError(f'Missing PASS marker: {tests}\n{log[-6000:]}')
after={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in tracked_sources}
if after!=fingerprint: raise RuntimeError("Sources changed during simulation; rerun before treating this as current evidence")
result_dir=LAB/'results'/'sim';result_dir.mkdir(parents=True,exist_ok=True)
(result_dir/(key+'.json')).write_text(json.dumps({'test':tests,'generics':args.generic,'pass':True,
    'time':datetime.datetime.now().astimezone().isoformat(),'markers':markers,'sources':fingerprint,'rom_simulation':rom,'compact_rom_simulation':compact_rom},indent=2))
(result_dir/(key+'.log')).write_text(log,encoding='utf-8')
for marker in markers: print(marker,flush=True)
