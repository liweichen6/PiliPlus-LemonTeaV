#!/usr/bin/env bash
# ==============================================================================
# PiliPlus-LemonTeaV: Build and Install the M12 Probe App
# ==============================================================================
# Builds probe_app/ (ProbeActivity plus CodecProbe.java) into a debug-signed APK
# without Gradle (javac, d8, aapt2, zipalign, apksigner), installs it on the TV
# as com.lemontea.m12probe with its video-read permission granted, and copies
# the named videos from the harness's work folder on the TV (pushed by probe.sh)
# to shared storage (Movies/m12), where other players can open them too. (The
# app can't read files adb puts in its own data folder: they belong to shell.)
#
# Usage:
#   ./tool/tv_m12/probe_app.sh [ID...]     build, install, copy videos
#   ./tool/tv_m12/probe_app.sh --uninstall remove the app and Movies/m12
#
# Start a run with run.sh, for example:
#   ./tool/tv_m12/run.sh NAME 600 shell \
#     "am start -n com.lemontea.m12probe/m12.ProbeActivity --es view texture \
#      --es file /sdcard/Movies/m12/V-AVC60.mp4 --es secs 600" \
#     "am force-stop com.lemontea.m12probe"
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
m12_require ANDROID_SERIAL

PACKAGE=com.lemontea.m12probe
SHARED_MEDIA=/sdcard/Movies/m12

if [[ "${1:-}" == --uninstall ]]; then
  adb uninstall "${PACKAGE}" || true
  adb shell rm -rf "${SHARED_MEDIA}"
  echo "removed ${SHARED_MEDIA} from the TV"
  exit 0
fi

m12_sdk
BUILD_TOOLS="$(dirname "${D8}")"
KEYSTORE="${HOME}/.android/debug.keystore"
if [[ ! -f "${KEYSTORE}" ]]; then
  echo "Error: no debug keystore at ~/.android/debug.keystore." >&2
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
javac --release 17 -cp "${ANDROID_JAR}" -d "${WORK}/classes" \
  "${M12_DIR}/CodecProbe.java" "${M12_DIR}/probe_app/ProbeActivity.java"
"${D8}" --min-api 30 --lib "${ANDROID_JAR}" --output "${WORK}" $(find "${WORK}/classes" -name '*.class')
"${BUILD_TOOLS}/aapt2" link -o "${WORK}/base.apk" -I "${ANDROID_JAR}" \
  --manifest "${M12_DIR}/probe_app/AndroidManifest.xml" --min-sdk-version 30 --target-sdk-version 34
(cd "${WORK}" && zip -q base.apk classes.dex)
"${BUILD_TOOLS}/zipalign" -f 4 "${WORK}/base.apk" "${WORK}/aligned.apk"
"${BUILD_TOOLS}/apksigner" sign --ks "${KEYSTORE}" --ks-pass pass:android --key-pass pass:android \
  --out "${WORK}/m12probe.apk" "${WORK}/aligned.apk"
adb install -r -g "${WORK}/m12probe.apk" >/dev/null
echo "installed ${PACKAGE}"

adb shell mkdir -p "${SHARED_MEDIA}"
for id in "$@"; do
  adb shell cp "${DEVICE_MEDIA}/${id}.mp4" "${SHARED_MEDIA}/${id}.mp4"
  echo "copied ${id}"
done
