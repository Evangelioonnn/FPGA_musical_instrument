"""Convert actual RTL PCM to unnormalised stereo WAV, preserving output gain."""
from pathlib import Path
import array
import hashlib
import json
import wave

LAB=Path(__file__).resolve().parents[1]
FS=50000000/1040


def main():
    directory=LAB/'audio'
    directory.mkdir(exist_ok=True)
    records=[]
    for n,shift in [(8,0),(16,1),(32,2)]:
        path=LAB/'sim'/f'poly_preview_{n}_{shift}_1_0.txt'
        samples=[int(s) for s in path.read_text().splitlines()]
        pcm=array.array('h',(v for s in samples for v in (s,s)))
        output=directory/f'piano{n}_shift{shift}_preview.wav'
        with wave.open(str(output),'wb') as wav:
            wav.setnchannels(2);wav.setsampwidth(2);wav.setframerate(round(FS));wav.writeframes(pcm.tobytes())
        records.append(dict(voices=n,output_shift=shift,frames=len(samples),
            sample_rate_exact_hz=FS,wav_header_hz=round(FS),seconds=len(samples)/FS,
            peak=max(map(abs,samples)),wave_sha256=hashlib.sha256(output.read_bytes()).hexdigest(),
            normalised=False,source_pcm=str(path.relative_to(LAB)).replace('\\','/')))
        print(f'{output}: {len(samples)} frames peak={records[-1]["peak"]}')
    (LAB/'results/audio.json').write_text(json.dumps(records,indent=2)+'\n',encoding='ascii')


if __name__=='__main__':main()
