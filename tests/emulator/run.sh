#!/bin/sh
# Runs KOReader under Xvfb with the plugin mounted, opens a book with the overlay on, saves screenshots into /out.
# Env: WIDTH HEIGHT DPI (default Paperwhite 11th gen), FONT_SIZE, BOOK (path in the container), WAIT seconds, PERCENT, PAGES (pages to turn before the screenshot), OVERLAY (true or false),
# HOLD_X HOLD_Y (long press point), DRAG_X (drag to select several words, opens the highlight dialog), CLICK_X CLICK_Y (point to tap afterwards).
set -e
WIDTH=${WIDTH:-1236}; HEIGHT=${HEIGHT:-1648}; DPI=${DPI:-300}
DATA=/root/.config/koreader/ipaoverlay
mkdir -p "$DATA"
[ -f "$DATA/cmudict.dict" ] || curl -fsSL -o "$DATA/cmudict.dict" https://raw.githubusercontent.com/cmusphinx/cmudict/74790861f652b15e4ac49015a90074ad62a27690/cmudict.dict
[ -f "$DATA/en_UK.txt" ] || curl -fsSL -o "$DATA/en_UK.txt" https://raw.githubusercontent.com/open-dict-data/ipa-dict/972cd67dd5f96bc5660e28070cde26e3928abcd7/data/en_UK.txt
SIDECAR="${BOOK%.*}.sdr"
mkdir -p "$SIDECAR"
cat >"$SIDECAR/metadata.epub.lua" <<LUA
return { ["ipa_overlay"] = ${OVERLAY:-true}, ["last_percent"] = ${PERCENT:-0.08}, ["doc_props"] = {} }
LUA
mkdir -p /root/.config/koreader/settings
cat >/root/.config/koreader/settings/ipa_overlay.lua <<LUA
return { ["language"] = "${VARIANT:-en_us}" }
LUA
Xvfb :99 -screen 0 ${WIDTH}x${HEIGHT}x24 >/dev/null 2>&1 &
export DISPLAY=:99 EMULATE_READER_W=$WIDTH EMULATE_READER_H=$HEIGHT EMULATE_READER_DPI=$DPI SDL_VIDEODRIVER=x11
sleep 2
cd /opt/lib/koreader
./koreader.sh "$BOOK" >/out/koreader.log 2>&1 &
sleep "${WAIT:-30}"
xdotool key Escape
sleep 3
import -window root /out/page1.png
for _ in $(seq 1 "${PAGES:-1}"); do
    xdotool key Right
    sleep 3
done
sleep 3
import -window root /out/page2.png
if [ -n "$HOLD_X" ]; then
    # long press selects the word under the point and opens the highlight dialog
    xdotool mousemove "$HOLD_X" "$HOLD_Y" mousedown 1
    sleep 2
    [ -n "$DRAG_X" ] && xdotool mousemove "$DRAG_X" "$HOLD_Y"
    sleep 1
    xdotool mouseup 1
    sleep 3
    import -window root /out/selection.png
    if [ -n "$CLICK_X" ]; then
        xdotool mousemove "$CLICK_X" "$CLICK_Y" click 1
        sleep 3
        import -window root /out/popup.png
    fi
fi
grep -i "ipa\|error\|scanned" /out/koreader.log | tail -15
