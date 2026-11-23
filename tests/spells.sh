#!/usr/bin/env bash
# Tests for the nix-shell spells. Run it from anywhere: tests/spells.sh
#
# Each `expect` line runs a command and passes when the given text shows up in
# what the command prints. Spells that change the system (GNOME settings, the
# firewall) run against the stand-ins in tests/stand-ins.
#
# Written for bash 3.2, the one macOS ships.

# Many checks hand a line of shell to `bash -c` in single quotes, so that it
# runs later, inside the check. shellcheck takes that for a mistake.
# shellcheck disable=SC2016

cd "$(dirname "$0")/.." || exit 1
SPELLS=$PWD
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

cd "$TMP" || exit 1

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

# --- howLongUntilChristmas ---------------------------------------------------
# The spell asks `date` for the year and the day of the year. A pretend `date`
# picks the day, and stand-ins take the notification and the song.
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
expect "already uses nixpkgs $pinned" own/spl bump "$pinned"
expect "is not a full commit hash" own/spl bump abc123

# This comes last: after it, the copy of spl names a commit that does not exist.
made_up=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
expect "3 files now use nixpkgs $made_up" own/spl bump "$made_up"
expect "$made_up" sed -n 2p own/cowecho
expect "$made_up" sed -n 2p own/demo

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

# With no base given, it compares with the repo's default branch.
git init --quiet --initial-branch master hex-on-master
# shellcheck disable=SC2059
printf "$lock_line" 1.4.1 >hex-on-master/mix.lock
in_dir hex-on-master git add mix.lock
in_dir hex-on-master git commit --quiet --message "add mix.lock"
# shellcheck disable=SC2059
printf "$lock_line" 1.4.4 >hex-on-master/mix.lock

expect "https://diff.hex.pm/diff/jason/1.4.1..1.4.4" in_dir hex-on-master hexdiff

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
expect "main" in_dir hex "$helper" default_branch
expect "master" in_dir hex-on-master "$helper" default_branch

