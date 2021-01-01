#!/usr/bin/env bash

id=$(xinput list | grep -i "Elantech Touchpad" | cut -d'=' -f2 | cut -d'[' -f1)

echo "Mouse ID $id"

natural_scrolling_id=$(xinput list-props "${id}" | grep -i "Natural Scrolling Enabled (" | cut -d'(' -f2 | cut -d')' -f1)

echo "Natural scrolling ID ${natural_scrolling_id}"

xinput --set-prop "$id" "${natural_scrolling_id}" 1
