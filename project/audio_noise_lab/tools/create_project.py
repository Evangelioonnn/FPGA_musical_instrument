"""Create the portable Gowin project with explicit audio-noise-lab sources."""
from pathlib import Path
import os
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parents[1]
ROOT = HERE.parents[1]
LOCAL = sorted((HERE / "src").glob("*.v"))
DEPENDENCIES = [
    "project/input/src/matrix_scanner.v",
    "project/system/src/stream_fifo.v",
    "project/input/matrix_playable/src/playable_button.v",
    "project/input/matrix_playable/src/playable_controls.v",
    "project/input/matrix_playable/src/playable_keys.v",
    "project/input/matrix_playable/src/playable_led.v",
    "project/input/knob_suite/src/knob_reference_voice.v",
    "project/input/knob_suite/src/knob_gain.v",
    "project/input/knob_suite/src/knob_volume_table.v",
    "project/instrument/src/synth_voice.v",
    "project/instrument/src/adsr_envelope.v",
    "project/instrument/src/sine_rom.v",
    "project/instrument/src/note_table.v",
    "project/input/matrix_playable/src/playable_fm_voice.v",
    "project/experiments/timbre/fm/src/fm_note_table.v",
    "project/experiments/timbre/fm/src/fm_sine_interp.v",
    "project/experiments/timbre/fm/src/fm_sine_rom.v",
    "project/experiments/timbre/pluck/src/pluck_voice.v",
    "project/experiments/timbre/pluck/src/pluck_note_table.v",
]
SOURCES = LOCAL + [ROOT / name for name in DEPENDENCIES]

project = ET.Element("Project")
ET.SubElement(project, "Template").text = "FPGA"
ET.SubElement(project, "Version").text = "5"
ET.SubElement(project, "Device", name="GW5AT-60B", pn="GW5AT-LV60PG484AC1/I0").text = "gw5at60b-002"
files = ET.SubElement(project, "FileList")
for path in SOURCES + [HERE / "src/audio_noise_lab.cst", HERE / "src/audio_noise_lab.sdc"]:
    if not path.exists():
        raise FileNotFoundError(path)
    suffix = path.suffix[1:]
    kind = {"v": "verilog", "cst": "cst", "sdc": "sdc"}[suffix]
    ET.SubElement(files, "File", path=Path(os.path.relpath(path, HERE)).as_posix(),
                  type="file." + kind, enable="1")
ET.indent(project, space="  ")
(HERE / "audio_noise_lab.gprj").write_text(
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<!DOCTYPE gowin-fpga-project>\n'
    + ET.tostring(project, encoding="unicode") + "\n",
    encoding="utf-8",
)
print(f"Created audio_noise_lab.gprj with {len(SOURCES)} Verilog sources")
