"""Adapt accepted system/board regressions to the new names and widths."""
from pathlib import Path

LAB = Path(__file__).resolve().parents[1]
OLD = LAB.parent / 'audio_core_v1'
SIM = LAB / 'sim'
SIM.mkdir(exist_ok=True)
for before, after in [('audio_core_tb', 'v2_core_tb'), ('audio_board_tb', 'v2_board_tb')]:
    dest = SIM / f'{after}.v'
    if dest.exists():
        raise RuntimeError(f'Refusing to overwrite {dest}')
    text = (OLD / 'sim' / f'{before}.v').read_text(encoding='utf-8')
    text = text.replace(before, after).replace(before.upper(), after.upper())
    text = text.replace('audio_core #', 'audio_v2_core #').replace('audio_top #', 'audio_v2_top #')
    text = text.replace('wire [7:0] occupied,held,gated;', 'wire [31:0] occupied,held,gated;')
    text = text.replace('wire [831:0] snap;', 'wire [2367:0] snap;')
    text = text.replace('dut.bank.slots[', 'dut.bank.harmonics[')
    dest.write_text(text, encoding='utf-8', newline='\n')
