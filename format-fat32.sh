#!/usr/bin/env sh

sudo fdisk -l

sudo mkfs.vfat "$1" -I

