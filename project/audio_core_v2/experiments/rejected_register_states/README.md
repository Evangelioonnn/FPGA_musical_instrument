# Rejected register-state design

The shared arithmetic/streaming mixer reduced the original 63353 Logic attempt,
but this all-register state design still exceeded the team's budget and failed
50 MHz physical timing: 32080 Logic /18614 Reg /40 BSRAM /58.5 DSP,
1178 setup violations, minimum setup slack -3.195 ns, Fmax 43.113 MHz.
Its bitstream is not approved for board testing. The saved provenance captures
the original source hashes. The historical audio_v2_bank.v remains for review;
the active GPRJ now uses audio_v2_bank_stream.v instead.

Before rejecting it, raw five-preset equivalence reached 6500 frames. The core
and board regressions passed (copied raw logs retained locally), but the full-capacity bank bench
failed on extreme bell release: 25-bit addition overflow. The RAM candidates
widen that addition to26 bits. No failure log is included here because the
runtime log was already replaced by the subsequent RAM regression.
