#!/bin/bash

if [ "$(playerctl status)" = "Playing" ]; then
    title=$(exec playerctl metadata xesam:title)
    artist=$(exec playerctl metadata xesam:artist)
  echo " $title - $artist"
else
  echo ""
fi
