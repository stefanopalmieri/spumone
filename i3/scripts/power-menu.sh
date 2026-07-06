#!/usr/bin/env bash
# Power menu for i3 — rofi-powered

chosen=$(echo -e " Lock\n Logout\n Suspend\n Reboot\n Shutdown" | rofi -dmenu -i -p "Power" -theme spacemacs -theme-str 'window {width: 250px;}')

# rofi returns the entry verbatim, including the leading space used for
# visual padding above — strip it so the case below matches.
chosen="${chosen# }"
chosen="${chosen%% }"

case "$chosen" in
    Lock)       i3lock -c 292b2e ;;
    Logout)     i3-msg exit ;;
    Suspend)    systemctl suspend ;;
    Reboot)     systemctl reboot ;;
    Shutdown)   systemctl poweroff ;;
esac
