# Validation status

Role A delegated effect experiment,2026-09-28. Branch:`codex/audio-core-v1`,
base commit:`de84fd3`. Allowed scope: only
`project/audio_fx_lab`; no hardware programming, remote publication or old
source changes. Branch and base commit are recorded by the parent integration
task. Source defines a real effect and real differing stereo wet channels.

No user board audition has occurred. Digital and standalone50MHz implementation
checks passed. Machine-readable source hashes and results are recorded in
`sim_validation.json` and `pnr_validation.json`; files in `impl` remain local.

## Digital results

The initial nominal1040-clock/frame regression checked142384 room frames plus
200000 LFO frames. Replacing constant-times-three with exact shift/add removed
two unnecessary DSPs. The final-source faster40-clock stress run checked182384
room frames and200000 LFO frames, plus invalid-rate and reset behavior.
The faster test preserves the same sample recurrence and proves24-clock
completion well inside the1040-clock production budget.

```
SHORT_ROOM_TB_PASS frames=182384 latency=24
VIBRATO_TB_PASS frames=200000 bound/slew/off-center
SHORT_ROOM_FAULT_TB_PASS busy rejection, in-flight reset, dry warmup
FX_ORACLE_PASS 182384 frames exact; stereo impulse, decay, DC, full-scale, bypass
VIBRATO_ORACLE_PASS 200000 frames exact; frequencies=2..9 Hz, clamp, slew, return to unity
```

All rendered samples match the independent integer model. Full-scale DC and
alternating extremes produced no clips; bypass outputs exactly match randomized
inputs after the smooth transition. The impulse tail decays to zero, and first
reflection channels differ as the stereo weights predict. The reference melody
has40000 zero frames of preroll; the oracle verifies every delay cell is zero
before reference generation, so stress-test history is not heard in the WAVs.
The three local WAVs are `sim/short_room_dry.wav`, `sim/short_room_wet.wav` and
`sim/short_room_impulse.wav`. The reference wet ratio is64=25%.

## Standalone implementation

Gowin V1.9.12.03, GW5AT-LV60PG484AC1/I0, device B; top:`fx_resource_top`.

| Measure | Result |
|---|---:|
| Logic | 788 |
| Register | 487 |
| BSRAM | 4 |
| DSP | 1.5 |
| I/O | 19 |
| Setup/hold violated endpoints | 0/0 |
| Minimum setup slack | 8.235ns |
| Fmax | 84.996MHz |

These counts include the diagnostic source/transport and shared LFO, not only
the room module; they must not be blindly added to an integrated design report.
The delay memory inferred actual block RAM. Constant gain weights use shift/add;
only wet mixing and vibrato use variable multipliers.

Three width-reduction warnings are intentional, justified by the amplitude
bounds in SPEC:28-bit shifted values fit20 bits and wet averages fit16 bits.
The diagnostic unused-button warning does not change the interface.
PR1014 reports generic clock routing from V22; this implementation's actual
setup/hold report passes. The integrated core must still rerun its own clock
routing and timing. The probe bitstream SHA256 is
`7f2df521c67b042dea3355caa3efb2ffaf104394e0dea06297641ecce855e046`.

Completed checks:

- Independent Python delay recurrence versus every recorded RTL sample.
- Full-scale positive and negative DC, alternating extremes and random inputs.
- Fixed24-clock output, one frame per input at1040 clocks, initialization dry fallback.
- Random bypass, control clamp, sample-boundary slew and return to exact dry.
- Impulse first-arrival/stereo separation and vanishing tail without DC limit cycle.
- LFO factor against independent phase/depth oracle, speed, range, slew and centering.
- Actual19-port resource probe50MHz PnR, BSRAM/DSP report and setup/hold checks.
- WAVs generated from real effect RTL for a synthetic harmonic melody.

Remaining physical work: integrated top resource/timing, actual loudness and
tail quality on headphones/speakers, switches during real performance, and DAC
plus master-volume behavior. Independent PnR does not substitute for integration.
