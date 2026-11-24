#!/usr/bin/env nix-shell
#! nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/680275f0bb6afce84fbac3e75fc47c5f2272400b.tar.gz
#! nix-shell -p shellcheck
#! nix-shell -i bash
# Run shellcheck on every bash and sh script in the repo: spells, tests,
# stand-ins and the nix-shell wrapper.
#
# Needs from your system: git, to list the files.

cd "$(dirname "$0")/.." || exit 1

# shell_of <file>: bash or sh, the shell the file is written for. Fails for
# any other file. A spell with a nix-shell header names its shell on the
# `-i` line, where shellcheck does not look.
shell_of() {
  local first shell
  first=$(head -c 200 "$1" 2>/dev/null | tr -d '\0' | head -n 1)
  case $first in
    '#!/usr/bin/env nix-shell') shell=$(sed -n 's/^#! nix-shell -i \([a-z0-9]*\).*/\1/p' "$1" | head -n 1) ;;
    '#!'*) shell=${first##*[/ ]} ;;
    *) return 1 ;;
  esac
  [[ $shell == bash || $shell == sh ]] && echo "$shell"
}

checks=0
failed=0

# Tracked files, and new ones that are not ignored.
while IFS= read -r file; do
  shell=$(shell_of "$file") || continue
  checks=$((checks + 1))
  if shellcheck --shell="$shell" "$file"; then
    echo "ok    $file"
  else
    echo "FAIL  $file"
    failed=$((failed + 1))
  fi
done < <(git ls-files --cached --others --exclude-standard)

echo
echo "$checks checks, $failed failed"
[[ $failed -eq 0 ]]
