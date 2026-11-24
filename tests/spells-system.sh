#!/usr/bin/env bash
# Tests for the spells that read or change the system, against the stand-ins.
# Run it from anywhere: tests/spells-system.sh
#
# tests/lib/checks.sh has the helpers: expect, in_dir, with_stand_ins and more.

# Many checks hand a line of shell to `bash -c` in single quotes, so that it
# runs later, inside the check. shellcheck takes that for a mistake.
# shellcheck disable=SC2016

# shellcheck source=tests/lib/checks.sh
source "$(dirname "$0")/lib/checks.sh"

# --- howLongUntilChristmas ---------------------------------------------------
# The spell asks `date` for the year and the day of the year. A pretend `date`
# picks the day, and stand-ins take the notification and the song: notify-send
# and pw-play on Linux, osascript and afplay on macOS.
mkdir pretend-date
cat >pretend-date/date <<'SH'
#!/bin/sh
case $1 in
  +%Y) echo "$PRETEND_YEAR" ;;
  +%j) echo "$PRETEND_DAY" ;;
esac
SH
chmod +x pretend-date/date

# notification_on <year> <day of the year>: what the spell says on that day.
notification_on() {
  PRETEND_YEAR=$1 PRETEND_DAY=$2 PATH=$TMP/pretend-date:$PATH with_stand_ins howLongUntilChristmas
  cat "$STAND_IN_STATE/notification"
}

expect "There are 32 days left" notification_on 2026 327
# 1 February. bash would read the padded "032" as an octal number.
expect "There are 327 days left" notification_on 2026 032
expect "There is 1 day left" notification_on 2026 358
expect "Merry Christmas!" notification_on 2026 359
# After Christmas it counts to the next one. 2028 is a leap year.
expect "There are 364 days left" notification_on 2026 360
expect "There are 360 days left" notification_on 2027 365
expect "There are 359 days left" notification_on 2028 366
expect "songs/christmas-song.wav" cat "$STAND_IN_STATE/played"

# --- pscpu and psmem ---------------------------------------------------------
# A busy program and a memory-heavy one, each under a name of its own, so the
# tests can find them in the lists. Both are awk, started through a link with
# that name. (A copy would not do: macOS refuses to run a copied system program.)
ln -s "$(command -v awk)" busy-for-the-test
./busy-for-the-test 'BEGIN { while (1) {} }' &
busy=$!

# This one fills about 300 MB, then waits on a pipe that nobody writes to.
ln -s "$(command -v awk)" heavy-for-the-test
mkfifo never-written
./heavy-for-the-test 'BEGIN { while (i++ < 2000000) held[i] = sprintf("%0100d", i); getline line < "never-written" }' &
heavy=$!
sleep 4

expect "busy-for-the-test" pscpu -n 5
expect "busy-for-the-test" pscpu --processes -n 5
expect "heavy-for-the-test" psmem -n 30
expect "PROCS  APP" psmem
expect "USER" psmem --processes -n 3
expect "-n takes a number" pscpu -n many

kill "$busy" "$heavy" 2>/dev/null
wait "$busy" "$heavy" 2>/dev/null

# --- clip --------------------------------------------------------------------
# It copies what comes in. With nothing coming in, it prints the clipboard.
echo "from a pipe" | with_stand_ins clip
expect "from a pipe" cat "$STAND_IN_STATE/clipboard"
expect "from a pipe" with_stand_ins clip </dev/null

echo "from a file" >clip.txt
with_stand_ins clip <clip.txt
expect "from a file" with_stand_ins clip </dev/null

expect "Usage:" clip nope </dev/null

# --- spells that change the system, against stand-ins ------------------------
echo inactive >"$STAND_IN_STATE/systemctl"
expect "off" with_stand_ins firewall status
expect "firewall is on" with_stand_ins firewall on
expect "on" with_stand_ins firewall status
expect "the firewall turns back on when you reboot" with_stand_ins firewall off

expect "caffeine is on" with_stand_ins caffeine on
expect "on" with_stand_ins caffeine status
expect "caffeine is off" with_stand_ins caffeine off
expect "off" with_stand_ins caffeine status

# macOS has no command for Do Not Disturb, so there the spell only says so.
if [[ $OSTYPE == darwin* ]]; then
  expect "notifications cannot be switched on macOS" with_stand_ins notifications off
else
  expect "notifications are off" with_stand_ins notifications off
  expect "off" with_stand_ins notifications status
fi

expect "light mode activated" with_stand_ins theme light
expect "light" with_stand_ins theme status
expect "dark mode activated" with_stand_ins theme dark
expect "dark" with_stand_ins theme status

