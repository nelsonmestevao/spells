#!/usr/bin/env bash

# Only exported variables can be used within the timer's command.
# export PRIMARY_DISPLAY="$(xrandr | awk '/ primary/{print $1}')"

# Run xidlehook
xidlehook \
  `# Don't lock when there's a fullscreen application` \
  --not-when-fullscreen \
  `# Exit after the whole chain of timer commands have been invoked once` \
  --once \
  `# Lock after 10 minutes` \
  --timer 600 \
  "$HOME/.spells/i3wm/manager.sh lock" \
  ''
