#!/usr/bin/env sh

sudo fdisk -l

sudo mkfs.vat "$1" -I

