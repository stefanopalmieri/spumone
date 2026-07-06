#!/bin/sh
# Emits an empty status line forever so i3bar renders only its background
# color — used as a fake bottom-border bar under the main i3bar.
while :; do
    echo ''
    sleep 60
done
