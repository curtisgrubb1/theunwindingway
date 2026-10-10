#!/usr/bin/env bash
# process-audio.sh — prepare Workbook voice recordings for The Way.
#
# Usage:   scripts/process-audio.sh [folder]        (default: ACIM-Voice-Recordings)
#          FORCE=1 scripts/process-audio.sh          (re-process everything)
#          FORCE=1 scripts/process-audio.sh ACIM-Voice-Recordings 'Lesson-01*'
#                                                    (only files matching a pattern)
#
# Reads every .m4a / .wav / .aif recording in the folder and writes a finished
# copy, same name, to <folder>/processed/. Originals are never touched.
# Files already processed (and unchanged since) are skipped.
#
# Each file gets identical treatment so all 365 lessons sound like one session:
#   1. trim dead air and record/stop taps: keep 0.5 s before the first word,
#      1.5 s after the last
#   2. high-pass at 80 Hz (removes hull/engine rumble)
#   3. loudness normalisation to -16 LUFS, true peak -1.5 dBTP (two-pass
#      loudnorm, then a measured gain correction + limiter for consistency)
#   4. short fades to avoid clicks
#   5. export AAC 96 kbps mono 48 kHz, web-streamable (+faststart)
#
# A line per file is appended to <folder>/processed/log.csv, and anything that
# needs a human ear is printed as a CHECK line.
#
# Requires ffmpeg (on a Mac: brew install ffmpeg).

set -euo pipefail

DIR="${1:-ACIM-Voice-Recordings}"
OUT="$DIR/processed"
FORCE="${FORCE:-0}"
MATCH="${2:-*}"

TARGET_I=-16      # LUFS — standard for phone listening
TARGET_TP=-1.5    # dBTP — headroom for AAC encoding
TARGET_LRA=11
HEAD=0.5          # seconds kept before first word
TAIL=1.5          # seconds kept after last word
TAP=0.25          # shorter blips inside the edge silence = clicks
EDGE=0.8          # sounds shorter than this at either end = button taps, trimmed
SIL_DB=-50dB      # below this counts as silence
SIL_MIN=0.4       # shortest gap counted as a pause (s)
LONG_PAUSE=6      # flag pauses longer than this (s)
QUIET_LUFS=-28    # flag recordings quieter than this
BITRATE=96k

command -v ffmpeg  >/dev/null || { echo "ffmpeg not found (Mac: brew install ffmpeg)"; exit 1; }
command -v ffprobe >/dev/null || { echo "ffprobe not found (comes with ffmpeg)"; exit 1; }
[ -d "$DIR" ] || { echo "No folder: $DIR"; exit 1; }
mkdir -p "$OUT"
LOG="$OUT/log.csv"
[ -f "$LOG" ] || echo "file,processed_at,orig_seconds,final_seconds,orig_lufs,orig_peak_dbtp,longest_pause_s,checks" > "$LOG"

mmss() { awk -v t="$1" 'BEGIN{printf "%d:%02d", int(t/60), int(t)%60}'; }
json() { echo "$2" | grep "\"$1\"" | sed -E 's/.*: *"?([^",]*)"?,?.*/\1/'; }

