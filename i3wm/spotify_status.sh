#!/usr/bin/env sh

PLAYER=$(playerctl --list-all)

if [ "$PLAYER" = "spotify" ]; then
  TITLE=$(exec playerctl metadata xesam:title)
  ARTIST=$(exec playerctl metadata xesam:artist)
  echo "$TITLE - $ARTIST"
fi
