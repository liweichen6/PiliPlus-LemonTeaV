#!/usr/bin/env bash
# ==============================================================================
# PiliPlus-LemonTeaV: One Guarded Run of the Dev App on ExoPlayer (M17)
# ==============================================================================
# Records a run with tool/tv_m12/run.sh (logcat, the kernel log and a sampler,
# kept on this machine so they survive a shutdown), guards it, and samples the
# app's threads and the video layer. See docs/tv/PLAYBACK_PARAMETERS.md.
#
#   ./tool/tv_m17/run.sh NAME SECS URL   opens URL (a bilibili:// or https://
#                                        link) in the dev app, force-stops it
#                                        at the end
#   ./tool/tv_m17/run.sh NAME SECS -     attaches: the user drives the app,
#                                        and the run neither starts nor stops it
#
# The guard only ever force-stops the dev app, and only while it's on top:
#   * Detile lines past a start burst, counted per 5 s window (200): frames
#     going through the GPU's detiler, the path that panics the TV at 4K;
#   * a decoder start with hwRender:0 or gdec:1: video off the video plane;
#   * a video layer above 1080p composed by the GPU (CLIENT), every 20 s.
# Every 20 s from 30 s in (SAMPLE=0 turns it off): the app's busiest threads,
# the layer table and each SurfaceView layer's frame times. At the end, the
# media service is asked for a dump: a timeout there is M16's hang.
#
# Needs ANDROID_SERIAL and M12_RUNS. Read the result with report.sh.
# ==============================================================================
set -uo pipefail
: "${ANDROID_SERIAL:?set ANDROID_SERIAL}" "${M12_RUNS:?set M12_RUNS}"

if [[ $# -lt 3 ]]; then
  sed -n '9,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
fi
NAME="$1"; SECS="$2"; URL="$3"
PKG="${PKG:-com.lemontea.piliplus.tv.dev}"
ACT=com.example.piliplus.MainActivity
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMPLE="${SAMPLE:-1}"

GUARD_LOG="${M12_RUNS}/m17-guard-${NAME}.txt"
OUT="${M12_RUNS}/${NAME}-samples"
mkdir -p "${OUT}"
: > "${GUARD_LOG}"

on_top() {
  adb shell dumpsys activity activities 2>/dev/null | grep -m 1 topResumedActivity | grep -q "${PKG}"
}
stop_app() {
  if on_top; then
    adb shell am force-stop "${PKG}"
    echo "GUARD: $1, force-stopped ${PKG}" | tee -a "${GUARD_LOG}"
  else
    echo "GUARD: $1 while another app was on top, ignored" | tee -a "${GUARD_LOG}"
  fi
}

PIDS=()
(
  win=0; detile=0
  adb logcat -b main -v threadtime -T 1 2>/dev/null \
    | grep --line-buffered -E 'hwRender:[0-9]|Detile' \
    | while IFS= read -r line; do
        if [[ "${line}" == *Detile* ]]; then
          # A decoder start on the plane logs one burst of 40-52 lines; the
          # GPU path logs about 1,000 a second. Per window, so several starts
          # in one session (a quality switch, next video) don't add up.
          now=$(date +%s)
          if (( now - win >= 5 )); then win=${now}; detile=0; fi
          detile=$((detile + 1))
          (( detile == 200 )) && stop_app "Detile past the start burst"
          continue
        fi
        echo "${line}" >> "${GUARD_LOG}"
        # The launcher's preview video logs these too; stop_app checks the top.
        if [[ "${line}" == *hwRender:0* || "${line}" == *"gdec:1"* ]]; then
          stop_app "decoder off the plane (${line##*bufferQueue})"
        fi
      done
) 2>/dev/null & PIDS+=($!)
(
  # A video layer above 1080p (either way up, so a vertical 1440x2560 live
  # room counts) must stay DEVICE: CLIENT means the GPU composes it.
  while sleep 20; do
    rows="$(adb shell dumpsys SurfaceFlinger 2>/dev/null \
      | grep -E '^ SurfaceView.*BLAST' -A1 \
      | grep -E ' ([0-9]+)\.0 +([0-9]+)\.0 \|' \
      | awk '{ for (i = 1; i < NF; i++) if ($i ~ /^[0-9]+\.0$/ && $(i+1) ~ /^[0-9]+\.0$/) { w = $i; h = $(i+1) }
               if ((w > 1920 && h > 1080) || (w > 1080 && h > 1920)) print }')"
    [[ -z "${rows}" ]] && continue
    echo "${rows}" | sed -E "s/ +/ /g; s/^/$(date +%H:%M:%S) /" >> "${GUARD_LOG}"
    [[ "${rows}" == *CLIENT* ]] && stop_app "a >1080p video layer on CLIENT"
  done
) 2>/dev/null & PIDS+=($!)
if [[ "${SAMPLE}" == 1 ]]; then
  (
    sleep 30
    n=0
    while :; do
      n=$((n + 1))
      pid="$(adb shell pidof "${PKG}" 2>/dev/null | tr -d '\r')"
      if [[ -n "${pid}" ]]; then
        { echo "== $(date +%T)"; adb shell top -H -b -n 1 -p "${pid}" 2>/dev/null | head -24; } >> "${OUT}/top.txt"
      fi
      # The layer table, then each video layer's composition and dataspace:
      # HDR10 is BT2020_ITU_PQ, HLG BT2020_ITU_HLG, Dolby Vision the vendor's
      # 0x10860000 on this TV.
      { echo "== $(date +%T)"
        adb shell dumpsys SurfaceFlinger 2>/dev/null > "${OUT}/sf.tmp"
        grep -E '^ (SurfaceView|com\.lemontea)' -A1 "${OUT}/sf.tmp"
        awk '/^\* Layer / { on = /SurfaceView.*\(BLAST\)/; if (on) { id = $0; sub(/.*#/, "#", id); sub(/\).*/, "", id); printf "\n%s", id } }
             on && match($0, /composition type=[A-Z_]+/) { printf " %s", substr($0, RSTART, RLENGTH) }
             on && match($0, /dataspace=[^ ]+ \([0-9]+\)/) { printf " %s", substr($0, RSTART, RLENGTH) }
             END { print "" }' "${OUT}/sf.tmp"
      } >> "${OUT}/layers.txt"
      adb shell dumpsys SurfaceFlinger --list 2>/dev/null | tr -d '\r' | grep -E '^SurfaceView\[.*\(BLAST\)#[0-9]+$' \
        | while IFS= read -r layer; do
            adb shell "dumpsys SurfaceFlinger --latency '${layer}'" > "${OUT}/latency-${layer##*#}-${n}.txt" 2>/dev/null </dev/null
          done
      sleep 18
    done
  ) 2>/dev/null & PIDS+=($!)
fi
cleanup() {
  exec 2>/dev/null  # no job reports for the loops killed below
  rm -f "${OUT}/sf.tmp"
  local p
  for p in "${PIDS[@]}"; do pkill -P "${p}" 2>/dev/null; kill "${p}" 2>/dev/null; done
  wait 2>/dev/null
  # M16's hang: media.player stops answering, and every new process with it.
  "${HERE}/health.sh" quick | tee -a "${GUARD_LOG}"
}
trap cleanup EXIT

if [[ "${URL}" == - ]]; then
  START=true; STOP=true
else
  START="am start -a android.intent.action.VIEW -d '${URL}' -n ${PKG}/${ACT}"
  STOP="am force-stop ${PKG}"
fi
"${HERE}/../tv_m12/run.sh" "${NAME}" "${SECS}" shell "${START}" "${STOP}"
