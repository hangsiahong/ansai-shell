#!/bin/sh
# Text in an image, English and Khmer: ocr.sh IMAGE prints it. Used by services/Ocr.qml.
# Khmer data isn't in most installs, so it is fetched once into ~/.local/share/ansai-shell/tessdata
# (next to links to the system languages); without it, English only.
img=$1
[ -r "$img" ] || { echo "No image to read" >&2; exit 2; }
command -v tesseract >/dev/null || { echo "Install tesseract and tesseract-data-eng to copy text from images" >&2; exit 3; }
d=${XDG_DATA_HOME:-$HOME/.local/share}/ansai-shell/tessdata
sys=$(tesseract --list-langs 2>/dev/null | sed -n 's/.*"\(.*\)".*/\1/p')
[ -d "$sys" ] || sys=/usr/share/tessdata
if [ ! -s "$sys/khm.traineddata" ] && [ ! -s "$d/khm.traineddata" ]; then
    mkdir -p "$d" && curl -fsSL -m 120 -o "$d/khm.part" https://github.com/tesseract-ocr/tessdata_best/raw/main/khm.traineddata \
        && mv "$d/khm.part" "$d/khm.traineddata" || rm -f "$d/khm.part"
fi
langs=eng
if [ -s "$sys/khm.traineddata" ]; then langs=khm+eng
elif [ -s "$d/khm.traineddata" ]; then
    for f in "$sys"/*.traineddata; do [ -e "$d/${f##*/}" ] || ln -s "$f" "$d/"; done
    export TESSDATA_PREFIX=$d
    langs=khm+eng
fi
# Screen text is small for tesseract; doubling small grabs reads them much better.
tmp=
h=$(magick identify -format %h "$img" 2>/dev/null)
if [ -n "$h" ] && [ "$h" -lt 900 ]; then
    tmp=$(mktemp --suffix=.png) && magick "$img" -resize 200% "$tmp" 2>/dev/null && img=$tmp
fi
tesseract "$img" - -l "$langs" 2>/dev/null | tr -d '\f' | sed -e 's/[[:space:]]*$//' | cat -s
r=$?
[ -n "$tmp" ] && rm -f "$tmp"
exit $r
