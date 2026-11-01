#!/usr/bin/env python3
"""Summarise the [m13] lines of each run named on the command line.

Usage: M12_RUNS=... ./tool/tv_m13/steps.py RUN_NAME...

All times in ms. `work` is the app's own share of a step: decide + build +
raster. `total` runs from Android's key event to the end of raster for the frame
that shows the ring. `input`, `ring` and `wait` are medians, and `no move` counts
keys that moved no ring, such as at the edge of a list. The frame columns are
over the whole run, and `engine` is the focus engine's work on every frame.
"""
import glob
import os
import re
import statistics as st
import sys

RUNS = os.environ["M12_RUNS"]
FRAME_BUDGET_MS = 16.667
STEP = re.compile(
    r"\[m13\] step key=\w+ rep=(\d) moved=1 handled=\d input=(-?\d+) decide=(\d+) "
    r"ring=(\d+) wait=(\d+) build=(\d+) raster=(\d+) total=(-?\d+)"
)
NO_MOVE = re.compile(r"\[m13\] step key=\w+ rep=\d moved=0")
WINDOW = re.compile(
    r"\[m13\] frames=(\d+) over16ms=(\d+) build p50=(\d+) p90=\d+ p99=\d+ max=\d+ "
    r"raster p50=(\d+) p90=\d+ p99=\d+ max=\d+ total p50=\d+ p90=\d+ p99=\d+ max=\d+"
    r"(?: engine p50=(\d+) p90=(\d+) p99=\d+ max=(\d+))?"
)


def pct(values, p):
    ordered = sorted(values)
    return ordered[round((len(ordered) - 1) * p)]


print(f"{'run':<20}{'steps':>6}{'no move':>8}{'work p50':>9}{'p90':>7}{'p99':>7}"
      f"{'total p50':>10}{'p90':>7}{'p99':>7}{'max':>7}{'input':>7}{'decide':>7}"
      f"{'ring':>6}{'wait':>6}{'over1f':>8}{'over16':>8}{'engine':>7}{'p90':>6}")
for name in sys.argv[1:]:
    paths = sorted(glob.glob(f"{RUNS}/*-{name}"))
    if not paths:
        print(name, "no run")
        continue
    steps, windows, no_move = [], [], 0
    with open(f"{paths[-1]}/logcat.txt", errors="replace") as f:
        for line in f:
            if m := STEP.search(line):
                steps.append([int(x) / 1000 for x in m.groups()[1:]])
            elif NO_MOVE.search(line):
                no_move += 1
            elif m := WINDOW.search(line):
                windows.append(m.groups())
    if not steps:
        print(name, "no step lines")
        continue
    work = [s[1] + s[4] + s[5] for s in steps]
    total = [s[6] for s in steps]
    med = lambda i: st.median(s[i] for s in steps)
    frames = sum(int(w[0]) for w in windows)
    over = sum(int(w[1]) for w in windows)
    engine = [w for w in windows if w[4] is not None]
    print(f"{name:<20}{len(steps):>6}{no_move:>8}"
          f"{st.median(work):>9.1f}{pct(work, .9):>7.1f}{pct(work, .99):>7.1f}"
          f"{st.median(total):>10.1f}{pct(total, .9):>7.1f}{pct(total, .99):>7.1f}{max(total):>7.1f}"
          f"{med(0):>7.1f}{med(1):>7.1f}{med(2):>6.1f}{med(3):>6.1f}"
          f"{100 * sum(w > FRAME_BUDGET_MS for w in work) / len(work):>7.1f}%"
          f"{100 * over / frames if frames else 0:>7.1f}%"
          f"{st.median(int(w[4]) for w in engine) / 1000 if engine else 0:>7.2f}"
          f"{max(int(w[5]) for w in engine) / 1000 if engine else 0:>6.1f}")
