# Editable four-harmonic timbre contract

Owner: A. Branch: `codex/editable-harmonic`. This experiment preserves all
five existing preset IDs and is isolated from their sources. The editable
timbre is an optional sixth preset candidate, ID 5, only if/when integrated.

## Controls and units

The future eight-channel, 12-bit SPI ADC supplies coherent channel snapshots.
Only CH0..CH4 are used:

| Channel | Meaning | RTL representation |
|---|---|---|
| CH0 | Master volume after voice mixing | unsigned Q0.16; 65535 is full scale, 0 is mute |
| CH1 | Fundamental amplitude | unsigned Q8; 256 means 1.0 |
| CH2 | 2x harmonic amplitude | unsigned Q8; 256 means 1.0 |
| CH3 | 3x harmonic amplitude | unsigned Q8; 256 means 1.0 |
| CH4 | 4x harmonic amplitude | unsigned Q8; 256 means 1.0 |

The ADC maps to Q8 using rounded `adc * 256 / 4095`, with the endpoint 4095
mapped exactly to 256. The implementation uses the equivalent 12-bit shortcut
`adc[11:4] + adc[3]`. CH0 maps monotonically to Q0.16 with
`(adc << 4) + adc[11:8]`, including exact zero/full-scale endpoints. The
accepted piano default is `[256,64,32,16]`, selected
by ADC values `[4095,1024,512,256]`; its coefficient sum is 368. This preserves
the current weighted expression `[128,32,16,8]` exactly because the four
harmonic products are summed in Q8 and shifted right by one.

## Headroom policy

The effective four-coefficient sum is limited to 368. If the raw sum exceeds
368, all four weights are proportionally normalized down; floor rounding
ensures their integer sum cannot exceed 368. When the sum is within the limit,
weights are not altered. Thus CH0 remains an independent post-mix volume
control and the four-pushers-full case `[256,256,256,256]` becomes
`[92,92,92,92]` (sum 368). Under this policy increasing one harmonic can
reduce the others only after the total crosses the headroom limit. This
preserves the default piano level while bounding the worst-case sum; without
normalization or fixed attenuation, full-scale settings could clip.

The coefficient limit is a conservative peak bound, not a loudness guarantee.
The eight-voice same-note case must still be measured in the RTL bench through
the existing bank mixer and post-mix volume stage. The required assertions are
no PCM clip, no unknown samples, and no missed audio-frame deadline.

## Update behavior

`adc_valid` means all used channel values belong to one coherent ADC scan. The
parameter service snapshots the complete set on that pulse and retains the
last valid values when `adc_valid` is low. Reset starts at the piano default,
not silence. Target coefficients and volume are approached only on
`sample_ce`; the audio synthesizer snapshots the four coefficients at the
start of each PCM frame, so one rendered sample cannot mix parameter versions.
The parameter service first applies all downward coefficient steps, then
allocates remaining sum headroom to upward steps in CH1-to-CH4 order. This
keeps the live coefficient sum at or below 368 throughout crossfades, not
only at their endpoints. The current RTL uses a maximum Q8 step of 2 per audio
frame and a Q0.16 volume step of 1024 per frame.

`adc_valid` is accepted only when `params_busy` is low. Under-limit snapshots
update all targets together immediately; over-limit snapshots run through a
shared 17-cycle restoring divider four times (about 72 clocks total) before
atomically committing volume and coefficients. `params_updated` pulses when a
complete target vector commits, not when smoothing reaches its endpoint. An
`adc_valid` pulse while busy is rejected as a whole and sets sticky
`adc_overrun`; an ADC reader must wait for `params_busy == 0` before publishing
its next coherent snapshot. The live coefficients and volume still slew at
`sample_ce` boundaries.

In the board candidate, preset 5 temporarily maps the EC11 to a simulated
fader interface: S4 short selects CH0 through CH4, and each encoder detent
changes that channel by 64 ADC codes with 0..4095 saturation. A changed value
emits one coherent `adc_valid` snapshot. This makes the full parameter path
available before B's control PCB and SPI ADC exist; it is a test adapter, not
the intended final physical control surface.

CH0 is applied after voice mixing. CH1..CH4 define one global editable
per-voice spectral shape. Four harmonics share each voice's phase and envelope;
this is not 32 independent oscillators and must not be described that way.

## Hardware boundary

The planned SPI ADC has 8 channels, 12-bit samples and four digital lines at
3.3 V to J13. ADC part number, SPI mode/rate, J13 pin numbers, acquisition
timing and physical control-board wiring are not frozen by this experiment.
Those pins are not exposed as board-top inputs until B's electrical proposal
and the actual ADC module are checked. The temporary EC11 fader adapter drives
the same parameter-service interface in this candidate.