# --- mode --------------------------------------------------------------------
# mode edits editor and terminal settings under $DOTFILES and calls theme,
# caffeine and notifications. It gets pretend settings files and the stand-ins.
mkdir -p "$DOTFILES/home/programs/vscode" "$DOTFILES/home/programs/zed" "$DOTFILES/home/programs/ghostty"
printf '{\n  "editor.fontSize": 18,\n  "terminal.integrated.fontSize": 16,\n}\n' >"$DOTFILES/home/programs/vscode/settings.json"
printf '{\n  "buffer_font_size": 18,\n  "terminal": {\n    "font_size": 16,\n  },\n}\n' >"$DOTFILES/home/programs/zed/settings.json"
printf 'background-opacity = 0.6\nfont-size = 16\n' >"$DOTFILES/home/programs/ghostty/config"

expect "USAGE" mode --help
expect "mode v" mode --version
expect "Changed to mode demo!" with_stand_ins mode demo
if [[ $OSTYPE == darwin* ]]; then
  expect "notifications: not on macOS, left as they are" with_stand_ins mode chill
  expect "notifications       -" with_stand_ins mode status
  with_stand_ins mode demo >/dev/null 2>&1
fi
expect "demo" with_stand_ins mode status
expect '"editor.fontSize": 32,' cat "$DOTFILES/home/programs/vscode/settings.json"
expect "font-size = 26" cat "$DOTFILES/home/programs/ghostty/config"
expect "Changed to mode chill!" with_stand_ins mode chill
expect "chill" with_stand_ins mode status

# --- herd --prune ------------------------------------------------------------
# Three pretend spaces: one whose folder is gone, one whose folder is there,
# and one on another machine, where this computer cannot look.
mkdir kept-space
cat >"$STAND_IN_STATE/herdr-spaces.json" <<JSON
{"spaces": [
  {"id": "sp1", "name": "gone", "folder": "$TMP/no-such-folder", "machine": null},
  {"id": "sp2", "name": "kept", "folder": "$TMP/kept-space", "machine": null},
  {"id": "sp3", "name": "far", "folder": "/srv/no-such-folder", "machine": "vps"}
]}
JSON

expect "Would close space gone" with_stand_ins herd --prune --dry-run
expect "nothing closed" bash -c '[ -e "$STAND_IN_STATE/herdr-commands" ] || echo "nothing closed"'
expect "Closed space gone" with_stand_ins herd --prune
# Only the first space was closed, and without Herdr asking first.
expect 'space.close {"id": "sp1", "confirmed": true}' cat "$STAND_IN_STATE/herdr-commands"
expect "1 command" bash -c 'echo "$(grep -c . "$STAND_IN_STATE/herdr-commands") command"'
# --prune takes no branch, and --dry-run only goes with --prune.
expect "Usage:" first_line with_stand_ins herd some-branch --prune
expect "Usage:" first_line with_stand_ins herd some-branch --dry-run

rm "$STAND_IN_STATE/herdr-spaces.json"
expect "Nothing to close" with_stand_ins herd --prune

# --- edex --------------------------------------------------------------------
# edex downloads its app once, checks the file and starts it. Pretend tools
# stand in for the three steps, so nothing is downloaded and nothing starts:
#
#   curl        writes a small file where the app would go, and notes each run
#   sha256sum   prints the checksum edex expects, or another one when
#               WRONG_FILE is set
#   nix-shell   prints the file edex asked it to start
mkdir pretend-edex
cat >pretend-edex/curl <<'SH'
#!/usr/bin/env bash
echo download >>"$STAND_IN_STATE/edex-downloads"
while [[ $# -gt 0 ]]; do
  [[ $1 == --output ]] && echo "the app" >"$2"
  shift
done
SH
cat >pretend-edex/sha256sum <<'SH'
#!/usr/bin/env bash
echo "${WRONG_FILE:+not-}$EXPECTED_SUM  $1"
SH
cat >pretend-edex/nix-shell <<'SH'
#!/usr/bin/env bash
echo "started $EDEX_APPIMAGE"
SH
chmod +x pretend-edex/curl pretend-edex/sha256sum pretend-edex/nix-shell

run_edex() {
  EXPECTED_SUM=$(sed -n 's/^SHA256=//p' "$SPELLS/edex") XDG_CACHE_HOME=$TMP/edex-cache PATH=$TMP/pretend-edex:$PATH edex
}
run_edex_with_a_wrong_file() {
  WRONG_FILE=yes run_edex
}
kept=$TMP/edex-cache/edex/eDEX-UI-2.2.8.AppImage

# A wrong file is thrown away, and nothing is started.
expect "wrong checksum" run_edex_with_a_wrong_file
expect "nothing kept" bash -c 'ls "$1" | grep . || echo "nothing kept"' _ "$TMP/edex-cache/edex"

# The first good run downloads the app and starts it. The second run starts
# the file it kept, with no download: two downloads in all, one of them wrong.
expect "started $kept" run_edex
expect "started $kept" run_edex
expect "2 downloads" bash -c 'echo "$(grep -c . "$STAND_IN_STATE/edex-downloads") downloads"'
expect "the app" cat "$kept"

finish
