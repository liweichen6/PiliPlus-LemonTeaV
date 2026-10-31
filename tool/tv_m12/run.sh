#!/usr/bin/env bash
# ==============================================================================
# PiliPlus-LemonTeaV: One M12 Crash-Debug Run on the TV
# ==============================================================================
# Starts a player, records logcat, the kernel log and a sampler on this machine
# (so they survive a kernel panic), and stops everything it started when the
# time is up, on Ctrl-C, or on an error.
#
# Usage:
#   ./tool/tv_m12/run.sh NAME SECS probe KEY=VALUE...
#       the MediaCodec harness (CodecProbe.java; push it first with probe.sh).
#       file=NAME is looked up in the TV's media folder (.mp4 added if missing).
#   ./tool/tv_m12/run.sh NAME SECS shell 'START COMMAND' 'STOP COMMAND'
#       anything else, for example an app started with am start and stopped
#       with am force-stop.
#
# Output goes to ${M12_RUNS}/<date>-NAME/. A one-line summary is printed and
# kept in summary.txt. If the TV stops answering, the run ends as "lost"; after
# the TV is back, collect the evidence with postpanic.sh.
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
m12_require ANDROID_SERIAL M12_RUNS

if [[ $# -lt 3 ]]; then
  sed -n '9,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 2
fi
NAME="$1"; SECS="$2"; KIND="$3"; shift 3

OUT="${M12_RUNS}/$(date +%Y%m%d-%H%M%S)-${NAME}"
mkdir -p "${OUT}"

case "${KIND}" in
  probe)
    PROBE_ARGS=("secs=${SECS}")
    for arg in "$@"; do
      if [[ "${arg}" == file=* && "${arg#file=}" != */* ]]; then
        f="${arg#file=}"; [[ "${f}" == *.* ]] || f="${f}.mp4"
        arg="file=${DEVICE_MEDIA}/${f}"
      fi
      PROBE_ARGS+=("${arg}")
    done
    START="CLASSPATH=${DEVICE_DIR}/probe.dex app_process /system/bin --nice-name=m12probe m12.CodecProbe ${PROBE_ARGS[*]}"
    STOP="pkill -f m12probe"
    ;;
  shell)
    START="$1"; STOP="$2"
    ;;
  *)
    echo "Error: KIND must be probe or shell." >&2
    exit 2
    ;;
esac

UP0="$(m12_uptime)"
if [[ -z "${UP0}" ]]; then
  echo "Error: the TV doesn't answer over adb." >&2
  exit 1
fi
{
  echo "name=${NAME} secs=${SECS} kind=${KIND}"
  echo "start=${START}"
  echo "stop=${STOP}"
  echo "uptime=${UP0}"
  echo "boot_reason=$(adb shell getprop sys.boot.reason | tr -d '\r')"
} > "${OUT}/pre.txt"

# End the screensaver if it runs (see sampler.sh).
adb shell input keyevent KEYCODE_WAKEUP
sleep 2
adb shell mkdir -p "${DEVICE_DIR}"
adb push "${M12_DIR}/sampler.sh" "${DEVICE_DIR}/sampler.sh" >/dev/null

PIDS=()
adb logcat -b kernel -v threadtime -T 1 > "${OUT}/kernel.txt" 2>&1 & PIDS+=($!)
adb logcat -b main,system,crash -v threadtime -T 1 > "${OUT}/logcat.txt" 2>&1 & PIDS+=($!)
adb shell sh "${DEVICE_DIR}/sampler.sh" > "${OUT}/samples.txt" 2>&1 & PIDS+=($!)

RESULT=running
T0=$(date +%s)
finish() {
  set +e  # cleanup must run to the end, whatever fails
  local alive elapsed
  elapsed=$(( $(date +%s) - T0 ))
  alive="$(m12_uptime)"
  if [[ -n "${alive}" ]]; then
    adb shell "${STOP}" >/dev/null 2>&1 || true
    adb shell pkill -f sampler.sh >/dev/null 2>&1 || true
    if [[ "${alive}" -lt "${UP0}" ]]; then RESULT=rebooted; fi
  elif [[ "${RESULT}" == running || "${RESULT}" == done ]]; then
    RESULT=lost
  fi
  if [[ "${RESULT}" == running ]]; then RESULT=stopped; fi
  sleep 1
  kill "${PIDS[@]}" 2>/dev/null || true
  wait 2>/dev/null || true
  local c2 detile last
  c2=$(grep -c 'consecutive failures' "${OUT}/logcat.txt" 2>/dev/null || true)
  detile=$(grep -c 'Detile' "${OUT}/logcat.txt" 2>/dev/null || true)
  last=""
  [[ -f "${OUT}/player.txt" ]] && last="$(grep -E '^(END|STALL|t=)' "${OUT}/player.txt" | tail -n 1 || true)"
  # The probe app prints the same lines to logcat (tag System.out).
  [[ -z "${last}" ]] && last="$(grep -oE 'System.out: (END|STALL|t=).*' "${OUT}/logcat.txt" | tail -n 1 | sed 's/^System.out: //' || true)"
  echo "${NAME}: ${RESULT} after ${elapsed}s, C2BqBuffer failures ${c2:-0}, Detile ${detile:-0}; ${last}" | tee "${OUT}/summary.txt"
  echo "output: ${OUT}"
}
trap finish EXIT
trap 'RESULT=stopped; exit 130' INT TERM

adb shell "${START}" > "${OUT}/player.txt" 2>&1 & PIDS+=($!)
PLAYER=$!

MISSES=0
while (( $(date +%s) - T0 < SECS + 10 )); do
  sleep 4
  if [[ "${KIND}" == probe ]] && ! kill -0 "${PLAYER}" 2>/dev/null; then
    RESULT=done
    break
  fi
  if [[ -z "$(m12_uptime)" ]]; then
    MISSES=$((MISSES + 1))
    if (( MISSES >= 2 )); then RESULT=lost; break; fi
  else
    MISSES=0
  fi
done
if [[ "${RESULT}" == running ]]; then RESULT=done; fi
