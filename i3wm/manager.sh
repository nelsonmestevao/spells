#!/usr/bin/env sh

[ "$(cat /proc/1/comm)" = "systemd" ] && logind=systemctl || logind=loginctl

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
        dm-tool lock && $logind suspend
        ;;
    hibernate)
        dm-tool lock && $logind hibernate
        ;;
    reboot)
        $logind reboot
        ;;
    shutdown)
        $logind poweroff
        ;;
    *)
        echo "== ! manager: missing or invalid argument ! =="
        echo "Try again with: lock | logout | switch_user | suspend | hibernate | reboot | shutdown"
        exit 2
esac

exit 0

