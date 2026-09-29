"""Create the isolated V1 voice fork from tracked reference sources."""
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
PROJECT = HERE.parent
CUSTOM = PROJECT / 'custom_harmonic_lab'
FIVE = PROJECT / 'five_timbre_core'


def main():
    sources = (
        (CUSTOM / 'src/custom_gallery_bank.v', 'audio_voice_bank.v',
         {'custom_gallery_bank': 'audio_voice_bank', 'gallery_slot': 'audio_voice_slot'}),
        (FIVE / 'src/gallery_slot.v', 'audio_voice_slot.v',
         {'gallery_slot': 'audio_voice_slot', 'gallery_tone_state': 'audio_voice_state'}),
        (FIVE / 'src/gallery_tone_state.v', 'audio_voice_state.v',
         {'gallery_tone_state': 'audio_voice_state'}),
    )
    (HERE / 'src').mkdir(parents=True, exist_ok=True)
    for source, name, replacements in sources:
        destination = HERE / 'src' / name
        if destination.exists():
            raise RuntimeError(f'Refusing to overwrite {destination}')
        text = source.read_text(encoding='utf-8')
        for old, new in replacements.items():
            text = text.replace(old, new)
        destination.write_text(text, encoding='utf-8')
    for ext in ('cst', 'sdc'):
        (HERE / 'src' / f'audio_core.{ext}').write_bytes(
            (CUSTOM / 'src' / f'custom_gallery.{ext}').read_bytes())


if __name__ == '__main__':
    main()
