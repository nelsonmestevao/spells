#!/usr/bin/env bash
# Tests for the git spells, and hexdiff, which reads a repo.
# Run it from anywhere: tests/spells-git.sh
#
# tests/lib/checks.sh has the helpers: expect, in_dir, with_stand_ins and more.

# Many checks hand a line of shell to `bash -c` in single quotes, so that it
# runs later, inside the check. shellcheck takes that for a mistake.
# shellcheck disable=SC2016

# shellcheck source=tests/lib/checks.sh
source "$(dirname "$0")/lib/checks.sh"

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

# The jokes come from GitHub, which turns a busy network away now and then.
# Every joke has a space in it, and so does the line the spell prints when
# no joke arrives. A line of GitHub's error page has none.
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

# --- git sync-branches and git sync-worktrees --------------------------------
# A local "remote" with main, and a clone with a branch that is one commit
# behind. After a sync, the commit under the branch tip must be main's newest.

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

finish
