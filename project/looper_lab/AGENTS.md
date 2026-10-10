# Looper lab scope

This is an isolated experiment based on the accepted audio V2 source. Keep V2
and all board-tested fallbacks unchanged. The 4x4 matrix is a development
adapter only; no new physical pin mapping is implied.

Use the actual 50 MHz / 1040-clock audio cadence. Preserve local live input
latency; quantization applies only to recorded playback. No pre-recorded PCM is
used. Record and replay note/control events while the audio engine synthesizes
every output sample.

Each evidence entry must identify the tested RTL fingerprint, simulation,
synthesis/PnR status, and whether a result is only a model or has board evidence.
Never treat this lab as an accepted board image until its own top, CST/SDC,
Gowin build, and physical listening are verified.
