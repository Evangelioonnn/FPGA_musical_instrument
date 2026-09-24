"""Build both sine-ROM probe tops and record comparable resources."""
from pathlib import Path
import argparse, hashlib, json, re, subprocess, time, xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parents[1]
ROOT = HERE.parents[2]

def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def source_files():
    project = HERE / "resource_sine.gprj"
    return [project, *(HERE / f.attrib["path"] for f in ET.parse(project).iter("File"))]

def build_one(gowin, variant):
    tcl = HERE / ("resource_sine_shared.tcl" if variant == "shared_sine8" else "resource_sine_duplicated.tcl")
    before = {str(p.resolve().relative_to(ROOT)): sha(p) for p in [tcl, *source_files()]}
    started = time.time()
    result = subprocess.run([gowin, str(tcl)], cwd=ROOT, capture_output=True, text=True, errors="replace")
    log = result.stdout + "\n" + result.stderr
    impl = HERE / "impl"; impl.mkdir(exist_ok=True)
    (impl / f"{variant}_build_console.log").write_text(log, encoding="utf-8")
    base = f"resource_sine_{'shared' if variant == 'shared_sine8' else 'duplicated'}"
    fs = impl / "pnr" / f"{base}.fs"
    record = {"variant": variant, "board_tested": False, "exit_code": result.returncode,
              "elapsed_seconds": round(time.time()-started, 2), "source_hashes": before}
    record["build_pass"] = result.returncode == 0 and not re.search(r"ERROR\s*\(", log) and fs.exists() and fs.stat().st_mtime >= started
    if before != {str(p.resolve().relative_to(ROOT)): sha(p) for p in [tcl, *source_files()]}:
        raise RuntimeError("Sources changed during build")
    if record["build_pass"]:
        report = (impl / "pnr" / f"{base}.rpt.txt").read_text(errors="replace")
        record["resources"] = {}
        for name in ("Logic", "Register", "BSRAM", "DSP", "I/O Port"):
            m = re.search(r"^\s*" + re.escape(name) + r"\s*\|\s*(\d+)/(\d+)", report, re.M)
            if not m:
                if name == "DSP":
                    record["resources"][name] = {"used": 0, "available": 118}
                    continue
                raise RuntimeError("Missing resource " + name)
            record["resources"][name] = {"used": int(m[1]), "available": int(m[2])}
        html = (impl / "pnr" / f"{base}_tr_content.html").read_text(errors="replace")
        for mode in ("Setup", "Hold"):
            m = re.search(r"Numbers of " + mode + r" Violated Endpoints</td>\s*<td[^>]*>(\d+)", html)
            record[mode.lower()+"_violated_endpoints"] = int(m[1]) if m else None
        record["timing_pass"] = record["setup_violated_endpoints"] == 0 and record["hold_violated_endpoints"] == 0
        record["bitstream_sha256"] = sha(fs)
        record["warnings"] = re.findall(r"^.*WARN.*$", log, re.M)
    else:
        print(log[-8000:])
    (impl / f"{variant}_build_provenance.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k:v for k,v in record.items() if k not in ("source_hashes", "warnings")}, indent=2))
    return record

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--gowin", default="E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe")
    p.add_argument("--variant", choices=["shared_sine8", "duplicated_sine8", "all"], default="all")
    args = p.parse_args()
    variants = ["shared_sine8", "duplicated_sine8"] if args.variant == "all" else [args.variant]
    records = [build_one(args.gowin, v) for v in variants]
    if not all(r.get("build_pass") and r.get("timing_pass") for r in records): raise SystemExit(1)

if __name__ == "__main__": main()
