#!/usr/bin/env sh

ssh-keygen -t rsa -C "$1"

SSH_PUB=$HOME/ssh/id_rsa.pub

if command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard < "$SSH_PUB"
else
    echo "[ssh]: xclip not found, you need to copy manually the following key"
    cat "$SSH_PUB"
    exit 1
fi

echo "[ssh]: SSH public key copied into the clipboard"