# A spell that loads the shared helpers must not keep its own copy of one.
# Copies drift apart, and the copy would win over the import.
shared=$(sed -n 's/^def \([a-z_]*\)(.*/\1/p' "$SPELLS/lib/spellbook.xsh" | paste -sd '|' -)
own_copies() {
  grep -IlE '^from spellbook import' "$SPELLS"/* "$SPELLS"/git/* 2>/dev/null |
    while read -r spell; do grep -HnE "^def ($shared)\\(" "$spell"; done | grep . || echo "no copies"
}
expect "no copies" own_copies

# --- git-rank and git-joke ---------------------------------------------------
# git-rank only prints when the name written in it is among the authors.
git init --quiet --initial-branch main rank
for author in "Nelson Estevão" "Nelson Estevão" "Someone Else"; do
  echo "$author" >>rank/file
  in_dir rank git add file
  GIT_AUTHOR_NAME=$author in_dir rank git commit --quiet --message "a line by $author"
done

expect "2	Nelson Estevão" in_dir rank git-rank
expect "2 Nelson Estevão" in_dir rank git-rank --by-line

# Every joke has a space in it. This only checks that one arrives.
expect " " git-joke

# --- small git spells --------------------------------------------------------
# The repo from above: three commits to one file, the last by Someone Else.
expect "a line by Someone Else - Someone Else" in_dir rank git-branches
expect "3 file" in_dir rank git-hotfiles
expect "a line by Someone Else" bash -c 'cd rank && echo "log --oneline -1" | git-repl'
expect "file" bash -c 'cd rank && echo ls | git-repl'

expect "test <test@example.com>" in_dir rank git-whoami
expect "Commit: someone else <test@example.com>" in_dir rank env GIT_COMMITTER_NAME="someone else" git-whoami

# Two branches change the same line, so the merge stops in a conflict.
git init --quiet --initial-branch main conflict
(
  cd conflict || exit 1
  echo "once upon a time" >story.txt
  git add story.txt
  git commit --quiet --message "start the story"
  git checkout --quiet -b other
  echo "a long time ago" >story.txt
  git commit --quiet --all --message "start it another way"
  git checkout --quiet main
  echo "in a land far away" >story.txt
  git commit --quiet --all --message "start it a third way"
)
expect "no conflicts" bash -c 'cd conflict && [ -z "$(git-conflicts)" ] && echo "no conflicts"'
in_dir conflict git merge --quiet other >/dev/null 2>&1
expect "story.txt" in_dir conflict git-conflicts
in_dir conflict git merge --abort

# git-sham changes the last commit until its hash matches the pattern.
expect "Usage: git-sham <pattern>" git-sham
in_dir conflict git-sham '^a' >/dev/null
expect "starts with a" bash -c 'cd conflict && case $(git rev-parse HEAD) in a*) echo "starts with a" ;; esac'

# git-remove-file takes a file out of every commit. git filter-branch waits
# ten seconds to warn about itself, unless told not to.
expect "story.txt" in_dir conflict git log --format= --name-only
FILTER_BRANCH_SQUELCH_WARNING=1 in_dir conflict git-remove-file story.txt >/dev/null 2>&1
expect "no commit has it" bash -c 'cd conflict && [ -z "$(git log --format= --name-only)" ] && echo "no commit has it"'

# --- jpg2jxl -----------------------------------------------------------------
mkdir pics
cp "$SPELLS/tests/fixtures/photo.jpg" pics/one.jpg
cp "$SPELLS/tests/fixtures/photo.jpg" "pics/two words.JPEG"

expect "2 converted, 0 skipped, 0 failed" jpg2jxl pics jxl
expect "0 converted, 2 skipped, 0 failed" jpg2jxl pics jxl
expect "is not a .jpg/.jpeg file" jpg2jxl b.txt

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

# --- review ------------------------------------------------------------------
# difit comes from npm, so this needs the network. A real review opens a
# browser, so only the help is checked here.
expect "Usage: difit" review --help

# --- cxls, cdoc, chtml and cpdf ----------------------------------------------
# Each fixture holds the same small report, saved in a different format.
fixtures=$SPELLS/tests/fixtures

expect "│ Ada    │      42 │ 2024-03-01 │" cxls "$fixtures/sample.xlsx"
expect "│ Linus  │     7.5 │ 2025-01-15 │" cxls "$fixtures/sample.xls"
expect "Hello from the second sheet" cxls "$fixtures/sample.ods" --sheet 2
expect $'Scores\nNotes' cxls "$fixtures/sample.xlsx" --list
expect "has no sheet 'Nope'. Its sheets are: Scores, Notes." cxls "$fixtures/sample.xlsx" --sheet Nope
expect "is not a spreadsheet" cxls "$fixtures/sample.pdf"

expect '<h1 id="quarterly-report">Quarterly Report</h1>' cdoc "$fixtures/sample.docx"
# pandoc drops the header row of an .odt table, unless cdoc steps in.
expect "<td>Name</td>" cdoc "$fixtures/sample.odt"
expect "This is a <strong>sample</strong> document" cdoc "$fixtures/sample.doc"
expect "is not a .docx, .odt or .doc file" cdoc "$fixtures/sample.pdf"

# From a pipe, as chtml reads when it gets no file.
doc_as_markdown() { cdoc "$1" | chtml; }

expect "| Ada   | 42    |" chtml "$fixtures/sample.html"
expect "This is a **sample** document with a [link](https://example.com)." doc_as_markdown "$fixtures/sample.docx"
expect "'nope.html' not found" chtml nope.html

expect "## **Highlights**" cpdf "$fixtures/sample.pdf"
expect "|Linus|7|" cpdf "$fixtures/sample.pdf"
expect "is not a PDF file" cpdf "$fixtures/sample.html"

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

# --- copy --------------------------------------------------------------------
echo "from a pipe" | with_stand_ins copy
expect "from a pipe" cat "$STAND_IN_STATE/clipboard"

echo "from a file" >copy.txt
with_stand_ins copy copy.txt
expect "from a file" cat "$STAND_IN_STATE/clipboard"

# --- git spells built on fzf -------------------------------------------------
# With --filter, fzf prints what matches and needs no terminal.
git init --quiet --initial-branch main picks
for name in apple banana; do
  in_dir picks touch "$name"
  in_dir picks git add "$name"
  in_dir picks git commit --quiet --message "add $name"
done
export FZF_DEFAULT_OPTS="--exact --filter=banana"

with_stand_ins in_dir picks git-pick
expect "$(in_dir picks git log --format=%h -1)" cat "$STAND_IN_STATE/clipboard"

echo change >>picks/banana
echo change >>picks/apple
expect "banana" in_dir picks git-review
unset FZF_DEFAULT_OPTS

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

# --- bash_color and keygen ---------------------------------------------------
expect "USAGE" bash_color --help
expect "bash_color v" bash_color --version
expect " TEST " bash_color 255 0 0
expect "USAGE" keygen --help
expect "keygen v" keygen --version
expect "USAGE" keygen nope

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

# --- git fire ----------------------------------------------------------------
# It pushes a new branch to every remote, so it gets a remote of its own.
expect "Usage: git fire" git-fire --help
expect "git-fire version 0.2.4" git-fire --version

git init --quiet --bare --initial-branch main fire-remote.git
git clone --quiet fire-remote.git fire 2>/dev/null
commit fire first
in_dir fire git push --quiet origin main
echo "not saved yet" >fire/unsaved

expect "Leave building!" in_dir fire git-fire "save it"
fire_branch=(git --git-dir=fire-remote.git log -1 --branches="fire-main-*" --name-only --format=%s)
expect "save it" "${fire_branch[@]}"
expect "unsaved" "${fire_branch[@]}"

# With no --branch given, both sync with the remote's default branch.
git init --quiet --bare --initial-branch master sync-on-master.git
git clone --quiet sync-on-master.git sync-on-master 2>/dev/null
commit sync-on-master first
in_dir sync-on-master git push --quiet origin master

in_dir sync-on-master git switch --quiet --create feature
commit sync-on-master on-feature
in_dir sync-on-master git push --quiet --set-upstream origin feature
in_dir sync-on-master git switch --quiet master
in_dir sync-on-master git worktree add --quiet ../sync-on-master-worktree -b in-worktree
commit sync-on-master-worktree on-worktree
in_dir sync-on-master-worktree git push --quiet --set-upstream origin in-worktree
commit sync-on-master second
in_dir sync-on-master git push --quiet origin master

expect "Syncing feature ✓" in_dir sync-on-master git-sync-branches
expect "second" in_dir sync-on-master git log --format=%s -1 origin/feature~1
expect "Syncing in-worktree ✓" in_dir sync-on-master git-sync-worktrees
expect "second" in_dir sync-on-master git log --format=%s -1 origin/in-worktree~1

# --- git clean-branches ------------------------------------------------------
# Merged branches go, also when they live in a worktree. A worktree with work
# that is not committed stays, and so does every branch that is not merged.
git init --quiet --bare --initial-branch main cleanup.git
git clone --quiet cleanup.git cleanup 2>/dev/null
commit cleanup base
in_dir cleanup git push --quiet origin main
in_dir cleanup git branch merged
in_dir cleanup git worktree add --quiet ../cleanup-merged -b merged-in-worktree
in_dir cleanup git worktree add --quiet ../cleanup-with-work -b merged-with-work
touch cleanup-with-work/not-committed
in_dir cleanup git worktree add --quiet ../cleanup-unmerged -b unmerged
commit cleanup-unmerged only-on-the-branch

expect "(dry-run) git worktree remove" in_dir cleanup git-clean-branches --dry-run
expect $'main\nmerged\nmerged-in-worktree\nmerged-with-work\nunmerged' in_dir cleanup git branch --format='%(refname:short)'

expect "Keeping merged branch: merged-with-work" in_dir cleanup git-clean-branches
expect $'main\nmerged-with-work\nunmerged' in_dir cleanup git branch --format='%(refname:short)'
expect "not-committed" ls cleanup-with-work
expect "No such file" ls cleanup-merged

# With no branch given, it compares against the remote's default branch.
git init --quiet --bare --initial-branch master on-master.git
git clone --quiet on-master.git on-master 2>/dev/null
commit on-master base
in_dir on-master git push --quiet origin master
in_dir on-master git branch merged

expect "Deleting merged branch: merged" in_dir on-master git-clean-branches

# --- git spells that ask questions (only the part that needs no terminal) ----
mkdir not-a-repo
expect "Must be run in a" in_dir not-a-repo git-branch-manager

# --- git browse --------------------------------------------------------------
# The stand-ins for open and xdg-open save the address and open no browser.
git init --quiet --initial-branch main browse
commit browse first
# As if a GitHub remote had been fetched.
in_dir browse git remote add origin git@github.com:you/repo.git
in_dir browse git update-ref refs/remotes/origin/main HEAD
in_dir browse git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

with_stand_ins in_dir browse git-browse >/dev/null
expect "https://github.com/you/repo" grep -x "https://github.com/you/repo" "$STAND_IN_STATE/opened"

in_dir browse git switch --quiet --create fix
expect "fix is not on origin yet" with_stand_ins in_dir browse git-browse
in_dir browse git update-ref refs/remotes/origin/fix HEAD
expect "https://github.com/you/repo/compare/main...fix" with_stand_ins in_dir browse git-browse

with_stand_ins in_dir browse git-browse --repo >/dev/null
expect "https://github.com/you/repo" grep -x "https://github.com/you/repo" "$STAND_IN_STATE/opened"

in_dir browse git remote set-url origin https://gitlab.com/group/repo.git
expect "https://gitlab.com/group/repo/-/compare/main...fix" with_stand_ins in_dir browse git-browse

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
