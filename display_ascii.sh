#!/usr/bin/env sh

clear

for (( i = 0; i < 10; i++ )); do
    lolcat "$@"
    sleep 0.3
    clear
done
