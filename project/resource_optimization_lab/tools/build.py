"""Build the resource-lab candidate and record a fresh resource/timing report."""
from pathlib import Path
import argparse, hashlib, json, re, subprocess, time, xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parents[1]
ROOT = HERE.parents[2]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def sources():
    project = HERE / "resource_optimization_lab.gprj"
    return [
        project, HERE / "build.tcl",
        *(HERE / f.attrib["path"] for f in ET.parse(project).iter("File")),
    ]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--gowin", default="E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe")
    parser.add_argument("--variant", choices=["pruned_sine8", "all"], default="all")
    args = parser.parse_args()
    before = {str(p.resolve().relative_to(ROOT)): sha(p) for p in sources()}
    started = time.time()
    result = subprocess.run([args.gowin, str(HERE / "build.tcl")], cwd=ROOT,
                            capture_output=True, text=True, errors="replace")
    log = result.stdout + "\n" + result.stderr
    impl = HERE / "impl"; impl.mkdir(exist_ok=True)
    (impl / "build_console.log").write_text(log, encoding="utf-8")
    record = {"variant": "pruned_sine8", "board_tested": False,
              "exit_code": result.returncode, "elapsed_seconds": round(time.time()-started, 2),
              "source_hashes": before}
    fs = impl / "pnr" / "resource_pruned.fs"
    record["build_pass"] = (result.returncode == 0 and not re.search(r"ERROR\s*\(", log)
                            and fs.exists() and fs.stat().st_mtime >= started)
    if before != {str(p.resolve().relative_to(ROOT)): sha(p) for p in sources()}:
        raise RuntimeError("Sources changed during build")
    if record["build_pass"]:
        report = (impl / "pnr" / "resource_pruned.rpt.txt").read_text(errors="replace")
        record["resources"] = {}
        for name in ("Logic", "Register", "BSRAM", "DSP", "I/O Port"):
            match = re.search(r"^\s*" + re.escape(name) + r"\s*\|\s*(\d+)/(\d+)", report, re.M)
            if not match: raise RuntimeError("Missing resource " + name)
            record["resources"][name] = {"used": int(match[1]), "available": int(match[2])}
        html = (impl / "pnr" / "resource_pruned_tr_content.html").read_text(errors="replace")
        for mode in ("Setup", "Hold"):
            match = re.search(r"Numbers of " + mode + r" Violated Endpoints</td>\s*<td[^>]*>(\d+)", html)
            record[mode.lower()+"_violated_endpoints"] = int(match[1]) if match else None
        record["timing_pass"] = record["setup_violated_endpoints"] == 0 and record["hold_violated_endpoints"] == 0
        record["warnings"] = re.findall(r"^.*WARN.*$", log, re.M)
        record["bitstream_sha256"] = sha(fs)
    else:
        print(log[-8000:])
    (impl / "build_provenance.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k:v for k,v in record.items() if k not in ("source_hashes", "warnings")}, indent=2))
    if not record.get("build_pass") or not record.get("timing_pass"):
        raise SystemExit(1)

if __name__ == "__main__": main()
