#!/usr/bin/env bash

set -ueo pipefail

script=$(basename "$0")
usage() {
    echo "usage: $script brewfile"
}

if [[ $# -ne 1  ]]; then
    usage
    exit 1
fi
if [[ ! -f $1 ]]; then
    echo "'$1' not found." >&2
    exit 1
fi

DOTFILES_BREWFILE="$1"

input=
has_diff=false

brew bundle dump --global --force >/dev/null

if type git >/dev/null 2>&1; then
    git diff "${HOME}/.Brewfile" "$DOTFILES_BREWFILE" || has_diff=true
else
    diff -u "${HOME}/.Brewfile" "$DOTFILES_BREWFILE" || has_diff=true
fi


if "$has_diff"; then
    echo
    while true; do
        read -rp "overwrite '${DOTFILES_BREWFILE}'? (y/n) " input
        if [[ $input =~ ^[Yy]|[Yy][Ee][Ss]$ ]]; then
            break
        elif [[ $input =~ ^[Nn]|[Nn][Oo]$ ]]; then
            echo 'not overwritten, aborted.' >&2
            exit 0
        fi
    done
    brew bundle dump --force "$DOTFILES_BREWFILE"
else
    echo 'no changes.'
fi
