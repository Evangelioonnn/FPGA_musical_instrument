# Rejected static-state prototype

The first attempt shared pitch multiplication and tone rendering but retained
32 replicated state/control datapaths. Gowin synthesis failed before PnR:
63353 Logic (50348 LUT, 13005 ALU), exceeding the physical 59904 capacity and
the team's 29000 cap. No downloadable approved bitstream exists for this design.
Default raw piano/pluck/bell comparisons reached 3900 frames, then simulation
was intentionally stopped once the capacity failure made the design unsuitable.
This partial run is not a complete verification pass. The copied sources and
reviewed summaries preserve the rejection evidence; raw logs stay local.
Current src uses a shared state datapath.
