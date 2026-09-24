"""Build one or all clean-lab variants with provenance checks."""
from pathlib import Path
import argparse, hashlib, json, os, re, subprocess, time
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parents[1]
ROOT = HERE.parents[1]
VARIANTS = ("reference_x8", "harmonic_piano", "low_fm", "triangle")

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def source_files():
    project = HERE / "audio_clean_lab.gprj"
    return [project, HERE / "build.tcl"] + [
        (HERE / item.attrib["path"]).resolve() for item in ET.parse(project).iter("File")
    ]

def build(variant, gowin):
    sources = source_files()
    before = {path.relative_to(ROOT).as_posix(): sha(path) for path in sources}
    started = time.time()
    env = os.environ.copy()
    env["AUDIO_CLEAN_VARIANT"] = variant
    result = subprocess.run([gowin, str(HERE / "build.tcl")], cwd=ROOT, env=env,
                            capture_output=True, text=True, errors="replace")
    impl = HERE / "impl"
    impl.mkdir(exist_ok=True)
    log = result.stdout + "\n" + result.stderr
    (impl / f"{variant}_build_console.log").write_text(log, encoding="utf-8")
    fs = impl / "pnr" / f"audio_clean_{variant}.fs"
    record = {"variant": variant, "top": {
        "reference_x8": "audio_clean_top_reference_x8",
        "harmonic_piano": "audio_clean_top_harmonic_piano",
        "low_fm": "audio_clean_top_low_fm",
        "triangle": "audio_clean_top_triangle",
    }[variant], "board_tested": False, "exit_code": result.returncode,
        "source_hashes": before, "build_pass": result.returncode == 0 and
        not re.search(r"ERROR\s*\(", log) and fs.exists() and fs.stat().st_mtime >= started}
    if before != {path.relative_to(ROOT).as_posix(): sha(path) for path in sources}:
        raise RuntimeError("Sources changed during build")
    if record["build_pass"]:
        record["bitstream_sha256"] = sha(fs)
        report = (impl / "pnr" / f"audio_clean_{variant}.rpt.txt").read_text(errors="replace")
        record["resources"] = {}
        for name in ("Logic", "Register", "BSRAM", "DSP", "I/O Port"):
            match = re.search(r"^\s*" + name + r"\s*\|\s*(\d+)/(\d+)", report, re.M)
            if not match: raise RuntimeError(f"Missing resource report field: {name}")
            record["resources"][name] = {"used": int(match[1]), "available": int(match[2])}
        html = (impl / "pnr" / f"audio_clean_{variant}_tr_content.html").read_text(errors="replace")
        for mode in ("Setup", "Hold"):
            record[mode.lower() + "_violated_endpoints"] = int(re.search(
                "Numbers of " + mode + r" Violated Endpoints</td>\s*<td[^>]*>(\d+)", html)[1])
        record["timing_pass"] = not (record["setup_violated_endpoints"] or record["hold_violated_endpoints"])
        record["recommended_for_board_test"] = record["timing_pass"] and record["resources"]["I/O Port"]["used"] == 15
    (impl / f"{variant}_build_provenance.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k:v for k,v in record.items() if k not in ("source_hashes",)}, indent=2))
    return bool(record.get("recommended_for_board_test"))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--gowin", default="E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe")
    parser.add_argument("--variant", choices=("all",) + VARIANTS, default="all")
    args = parser.parse_args()
    selected = VARIANTS if args.variant == "all" else (args.variant,)
    failed = [v for v in selected if not build(v, args.gowin)]
    if failed: raise SystemExit("Build/timing/I-O check failed: " + ", ".join(failed))

if __name__ == "__main__": main()
