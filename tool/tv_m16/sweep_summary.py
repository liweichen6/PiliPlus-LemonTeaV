#!/usr/bin/env python3
"""One line for a sweep run: mpv's drops and the layer's cadence.

Usage: sweep_summary.py NAME LOGCAT CADENCE_FILE
Skips the first 30 s. A position that doesn't move means the run hit the end of
the video, so it says so instead of reporting a rate.
"""
import re
import statistics as st
import sys

name, log, cad = sys.argv[1:4]
rows = []
for line in open(log, errors="replace"):
    m = re.search(r"stats pos=([0-9.]+) .*size=(\d+)x.*drop=(\d+) decdrop=(\d*) delayed=(\d*)", line)
    if m and int(m.group(2)) > 1920:
        rows.append((float(m.group(1)), int(m.group(3)), int(m.group(5) or 0)))
rows = rows[3:]
over, fps = [], []
for line in open(cad):
    m = re.search(r"over 25 ms \d+ \(([0-9.]+)%\).*fps ([0-9.]+)", line)
    if m:
        over.append(float(m.group(1)))
        fps.append(float(m.group(2)))
if len(rows) < 2 or not fps:
    print(f"{name:<10} no data ({len(rows)} stats, {len(fps)} cadence)")
    sys.exit()
secs = rows[-1][0] - rows[0][0]
if secs < 1:
    print(f"{name:<10} position didn't move: the end of the video?")
    sys.exit()
drop = rows[-1][1] - rows[0][1]
print(f"{name:<10} {secs:5.0f} s  mpv drop {drop:5d} ({100 * drop / (secs * 59.94):4.1f}%)  "
      f"delayed {rows[-1][2] - rows[0][2]:5d}  layer fps {st.mean(fps):4.1f}  long intervals {st.mean(over):4.1f}%")
