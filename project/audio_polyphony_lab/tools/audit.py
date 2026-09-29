"""Check evidence, current build inputs and unnormalised RTL audio agree."""
from pathlib import Path
import array
import hashlib
import json
import wave

LAB=Path(__file__).resolve().parents[1]
ROOT=LAB.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    for name,n,shift in [('piano16',16,1),('piano32',32,2)]:
        record=json.loads((LAB/'results'/f'{name}_pnr.json').read_text())
        assert record['timing_pass'] and record['budget_pass'] and not record['board_tested']
        for relative,expected in record['source_sha256'].items():
            current=(ROOT/relative).read_bytes()
            portable=hashlib.sha256(current.replace(b'\r\n',b'\n')).hexdigest()
            assert sha(ROOT/relative)==expected or \
                record.get('source_lf_sha256',{}).get(relative)==portable, \
                f'{name}: source changed: {relative}'
        bitstream=LAB/'variants'/name/'impl/pnr'/f'{name}.fs'
        if bitstream.exists():
            assert sha(bitstream)==record['bitstream_sha256'], name+' bitstream mismatch'
        print(f'POLY_PNR_FINGERPRINT_PASS {name} sources and available FS')

    markers=json.loads((LAB/'results/simulation.json').read_text())['pass_markers']
    for n,shift in [(8,0),(16,1),(32,2),(16,0),(32,0)]:
        assert any(f'POLY_CORE_TB_PASS N={n} shift={shift} ' in line for line in markers)
    for n in (16,32):
        assert any(f'POLY_BOARD_TB_PASS N={n} ' in line for line in markers)
    assert any('POLY_CADENCE_EQUIVALENCE_PASS' in line for line in markers)
    assert any('POLY_EQUIVALENCE_TB_PASS' in line for line in markers)

    for record in json.loads((LAB/'results/audio.json').read_text()):
        n,shift=record['voices'],record['output_shift']
        assert any(f'POLY_PREVIEW_TB_PASS N={n} shift={shift} FAST=1 SHORT=0' in line and
            f'max-occupied={n}' in line for line in markers)
        assert not record['normalised'] and shift=={8:0,16:1,32:2}[n]
        source=LAB/record['source_pcm']
        samples=[int(value) for value in source.read_text().splitlines()]
        output=LAB/'audio'/f'piano{n}_shift{shift}_preview.wav'
        assert sha(output)==record['wave_sha256']
        expected=array.array('h',(v for s in samples for v in (s,s))).tobytes()
        with wave.open(str(output),'rb') as wav:
            assert wav.getnchannels()==2 and wav.getsampwidth()==2
            assert wav.getframerate()==record['wav_header_hz']==48077
            assert wav.getnframes()==record['frames']==len(samples)
            assert wav.readframes(wav.getnframes())==expected
        assert max(map(abs,samples))==record['peak']
        print(f'POLY_AUDIO_FINGERPRINT_PASS N={n} frames={len(samples)} no normalisation')
    print('POLY_EVIDENCE_AUDIT_PASS')


if __name__=='__main__':main()
