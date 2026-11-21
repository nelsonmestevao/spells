#!/usr/bin/env bash
# Tests for the nix-shell spells. Run it from anywhere: tests/spells.sh
#
# Each `expect` line runs a command and passes when the given text shows up in
# what the command prints. Spells that change the system (GNOME settings, the
# firewall) run against the stand-ins in tests/stand-ins.
#
# Written for bash 3.2, the one macOS ships.

cd "$(dirname "$0")/.." || exit 1
SPELLS=$PWD
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# The spells of this checkout come first, ahead of any installed copy.
export PATH=$SPELLS:$SPELLS/git:$PATH
export STAND_IN_STATE=$TMP
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
  # Compare without colour codes.
  output=$("$@" 2>&1 | sed -E $'s/\x1b\\[[0-9;?]*[a-zA-Z]//g; s/\x1b\\(B//g')
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

# with_stand_ins <command...>: run with the pretend systemctl, sudo and gsettings.
with_stand_ins() {
  PATH=$SPELLS/tests/stand-ins:$PATH "$@"
}

cd "$TMP" || exit 1

# --- every xonsh spell shows its help ---------------------------------------
for spell in caffeine excoveralls-report firewall fulldoctest herd hexdiff jpg2jxl \
  notifications spl theme git-sync-branches git-sync-worktrees git-worktree-select; do
  expect "Usage:" "$spell" --help
done
expect "hexdiff v0.1.0" hexdiff --version

# --- small bash spells -------------------------------------------------------
expect "< hello there >" cowecho hello there

printf 'one\ntwo\n' >"a b.txt"
printf 'one\n2\n' >b.txt
expect "a b.txt" filediff "a b.txt" b.txt

expect "$(curl --silent --fail --location https://channels.nixos.org/nixos-26.05/git-revision)" get_nix_channel_revision 26.05
expect "Usage:" get_nix_channel_revision

expect "USAGE" yt2mp3 --help
expect "yt2mp3 v0.1.0" yt2mp3 --version
expect "unknown option: --nope" yt2mp3 --nope

expect "█" qrcode https://example.com
expect "https://example.com" qrcode https://example.com
expect "https://example.com" qrcode https://example.com --large
expect "Usage:" qrcode

# --- hexdiff -----------------------------------------------------------------
lock_line='  "jason": {:hex, :jason, "%s", "abc", [:mix], [], "hexpm", "def"},\n'
git init --quiet --initial-branch main hex
# shellcheck disable=SC2059  # the version goes into the format on purpose
printf "$lock_line" 1.4.1 >hex/mix.lock
in_dir hex git add mix.lock
in_dir hex git commit --quiet --message "add mix.lock"
# shellcheck disable=SC2059
printf "$lock_line" 1.4.4 >hex/mix.lock

expect "https://diff.hex.pm/diff/jason/1.4.1..1.4.4" in_dir hex hexdiff
expect "Could not compare mix.lock with 'nope'" in_dir hex hexdiff nope
expect "No mix.lock found" hexdiff

# --- jpg2jxl -----------------------------------------------------------------
mkdir pics
cp "$SPELLS/tests/fixtures/photo.jpg" pics/one.jpg
cp "$SPELLS/tests/fixtures/photo.jpg" "pics/two words.JPEG"

expect "2 converted, 0 skipped, 0 failed" jpg2jxl pics jxl
expect "0 converted, 2 skipped, 0 failed" jpg2jxl pics jxl
expect "is not a .jpg/.jpeg file" jpg2jxl b.txt

# --- excoveralls-report ------------------------------------------------------
mkdir -p coverage/cover
cat >coverage/cover/excoveralls.html <<'HTML'
<span class="cov high">100.0</span> <a href="#lib/app/a.ex"><span class="dirname">lib/app/</span><span class="basename">a.ex</span></a>
<span class="cov none">0.0</span> <a href="#lib/app/b.ex"><span class="dirname">lib/app/</span><span class="basename">b.ex</span></a>
HTML

expect "2 files, 50.0% average coverage" in_dir coverage excoveralls-report
expect "lib/app/a.ex,100.0,high" cat coverage/cover/coverage_report.csv

# --- fulldoctest (only what it would run; the real thing downloads GHC) ------
expect "haskellPackages.doctest --run" fulldoctest --dry-run -p gloss Demo.hs -- --verbose

# --- spells that change the system, against stand-ins ------------------------
echo inactive >"$STAND_IN_STATE/systemctl"
expect "off" with_stand_ins firewall status
expect "firewall is on" with_stand_ins firewall on
expect "on" with_stand_ins firewall status
expect "the firewall turns back on when you reboot" with_stand_ins firewall off

expect "caffeine is on" with_stand_ins caffeine on
expect "on" with_stand_ins caffeine status

expect "notifications are off" with_stand_ins notifications off
expect "off" with_stand_ins notifications status

mkdir -p "$DOTFILES/home/programs/git"
printf '[delta]\n    light = false\n' >"$DOTFILES/home/programs/git/common.ini"
expect "light mode activated" with_stand_ins theme light
expect "light = true" cat "$DOTFILES/home/programs/git/common.ini"
expect "light" with_stand_ins theme status

# --- git sync-branches and git sync-worktrees --------------------------------
# A local "remote" with main, and a clone with a branch that is one commit
# behind. After a sync, the commit under the branch tip must be main's newest.
commit() { # commit <folder> <file>
  in_dir "$1" touch "$2"
  in_dir "$1" git add "$2"
  in_dir "$1" git commit --quiet --message "$2"
}

git init --quiet --bare --initial-branch main remote.git
git clone --quiet remote.git clone 2>/dev/null
commit clone first
in_dir clone git push --quiet origin main

in_dir clone git switch --quiet --create feature
commit clone on-feature
in_dir clone git push --quiet --set-upstream origin feature
in_dir clone git switch --quiet main
commit clone second
in_dir clone git push --quiet origin main

expect "Syncing feature ✓" in_dir clone git-sync-branches
expect "second" in_dir clone git log --format=%s -1 origin/feature~1

in_dir clone git switch --quiet main
in_dir clone git worktree add --quiet ../worktree -b in-worktree
commit worktree on-worktree
in_dir worktree git push --quiet --set-upstream origin in-worktree
commit clone third
in_dir clone git push --quiet origin main

expect "Syncing in-worktree ✓" in_dir clone git-sync-worktrees
expect "third" in_dir clone git log --format=%s -1 origin/in-worktree~1

# --- serve -------------------------------------------------------------------
serve 8765 --bind 127.0.0.1 --directory coverage >/dev/null 2>&1 &
server=$!
for _ in $(seq 120); do
  curl --silent --max-time 2 --output served.html http://127.0.0.1:8765/cover/excoveralls.html && break
  sleep 0.5
done
kill "$server" 2>/dev/null
wait "$server" 2>/dev/null
expect "basename" cat served.html

echo
echo "$checks checks, $failed failed"
[[ $failed -eq 0 ]]
