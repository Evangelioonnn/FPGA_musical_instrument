# 2026-09-29 user board acceptance

Source baseline: 615cb94. User reported that the main project's timbres and
effects work well, and both independent high-polyphony projects work well.

Accepted scope: audio_core_v1 five-timbre main, independent piano16/piano32.
This is user listening/functional feedback, not a measured analogue SNR,
key-to-analogue latency, physical ADC or combined display/Bluetooth test.

Known fixed gain in independent high-polyphony tests: piano16 1/2,
piano32 1/4 of the eight-voice reference per-note level.

Main audio_core.fs SHA256:
a6a87412864366c8c747485a298b503078a08ac07a031a11d578118c4ee8bb46.

The current baseline is preserved; new V2 firmware requires separate audition.
