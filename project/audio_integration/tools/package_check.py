"""Validate source import, exported-tree elaboration and coherent UI consumers."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

from source_manifest import PACKAGE, ROOT, MANIFEST_PATH, manifest, sources, tcl_manifest


def executable(directory, name):
    candidates = [Path(directory) / f"{name}.exe", Path(directory) / name] if directory else []
    located = shutil.which(name)
    if located:
        candidates.append(Path(located))
    for path in candidates:
        if path.is_file():
            return path.resolve()
    raise RuntimeError(f"Cannot find {name}; pass --modelsim-bin")


def validate_static(bank=None):
    data = manifest()
    generated = Path(__file__).with_name("source_manifest.tcl")
    if not generated.is_file() or generated.read_text(encoding="ascii") != tcl_manifest():
        raise RuntimeError("Refresh source_manifest.tcl using source_manifest.py --write-tcl")
    baseline = ROOT / data["baseline_project"]
    listed = {(baseline.parent / item.attrib["path"]).resolve().relative_to(ROOT).as_posix()
              for item in ET.parse(baseline).iter("File") if item.attrib.get("type") == "file.verilog"}
    for path in sources("core"):
        if path not in listed and path != data["default_bank"]:
            raise RuntimeError(f"Core source absent from the baseline GPRJ: {path}")
    inventories = {}
    for profile in data["profiles"]:
        files = sources(profile, bank if "core" in profile or profile == "integration" else None)
        modules = {}
        for relative in files:
            text = (ROOT / relative).read_text(encoding="utf-8-sig")
            for module in re.findall(r"(?m)^\s*module\s+([A-Za-z_][A-Za-z0-9_]*)", text):
                if module in modules:
                    raise RuntimeError(f"Duplicate module {module}: {modules[module]}, {relative}")
                modules[module] = relative
        if data["profiles"][profile]["top"] not in modules:
            raise RuntimeError(f"Top absent in {profile}: {data['profiles'][profile]['top']}")
        inventories[profile] = {"files": len(files), "modules": len(modules)}
    return inventories


def run_tool(command, directory, label):
    completed = subprocess.run([str(value) for value in command], cwd=directory,
                               capture_output=True, text=True, errors="replace")
    output = completed.stdout + "\n" + completed.stderr
    (directory / f"{label}.log").write_text(output, encoding="utf-8")
    if completed.returncode or re.search(r"\*\*\s+(?:Error|Fatal)|FileWatch", output):
        raise RuntimeError(f"{label} failed; see {directory / (label + '.log')}")
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--modelsim-bin", default=os.environ.get("MODELSIM_BIN"))
    parser.add_argument("--bank", help="Repository-relative alternative bank, replacing baseline exactly once")
    parser.add_argument("--static-only", action="store_true")
    args = parser.parse_args()
    inventory = validate_static(args.bank)
    files = list(dict.fromkeys(sources("integration", args.bank) + sources("consumer")))
    additional = [
        "project/audio_integration/include/audio_api_v2.vh",
        "project/audio_integration/tools/source_manifest.json",
        "project/audio_integration/tools/source_manifest.py",
        "project/audio_integration/tools/source_manifest.tcl",
        "project/audio_integration/tools/import_audio.tcl",
        "project/audio_integration/tools/package_check.py",
        "project/audio_integration/examples/sim/audio_state_view_tb.v",
        "project/audio_integration/examples/sim/audio_observer_mock_tb.v",
        manifest()["baseline_project"],
        manifest()["default_bank"],
    ]
    inputs = list(dict.fromkeys(files + additional))
    fingerprints = {relative: hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() for relative in inputs}
    portable = {relative: hashlib.sha256((ROOT / relative).read_bytes().replace(b"\r\n", b"\n")).hexdigest()
                for relative in inputs}
    record = {"static_pass": True, "profiles": inventory,
              "audio_reference": "audio_v2_core N32/PLUCK12; explicit bank override permitted",
              "bank_override": args.bank, "board_PnR": False,
              "source_sha256": fingerprints, "source_lf_sha256": portable}
    if not args.static_only:
        result_dir = ROOT / "tmp/audio_integration_package_check"
        result_dir.mkdir(parents=True, exist_ok=True)
        workdir = Path(tempfile.mkdtemp(prefix="clean-", dir=result_dir))
        export = workdir / "export"
        export.mkdir(parents=True, exist_ok=True)
        for relative in inputs:
            destination = export / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, destination)
        vlib = executable(args.modelsim_bin, "vlib")
        vlog = executable(args.modelsim_bin, "vlog")
        vsim = executable(args.modelsim_bin, "vsim")
        library = workdir / "work"
        if not library.exists():
            run_tool([vlib, "work"], workdir, "vlib")
        benches = [export / path for path in additional if path.endswith("_tb.v")]
        imported = [export / relative for relative in files]
        include_dirs = list(dict.fromkeys(path.parent for path in imported + benches))
        run_tool([vlog, "-quiet", "-sv", "-work", "work"] +
                 [f"+incdir+{path.as_posix()}" for path in include_dirs] + imported + benches,
                 workdir, "vlog")
        tops = ["audio_v2_core", "audio_integration_example", "audio_state_view", "audio_observer_mock"]
        for top in tops:
            run_tool([vsim, "-c", "-quiet", "-lib", "work", top,
                      "-do", "onerror {quit -code 1}; run 0; quit -code 0"], workdir, top + "_elaborate")
        passed = []
        for bench in ("audio_state_view_tb", "audio_observer_mock_tb"):
            output = run_tool([vsim, "-c", "-quiet", "-onfinish", "stop", "-lib", "work", bench,
                               "-do", "onerror {quit -code 1}; run -all; quit -code 0"], workdir, bench)
            if bench.upper() + "_PASS" not in output:
                raise RuntimeError(f"Missing PASS marker for {bench}")
            passed.append(bench)
        exported_generator = export / "project/audio_integration/tools/source_manifest.py"
        target = export / "tmp/imported_audio.gprj"
        run_tool([sys.executable, exported_generator, "--profile", "integration", "--gprj", target] +
                 (["--bank", args.bank] if args.bank else []), workdir, "exported_manifest")
        for item in ET.parse(target).iter("File"):
            dependency = (target.parent / item.attrib["path"]).resolve()
            dependency.relative_to(export)
            if not dependency.is_file():
                raise RuntimeError(f"Exported source project dependency missing: {dependency}")
        if fingerprints != {relative: hashlib.sha256((ROOT / relative).read_bytes()).hexdigest() for relative in inputs}:
            raise RuntimeError("Source changed during package verification")
        record.update({"clean_export_elaboration_pass": True, "logical_tops": tops,
                       "consumer_regressions": passed, "portable_project_pass": True})
        (result_dir / "result.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in record.items() if key != "source_sha256"}, indent=2))
    print("AUDIO_IMPORT_PACKAGE_PASS")


if __name__ == "__main__":
    main()
