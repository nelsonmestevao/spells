#!/usr/bin/env bash

VERSION="spells-0.2.2"

tput sgr0
RED=$(tput setaf 1)
ORANGE=$(tput setaf 3)
GREEN=$(tput setaf 2)
PURPLE=$(tput setaf 5)
CYAN=$(tput setaf 4)
BLUE=$(tput setaf 6)
WHITE=$(tput setaf 7)
BOLD=$(tput bold)
RESET=$(tput sgr0)

ansi() { echo -e "\e[${1}m${*:2}\e[0m"; }
bold() { ansi 1 "$@"; }
italic() { ansi 3 "$@"; }
underline() { ansi 4 "$@"; }
strikethrough() { ansi 9 "$@"; }

function log() {
  local LABEL="$1"
  local COLOR="$2"
  shift 2
  local MSG=("$@")
  printf "[${COLOR}${BOLD}${LABEL}${RESET}]%*s" $(($(tput cols) - ${#LABEL} - 2)) | tr ' ' '='
  for M in "${MSG[@]}"; do
    let COL=$(tput cols)-2-${#M}
    printf "%s%${COL}s${RESET}" "* $M"
  done
  printf "%*s\n" $(tput cols) | tr ' ' '='
}

function log_error() {
  log "FAIL" "$RED" "$@"
}

function log_warn() {
  log "WARN" "$ORANGE" "$@"
}

function log_success() {
  log "OK" "$GREEN" "$@"
}

function log_info() {
  local LABEL="INFO"

  if ! [ "$#" -eq 1 ]; then
    LABEL=$(echo "$1" | tr [a-z] [A-Z])
    shift 1
  fi

  log "${LABEL}" "$CYAN" "$@"
}

function not_installed() {
  [ ! -x "$(command -v "$@")" ]
}

function help_section() {
  local TITLE=$(echo "$@" | tr [a-z] [A-Z])
  echo -e "${BOLD}${TITLE}${RESET}"
}

function display_version() {
  local program="$1"
  local version="$2"
  if not_installed figlet; then
    echo "${program} script version ${version}"
  else
    echo -en "${BLUE}${BOLD}"
    figlet "${program} script"
    echo -en "${RESET}"
    echo "version ${version}"
  fi
}
