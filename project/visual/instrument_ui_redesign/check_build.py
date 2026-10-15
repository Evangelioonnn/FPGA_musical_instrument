"""Capture routed results; refuse a stale or timing-failing programming image."""
import hashlib
import html
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

project = Path(__file__).resolve().parent
repo = project.parents[2]
pnr = project / "impl/pnr"
base = "instrument_ui_redesign"
report = pnr / (base + "_tr_content.html")
bitstream = pnr / (base + ".fs")
gprj = project / "instrument_ui_redesign.gprj"
sources = [(project / f.attrib["path"]).resolve() for f in ET.parse(gprj).getroot().find("FileList")]
sources += [gprj, project / "build.tcl", repo / "project/audio_integration/include/audio_api_v2.vh"]
log = pnr / (base + ".log")
def reject(reason):
    output = project / "validation/routed_build.json"
    output.write_text(json.dumps({"routed_timing_pass": False, "download_gate_pass": False,
        "reason": reason, "board_test": "NOT RUN"}, indent=2) + "\n")
    sys.exit("NOT READY: " + reason)
if not report.exists() or not bitstream.exists() or not log.exists():
    reject("redesign routed report, log or FS is missing")
log_text = log.read_text(errors="replace")
if re.search(r"^\s*ERROR\s*\(", log_text, re.M):
    reject("current PnR log contains errors; any older FS is invalid for this run")
if "Placement and routing completed" not in log_text or "Bitstream generation completed" not in log_text:
    reject("current PnR/bitstream generation has not completed")
text = report.read_text(errors="replace")

def clean(value):
    return html.unescape(re.sub(r"<[^>]*>", "", value)).strip()

def cells(fragment):
    return [clean(s) for s in re.findall(r"<td[^>]*>(.*?)</td>", fragment, re.S)]

def count(label):
    match = re.search(r">" + re.escape(label) + r"</td>\s*<td[^>]*>(\d+)</td>", text)
    if not match:
        raise ValueError("Missing timing statistic: " + label)
    return int(match.group(1))

setup = count("Numbers of Setup Violated Endpoints")
hold = count("Numbers of Hold Violated Endpoints")
setup_table = text.split('name="Setup_Slack_Table"', 1)[1].split('name="Hold_Slack_Table"', 1)[0]
setup_slacks = [float(c[1]) for row in re.findall(r"<tr[^>]*>(.*?)</tr>", setup_table, re.S)
                if len(c := cells(row)) == 9]
if not setup_slacks:
    raise ValueError("Missing setup path slack table")
section = text.split('name="Max_Frequency_Report"', 1)[1].split('name="Total_Negative_Slack_Report"', 1)[0]
clocks = []
for row in re.findall(r"<tr>(.*?)</tr>", section, re.S):
    c = cells(row)
    if len(c) == 6:
        clocks.append({"name": c[1], "required_mhz": float(c[2].split("(")[0]), "fmax_mhz": float(c[3].split("(")[0])})
resource_text = (pnr / (base + ".rpt.txt")).read_text(errors="replace")
resources = {}
for label in ("Logic", "Register", "BSRAM", "DSP", "I/O Port", "PLLA", "PRIMARY", "LW"):
    match = re.search(r"^\s*" + re.escape(label) + r"\s*\|\s*([\d.]+)/([\d.]+)", resource_text, re.M)
    if not match:
        raise ValueError("Missing resource: " + label)
    resources[label] = {"used": float(match[1]), "available": float(match[2])}
pin_report = pnr / (base + ".pin.html")
pin_text = pin_report.read_text(errors="replace").split('name="Pinout_by_Port_Name"', 1)[1].split('name="All_Package_Pins"', 1)[0]
pins = {}
for row in re.findall(r"<tr>(.*?)</tr>", pin_text, re.S):
    c = cells(row)
    if len(c) >= 18 and c[0] != "Port Name":
        pins[c[0]] = {"ball": c[2].split('/')[0], "bank": c[2].split('/')[1], "io_type": c[7], "vccio": c[17], "constrained": c[3]}
expected_pins = {"sys_clk": "V22", "enc_a": "T18", "enc_b": "R17",
                 "hp_bck": "Y17", "hp_ws": "AB17", "hp_din": "AA16", "pa_en": "AB16",
                 "tmds_clk_p_0": "G15", "tmds_clk_n_0": "G16"}
for bus, balls in {"button_n": ["AA13", "AB13", "Y12"],
                   "matrix_col_n": ["AB22", "AB21", "Y22", "Y21"],
                   "matrix_row_n": ["AA20", "AA21", "AA19", "AB20"],
                   "tmds_d_p_0": ["J14", "J15", "K17"],
                   "tmds_d_n_0": ["H14", "H15", "J17"]}.items():
    expected_pins.update({f"{bus}[{i}]": ball for i, ball in enumerate(balls)})
pin_pass = set(pins) == set(expected_pins)
for name, ball in expected_pins.items():
    io_type, voltage = ("LVDS25E", "2.5") if name.startswith("tmds_") else (("LVCMOS15", "1.5") if name.startswith("button_n") else ("LVCMOS33", "3.3"))
    p = pins.get(name, {})
    pin_pass = pin_pass and p.get("ball") == ball and p.get("io_type") == io_type and p.get("vccio") == voltage and p.get("constrained") == "Y"
latest_source = max(s.stat().st_mtime for s in sources)
fresh = min(report.stat().st_mtime, bitstream.stat().st_mtime, pin_report.stat().st_mtime) >= latest_source
expected_clocks = any(c["name"] == "sys_clk" and c["required_mhz"] == 50 for c in clocks) and any(c["required_mhz"] == 150 for c in clocks)
passes = fresh and expected_clocks and setup == 0 and hold == 0 and all(c["fmax_mhz"] >= c["required_mhz"] for c in clocks)
result = {
    "routed_timing_pass": passes, "source_timestamps_fresh": fresh,
    "setup_violations": setup, "hold_violations": hold, "clocks": clocks,
    "worst_setup_slack_ns": min(setup_slacks),
    "pnr_warnings": [line.strip() for line in log_text.splitlines() if "WARN" in line],
    "pin_mapping_pass": pin_pass, "pin_mapping": pins,
    "download_gate_pass": passes and pin_pass,
    "resources": resources, "fs_sha256": hashlib.sha256(bitstream.read_bytes()).hexdigest(),
    "source_sha256": {str(s.relative_to(repo)).replace('\\', '/'): hashlib.sha256(s.read_bytes()).hexdigest() for s in sources},
    "source_lf_sha256": {str(s.relative_to(repo)).replace(chr(92), chr(47)): hashlib.sha256(s.read_bytes().replace(bytes([13,10]), bytes([10]))).hexdigest() for s in sources},
    "board_test": "NOT RUN", "note": "Review CDC/IO constraints and build warnings separately; passing STA is not board acceptance."
}
out = project / "validation/routed_build.json"
out.parent.mkdir(exist_ok=True)
out.write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps({k: v for k, v in result.items() if k not in ("source_sha256", "pin_mapping")}, indent=2))
sys.exit(0 if passes and pin_pass else 1)
