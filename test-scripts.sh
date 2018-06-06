#!/bin/bash

if find . -name '*.sh' -print0 | xargs -n1 -0 shellcheck -s bash; then
    echo "\e[0;32mShell script linting passed!\e[0m"
else
    echo "\e[0;31mShell script linting failed!\e[0m"
    exit 1
fi

