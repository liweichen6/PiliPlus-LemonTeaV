#!/usr/bin/env python3
"""Frame cadence of the video layer, from `dumpsys SurfaceFlinger --latency`.
stdin: the dump. Prints how many intervals ran long against the stream's 16.68 ms."""
import statistics as st
import sys
rows = [l.split() for l in sys.stdin if len(l.split()) == 3]
t = [int(r[2]) for r in rows if int(r[2]) not in (0, 9223372036854775807)]
d = [(b - a) / 1e6 for a, b in zip(t, t[1:]) if b > a]
if len(d) < 20:
    print(f"cadence: only {len(d)} intervals")
    sys.exit()
late = sum(1 for x in d if x > 25)
print(f"cadence: {len(d)} intervals, median {st.median(d):.1f} ms, over 25 ms {late} ({100 * late / len(d):.1f}%), worst {max(d):.0f} ms, fps {1000 * len(d) / sum(d):.1f}")
