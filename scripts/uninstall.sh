#!/usr/bin/env bash

set -Eueo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_PATH}/libs/bash/import.sh"
import dotfiles log msg

if [ -z "${BASH_VERSION:-}" ]; then
  abort "Bash is required to interpret this script."
fi

: "${DOTFILES_UNINSTALL_DRYRUN:=false}"
: "${DOTFILES_UNINSTALL_COLOR:="$ESC_C_CRITICAL"}"

case "${1:-notset}" in
  --dryrun) DOTFILES_UNINSTALL_DRYRUN=true ;;
  notset) :;;
  *) abort "invalid option: $1" ;;
esac

# shellcheck disable=SC2034
MSG_LOGO="$(cat <<LOGO
 _______ _______ _______ _______ _______ _______ _______ _____   _____
|   |   |    |  |_     _|    |  |     __|_     _|   _   |     |_|     |_
|   |   |       |_|   |_|       |__     | |   | |       |       |       |
|_______|__|____|_______|__|____|_______| |___| |___|___|_______|_______|

LOGO
)"

exec_user="$(whoami)"
[[ "$exec_user" == 'root' ]] && abort "don't run this script as root"
[[ ! -t 0 ]] && abort 'stdin is not connected to a tty'

greet() {
  MSG_INDENT=2 \
    msg::box --logo --top-padding --bot-padding --base-color "$DOTFILES_UNINSTALL_COLOR" \
      'hello:)' \
      'this is the dotfiles uninstallation script.' \
      "date: <b><hl>$(date '+%Y/%m/%d %H:%M:%S %Z')</hl></b>" \
      "dotfiles path: <b><hl>${DOTFILES_PATH}</b></hl>"

  if [[ "$DOTFILES_UNINSTALL_DRYRUN" == 'true' ]]; then
    msg::box \
      'dryrun mode is enabled.' \
      "${ESC_C_WARNING}  empty directories resulting from configuration removal will be removed," \
      "${ESC_C_WARNING}  but will not be shown in dry-run mode."
  fi
  newline
}

remove_configs() {
  local pkg pkg_dir pkg_dirs

  msg -p 'removing configuration files'

  pkg_dirs="$(find "$DOTFILES_CONFIG_DIR" \
                   -mindepth 1 \
                   -maxdepth 1 \
                   -type d)"

  if [[ -z "$pkg_dirs" ]]; then
    msg::abort "package directories not found:/"
  fi

  while read -r pkg_dir; do
    if [[ -d "$pkg_dir" ]]; then
      pkg="$(basename "$pkg_dir")"
      msg -2 "config: <b><hl>${pkg}</hl></b>"
      log::debug "pkg_dir: ${pkg_dir}/"
    else
      abort "package directory not found: ${pkg_dir}/"
    fi

    local src_files src_file
    local src_dirs src_dir

    src_dirs="$(find "$pkg_dir" -mindepth 1 -type d)"
    src_files="$(find "$pkg_dir" -mindepth 1 -type f)"

    [[ -z $src_files && -z $src_dirs ]] && continue

    local relpath target

    if [[ -n "${src_files:-}" ]]; then
      while read -r src_file; do
        relpath="${src_file#"${pkg_dir}/"}"
        target="${HOME}/${relpath}"
        log::debug "remove target config file: ${target}"

        if [[ ! -e "$target" ]]; then
          log::debug "target file is not exists: ${target}"
          continue
        fi

        if [[ ! -L "$target" ]]; then
          msg::notice --skip "symlink points outside dotfiles: ${target}"
          continue
        else
          src_link="$(realpath "$target")"
          log::debug "target realpath: ${src_link}"
          if [[ "$src_link" == "$src_file" ]]; then
            [[ "$DOTFILES_UNINSTALL_DRYRUN" == 'true' ]] || unlink -- "$target"
            msg::notice --unlink "$target"
          else
            msg::notice --skip "symlink points outside dotfiles: ${target}"
            continue
          fi
        fi
      done < <(echo "$src_files")
    fi

    # 空のディレクトリを削除
    if [[ -n "${src_dirs:-}" ]]; then
      while read -r src_dir; do
        relpath="${src_dir#"${pkg_dir}/"}"
        target="${HOME}/${relpath}"
        log::debug "remove target dir: ${target}/"
        if [[ ! -d "$target" ]]; then
          log::debug "target dir is not exists: ${target}/"
          continue
        else
          if [[ -z "$(ls -A "$target")" ]]; then
            log::debug "dir is empty: ${target}/"
            [[ "$DOTFILES_UNINSTALL_DRYRUN" == 'true' ]] || rmdir -- "$target"
            msg::notice --rmdir "${target}/"
          else
            log::debug "dir is not empty: ${target}/"
          fi
        fi
      done < <(echo "$src_dirs")
    fi
  done < <(echo "$pkg_dirs")
  msg::marker --complete 'configuration files removal completed:)'
}

# DOTFILES_PATH の環境変数でディレクトリを rm -rf で削除するのは、変数次第で怖かったので
# 手動で削除する方針にします。
#self_destruct() {
#  if [[ ! -d "$DOTFILES_PATH" ]]; then
#    log::abort "dotfiles directory not found: ${DOTFILES_PATH}"
#  fi
#
#  if msg::confirm "do you really want to delete <b><hl>${DOTFILES_PATH}</hl></b>?"; then
#    msg -p -b --base-color "$DOTFILES_UNINSTALL_COLOR" 'self-destructing'
#
#    local dotfiles_dirname script_path
#
#    dotfiles_dirname="$(basename "$DOTFILES_PATH")"
#    log::debug "dotfiles_dirname: ${dotfiles_dirname}"
#
#    script_path="$(realpath "$0")"
#    log::debug "script path: ${script_path}"
#
#    if ! [[ "${DOTFILES_PATH}/scripts/uninstall.sh" == "$script_path" ]]; then
#      abort "uninstallation script path mismatch: ${script_path}"
#      exit 1
#    fi
#
#    if ! [[ "$dotfiles_dirname" =~ .*dotfiles.* ]]; then
#      abort "the target directory may not be a dotfiles directory: ${DOTFILES_PATH}"
#      exit 1
#    fi
#
#    ### DANGER ###
#    #rm -rf "$DOTFILES_PATH"
#    ### DANGER ###
#
#    msg::marker --complete 'dotfiles deleted:)'
#  else
#    msg::marker --terminate 'self-destruction aborted!'
#    exit 1
#  fi
#}

greet
msg 'starting dotfiles uninstallation.'
if msg::confirm -r; then
  newline
  remove_configs
  #self_destruct
  msg -b --base-color "$ESC_C_COMPLETE" 'goodbye👋'
  newline
else
  msg::marker --terminate 'uninstallation aborted!'
  exit 1
fi
