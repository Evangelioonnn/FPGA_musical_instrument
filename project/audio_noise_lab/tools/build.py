"""Build one or all isolated audio-noise-lab variants with provenance checks."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import subprocess
import time
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parents[1]
ROOT = HERE.parents[1]
VARIANTS = (
    "baseline", "activity_gate", "gain_x2", "gain_x4",
    "oversample_x2", "oversample_x4",
)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_files():
    project = HERE / "audio_noise_lab.gprj"
    return [project, HERE / "build.tcl"] + [
        (HERE / item.attrib["path"]).resolve()
        for item in ET.parse(project).iter("File")
    ]


def build(variant, gowin):
    sources = source_files()
    before = {path.relative_to(ROOT).as_posix(): sha(path) for path in sources}
    started = time.time()
    env = os.environ.copy()
    env["AUDIO_NOISE_VARIANT"] = variant
    result = subprocess.run(
        [gowin, str(HERE / "build.tcl")], cwd=ROOT, env=env,
        capture_output=True, text=True, errors="replace",
    )
    impl = HERE / "impl"
    impl.mkdir(exist_ok=True)
    log = result.stdout + "\n" + result.stderr
    (impl / f"{variant}_build_console.log").write_text(log, encoding="utf-8")
    fs = impl / "pnr" / f"audio_noise_{variant}.fs"
    record = {
        "variant": variant,
        "top": {
            "baseline": "noise_lab_top_baseline",
            "activity_gate": "noise_lab_top_activity_gate",
            "gain_x2": "noise_lab_top_gain_x2",
            "gain_x4": "noise_lab_top_gain_x4",
            "oversample_x2": "noise_lab_top_oversample_x2",
            "oversample_x4": "noise_lab_top_oversample_x4",
        }[variant],
        "elapsed_seconds": round(time.time() - started, 2),
        "board_tested": False,
        "exit_code": result.returncode,
        "source_hashes": before,
        "build_pass": result.returncode == 0 and not re.search(r"ERROR\s*\(", log)
        and fs.exists() and fs.stat().st_mtime >= started,
    }
    if before != {path.relative_to(ROOT).as_posix(): sha(path) for path in sources}:
        raise RuntimeError("Sources changed during build")
    if record["build_pass"]:
        record["bitstream_sha256"] = sha(fs)
        report = (impl / "pnr" / f"audio_noise_{variant}.rpt.txt").read_text(errors="replace")
        record["resources"] = {}
        for name in ("Logic", "Register", "BSRAM", "DSP", "I/O Port"):
            match = re.search(r"^\s*" + name + r"\s*\|\s*(\d+)/(\d+)", report, re.M)
            if not match:
                raise RuntimeError(f"Missing resource report field: {name}")
            record["resources"][name] = {"used": int(match[1]), "available": int(match[2])}
        html = (impl / "pnr" / f"audio_noise_{variant}_tr_content.html").read_text(errors="replace")
        for mode in ("Setup", "Hold"):
            record[mode.lower() + "_violated_endpoints"] = int(re.search(
                "Numbers of " + mode + r" Violated Endpoints</td>\s*<td[^>]*>(\d+)", html
            )[1])
            table = html.split(f'<h3><a name="{mode}_Slack_Table">')[1].split("</table>")[0]
            row = re.findall(r"<tr[^>]*>(.*?)</tr>", table, re.S)[1]
            cells = [re.sub("<[^>]*>", "", cell).strip()
                     for cell in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", row, re.S)]
            record[mode.lower() + "_worst_slack_ns"] = float(cells[1])
        record["timing_pass"] = not (
            record["setup_violated_endpoints"] or record["hold_violated_endpoints"]
        )
        record["warnings"] = re.findall(r"^.*WARN.*$", log, re.M)
        record["recommended_for_board_test"] = (
            record["timing_pass"] and record["resources"]["I/O Port"]["used"] == 15
        )
    else:
        print(log[-6000:])
    (impl / f"{variant}_build_provenance.json").write_text(
        json.dumps(record, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({key: value for key, value in record.items()
                      if key not in ("source_hashes", "warnings")}, indent=2))
    return bool(record.get("recommended_for_board_test"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gowin", default="E:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe")
    parser.add_argument("--variant", choices=("all",) + VARIANTS, default="all")
    args = parser.parse_args()
    selected = VARIANTS if args.variant == "all" else (args.variant,)
    failed = [variant for variant in selected if not build(variant, args.gowin)]
    if failed:
        raise SystemExit("Build/timing/I-O check failed: " + ", ".join(failed))


if __name__ == "__main__":
    main()
