#! /usr/bin/env bash

ssh-keygen -t rsa -C "$1"
cat ~/.ssh/id_rsa.pub
