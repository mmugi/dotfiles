#!/usr/bin/env bash

set -ueo pipefail

DOTFILES_PATH="${HOME:?}/.dotfiles"

# shellcheck source=/dev/null
source "${DOTFILES_PATH:?}/scripts/lib/format.bash"

abort() {
    printf "\033[1;31m⛔ %s\033[0m\n" "$@" >&2
    exit 1
}

if [ -z "${BASH_VERSION:-}" ]; then
    abort "Bash is required to interpret this script."
fi

executing_user=$(whoami)
[[ $executing_user == root ]] && abort "Don't run this as root."
[[ ! -t 0 ]] && abort "'stdin' is not a TTY."


### functions ###

line() {
    local line_length=76
    draw.line "$line_length"
}

uninstall_failed() {
    abort 'Uninstallation failed;('
}

uninstall_abort() {
    msg.warn 'Uninstallation aborted:P'
    exit
}

greet() {
    local -r greeting_messages=(
              'Hello:)'
              'This is the dotfiles uninstallation script.'
              "Date: $(LANG=C date)")
    line
    draw.logo -u -c "$RED"
    for msg in "${greeting_messages[@]}"; do
        msg -c "$RED" -- "$msg"
    done
    newline
    line
    newline
}

confirm_uninstall() {
    msg.attention "Starting dotfiles uninstallation."
    printf "Press %s to continue or press any other key to abort.\n" "$(sgr bold)RETURN/ENTER$(sgr)"
    IFS='' read -sr -n 1 -p 'Ready?' input && echo
    if [[ -n ${input:-} ]]; then
        uninstall_abort
    else
        newline
    fi
}

self_destruct() {
    msg -c "$RED" -p 'Self-destructing'

    if [[ ! -d $DOTFILES_PATH ]]; then
        log.error "dotfiles directory not found: $DOTFILES_PATH"
        uninstall_failed
    fi

    printf "DOTFILES: %s\n" "$(sgr bold "$FG_ACCENT")${DOTFILES_PATH}$(sgr)"

    local input
    local cmd_result

    while true; do
        read -rp 'Are you sure you want to delete this? (y/n) ' input
        if [[ $input =~ ^[Yy]|[Yy][Ee][Ss]$ ]]; then
            break
        elif [[ $input =~ ^[Nn]|[Nn][Oo]$ ]]; then
            uninstall_abort
        fi
    done

    echo -n "Deleting dotfiles..."
    if cmd_result="$(echo rm -r "${DOTFILES_PATH:?}" 2>&1)"; then
        result.ok
        newline
    else
        result.failed
        log.error "$cmd_result"
        uninstall_failed
    fi
}

uninstall_complete() {
    line
    newline
    printf "%s\n" "$(sgr bold "$PINK")GoodBye!👋$(sgr)"
}


### main ###

greet
confirm_uninstall
self_destruct
uninstall_complete
