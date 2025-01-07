#!/usr/bin/env bash

set -ueo pipefail

script=$(basename "$0")
usage() {
    echo "usage: $script makefile"
}

if [[ $# -ne 1  ]]; then
    usage
    exit 1
fi
if [[ ! -f $1 ]]; then
    echo "'$1' not found." >&2
    exit 1
fi

if [[ -t 1 ]]; then
    tty_escape() { printf "\033[%sm" "$1"; }
else
    tty_escape() { :; }
fi
tty_256fg() { tty_escape "38;5;$1"; }
tty_accent() { tty_256fg 69;}

makefile="$1"
cat "$makefile" |\
grep -E '(^.+): ## (.+)' |\
perl -pe "s/(^.+): ## (.+)/$(tty_accent)\1\033[m:\2/" |\
column -t -s:
