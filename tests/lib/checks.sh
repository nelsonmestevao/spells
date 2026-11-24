# shellcheck shell=bash
# What every spell test file starts with:
#
#   source "$(dirname "$0")/lib/checks.sh"
#
# It makes a throwaway folder and moves into it, puts the spells of this
# checkout first on PATH, and brings the helpers below. A test file ends with
# `finish`.
#
# Each `expect` line runs a command and passes when the given text shows up in
# what the command prints. Spells that change the system (GNOME settings, the
# firewall) run against the stand-ins in tests/stand-ins.
#
# Written for bash 3.2, the one macOS ships.

SPELLS=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# The spells of this checkout come first, ahead of any installed copy.
export PATH=$SPELLS:$SPELLS/git:$PATH
export STAND_IN_STATE=$TMP
# Spells that keep notes between runs (caffeine on macOS) keep them here.
export XDG_STATE_HOME=$TMP/state
export DOTFILES=$TMP/dotfiles
# The throwaway repos below must not use your git settings (signing, hooks,
# aliases). They only need a name to commit with.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

checks=0
failed=0

# expect <text> <command...>
expect() {
  local wanted=$1 output
  shift
  # Compare without colour codes, and without the NUL bytes `grep -z` adds.
  output=$("$@" 2>&1 | tr -d '\0' | sed -E $'s/\x1b\\[[0-9;?]*[a-zA-Z]//g; s/\x1b\\(B//g')
  checks=$((checks + 1))
  if [[ $output == *"$wanted"* ]]; then
    echo "ok    $*"
  else
    echo "FAIL  $*"
    echo "        wanted: $wanted"
    echo "        got:    $(tail -n 3 <<<"$output")"
    failed=$((failed + 1))
  fi
}

# in_dir <folder> <command...>
in_dir() {
  (cd "$1" && shift && "$@")
}

# with_stand_ins <command...>: run with the pretend systemctl, sudo, gsettings
# and clipboard. With no WAYLAND_DISPLAY, the clipboard spells skip wl-copy and
# use the pretend pbcopy, even on a Wayland desktop.
with_stand_ins() {
  WAYLAND_DISPLAY='' PATH=$SPELLS/tests/stand-ins:$PATH "$@"
}

# first_line <command...>: only the first line the command prints, errors included.
first_line() {
  "$@" 2>&1 | head -n 1
}

# commit <folder> <file>: add an empty file to a repo and commit it.
commit() {
  in_dir "$1" touch "$2"
  in_dir "$1" git add "$2"
  in_dir "$1" git commit --quiet --message "$2"
}

# finish: say how many checks ran and how many failed. A test file ends with
# this line, so its exit status is the one of the file.
finish() {
  echo
  echo "$checks checks, $failed failed"
  [[ $failed -eq 0 ]]
}

cd "$TMP" || exit 1
