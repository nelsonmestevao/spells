#!/usr/bin/env sh

case "$1" in
  lock)
    dm-tool lock
    ;;
  logout)
    i3-msg exit
    ;;
  switch_user)
    dm-tool switch-to-greeter
    ;;
  suspend)
    dm-tool lock && systemctl suspend
    ;;
  hibernate)
    dm-tool lock && systemctl hibernate
    ;;
  reboot)
    systemctl reboot
    ;;
  shutdown)
    systemctl poweroff
    ;;
  *)
    echo "== ! manager: missing or invalid argument ! =="
    echo "Try again with: lock | logout | switch_user | suspend | hibernate | reboot | shutdown"
    exit 2
    ;;
esac

exit 0
