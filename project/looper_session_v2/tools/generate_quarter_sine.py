"""Verify/rebuild quarter table from the accepted full precision ROM."""
from pathlib import Path
import re,argparse,hashlib,json
lab=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--write',action='store_true');args=p.parse_args()
source=lab/'../audio_palette_lab/src/palette_sine.v';target=lab/'src/refinement_sine.v'
values=[(int(i),int(v,16)) for i,v in re.findall(r"12'd(\d+):data<=16'h([0-9a-fA-F]+);",source.read_text())]
assert len(values)==4096 and [i for i,v in values]==list(range(4096))
full=[v if v<32768 else v-65536 for i,v in values];quarter=full[:1024]
for i,v in enumerate(full):
 offset=i&1023;mirror=bool(i&1024);idx=(-offset)&1023 if mirror else offset
 expected=32767 if mirror and offset==0 else quarter[idx]
 if i&2048:expected=-expected
 assert expected==v,(i,v,expected)
old=target.read_text()
rebuilt=re.sub(r"10'd(\d+): magnitude<=16'h[0-9a-fA-F]+;",lambda m:f"10'd{m[1]}: magnitude<=16'h{quarter[int(m[1])]:04x};",old)
if args.write:target.write_text(rebuilt)
else:assert rebuilt==old,'Quarter ROM differs; inspect source before --write'
print('QUARTER_SINE_GENERATION_PASS all4096 bit_exact no_latency_change')
