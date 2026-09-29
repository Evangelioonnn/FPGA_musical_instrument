# Audio observation and command transport V1

Owner A. Source contracts: [audio V2](AUDIO_CORE_V2.md) and
[parameter/PCM fields](AUDIO_CORE_V1.md). This package supplies clock crossing,
buffering and backpressure isolation. It does not implement HDMI pixels,
Bluetooth, UART packet framing, FFT, decimation or an external ADC.

## Clock and Reset Contract

All three bridges accept a single common asynchronous active-high `arst`.
It asserts reset in both clock domains immediately; each domain releases reset
after its own two rising clock edges. The source audio domain is 50 MHz; the
observer/client clocks may differ and may stall. Independent one-sided reset
is unsupported. Changing either side's clock/reset configuration requires a
common link reset. In the integration example the core and all bridges share
this common reset. Audio panic is a separate audio operation: it does not reset
the transport link, and consumers identify the resulting gaps through sample
indices and the V2 stream-reset counter. The user of a stream discards partial records and FFT
windows on reset. First accepted output after reset has `dst_session_start=1`.
Reset cancels outstanding commands/replies; the client must retry after reset.
Reset counters are not a persistent boot ID and cannot distinguish two sessions
without this reset indication.

Pointers/toggles cross through two-flop synchronizers. The RAM payload crosses
only under ownership of a frozen bank or a completed FIFO frame. No state
payload is synchronized bit by bit. Top-level CDC constraints must preserve
the intended synchronizers and constrain Gray-pointer skew; ordinary RTL
simulation does not prove metastability behavior or routed CDC constraints.

## Snapshot Bridge

Module `audio_snapshot_bridge`, defaults `SNAPSHOT_W=2368,KEYS=25`.

Source ports: `src_snapshot_valid`, `src_snapshot_data`,
`src_snapshot_extension[255:0]`, `src_snapshot_keys[KEYS-1:0]`, and
`src_capabilities[127:0]`. The complete producer bundle must hold its value
until the next publication, as audio V2 already does. `src_busy` is observation
status only and must never feed audio backpressure.
An unrelated producer that changes its bundle one clock after merely pulsing
valid is unsupported: this bridge deliberately reads the stable producer
registers instead of capturing another thousands-bit register bank.

One narrow `16bit x 256` dual-clock RAM stores a complete 46-word record;
the observer assembles each 64-bit word from four RAM reads. The audio domain
copies 184 halfwords in 184 clocks (3.68 us at 50 MHz), far below the ordinary
1024-PCM snapshot interval. Source metadata is latched; the large audio V2
snapshot registers are reused and are not duplicated in the bridge.

| 64-bit Word | Payload |
|---|---|
| 0 | `[63:48]=0x4132`, `[47:40]=1` transport version, `[39:32]=record word count`, `[31:24]=base word count`, `[23:16]=4` extension words, `[15:8]=KEYS`, `[7:0]=0` reserved |
| 1 | `[31:0]=transport_sequence`, `[63:32]=source whole-record drop count at start of this copy` |
| 2..3 | V2 capabilities, least significant 64-bit word first |
| 4..40 | V2 base snapshot, least significant 64-bit word first |
| 41..44 | V2 extension, least significant 64-bit word first |
| 45 | Actual logical keys, zero padded to 64 bits |

Widths other than V2's 2368-bit base use `ceil(SNAPSHOT_W/64)` base words,
with the highest base word zero padded. Up to 64 logical keys are supported;
the total record must fit 64 words. The V2 voice layout and preset IDs remain
unchanged. Capabilities are included in every record, so late observers need
no separate startup transaction.

`dst_valid/dst_ready` use the standard held-payload handshake. Data,
`dst_word_index`, `dst_first`, `dst_last` and `dst_session_start` remain stable
while valid is stalled. Index starts at zero. `dst_first` marks the first word
of every record; `dst_session_start` marks only the first word after common
reset. The observer must publish UI state only after accepting `dst_last`;
it may latch the completed state at a display frame boundary.

`transport_sequence` starts at zero and increments modulo 2^32 on every source
publication, including dropped ones. It is distinct from the audio snapshot
sequence in base bits31:0. Once a record is handed to the destination its bank
cannot be overwritten until `dst_last` is accepted. Publications during this
ownership period are dropped whole and increment `src_drop_count` modulo 2^32.
If a new publication arrives while the previous record is still being copied,
the incomplete copy is discarded, counted once, and restarted using the new
complete producer bundle. No partial or mixed record is published. A frozen
record cannot include drops that happen after it was frozen; the next record
reports them. A stopped/stalled observer therefore affects freshness only.

At the ordinary 1024-PCM publication interval a complete record is 368 bytes,
or about **17.28 kB/s** before any serial framing. UART115200 with 8N1 carries
at most 11.52 kB/s, so C must send selected compact fields or complete records
at a lower rate. The internal word stream is not a requirement to transmit all
voice records over Bluetooth. Stalling it indefinitely causes documented whole
record drops; it never slows synthesis.

## Full-Rate PCM Bridge

Module `audio_pcm_bridge`, default `ADDR_W=6` gives 64 complete stereo frames.
At Fs=50 MHz/1040 this covers about 1.3312 ms of observer backlog. C may change
the power-of-two depth after measuring its consumer latency and resources.
`ADDR_W` must be at least 1. Default RAM is `16bit x 256`; a 64-bit staging
register at each end packs/unpacks `{sample_index32,right16,left16}`. The FIFO
publishes its Gray pointer only after all four halfwords have been written.

