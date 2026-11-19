#!/usr/bin/env bash
# ==============================================================================
# PiliPlus-LemonTeaV: What Each M17 Run Did (M17)
# ==============================================================================
#   ./tool/tv_m17/report.sh NAME...
#
# For each run of run.sh: its summary and the guard's stops; the bridge's
# lines (what played, on which decoder and in which HDR mode, the first frame,
# refusals, load errors and failures); each decoder start's hwRender and gdec;
# the video layer's cadence from 30 s in (FIRST=N from the Nth sample, 20 s
# apart, to skip a quality switch); the last layer table and the busiest
# threads. Needs M12_RUNS.
# ==============================================================================
set -uo pipefail
: "${M12_RUNS:?set M12_RUNS}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for name in "$@"; do
  r="$(ls -td "${M12_RUNS}"/*-"${name}" 2>/dev/null | grep -v -- '-samples$' | head -n 1)"
  s="${M12_RUNS}/${name}-samples"
  echo "=== ${name}: $(cat "${r}/summary.txt" 2>/dev/null || echo 'no summary')"
  grep -a -E '^GUARD|^media.player' "${M12_RUNS}/m17-guard-${name}.txt" 2>/dev/null
  grep -a -E ' TvExoPlayer: ' "${r}/logcat.txt" 2>/dev/null \
    | grep -a -E 'open gen|videoFormat|firstFrame|refused|loadError|error kind|declared|released' \
    | sed -E 's/^([0-9-]+ [0-9:.]+) .* TvExoPlayer: /\1 /' | cut -c1-${COLS:-200} | tail -n "${LINES_MAX:-40}"
  echo "decoder starts: $(grep -a -oE 'hwRender:[0-9], *secure:[0-9], *gdec:[0-9]' "${r}/logcat.txt" 2>/dev/null | sort | uniq -c | tr '\n' ';')"
  echo "fatal: $(grep -a -cE 'FATAL|ANR in com\.lemontea' "${r}/logcat.txt" 2>/dev/null)"
  for id in $(ls "${s}"/latency-*-*.txt 2>/dev/null | sed -E 's/.*latency-([0-9]+)-[0-9]+\.txt/\1/' | sort -u); do
    python3 -I "${HERE}/layer.py" "${s}" "${id}" "${FIRST:-1}"
  done
  if [[ -f "${s}/layers.txt" ]]; then
    echo "last layers:"
    awk '/^==/{blk=""} {blk=blk $0 "\n"} END{printf "%s", blk}' "${s}/layers.txt" | sed -E 's/ +/ /g' | cut -c1-150
  fi
  if [[ -f "${s}/top.txt" ]]; then
    echo "busiest threads (last sample):"
    awk '/^==/{blk=""} {blk=blk $0 "\n"} END{printf "%s", blk}' "${s}/top.txt" | sed -n '/ TID /,$p' | head -n 9
  fi
done
