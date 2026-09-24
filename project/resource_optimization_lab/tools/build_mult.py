"""Build the shared and duplicated multiplier probes."""
from pathlib import Path
import argparse, hashlib, json, re, subprocess, time, xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parents[1]
ROOT = HERE.parents[2]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def files():
    project = HERE / "resource_mult.gprj"
    return [project, *(HERE / f.attrib["path"] for f in ET.parse(project).iter("File"))]

def build_one(gowin, variant):
    tcl = HERE / ("resource_mult_shared.tcl" if variant == "shared_mult8" else "resource_mult_duplicated.tcl")
    tracked = [tcl, *files()]
    before = {str(p.resolve().relative_to(ROOT)): sha(p) for p in tracked}
    started = time.time()
    result = subprocess.run([gowin, str(tcl)], cwd=ROOT, capture_output=True, text=True, errors="replace")
    log = result.stdout + "\n" + result.stderr
    impl = HERE / "impl"; impl.mkdir(exist_ok=True)
    (impl / f"{variant}_build_console.log").write_text(log, encoding="utf-8")
    base = "resource_mult_shared" if variant == "shared_mult8" else "resource_mult_duplicated"
    fs = impl / "pnr" / f"{base}.fs"
    record = {"variant": variant, "board_tested": False, "exit_code": result.returncode,
              "elapsed_seconds": round(time.time() - started, 2), "source_hashes": before}
    record["build_pass"] = (result.returncode == 0 and not re.search(r"ERROR\s*\(", log)
                            and fs.exists() and fs.stat().st_mtime >= started)
    after = {str(p.resolve().relative_to(ROOT)): sha(p) for p in tracked}
    if before != after: raise RuntimeError("Sources changed during build")
    if record["build_pass"]:
        report = (impl / "pnr" / f"{base}.rpt.txt").read_text(errors="replace")
        record["resources"] = {}
        for name in ("Logic", "Register", "BSRAM", "DSP", "I/O Port"):
            match = re.search(r"^\s*" + re.escape(name) + r"\s*\|\s*(\d+)/(\d+)", report, re.M)
            record["resources"][name] = ({"used": int(match[1]), "available": int(match[2])}
                                           if match else {"used": 0, "available": 118})
        html = (impl / "pnr" / f"{base}_tr_content.html").read_text(errors="replace")
        for mode in ("Setup", "Hold"):
            match = re.search(r"Numbers of " + mode + r" Violated Endpoints</td>\s*<td[^>]*>(\d+)", html)
            record[mode.lower() + "_violated_endpoints"] = int(match[1]) if match else None
        record["timing_pass"] = record["setup_violated_endpoints"] == 0 and record["hold_violated_endpoints"] == 0
        record["bitstream_sha256"] = sha(fs)
    else:
        print(log[-8000:])
    (impl / f"{variant}_build_provenance.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in record.items() if k != "source_hashes"}, indent=2))
    return record

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--gowin", default="E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe")
    parser.add_argument("--variant", choices=["shared_mult8", "duplicated_mult8", "all"], default="all")
    args = parser.parse_args()
    variants = ["shared_mult8", "duplicated_mult8"] if args.variant == "all" else [args.variant]
    records = [build_one(args.gowin, variant) for variant in variants]
    if not all(record.get("build_pass") and record.get("timing_pass") for record in records): raise SystemExit(1)

if __name__ == "__main__":
    main()
