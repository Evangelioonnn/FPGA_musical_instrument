# Configuration and fader contract

All ports use `clk` at 50 MHz and synchronous active-high `rst`. `sample_ce`
marks each audio frame (currently every 1040 clocks). Targets change only on
that boundary; consumers may add their own documented smoothing. No DSP
normalization or PCM gain smoothing is duplicated in this module.

## Configuration transport

`local_valid/local_ready/local_addr[4:0]/local_value[31:0]` and the corresponding
`host_*` port share one authoritative state. A handshake captures the complete
payload in a one-entry register; publishers may change it after handshake.
When both sources remain valid, capture alternates local and host, starting
with local. A pending transaction cannot be overwritten. The response is a
one-clock `ack_valid`, `ack_source` (0 local, 1 host), `ack_addr`, `ack_value`,
`ack_accepted`, `ack_applied`. Legal requests commit at `sample_ce`; both result
bits are 1, including legal no-ops. Illegal requests leave state unchanged and
return both bits 0. `ack_value` is the new canonical target for relative volume
and otherwise the original request value. Responses cannot be backpressured;
the caller must capture them. Integration must connect every enabled output:
parameter acceptance here means the target was committed, not that audio has
finished slewing to it.

| Address | Parameter | Legal value / reset |
|---:|---|---|
| 0 | selected preset | 0,2,3,4,5 / 0 |
| 1 | master volume target, unsigned Q16 | 0..65536 / 8249 |
| 2 | relative master delta, signed two's-complement | -65536..65536; saturates target |
| 3,4 | left/right zone MIDI base | 36,48,60,72 / 48,60 |
| 5,6 | ordinary/selective sustain | 0 or 1 / 0 |
| 7 | release index | 0..7 / 5 |
| 8 | glide index | 0..4 / 0 |
| 9 | bend index, signed quarter-semitone | -8..8 / 0 |
| 10 | lead attack index | 0..3 / 2 |
| 11,12 | override attack/decay increment per PCM frame | 1..65535 / 68,6 |
| 13 | override sustain Q16 level | 0..65535 / 32768 |
| 14 | override release increment per PCM frame | 1..65535 / 3 |
| 15 | custom sustained-envelope mode | 0 or 1 / 0 |
| 16 | vibrato depth index | 0..64 / 0 |
| 17 | vibrato speed index | 0..7 / 0 |
| 18 | effect enable | 0 or 1 / 0 |
| 19 | effect wet/dry mix Q8 | 0..128 (0..1/2) / 32 (1/8) |
| 20..23 | raw editable-harmonic CH1..CH4 | 0..4095 / 4095,1024,512,256 |
| 24 | envelope override enabled | 0 or 1 / 0 |
| 30 | panic | exactly 1 |
| 31 | restore defaults | exactly 1 |

Other addresses are illegal. Writing 11..14 enables `envelope_override`;
writing 24=0 restores preset-specific envelope selection in the consumer.
`panic_pulse` also clears both sustain flags and bend. Restore resets parameter
targets and re-arms pickup coherently; it does not erase voice state or generate
a panic. `parameter_revision` increments on accepted configuration and on a
fader scan that actually changes an authoritative target. `params_updated`
marks those commits. `master_owner` is 0 defaults, 1 local, 2 host, 3 fader.

## Coherent ADC scans and pickup

`adc_valid` is a one-clock publication pulse for coherent CH0..CH4[11:0].
`adc_ready` must be high on that pulse. A pulse while not ready is dropped as a
whole and sets sticky `adc_overrun`; it never partially updates channels. An
accepted scan is retained until it commits. Pending configuration and ADC
scans alternate when both can commit, so either stream can make progress.

CH0 controls all-timbre post-mix master volume. Its mapping is monotonic:
`(adc << 4) + (adc >> 8)`, with 4095 mapped exactly to 65536. CH1..CH4 change
the raw harmonic targets only while selected preset is 5. They do not affect
the other four preset sounds. Scan history is retained even outside preset 5.

Pickup is initially unacquired for every channel. A channel engages when its
physical value is within 16 ADC codes of the current target or crosses it
between scans. An acquired channel subsequently tracks movement. Explicit
configuration of a channel re-arms its pickup; entering preset 5 re-arms CH1..4.
Restore re-arms all five. CH0 at exact ADC zero is an unconditional safety mute
even before pickup and marks that channel acquired. This also means a physical
master fader left at zero overrides a later host unmute on its next scan.

`fader_acquired[4:0]` exposes pickup status. Master pickup converts the current
Q16 target to the nearest 12-bit physical position with endpoint saturation.
The four harmonic pickup targets are their unnormalized raw ADC values. The
downstream normalizer may proportionally reduce their effective coefficients;
that result must not be fed back as the physical pickup target.

## Harmonic publication

`raw_ch1..4` are authoritative targets. `harmonic_snapshot_valid`,
`harmonic_snapshot_ch1..4`, and `harmonic_snapshot_ready` form a separate held
bundle for the downstream normalizer. The bundle is stable until handshake;
reset publishes [4095,1024,512,256]. Harmonic writes, restore and ADC scans that
change harmonics wait while this bundle is backpressured, preserving coherent
processing. A master-only scan and a non-harmonic pending configuration do not
require bundle space. One pending harmonic request blocks later configuration
capture; the downstream normalizer must provide bounded readiness in the
integrated system. A coherent scan changing harmonics and setting CH0=0 waits
for that readiness before the zero mute commits.
The normalizer should use the snapshot ports, force its legacy CH0 to 4095,
and ignore its legacy volume result; master volume belongs to this service.

ADC chip, SPI mode, acquisition rate, electrical wiring and J13 pins are still
outside this contract. No physical-hardware acceptance is claimed here.
