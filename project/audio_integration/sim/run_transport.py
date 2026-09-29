"""Run coherent-clock-crossing regression with portable source fingerprints."""
from pathlib import Path
import argparse
import hashlib
import importlib.util
import json
import re
import subprocess
import tempfile

LAB = Path(__file__).resolve().parents[1]
ROOT = LAB.parents[1]
SIM = LAB / "sim"
DEFAULT_TESTS = ["snapshot_transport_tb", "pcm_transport_tb", "command_transport_tb"]
CORE_TEST = "core_transport_tb"
parser = argparse.ArgumentParser()
parser.add_argument("--modelsim", default="E:/QuartusII/modelsim_ase/win32aloem")
parser.add_argument("--test", action="append", choices=DEFAULT_TESTS + [CORE_TEST])
parser.add_argument("--bank", help="Repository-relative bank replacement for core_transport_tb")
args = parser.parse_args()
tests = args.test or DEFAULT_TESTS
with_core = CORE_TEST in tests
if args.bank and not with_core:
    parser.error("--bank requires --test core_transport_tb")


def run(tool, options, cwd):
    result = subprocess.run([str(Path(args.modelsim) / tool), *options], cwd=cwd,
                            capture_output=True, text=True, errors="replace")
    output = result.stdout + "\n" + result.stderr
    if result.returncode or re.search(r"\*\* (?:Error|Fatal)|FileWatch", output):
        raise RuntimeError(output[-6500:])
    return output


manifest_path = LAB / "tools/source_manifest.py"
manifest_spec = importlib.util.spec_from_file_location("audio_integration_manifest", manifest_path)
manifest_module = importlib.util.module_from_spec(manifest_spec)
manifest_spec.loader.exec_module(manifest_module)
profile = "integration" if with_core else "transport"
sources = [ROOT / relative for relative in manifest_module.sources(profile, args.bank)]
if with_core:
    sources += [LAB / "examples/audio_state_view.v"]
else:
    sources += [ROOT / "project/audio_parameter_lab/src/audio_parameter_service.v"]
sources += [SIM / (name + ".v") for name in tests]
sources = list(dict.fromkeys(sources))
inputs = sources + [Path(__file__).resolve(), SIM / "run_transport.do", manifest_path,
                   manifest_path.with_suffix(".json"), manifest_path.with_suffix(".tcl"),
                   LAB / "include/audio_api_v2.vh"]
if with_core:
    inputs += [ROOT / "project/audio_core_v1/tools/sim_rom.py",
               ROOT / "project/audio_core_v1/sim/sine_rom_equivalence_tb.v"]
inputs = list(dict.fromkeys(inputs))


def fingerprints(portable=False):
    return {path.relative_to(ROOT).as_posix(): hashlib.sha256(
                path.read_bytes().replace(b"\r\n", b"\n") if portable else path.read_bytes()).hexdigest()
            for path in inputs}


source_hashes = fingerprints()
portable_hashes = fingerprints(portable=True)
rom = None
build_root = ROOT / "tmp/audio_integration_sim"
build_root.mkdir(parents=True, exist_ok=True)
workspace = Path(tempfile.mkdtemp(prefix="core-" if with_core else "bridges-", dir=build_root))
if with_core:
    rom_path = ROOT / "project/audio_core_v1/tools/sim_rom.py"
    rom_spec = importlib.util.spec_from_file_location("audio_integration_sim_rom", rom_path)
    rom_module = importlib.util.module_from_spec(rom_spec)
    rom_spec.loader.exec_module(rom_module)
    rom = rom_module.prepare_and_verify(args.modelsim)
    sources = [Path(rom["replacement_source"]) if path.name == "palette_sine.v" else path
               for path in sources]
library = "work"
run("vlib.exe", [library], workspace)
include_dirs = list(dict.fromkeys([path.parent for path in sources] + [LAB / "include"]))
run("vlog.exe", ["-vlog01compat", "-work", library,
                 *["+incdir+" + path.as_posix() for path in include_dirs], *map(str, sources)], workspace)
results = []
for name in tests:
    log_file = name + ".log"
    log = run("vsim.exe", ["-c", "-lib", library, name, "-l", log_file,
                           "-do", str(SIM / "run_transport.do")], workspace)
    marker = name.upper() + "_PASS"
    result = next((line.strip() for line in log.splitlines() if marker in line), None)
    if result is None or "_TB_FAIL" in log:
        raise RuntimeError("Missing PASS marker: " + name + "\n" + log[-6500:])
    if source_hashes != fingerprints():
        raise RuntimeError("Source changed while running " + name)
    results.append({"test": name, "result": result, "source_sha256": source_hashes,
                    "source_lf_sha256": portable_hashes,
                    "log_sha256": hashlib.sha256((workspace / log_file).read_bytes()).hexdigest()})
    print(result, flush=True)
if with_core:
    bank_suffix = "_" + Path(args.bank).stem if args.bank else ""
    destination = LAB / ("results/core_transport_validation" + bank_suffix + ".json")
else:
    destination = LAB / "results/transport_validation.json"
destination.parent.mkdir(exist_ok=True)
record = {"tests": results, "bank_override": args.bank, "profile": profile,
          "simulation_workspace": workspace.relative_to(ROOT).as_posix()}
if rom is not None:
    record["simulation_rom_verification"] = rom
destination.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
