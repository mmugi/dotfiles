#!/usr/bin/env bash

set -ueo pipefail

DOTFILES_PATH="${HOME:?}/.dotfiles"
DOTFILES_CONFIG_DIR="${DOTFILES_PATH}/configs"

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


###  functions  ###

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

delete_configs() {
    local pkg_dirs
    local pkg_dir
    local pkg
    local src_files
    local src_dirs
    local target
    local link_src
    local cmd_result

    delete_configs_failed() { abort 'Config deletion failed;('; }

    msg -p 'Starting config deletion'

    if [[ -z ${DOTFILES_CONFIG_DIR:-} ]]; then
        log.error "'DOTFILES_CONFIG_DIR' is not set"
        delete_configs_failed
    fi

    if ! pkg_dirs=$(find "$DOTFILES_CONFIG_DIR" -mindepth 1 -maxdepth 1 -type d 2>&1); then
        log.error "$pkg_dirs"
        delete_configs_failed
    elif [[ -z $pkg_dirs ]]; then
        msg.warn "Package directory not found:/"
        return
    fi

    while read -r pkg_dir; do
        if [[ -d $pkg_dir ]]; then
            pkg=$(basename "$pkg_dir")
            msg "Deleting configs: $pkg"
        else
            log.error "package directory not found: $pkg_dir"
            delete_configs_failed
        fi

        if ! src_files=$(find "$pkg_dir" -mindepth 1 -type f 2>&1); then
            log.error "$src_files"
            delete_configs_failed
        fi

        if ! src_dirs=$(find "$pkg_dir" -mindepth 1 -type d 2>&1); then
            log.error "$src_dirs"
            delete_configs_failed
        fi

        if [[ -z $src_files && -z $src_dirs ]]; then
            continue
        fi

        if [[ -n $src_files ]]; then
            while read -r src_file; do
                target="${HOME}/${src_file#"${DOTFILES_CONFIG_DIR}/$pkg/"}"
                if [[ ! -e $target ]]; then
                    continue
                elif [[ ! -L $target ]]; then
                    log.warn "not a symlink: $target"
                    continue
                else
                    if link_src=$(readlink "$target"); then
                        if [[ $link_src != "$src_file" ]]; then
                            log.warn "target is not owned by dotfiles: $target"
                            continue
                        fi
                    else
                        log.error "$cmd_result"
                        delete_config_failed
                    fi
                    if cmd_result=$(echo 'rm "$target"'); then
                        log.remove "$target"
                    else
                        log.error "$cmd_result"
                        delete_config_failed
                    fi
                fi
            done < <(echo "$src_files")
        fi

        # 空のディレクトリを削除
        if [[ -n $src_dirs ]]; then
            while read -r src_dirs; do
                target="${HOME}/${src_dirs#"${DOTFILES_CONFIG_DIR}/$pkg/"}"
                if [[ -z $(ls -A "$target") ]]; then
                    if cmd_result=$(echo 'rm -r "$target"'); then
                        log.remove "$target"
                    else
                        log.error "$cmd_result"
                        delete_config_failed
                    fi
                fi
            done < <(echo "$src_dirs")
        fi
    done < <(echo "$pkg_dirs")

    msg.complete 'Deleted config files:)'
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


###  main  ###

opt_all=false
opt_delete_configs=false

if [[ $# -eq 0 ]]; then
    opt_all=true
else
    while (($# > 0)); do
        case "$1" in
            --all) opt_all=true && break ;;
            --delete-configs) opt_delete_configs=true ;;
        esac
        shift
    done
fi

if "$opt_all"; then
    greet
    confirm_uninstall
    delete_configs
    self_destruct
    uninstall_complete
else
    "$opt_delete_configs" && delete_configs
    exit 0
fi
