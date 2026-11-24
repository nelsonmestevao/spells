# shellcheck shell=bash
# The helpers that the bash spells share. A spell loads them with:
#
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/spellbook.sh"
#
# A spell in git/ goes one folder up first: .../../lib/spellbook.sh
#
# A helper goes in here once two spells need it. The xonsh spells have a file
# of their own, lib/spellbook.xsh.
#
# Written for bash 3.2, the one macOS ships.

# help_section <title>: print the title of a help section in bold capitals.
# (tr, not ${*^^}: bash 3.2 has no ^^.)
help_section() {
  printf '\033[1m%s\033[0m' "$(echo "$*" | tr '[:lower:]' '[:upper:]')"
}

# to_clipboard: copy what comes in to the clipboard, with the tool this
# system has. With no such tool it fails without a word, so the spell can say
# what it does instead.
to_clipboard() {
  if [[ -n ${WAYLAND_DISPLAY-} ]] && command -v wl-copy >/dev/null; then
    wl-copy
  elif command -v pbcopy >/dev/null; then
    pbcopy
  elif command -v xsel >/dev/null; then
    xsel --input --clipboard
  else
    return 1
  fi
}
