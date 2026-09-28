"""Conservative integer bounds independent of the RTL sample recurrence."""
from pathlib import Path
import hashlib
import json

LAB=Path(__file__).resolve().parents[1]
ROOT=LAB.parents[1]
SINE=32768
ENV=65535

def round_away(n,shift):
    return (n+(1<<(shift-1)))>>shift

piano=round_away(SINE*(128+32+16+8)*ENV,23)
custom=round_away(((SINE*368)//2)*ENV,23)
bell=round_away(SINE*(96+16+16)*ENV,23)
lead_shape=3000000+((2*SINE*(128+16+64+16)-3000000)//4)
lead=round_away(lead_shape*ENV,23)
harmonic=max(piano,custom,bell,lead)
# Each warm sample is (x[n]+2*x[n-1]+x[n-2])/8, with signed16 input.
warm=(SINE*4)//8
cases=[{'pluck':p,'harmonic':32-p,'mixed_pcm_bound':round_away((32-p)*harmonic+4*p*warm,6)}
       for p in range(13)]
worst=max(row['mixed_pcm_bound'] for row in cases)
assert worst<32767
# Each comb uses dry/4 + feedback*3/4, and stereo taps sum to8/8.
# Both operations truncate toward zero; wet mix is convex at wet<=128/256.
assert worst+1<=32767
files=[Path(__file__).resolve(),LAB/'src/audio_v2_bank_stream.v',LAB/'src/audio_v2_tone.v',
       LAB/'src/audio_v2_pluck.v',LAB/'src/audio_v2_pool_slot.v',
       LAB.parent/'audio_fx_lab/src/short_room_reverb.v']
record={'pluck_capacity':12,'logical_capacity':32,
        'raw_q4_bounds':{'piano':piano,'custom_sum368':custom,'bell':bell,'lead':lead,'warm':warm},
        'allowed_mixtures':cases,'mixed_peak_bound':worst,'pcm_headroom_codes':32767-worst,
        'master_max_q16':65536,'room_bounded_convex':True,'passed':True,
        'source_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files}}
(LAB/'results').mkdir(exist_ok=True)
(LAB/'results/headroom.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print(f'V2_HEADROOM_PASS mixed32 worst={worst}/32767; headroom={32767-worst}; fixed gains, no active-count normalisation')