Source ports are single-cycle `src_valid`, signed16 `src_left/src_right`,
and `src_index[31:0]`. They are exactly V2's post-effect/post-master DAC PCM
and matching sample index. There is no source ready/backpressure. A frame
while the FIFO is full or while its four-clock serializer is busy is dropped
whole; `src_drop_count` increments modulo 2^32 and `src_overflow` stays set
until common reset. Normal 1040-clock audio publication has ample serialization
time: capture plus four writes requires a minimum spacing of five source
clocks between accepted frames. All incoming frames count, even if two arrive
unrealistically close. Core integration tests use the real 1040-clock sampling
period rather than a sped-up source to claim audio throughput.

Destination is held `dst_valid/dst_ready` plus `dst_left/dst_right/dst_index`.
`dst_session_start` is one for the first accepted frame after reset.
`dst_gap` is one for that first frame or whenever its index differs from the
previous accepted index plus one modulo 2^32. It therefore covers source panic
gaps, observation overflow, duplicate/out-of-order input and index reset;
normal 0xffffffff -> 0 wrap is continuous. The gap flag stays stable through a
stall. Consumers restart a contiguous FFT/window at a gap; they must not join
samples on opposite sides of a missing frame. No waveform decimation is done
here. FFT must consume full rate or a separately low-pass-filtered stream.

Slow consumers cannot stall the synthesizer. Overflow may conservatively drop
a frame briefly after a slot has been freed until its read pointer synchronizes
back; this is explicit bounded buffering, not lossless UART audio streaming.

## Host Command and Reply Bridge

Module `audio_command_bridge` crosses one outstanding command from `client_clk`
to `audio_clk`. Client request is held `client_valid/client_ready` plus
`client_addr[4:0]`, `client_value[31:0]`, `client_tag[15:0]`; no unit conversion
occurs. Addresses/units/legal values are V2/V1 parameter service definitions.
The client tag is an opaque correlation ID, not a replay-protection counter.

The audio `host_valid/host_ready/host_addr/host_value` connect directly to the
existing unified parameter service. The bridge holds the request through the
service handshake and waits for the host-source ACK. Local-source ACKs are
ignored. It returns the service's canonical `ack_addr/ack_value`,
`ack_accepted/ack_applied`, and the original tag through held
`reply_valid/reply_ready`. Illegal commands therefore receive the service NACK.
`applied` means target committed, not audio smoothing finished.

Only this bridge may own that host port. An unexpected host ACK or mismatched
ACK address raises sticky `audio_protocol_error`; it is an integration bug,
not an automatically acknowledged client command. No timeout or silent retry
is inserted. Stalling reply consumption prevents further client commands but
does not stall audio, local configuration or an already accepted service ACK.
Use the snapshot to observe the actual smooth values. UART/Bluetooth transport
may add framing, CRC and tags outside this bridge, without directly writing a
second set of audio parameter registers.

## Validation Boundary

The three bridge tests were actually run in ModelSim on 2026-09-29, using
unrelated clocks and independent expected records/sample values:

| Test | Actual Result |
|---|---|
| Snapshot | 5 complete records, 238 accepted words including a cancelled partial record, 97 stalled cycles; 2 busy-publication drops, 1 interrupted-copy drop; reset during copy and partial output |
| PCM | 258 bit-exact delivered frames, 10 full-FIFO drops, 1 busy-serializer drop, 7 gaps, 2 sessions, 731 stalled cycles; pointer wrap and reset during queued/serialized frames |
| Commands | 6 delivered replies, 7 host ACKs including a cancelled reply, 1 filtered local ACK, 2 NACKs, 26 host-stall and 38 reply-stall cycles; pending/stalled-reply reset and unexpected-ACK diagnosis |

Reproduce the default three tests with
`python project/audio_integration/sim/run_transport.py`. Their actual result and
portable source fingerprints are generated under `project/audio_integration/results`.
The runner also supports the root-owned complete core integration bench:

```powershell
python project/audio_integration/sim/run_transport.py --test core_transport_tb
python project/audio_integration/sim/run_transport.py --test core_transport_tb --bank project/audio_integration/optimized/audio_v2_bank_packed.v
```

`--bank` is an explicit repository-relative replacement through the package
manifest; the runner does not edit the accepted core's project/source list.
The complete-core bench checks real post-master DAC PCM, every word of the
coherent producer state, compact UI fields and actual host ACKs while state
and PCM consumers both stall. Its sampling period is 1040 audio clocks. The
simulation-only ROM replacement first proves all 4096 table entries and X/Z
retention against the unchanged synthesis ROM. Complete-core results are
written separately from the three-bridge evidence; only a real PASS marker
with current source fingerprints qualifies them as verified.

The regressions cover
held-ready stalls, whole-record/FIFO pressure, pointer wrap, source index gaps,
common reset during copy/partial output/queued PCM/pending command, and real
parameter-service legal/illegal commands with interleaved local ACKs.
Simulation/resource audits do not claim C's real screen/Bluetooth
implementation, physical ADC or whole-system PnR/board acceptance.
