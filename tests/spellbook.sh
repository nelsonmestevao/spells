#!/usr/bin/env bash
# Tests for spl, the helpers the xonsh spells share, and what every xonsh spell must do.
# Run it from anywhere: tests/spellbook.sh
#
# tests/lib/checks.sh has the helpers: expect, in_dir, with_stand_ins and more.

# Many checks hand a line of shell to `bash -c` in single quotes, so that it
# runs later, inside the check. shellcheck takes that for a mistake.
# shellcheck disable=SC2016

# shellcheck source=tests/lib/checks.sh
source "$(dirname "$0")/lib/checks.sh"

# --- every xonsh spell shows its help ---------------------------------------
# A wrong option must print the usage first, with no xonsh traceback hint
# above it.
for spell in caffeine cdoc chtml cpdf cxls excoveralls-report firewall fulldoctest herd \
  hexdiff jpg2jxl notifications pscpu psmem spl theme git-sync-branches git-sync-worktrees \
  git-worktree-select; do
  expect "Usage:" "$spell" --help
  expect "Usage:" first_line "$spell" --nope
done
expect "hexdiff v" hexdiff --version

# --- spl ---------------------------------------------------------------------
# spl works on the folder it is in, so it gets a folder of its own to change.
# A new spell loads the shared helpers from the lib folder next to it.
mkdir own
cp "$SPELLS/spl" "$SPELLS/cowecho" own/
cp -R "$SPELLS/lib" own/
git init --quiet own
pinned=$(grep -oE '[0-9a-f]{40}' own/cowecho)

expect "Created spell 'demo'" env EDITOR=true own/spl new demo --description "Say hello."
expect "Say hello." own/demo --help
expect "demo v0.1.0" own/demo --version
expect "Usage:" first_line own/demo --nope

# `spl list` shows each spell with the line that says what it does. A spell in
# git/ is listed the way you run it.
mkdir own/git
cp "$SPELLS/git/git-browse" own/git/
expect "demo        Say hello." own/spl list
expect "git browse  Open this repo in the browser." own/spl list

# Every spell says what it does. `spl list` prints a bare name for one that
# does not.
undescribed() { spl list | grep -vE '  [^ ]' || echo "none"; }
expect "none" undescribed

# `spl warm` builds each environment once. This folder has three: the one of
# spl (the header in its template counts too), of demo and of cowecho.
expect "All 3 environments are ready" own/spl warm
expect "already uses nixpkgs $pinned" own/spl bump "$pinned"
expect "is not a full commit hash" own/spl bump abc123

# This comes last: after it, the copy of spl names a commit that does not exist.
made_up=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
expect "3 files now use nixpkgs $made_up" own/spl bump "$made_up"
expect "$made_up" sed -n 2p own/cowecho
expect "$made_up" sed -n 2p own/demo

# --- the shared helpers (lib/spellbook.xsh) ----------------------------------
# A small spell in tests/fixtures calls one helper at a time.
helper=$SPELLS/tests/fixtures/spellbook-demo

# exit_status <command...>: run it quietly and print how it ended.
exit_status() {
  "$@" >/dev/null 2>&1
  echo "exit status $?"
}

expect "all good ✓" "$helper" success "all good"
expect "careful" "$helper" log_warn careful
expect "by the way" "$helper" log_info "by the way"

# failure says so and carries on. error says so and stops.
expect "and carried on" "$helper" failure "went wrong"
expect "went wrong ✗" "$helper" failure "went wrong"
expect "stopped ✗" first_line "$helper" error stopped
expect "exit status 1" exit_status "$helper" error stopped

expect "spellbook-demo v0.1.0" "$helper" --version
expect "Usage:" first_line "$helper" --nope

expect "worked: True" "$helper" spin Waiting true
expect "worked: False" "$helper" spin Waiting false

# step is spin, and then a line that says how it went.
expect "Waiting ✓" "$helper" step Waiting true
expect "Waiting ✗" "$helper" step Waiting false
expect "worked: False" "$helper" step Waiting false

# Neither repo has a remote, so the answer is the branch that exists.
git init --quiet --initial-branch main on-main
git init --quiet --initial-branch master on-master
commit on-main file
commit on-master file
expect "main" in_dir on-main "$helper" default_branch
expect "master" in_dir on-master "$helper" default_branch

# A spell that loads the shared helpers must not keep its own copy of one.
# Copies drift apart, and the copy would win over the import.
shared=$(sed -n 's/^def \([a-z_]*\)(.*/\1/p' "$SPELLS/lib/spellbook.xsh" | paste -sd '|' -)
own_copies() {
  grep -IlE '^from spellbook import' "$SPELLS"/* "$SPELLS"/git/* 2>/dev/null |
    while read -r spell; do grep -HnE "^def ($shared)\\(" "$spell"; done | grep . || echo "no copies"
}
expect "no copies" own_copies

# The same goes for a bash spell that loads lib/spellbook.sh.
shared_in_bash=$(sed -n 's/^\([a-z_]*\)() {$/\1/p' "$SPELLS/lib/spellbook.sh" | paste -sd '|' -)
own_bash_copies() {
  grep -IlE '^source .*lib/spellbook\.sh' "$SPELLS"/* "$SPELLS"/git/* 2>/dev/null |
    while read -r spell; do grep -HnE "^(function )?($shared_in_bash)\\(\\)" "$spell"; done | grep . || echo "no copies"
}
expect "no copies" own_bash_copies

finish
