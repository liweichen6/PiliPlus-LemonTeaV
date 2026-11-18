#!/usr/bin/env bash
# ==============================================================================
# PiliPlus-LemonTeaV: Is the TV's Media Service Healthy? (M17 Soak)
# ==============================================================================
# M16 once left the media service stuck: `dumpsys media.player` timed out, and
# every new process hung on the codec list until the TV was restarted.
#
#   ./tool/tv_m17/health.sh quick   one line: media.player's answer time
#   ./tool/tv_m17/health.sh         for the soak: that, the uptime and boot
#                                   reason, and the dev app's last exits and
#                                   why (crash, ANR, low memory, force stop)
#
# Reads only. Needs ANDROID_SERIAL.
# ==============================================================================
set -uo pipefail
: "${ANDROID_SERIAL:?set ANDROID_SERIAL}"
PKG="${PKG:-com.lemontea.piliplus.tv.dev}"

t0=$(perl -MTime::HiRes=time -e 'print time')
out="$(timeout 15 adb shell 'dumpsys -t 6 media.player 2>&1 | grep -c TIMEOUT' 2>/dev/null | tr -d '\r ')"
t1=$(perl -MTime::HiRes=time -e 'print time')
secs="$(perl -e "printf '%.2f', ${t1} - ${t0}")"
if [[ "${out}" == 0 ]]; then
  echo "media.player: ok, ${secs} s"
elif [[ -z "${out}" ]]; then
  echo "media.player: no answer over adb after ${secs} s (asleep, shut down, or adb dropped)"
else
  echo "media.player: HANG (timed out, ${secs} s); the TV needs a restart"
fi
[[ "${1:-}" == quick ]] && exit 0

up="$(adb shell 'read up rest < /proc/uptime; echo ${up%.*}' 2>/dev/null | tr -d '\r')"
[[ -n "${up}" ]] && echo "uptime: $((up / 86400))d $((up % 86400 / 3600))h $((up % 3600 / 60))m, boot reason $(adb shell getprop sys.boot.reason | tr -d '\r')"
echo "dev app: pid $(adb shell pidof "${PKG}" 2>/dev/null | tr -d '\r' || true), $(adb shell dumpsys package "${PKG}" 2>/dev/null | grep -m 1 -oE 'versionName=[^ ]+' | tr -d '\r')"
# This TV keeps no dropbox entries, so read the app's exit history instead:
# CRASH, CRASH_NATIVE, ANR and LOW_MEMORY are what the soak looks for;
# SIGNALED (status 9) with importance 400 is the system reclaiming a cached app.
adb shell dumpsys activity exit-info "${PKG}" 2>/dev/null | tr -d '\r' \
  | awk '/timestamp=/ { t = $1 " " $2; sub(/timestamp=/, "", t) }
         / reason=/ { r = $0; sub(/.* reason=/, "", r); sub(/ subreason=[0-9]+/, "", r); sub(/ status=.*/, "", r) }
         /importance=/ { i = $1; sub(/importance=/, "", i); print "exit: " t " " r " importance=" i }' \
  | head -n "${EXITS:-10}"
