#!/usr/bin/env bash
# ==============================================================================
# PiliPlus-LemonTeaV: Collect the Evidence After a TV Reboot (M12)
# ==============================================================================
# Run once the TV answers over adb again (wireless debugging gets a new port
# after a reboot: update ANDROID_SERIAL). Saves the boot reason, the kernel log
# of the previous boot (dropbox SYSTEM_LAST_KMSG), SYSTEM_BOOT and the app exit
# reasons, and prints each panic's signature on one line.
#
# Usage: ./tool/tv_m12/postpanic.sh NAME
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
m12_require ANDROID_SERIAL M12_RUNS

NAME="${1:-panic}"
OUT="${M12_RUNS}/$(date +%Y%m%d-%H%M%S)-postpanic-${NAME}"
mkdir -p "${OUT}"

{
  echo "uptime=$(m12_uptime)"
  echo "boot_reason=$(adb shell getprop sys.boot.reason | tr -d '\r')"
} | tee "${OUT}/boot.txt"
adb shell dumpsys dropbox --print SYSTEM_LAST_KMSG > "${OUT}/last_kmsg.txt"
adb shell dumpsys dropbox --print SYSTEM_BOOT > "${OUT}/system_boot.txt"
adb shell dumpsys activity exit-info > "${OUT}/exit_info.txt" 2>&1 || true

echo "panics in the saved kernel logs:"
grep -E '\[MIUP\]\[HIT\]|Kernel panic|vdec_fb ' "${OUT}/last_kmsg.txt" \
  | awk '/MIUP\]\[HIT\]/ { hit = $0 } /Kernel panic/ { print hit; n = 0 } /vdec_fb / { n++ } END { }' \
  | sed 's/^/  /'
grep -c 'vdec_fb ' "${OUT}/last_kmsg.txt" | sed 's/^/  vdec_fb lines (all panics): /'
echo "output: ${OUT}"
