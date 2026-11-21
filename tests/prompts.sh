#!/usr/bin/env nix-shell
#! nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/680275f0bb6afce84fbac3e75fc47c5f2272400b.tar.gz
#! nix-shell -p tmux
#! nix-shell -i bash
# Tests for the prompts: what a spell does on Esc, Ctrl-C and Enter.
#
# A prompt needs a real terminal, so each case runs inside tmux. A case is a
# list of steps, then `--`, then the command:
#
#   in_terminal wait:navigate Escape -- caffeine
#
# `wait:TEXT` waits until TEXT is on the screen. Any other step is a key for
# tmux (Enter, Escape, C-c, Down) or text to type. Afterwards $screen holds
# what the terminal showed and $status the exit status of the command.

cd "$(dirname "$0")/.." || exit 1
SPELLS=$PWD
TMP=$(mktemp -d)

# One tmux server for the whole run, with a new session for each case.
#   - The server must not stop when a session ends: a new session that arrives
#     while it is shutting down is lost.
#   - Commands run through this bash, not your login shell. Its startup files
#     could put your real tools on PATH ahead of the stand-ins.
T() { tmux -L spells-prompts -f /dev/null "$@"; }
T kill-server 2>/dev/null
trap 'T kill-server 2>/dev/null; rm -rf "$TMP"' EXIT

# The spells of this checkout come first, with the stand-ins ahead of them.
export PATH=$SPELLS/tests/stand-ins:$SPELLS:$SPELLS/git:$PATH
export STAND_IN_STATE=$TMP
export DOTFILES=$TMP/dotfiles
export EDITOR=true
# The throwaway repos below must not use your git settings.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

checks=0
failed=0
cases=0
session=
screen=
status=
last_case=

fail() {
  echo "FAIL  $last_case"
  echo "        $1"
  echo "        screen: $(grep -v '^ *$' <<<"$screen" | tail -n 4 | tr '\n' '|')"
  failed=$((failed + 1))
}

# Wait up to a minute for some text to show on the screen.
wait_until() {
  local _
  for _ in $(seq 300); do
    T capture-pane -p -t "$session" 2>/dev/null | grep -qF -- "$1" && return 0
    sleep 0.2
  done
  return 1
}

in_terminal() {
  local steps=() step
  while [[ $1 != -- ]]; do
    steps+=("$1")
    shift
  done
  shift
  last_case="$* [${steps[*]}]"

  cases=$((cases + 1))
  session=case-$cases
  T start-server \; set-option -g exit-empty off \; set-option -g default-shell "$BASH" \; \
    new-session -d -s "$session" -x 120 -y 40 -c "$PWD" \
    "$(printf '%q ' "$@"); echo \"[exit status: \$?]\"; sleep 600"
  for step in "${steps[@]}"; do
    case $step in
      wait:*) wait_until "${step#wait:}" ;;
      *) T send-keys -t "$session" "$step" && sleep 0.3 ;;
    esac
  done
  wait_until "[exit status:"
  screen=$(T capture-pane -p -t "$session")
  status=$(sed -n 's/.*\[exit status: \([0-9]*\)\].*/\1/p' <<<"$screen" | tail -n 1)
  T kill-session -t "$session" 2>/dev/null

  # No case may ever end in a Python traceback.
  checks=$((checks + 1))
  if [[ $screen == *CalledProcessError* || $screen == *Traceback* ]]; then
    fail "the spell ended in a traceback"
  fi
}

expect_exit() {
  checks=$((checks + 1))
  if [[ $status == "$1" ]]; then
    echo "ok    $last_case -> exit $1"
  else
    fail "wanted exit status $1, got ${status:-none}"
  fi
}

expect_on_screen() {
  checks=$((checks + 1))
  if [[ $screen == *"$1"* ]]; then
    echo "ok    $last_case -> shows \"$1\""
  else
    fail "wanted \"$1\" on the screen"
  fi
}

cd "$TMP" || exit 1

# --- a list to choose from (gum choose) --------------------------------------
in_terminal wait:navigate Escape -- caffeine
expect_exit 1
in_terminal wait:navigate C-c -- caffeine
expect_exit 130
in_terminal wait:navigate Enter -- caffeine
expect_exit 0
expect_on_screen "caffeine is on"

echo active >"$STAND_IN_STATE/systemctl"
in_terminal wait:navigate Down Enter -- firewall
expect_exit 0
expect_on_screen "firewall is off"

# --- a list to search (gum filter) -------------------------------------------
# spl works on the folder it is in, so it gets a folder of its own.
mkdir own
cp "$SPELLS/spl" "$SPELLS/cowecho" own/
git init --quiet own

# The first Esc only leaves the search box. The second one cancels.
in_terminal wait:navigate Escape Escape -- own/spl edit
expect_exit 1
in_terminal wait:navigate C-c -- own/spl edit
expect_exit 130
in_terminal wait:navigate Enter -- own/spl edit
expect_exit 0

# --- a line to type (gum input) ----------------------------------------------
in_terminal "wait:Spell name" Escape -- own/spl new
expect_exit 1
in_terminal "wait:Spell name" demo Enter "wait:Short description" "Say hello." Enter -- own/spl new
expect_exit 0
expect_on_screen "Created spell 'demo'"

# --- the git spells that ask questions ---------------------------------------
git init --quiet --bare --initial-branch main remote.git
git clone --quiet remote.git repo 2>/dev/null
cd repo || exit 1
touch first
git add first
git commit --quiet --message first
git push --quiet origin main
git branch one
git branch two
git worktree add --quiet ../second -b second

in_terminal wait:navigate Enter -- git-worktree-select
expect_exit 0
expect_on_screen "$TMP/repo"

in_terminal wait:navigate C-c -- herd
expect_exit 130

# Pick the branch "one" (x marks it), then the command "delete".
in_terminal wait:navigate Down x Enter wait:rebase Down Enter -- git-branch-manager
expect_exit 0
expect_on_screen "Deleted branch one"

touch second-file
in_terminal "wait:Stage all" y wait:refactor Down Enter wait:scope ui Enter \
  "wait:feat(ui):" "add a file" Enter wait:Details why Enter "wait:Commit changes" y -- git-conventional-commit
expect_exit 0
expect_on_screen "feat(ui): add a file"

echo
echo "$checks checks, $failed failed"
[[ $failed -eq 0 ]]