done_count=0; skip_count=0
for f in "$DIR"/$MATCH.m4a "$DIR"/$MATCH.wav "$DIR"/$MATCH.aif "$DIR"/$MATCH.aiff; do
  [ -e "$f" ] || continue
  name="$(basename "${f%.*}")"
  case "$name" in *-processed) continue ;; esac
  out="$OUT/$name.m4a"
  if [ "$FORCE" != "1" ] && [ -e "$out" ] && [ "$out" -nt "$f" ]; then
    skip_count=$((skip_count+1)); continue
  fi

  dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")

  # --- find speech boundaries and pauses ---
  read -r start end maxpause maxat endblip <<<"$(
    ffmpeg -hide_banner -nostats -i "$f" -af "silencedetect=noise=$SIL_DB:d=$SIL_MIN" -f null - 2>&1 \
    | sed -nE 's/.*silence_start: (-?[0-9.]+).*/S \1/p; s/.*silence_end: (-?[0-9.]+) \| silence_duration: ([0-9.]+).*/E \1 \2/p' \
    | awk -v dur="$dur" -v head="$HEAD" -v tail="$TAIL" -v edge="$EDGE" -v tap="$TAP" '
        # Collect silences. A sound shorter than EDGE seconds before the first
        # silence or after the last one is a record/stop tap, not speech; it is
        # cut, along with any short clicks (< TAP s) inside the edge silences.
        $1=="S" { s=$2; open=1 }
        $1=="E" { n++; S[n]=s; E[n]=$2; D[n]=$3; open=0 }
        END {
          if (open) { n++; S[n]=s; E[n]=dur; D[n]=dur-s }
          st=0; en=dur; lead=0; trail=0; kl=1; kt=n
          # clicks shorter than tap seconds between silences count as silence
          while (kl<n && S[kl+1]-E[kl]<tap) kl++
          while (kt>1 && S[kt]-E[kt-1]<tap) kt--
          if (n>=1 && S[1]<edge) {
            lead=kl; st=E[kl]-head
            lo=(kl>1 || S[1]>0.05) ? S[kl]+0.02 : 0
            if (st<lo) st=lo }
          if (n>=1 && dur-E[n]<edge && kt>lead) {
            trail=n-kt+1; en=S[kt]+tail
            hi=(E[kt]<dur-0.1) ? E[kt]-0.02 : dur; if (en>hi) en=hi }
          for (i=1+lead; i<=n-trail; i++) if (D[i]>mp) { mp=D[i]; ma=S[i] }
          # a lone short sound (TAP..0.7 s) just before the trailing silence may
          # be a final syllable or a stop tap: kept, but flagged for a listen
          blip=0
          if (trail && kt>1) { g=S[kt]-E[kt-1]; if (g>=tap && g<0.7 && D[kt-1]>=0.5) blip=g }
          printf "%.3f %.3f %.2f %.2f %.2f\n", st, en, mp+0, ma+0, blip }'
  )"
  len=$(awk -v a="$start" -v b="$end" 'BEGIN{printf "%.3f", b-a}')
  fo=$(awk -v l="$len" 'BEGIN{x=l-0.4; if (x<0) x=0; printf "%.3f", x}')
  PRE="atrim=start=$start:end=$end,asetpts=PTS-STARTPTS,highpass=f=80"

  # --- pass 1: measure ---
  m=$(ffmpeg -hide_banner -nostats -i "$f" \
      -af "$PRE,loudnorm=I=$TARGET_I:TP=$TARGET_TP:LRA=$TARGET_LRA:print_format=json" -f null - 2>&1 \
      | sed -n '/^{/,/^}/p')
  ii=$(json input_i "$m"); itp=$(json input_tp "$m"); ilra=$(json input_lra "$m")
  ith=$(json input_thresh "$m"); off=$(json target_offset "$m")

  # --- pass 2: apply (to a lossless temp file) ---
  wav="${TMPDIR:-/tmp}/process-audio-$$-$name.wav"; tmp="$OUT/.tmp-$name.m4a"
  r=$(ffmpeg -hide_banner -nostats -y -i "$f" \
      -af "$PRE,loudnorm=I=$TARGET_I:TP=$TARGET_TP:LRA=$TARGET_LRA:measured_I=$ii:measured_TP=$itp:measured_LRA=$ilra:measured_thresh=$ith:offset=$off:linear=true:print_format=summary,afade=t=in:d=0.15,afade=t=out:st=$fo:d=0.4,aresample=48000" \
      -ac 1 -c:a pcm_s24le "$wav" 2>&1)

  # --- pass 3: loudnorm undershoots when it must limit peaks; measure and
  #     correct with a fixed gain plus a true-peak limiter, so every file
  #     lands on the same loudness ---
  got=$(ffmpeg -hide_banner -nostats -i "$wav" -af ebur128 -f null - 2>&1 \
        | grep -A3 Summary | grep -m1 ' I:' | awk '{print $2}')
  gain=$(awk -v t="$TARGET_I" -v g="$got" 'BEGIN{printf "%.2f", t-g}')
  lim=$(awk -v tp="$TARGET_TP" 'BEGIN{printf "%.4f", 10^(tp/20)}')
  ffmpeg -hide_banner -loglevel error -y -i "$wav" \
      -af "volume=${gain}dB,alimiter=limit=$lim:attack=1:release=50:level=disabled" \
      -ac 1 -c:a aac -b:a "$BITRATE" -movflags +faststart "$tmp"
  rm -f "$wav"
  mv -f "$tmp" "$out"

  # --- checks for a human ear ---
  checks=""
  awk -v x="$ii" -v q="$QUIET_LUFS" 'BEGIN{exit !(x<q)}' && \
    checks="$checks; quiet original ($ii LUFS) - move closer or raise gain"
  echo "$r" | grep -qi "Normalization Type: *Dynamic" && \
    checks="$checks; peaks had to be limited to reach target loudness"
  awk -v x="$itp" 'BEGIN{exit !(x>-1)}' && \
    checks="$checks; original peaks at $itp dBTP - listen for distortion"
  awk -v x="$maxpause" -v l="$LONG_PAUSE" 'BEGIN{exit !(x>l)}' && \
    checks="$checks; ${maxpause}s pause at $(mmss "$maxat") - retake gap or intentional?"
  awk -v x="$endblip" 'BEGIN{exit !(x>0)}' && \
    checks="$checks; lone ${endblip}s sound in the last second - final word or stop tap? listen"
  checks="${checks#; }"

  echo "$name,$(date '+%Y-%m-%d %H:%M'),$(printf %.1f "$dur"),$(printf %.1f "$len"),$ii,$itp,$maxpause,\"$checks\"" >> "$LOG"
  echo "✓ $name  $(mmss "$dur") → $(mmss "$len")  (was $ii LUFS)"
  [ -n "$checks" ] && echo "$checks" | tr ';' '\n' | sed 's/^ */    CHECK: /'
  done_count=$((done_count+1))
done

echo "Processed $done_count, skipped $skip_count already done. Output: $OUT/"
