# Release-only shared pluck arithmetic

16-pluck pool passed the independent bank capacity stress (898 PCM frames,
533 worst rendering clocks). Its synthesis totals were33416 Logic /17660 Reg
/59 BSRAM /75.5 DSP. Logic and Register already exceeded A's caps before the
full-interface audit, so PnR was intentionally stopped and no bitstream approved.
The retained sources show this intermediate implementation. Current pool code
shares mean/interpolation/feedback/release multiplication, instead of release only.
