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
# and pw-play on Linux, osascript and afplay on macOS. The test runs the spell
# with bash, not through its nix-shell header: the header would put the real
# notify-send and pw-play in front of the stand-ins.
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
  PRETEND_YEAR=$1 PRETEND_DAY=$2 PATH=$TMP/pretend-date:$PATH with_stand_ins bash "$SPELLS/howLongUntilChristmas"
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

# --- edex --------------------------------------------------------------------
# edex downloads its app once, checks the file and starts it. Pretend tools
# stand in for the three steps, so nothing is downloaded and nothing starts.
# nix-shell runs the spell with plain bash, so the stand-ins come before what
# the header would add:
#
#   curl        writes a small file where the app would go, and notes each run
#   sha256sum   prints the checksum edex expects, or another one when
#               WRONG_FILE is set
#   nix-shell     runs the spell with bash, skipping the header
#   appimage-run  prints the file edex asked it to start
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
exec bash "$@"
SH
cat >pretend-edex/appimage-run <<'SH'
#!/usr/bin/env bash
echo "started $1"
SH
chmod +x pretend-edex/curl pretend-edex/sha256sum pretend-edex/nix-shell pretend-edex/appimage-run

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
