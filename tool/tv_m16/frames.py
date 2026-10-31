#!/usr/bin/env python3
"""Summarise the [m16] frame lines of each run named on the command line.

Usage: M12_RUNS=... ./tool/tv_m16/frames.py RUN_NAME...

Skips the first 3 windows (30 s of page start-up) and the last one (cut short
by the end of the run). All times in ms; p50 and p90 are the median of the 10 s
windows, p99 the worst window.
"""
import glob
import os
import re
import statistics as st
import sys

RUNS = os.environ["M12_RUNS"]
LINE = re.compile(
    r"frames=(\d+) over16ms=(\d+) build p50=(\d+) p90=(\d+) p99=(\d+) max=(\d+) "
    r"raster p50=(\d+) p90=(\d+) p99=(\d+) max=(\d+) "
    r"total p50=(\d+) p90=(\d+) p99=(\d+) max=(\d+)"
)
print(f"{'run':<22}{'win':>4}{'fps':>7}{'over16':>8}{'build p50':>10}{'raster p50':>11}"
      f"{'raster p90':>11}{'total p50':>10}{'total p90':>10}{'total p99':>10}")
for name in sys.argv[1:]:
    paths = sorted(glob.glob(f"{RUNS}/*-{name}"))
    if not paths:
        print(name, "no run")
        continue
    rows = []
    with open(f"{paths[-1]}/logcat.txt", errors="replace") as f:
        for line in f:
            m = LINE.search(line)
            if m:
                rows.append([int(x) for x in m.groups()])
    rows = rows[3:-1]
    if not rows:
        print(name, "no frame lines")
        continue
    frames = sum(r[0] for r in rows)
    over = sum(r[1] for r in rows)
    med = lambda i: st.median(r[i] for r in rows) / 1000
    print(f"{name:<22}{len(rows):>4}{frames / (len(rows) * 10):>7.1f}{100 * over / frames:>7.1f}%"
          f"{med(2):>10.1f}{med(6):>11.1f}{med(7):>11.1f}{med(10):>10.1f}{med(11):>10.1f}"
          f"{max(r[12] for r in rows) / 1000:>10.1f}")
