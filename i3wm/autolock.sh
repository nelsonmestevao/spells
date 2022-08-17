#!/usr/bin/env bash

# Only exported variables can be used within the timer's command.
export PRIMARY_DISPLAY="$(xrandr | awk '/ primary/{print $1}')"

# Run xidlehook
xidlehook \
  `# Don't lock when there's a fullscreen application` \
  --not-when-fullscreen \
  `# Dim the screen after 5 minutes, undim if user becomes active` \
  # --timer 10 \
  #   'redshift -g 0.5' \
  #   'redshift -g 1' \
  `# Undim & lock after 10 minutes` \
  --timer 600 \
    "~/.spells/i3wm/manager.sh lock" \
    '' \
  `# Finally, suspend an hour after it locks` \
  --timer 3600 \
    "~/.spells/i3wm/manager.sh suspend" \
    ''
