# Looper refinement scope

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

Read README/SPEC/INTEGRATION/VALIDATION/WORK_PLAN before editing. The branch is
codex/looper-refinement-20261007, comparison commit 0199ed7. Board top has 19 IO;
external audit top has 27 placeholder IO; PLL audit has 26. Both MUST NOT be
downloaded. LR1 is an isolated
versioned 54-word contract, not a silent replacement of SYSTEM_V0.

Use 20 ns for the actual 50 MHz acceptance build. Preserve failed 18 ns guard
evidence. Preserve C reservation and check CLS, not only Logic/BSRAM totals.
collect_evidence.py must reject absent, stale or failed mandatory results.
Full DELIVERY also requires qualified interface PnR/STA. The explicit
--board-only mode may publish BOARD_DELIVERY with a verified negative audit and
interface_audit_qualified=false; it is never whole-instrument qualification.

Final result on 2026-10-08: BOARD_DELIVERY.json qualifies only the 19-IO
candidate. All four interface audits failed routing, including PLL audit with
3402 unrouted nets. Do not cite a nonexistent DELIVERY.json or inherit C/V2
board qualification. The PLL wrapper behavioral clock model is not vendor
primitive simulation or successful physical STA.
