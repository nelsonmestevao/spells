#!/usr/bin/env bash
# Tests for shims/nix-shell. Run it from anywhere: tests/nix-shell-cache.sh
#
# shellcheck disable=SC2016  # the test scripts below are meant to expand later
#
# A spy stands between the wrapper and the real nix-shell and counts how often
# the real one is asked to do work. A cache hit must not add to that count.

cd "$(dirname "$0")/.." || exit 1
SPELLS=$PWD
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

REAL=$(command -v nix-shell)
if [[ -z $REAL || $REAL -ef $SPELLS/shims/nix-shell ]]; then
  REAL=$(PATH=${PATH//$SPELLS\/shims:/} command -v nix-shell)
fi

mkdir "$TMP/spy"
cat >"$TMP/spy/nix-shell" <<SPY
#!/usr/bin/env bash
echo call >>"$TMP/calls"
exec "$REAL" "\$@"
SPY
chmod +x "$TMP/spy/nix-shell"

# Only the wrapper's own folder moves. Moving XDG_CACHE_HOME would also move
# nix's download cache, and nix would fetch nixpkgs again on every run.
export NIX_SHELL_CACHE_DIR=$TMP/cache
export PATH=$SPELLS/shims:$TMP/spy:$PATH
unset PYTHONPATH NIX_SHELL_CACHE

# Test scripts use the same nixpkgs as the spells do.
NIXPKGS=$(sed -n '2p' "$SPELLS/cowecho")

calls() { wc -l <"$TMP/calls" 2>/dev/null | tr -d ' ' || echo 0; }
saved_count() { find "$NIX_SHELL_CACHE_DIR" -type f | wc -l | tr -d ' '; }

failed=0
check() { # check <what> <expected> <actual>
  if [[ $2 == "$3" ]]; then
    echo "ok    $1"
  else
    echo "FAIL  $1"
    echo "        expected: $2"
    echo "        actual:   $3"
    failed=1
  fi
}

new_script() { # new_script <name> <packages> <interpreter> <body> [extra header line]
  {
    echo '#!/usr/bin/env nix-shell'
    echo "$NIXPKGS"
    [[ -n ${5-} ]] && echo "$5"
    echo "#! nix-shell -p $2"
    echo "#! nix-shell -i $3"
    echo "$4"
  } >"$TMP/$1"
  chmod +x "$TMP/$1"
}

# --- a plain bash script ---------------------------------------------------
new_script hello "pv" bash 'echo "pv is $(command -v pv | grep -c /nix/store/), args: $# [$2], stdin: $(cat)"; exit 7'

: >"$TMP/calls"
out=$(echo piped | "$TMP/hello" one "two words" three 2>/dev/null)
check "first run: exit status passes through" 7 "$?"
check "first run: tools, arguments and stdin arrive" "pv is 1, args: 3 [two words], stdin: piped" "$out"
check "first run: asks the real nix-shell once" 1 "$(calls)"

out=$(echo piped | "$TMP/hello" one "two words" three 2>/dev/null)
check "second run: same result" "pv is 1, args: 3 [two words], stdin: piped" "$out"
check "second run: does not ask the real nix-shell" 1 "$(calls)"

# --- when a saved environment must not be used -----------------------------
saved_file=$(find "$NIX_SHELL_CACHE_DIR" -type f)

sed -i.bak 's/^saved_at=.*/saved_at=1/' "$saved_file"
"$TMP/hello" </dev/null >/dev/null 2>&1
check "older than a week: built again" 2 "$(calls)"

sed -i.bak 's|^extra_path=|extra_path=/nix/store/gone-by-garbage-collection/bin:|' "$saved_file"
out=$("$TMP/hello" a b </dev/null 2>/dev/null)
check "a saved folder is gone: built again" 3 "$(calls)"
check "a saved folder is gone: still works" "pv is 1, args: 2 [b], stdin: " "$out"

NIX_SHELL_CACHE=off "$TMP/hello" </dev/null >/dev/null 2>&1
check "NIX_SHELL_CACHE=off: goes to the real nix-shell" 4 "$(calls)"

echo '# a comment, not a header line' >>"$TMP/hello"
"$TMP/hello" </dev/null >/dev/null 2>&1
check "script body changed, header the same: no rebuild" 4 "$(calls)"

sed -i.bak 's/^#! nix-shell -p pv$/#! nix-shell -p pv neo-cowsay/' "$TMP/hello"
"$TMP/hello" </dev/null >/dev/null 2>&1
check "header changed: built again" 5 "$(calls)"

# --- headers the wrapper leaves alone --------------------------------------
new_script pure "pv" bash 'echo "HOME is ${HOME:-unset}"' '#! nix-shell --pure'
: >"$TMP/calls"
"$TMP/pure" >/dev/null 2>&1
"$TMP/pure" >/dev/null 2>&1
check "--pure header: always the real nix-shell" 2 "$(calls)"

: >"$TMP/calls"
out=$(nix-shell -I "${NIXPKGS#*-I }" -p pv --run 'echo direct' 2>/dev/null)
check "not a script: passed through" "direct" "$out"
check "not a script: one call to the real nix-shell" 1 "$(calls)"

# --- a header nix cannot build ---------------------------------------------
new_script broken "this-package-does-not-exist" bash 'echo unreachable'
saved_before=$(saved_count)
out=$("$TMP/broken" 2>&1)
check "unknown package: fails" 1 "$?"
check "unknown package: nix's own error is shown" 1 "$(grep -c 'this-package-does-not-exist' <<<"$out" | sed 's/[2-9]/1/')"
check "unknown package: nothing is saved" "$saved_before" "$(saved_count)"

# --- Python packages -------------------------------------------------------
mkdir "$TMP/mine"
echo 'NAME = "mine"' >"$TMP/mine/my_module.py"
new_script py "python3 python3Packages.docopt" python3 'import docopt, my_module; print("docopt", docopt.__name__, "and", my_module.NAME)'

: >"$TMP/calls"
out=$(PYTHONPATH=$TMP/mine "$TMP/py" 2>/dev/null)
check "python: first run imports a nix package and one from PYTHONPATH" "docopt docopt and mine" "$out"
out=$(PYTHONPATH=$TMP/mine "$TMP/py" 2>/dev/null)
check "python: second run does too" "docopt docopt and mine" "$out"
check "python: second run does not ask the real nix-shell" 1 "$(calls)"

# --- more than one copy of the wrapper on PATH -----------------------------
# This happens when a second checkout is on PATH, or when these tests run
# while the wrapper is already installed. Two copies must never take each
# other for the real nix-shell, or they call each other forever.
with_time_limit() { # with_time_limit <seconds> <command...>
  local limit=$1 status
  shift
  "$@" &
  local command=$!
  (sleep "$limit" && kill "$command" 2>/dev/null) &
  local watchdog=$!
  wait "$command"
  status=$?
  kill "$watchdog" 2>/dev/null
  return $status
}

mkdir "$TMP/copy" "$TMP/other-copy"
cp "$SPELLS/shims/nix-shell" "$TMP/copy/nix-shell"
cp "$SPELLS/shims/nix-shell" "$TMP/other-copy/nix-shell"
new_script twice "pv" bash 'echo "ran once"'

# NIX_SHELL_CACHE=off makes every wrapper hand over to what it thinks is real.
out=$(PATH=$TMP/copy:$PATH NIX_SHELL_CACHE=off with_time_limit 60 "$TMP/twice" 2>/dev/null)
check "a copy earlier on PATH: the script still runs" "ran once" "$out"

out=$(PATH=$SPELLS/shims:$TMP/copy:$PATH NIX_SHELL_CACHE=off with_time_limit 60 "$TMP/twice" 2>/dev/null)
check "a copy later on PATH: the script still runs" "ran once" "$out"

# A spy that hands over to a copy, the way these tests do on a machine that
# has the wrapper installed.
mkdir "$TMP/spy-to-copy"
printf '#!/usr/bin/env bash\nexec "%s" "$@"\n' "$TMP/other-copy/nix-shell" >"$TMP/spy-to-copy/nix-shell"
chmod +x "$TMP/spy-to-copy/nix-shell"
out=$(PATH=$SPELLS/shims:$TMP/spy-to-copy:$TMP/other-copy:$PATH NIX_SHELL_CACHE=off with_time_limit 60 "$TMP/twice" 2>/dev/null)
check "a spy that calls a copy: the script still runs" "ran once" "$out"

# --- the bash that macOS ships ---------------------------------------------
if [[ $(/bin/bash -c 'echo ${BASH_VERSINFO[0]}') == 3 ]]; then
  : >"$TMP/calls"
  out=$(/bin/bash "$SPELLS/shims/nix-shell" "$TMP/py" 2>/dev/null)
  check "bash 3.2: runs from the saved environment" "0 calls" "$(calls) calls"
fi

exit $failed
