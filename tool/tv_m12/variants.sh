#!/usr/bin/env bash
# ==============================================================================
# PiliPlus-LemonTeaV: Make the M12 Test Variants
# ==============================================================================
# Builds the 3-minute variants listed in docs/tv/M12_CRASH_DEBUG.md from the
# originals in ${M12_MEDIA}/originals (M2: AV1 4K59.94, M4: AVC 4K59.94) into
# ${M12_MEDIA}/variants. Existing variants are skipped. Uses ffmpeg with the
# VideoToolbox encoders where possible, libx264 where the encoder settings
# matter (reference frames).
#
# Usage: ./tool/tv_m12/variants.sh [ID...]    (default: all)
# ==============================================================================

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
m12_require M12_MEDIA

SRC="${M12_MEDIA}/originals"
DST="${M12_MEDIA}/variants"
mkdir -p "${DST}"
AVC="${SRC}/M4_avc_4k5994.mp4"
AV1="${SRC}/M2_av1_4k5994.mp4"
CUT=(-ss 120 -t 180)
VT_AVC=(-c:v h264_videotoolbox -profile:v high -allow_sw 0)
VT_HEVC=(-c:v hevc_videotoolbox -profile:v main -tag:v hvc1 -allow_sw 0)

make() {
  local id="$1"; shift
  local out="${DST}/${id}.mp4"
  if [[ ${#WANT[@]} -gt 0 && ! " ${WANT[*]} " == *" ${id} "* ]]; then return; fi
  if [[ -s "${out}" ]]; then echo "skip ${id}"; return; fi
  echo "make ${id}"
  ffmpeg -hide_banner -loglevel error -y "$@" -c:a copy -movflags +faststart "${out}.tmp.mp4"
  mv "${out}.tmp.mp4" "${out}"
}

WANT=("$@")

# bilibili's own AVC encode, cut to 3 minutes without re-encoding.
make V-AVC60 "${CUT[@]}" -i "${AVC}" -c:v copy
make V-AV1-60 "${CUT[@]}" -i "${AV1}" -c:v copy

# Codec and frame rate.
make V-HEVC60-8 "${CUT[@]}" -i "${AVC}" "${VT_HEVC[@]}" -b:v 8M
make V-AVC30 "${CUT[@]}" -i "${AVC}" -vf fps=30000/1001 "${VT_AVC[@]}" -b:v 10M
make V-AVC50 "${CUT[@]}" -i "${AVC}" -vf fps=50 "${VT_AVC[@]}" -b:v 16M

# Resolution ladder at 59.94 fps.
make V-AVC-1800 "${CUT[@]}" -i "${AVC}" -vf scale=3200:1800 "${VT_AVC[@]}" -b:v 14M
make V-AVC-1440 "${CUT[@]}" -i "${AVC}" -vf scale=2560:1440 "${VT_AVC[@]}" -b:v 10M
make V-AVC-1080 "${CUT[@]}" -i "${AVC}" -vf scale=1920:1080 "${VT_AVC[@]}" -b:v 6M

# Height alignment.
make V-AVC-2176 "${CUT[@]}" -i "${AVC}" -vf pad=3840:2176:0:8 "${VT_AVC[@]}" -b:v 20M
make V-AVC-2048 "${CUT[@]}" -i "${AVC}" -vf scale=3840:2048 "${VT_AVC[@]}" -b:v 20M
make V-AVC-4096 "${CUT[@]}" -i "${AVC}" -vf pad=4096:2160:128:0 "${VT_AVC[@]}" -b:v 20M

# Bitrate.
make V-AVC60-8M "${CUT[@]}" -i "${AVC}" "${VT_AVC[@]}" -b:v 8M
make V-AVC60-40M "${CUT[@]}" -i "${AVC}" "${VT_AVC[@]}" -b:v 40M

# One reference frame, no B-frames (fewer decoder buffers held as references).
make V-AVC60-ref1 "${CUT[@]}" -i "${AVC}" -c:v libx264 -preset veryfast -profile:v high \
  -x264-params ref=1:bframes=0 -b:v 20M -maxrate 30M -bufsize 40M

ls -la "${DST}"
