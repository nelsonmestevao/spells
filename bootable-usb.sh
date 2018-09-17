#!/usr/bin/env sh

sudo fdisk -l

sudo dd bs=4M if="$1" of="$2" status=progress

