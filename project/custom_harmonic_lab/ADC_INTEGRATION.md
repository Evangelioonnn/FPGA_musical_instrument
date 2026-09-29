# SPI ADC integration handoff

The renderer and parameter service accept five parallel 12-bit channels and
one `adc_valid` pulse. This is the stable boundary for a future SPI reader; the
current board build supplies the values through `custom_fader_emulator`. The
parameter service exposes `params_busy` and sticky `adc_overrun` status.

When B selects the actual ADC and publishes the control-board schematic, the
SPI reader should:

1. Read the used channels in a deterministic CH0-to-CH4 scan, retaining each
   conversion in scratch registers.
2. Publish all five values together and pulse `adc_valid` only after the full
   scan is complete and `params_busy` is low. Never expose a mixed-age group
   where one new fader sample is combined with four values from the previous
   scan. Wait until the busy flag clears before publishing the next snapshot;
   a pulse during normalization is rejected atomically and recorded in
   `adc_overrun`.
3. Keep the last complete snapshot on reset, incomplete transactions, SPI
   timeout or invalid conversion. The parameter service's reset defaults are
   full CH0 and harmonic Q8 `[256,64,32,16]`.
4. Synchronize the `adc_valid` transaction into the 50 MHz audio clock domain
   with a handshake or small asynchronous FIFO if the ADC controller has a
   different clock. Do not synchronize each data bit independently.

The expected physical link is four 3.3 V digital signals (SCLK, MOSI, MISO,
CS) to J13, plus the required power and ground through the control-board
connector. This is not a frozen pin map: no ADC part, SPI mode, conversion
rate, J13 ball numbers, analog reference, fader taper or electrical schematic
has been selected or measured. B and A must confirm the exact part's logic
levels and the J13 pin/bank assignment before replacing the EC11 test adapter.

CH0 is the post-mix volume input. CH1..CH4 are global harmonic amplitudes for
every active harmonic voice. The current normalization is performed when a
coherent snapshot arrives; over-limit normalization takes about 72 clocks. The
live coefficients then slew only at audio-frame boundaries and preserve the
sum cap throughout a transition. A later SPI implementation should scan
quickly enough for useful fader response, but the frame smoother must remain
the final click-control stage.
