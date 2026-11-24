#!/usr/bin/env bash
# Tests for the small spells: one tool each, or a few lines of bash.
# Run it from anywhere: tests/spells-small.sh
#
# tests/lib/checks.sh has the helpers: expect, in_dir, with_stand_ins and more.

# Many checks hand a line of shell to `bash -c` in single quotes, so that it
# runs later, inside the check. shellcheck takes that for a mistake.
# shellcheck disable=SC2016

# shellcheck source=tests/lib/checks.sh
source "$(dirname "$0")/lib/checks.sh"

# --- small bash spells -------------------------------------------------------
expect "< hello there >" cowecho hello there

printf 'one\ntwo\n' >"a b.txt"
printf 'one\n2\n' >b.txt
expect "a b.txt" filediff "a b.txt" b.txt

expect "$(curl --silent --fail --location https://channels.nixos.org/nixos-26.05/git-revision)" get_nix_channel_revision 26.05
expect "Usage:" get_nix_channel_revision

expect "USAGE" yt2mp3 --help
expect "yt2mp3 v" yt2mp3 --version
expect "unknown option: --nope" yt2mp3 --nope

expect "█" qrcode https://example.com
expect "https://example.com" qrcode https://example.com
expect "https://example.com" qrcode https://example.com --large
expect "Usage:" qrcode

# --- forall ------------------------------------------------------------------
# Two folders, one with a space in its name, and a hidden one to skip.
mkdir -p many/one "many/two words" many/.hidden

expect "<a b>" in_dir many forall -- printf "<%s>" "a b"
expect "many/two words" in_dir many forall -- true
expect "HI" in_dir many forall -- 'echo hi | tr a-z A-Z'
in_dir many forall -- touch ran >/dev/null
expect "skipped .hidden" bash -c '[ -e many/.hidden/ran ] && echo "ran in .hidden" || echo "skipped .hidden"'
expect "exit 1" bash -c 'cd many && forall -- false >/dev/null; echo "exit $?"'
# A failure in the first folder must not stop the others.
expect "many/two words" in_dir many forall -- "exit 3"

expect "<a b>" in_dir many forall -p -- printf "<%s>" "a b"
expect "exit 3" bash -c 'cd many && forall -p -- "exit 3" >/dev/null 2>&1; echo "exit $?"'
expect "--jobs needs a number" forall --jobs

# --- showIt ------------------------------------------------------------------
# Five rounds of 0.8 seconds, so this one takes a moment.
expect "< hello >" env TERM=xterm showIt hello

# --- localip -----------------------------------------------------------------
# The address differs per machine. Every IPv4 address has a dot in it.
expect "." localip

# --- most_used_programs ------------------------------------------------------
# It reads ~/.zsh_history and the aliases in ~/.zshrc, so it gets a pretend
# home. nix keeps its download cache, or it would fetch nixpkgs again.
mkdir home
echo "alias gs='git status'" >home/.zshrc
printf ': 1700000000:0;%s\n' gs gs ls >home/.zsh_history
nix_cache=${XDG_CACHE_HOME:-$HOME/.cache}
with_pretend_home() {
  XDG_CACHE_HOME=$nix_cache HOME=$TMP/home "$@"
}

expect "66.67%     2   git" with_pretend_home most_used_programs

# --- small spells that run one tool ------------------------------------------
expect "4" math 2+2
expect "2.50" math "scale=2; 10/4"

expect "Needs 3 parameters" split-video.sh

# matrix runs until a key is pressed, so one is piped in.
expect "exit 0" bash -c 'printf x | TERM=xterm matrix >/dev/null 2>&1; echo "exit $?"'

# clean_downloads_folder sorts ~/Downloads, so it works on the pretend home.
mkdir home/Downloads
touch home/Downloads/photo.png home/Downloads/scan.bmp home/Downloads/notes.pdf home/Downloads/unknown.xyz
with_pretend_home clean_downloads_folder
expect "photo.png" ls home/Downloads/Images
expect "scan.bmp" ls home/Downloads/Images
expect "notes.pdf" ls home/Downloads/Documents
expect "unknown.xyz" ls home/Downloads/Misc

# --- bash_color and keygen ---------------------------------------------------
expect "USAGE" bash_color --help
expect "bash_color v" bash_color --version
expect " TEST " bash_color 255 0 0
expect "USAGE" keygen --help
expect "keygen v" keygen --version
expect "USAGE" keygen nope

# --- review ------------------------------------------------------------------
# difit comes from npm, so this needs the network. A real review opens a
# browser, so only the help is checked here.
expect "Usage: difit" review --help

# --- serve -------------------------------------------------------------------
mkdir site
echo "hello from serve" >site/index.html
serve 8765 --bind 127.0.0.1 --directory site >/dev/null 2>&1 &
server=$!
for _ in $(seq 120); do
  curl --silent --max-time 2 --output served.html http://127.0.0.1:8765/index.html && break
  sleep 0.5
done
kill "$server" 2>/dev/null
wait "$server" 2>/dev/null
expect "hello from serve" cat served.html

finish
