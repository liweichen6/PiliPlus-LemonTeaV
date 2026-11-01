#!/usr/bin/env bash
# ==============================================================================
# PiliPlus-LemonTeaV: One M13.0 D-Pad Run on the TV
# ==============================================================================
# Replays D-pad keys on whatever is on screen, recorded by tool/tv_m12/run.sh.
# Get to the screen by hand and check it first. See docs/tv/M13_BASELINE.md.
#
#   ./tool/tv_m13/run.sh NAME SECS KEY...
#
# KEY is up, down, left or right, and the list repeats until SECS is used up.
# Back and Select are refused: on a player they leave it or pause it. GAP is
# the pause between keys, 0.5 s by default.
#
# It only stops its own key loop, never the app. Needs ANDROID_SERIAL and
# M12_RUNS. Read the results with tool/tv_m13/steps.py.
# ==============================================================================
set -uo pipefail
: "${ANDROID_SERIAL:?set ANDROID_SERIAL}" "${M12_RUNS:?set M12_RUNS}"

if [[ $# -lt 3 ]]; then
  sed -n '8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
fi
NAME="$1"; SECS="$2"; shift 2
GAP="${GAP:-0.5}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CODES=""
for key in "$@"; do
  case "${key}" in
    up) CODES+=" 19" ;;
    down) CODES+=" 20" ;;
    left) CODES+=" 21" ;;
    right) CODES+=" 22" ;;
    *)
      echo "Error: ${key} isn't up, down, left or right." >&2
      exit 2
      ;;
  esac
done

# Runs on the TV, so the time between keys doesn't depend on the network.
LOOP="read up rest < /proc/uptime; end=\$((\${up%.*} + ${SECS})); \
while :; do for k in${CODES}; do \
read up rest < /proc/uptime; [ \${up%.*} -ge \$end ] && exit 0; \
input keyevent \$k; sleep ${GAP}; done; done"

"${HERE}/../tv_m12/run.sh" "${NAME}" "${SECS}" shell "${LOOP}" true
