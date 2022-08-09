#!/usr/bin/env sh

device=$(xinput list | grep Touchpad | grep -Eo 'id=([0-9]*)' | awk -F'=' '{ print $2 }')

prop=$(xinput list-props "$device" | grep "Natural Scrolling Enabled" | grep -oP '\(\K[^\])]+' | sed -n 1p)

xinput --set-prop "$device" "$prop" 1
