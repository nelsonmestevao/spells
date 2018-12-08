#!/bin/bash

function howLongUntilChristmas() {
  local today=$(date +"%j")
  local christmas=$(date -d 25-Dec +"%j")

  notify-send -t 16000 "There are $((christmas - today)) days left until Christmas!"
  XDG_RUNTIME_DIR=/run/user/`id -u` /usr/bin/paplay ~/Music/christmas-song.wav
}

howLongUntilChristmas

