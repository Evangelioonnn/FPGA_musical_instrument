# Looper session V2 scope

User approved drum revision and a ready-to-integrate C interface; no actual C display wiring in this task.
Keep old labs/V2/board constraints unchanged. Work in the existing D workspace only.
Five melodic IDs 0/2/3/4/5 remain, drums are menu6. Preserve 32 melody slots (12 Warm pluck within32), 8 drum slots, 2048 events, 50MHz/1040 cadence, no voice stealing or active-count normalization.
New UI transport is versioned LU1; legacy LR1 remains optional and distinct. Define commands, ranges, clock/reset/ACK meanings before coding. Do not claim a UI/control mock is the real display or ADC board test.
Board entry: looper_session_v2.gprj / looper_session_top / 19 IO. Audit tops are never downloadable.
Run independent drum math/PCM comparison, control lifecycle and CDC/reset/backpressure tests, existing relevant regression, reference WAV and final50MHz PnR. Do not inherit old source fingerprints as new PASS. Keep C's reservation and report actual routing/timing limitations.
