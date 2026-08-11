#!/usr/bin/env bash

set -ueo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_PATH}/lib/bash/import.sh"
import log theme dotfiles msg util

theme::load
msg::init

exec_user="$(whoami)"
if [[ "$exec_user" == 'root' ]]; then
  logger --fatal "don't run this script as root:<"
  exit 1
fi

if [[ ! -t 0 ]]; then
  logger --fatal 'stdin is not connected to a tty'
  exit 1
fi

DOTFILES_UNINSTALL_DRYRUN=0

case "${1:-notset}" in
  --dryrun) DOTFILES_UNINSTALL_DRYRUN=1 ;;
  notset) :;;
  *)
    logger --fatal "invalid option: $1"
    exit 1
    ;;
esac

greet() {
  local date greet_msg

  date="$(date '+%Y/%m/%d %H:%M:%S %Z')"
  greet_msg="$(cat <<EOF
<@noprompt><@hl style="danger"><@b>
${DOTFILES_LOGO_UNINSTALL}
</@noprompt></@hl></@b>
<@br>
hello:)
this is the dotfiles uninstallation script.
date: ${date}
dotfiles path: <hl>${DOTFILES_PATH}</hl>
EOF
  )"

  msg::box -- "$greet_msg"
  newline
}

uninstall_configs() {
  local pkg_dirs pkg_dir pkg_name

  if [[ -z "${DOTFILES_CONFIG_DIR:-}" ]]; then
    logger --fatal 'DOTFILES_CONFIG_DIR is not set'
    exit 1
  fi

  pkg_dirs="$(
    find "$DOTFILES_CONFIG_DIR" \
      -mindepth 1 \
      -maxdepth 1 \
      -type d
  )"

  if [[ -z "$pkg_dirs" ]]; then
    msg::warning "package directories not found:/"
    return 0
  fi

  while read -r pkg_dir; do
    if [[ -d "$pkg_dir" ]]; then
      pkg_name="$(basename "$pkg_dir")"
      msg "removing <hl>${pkg_name}</hl> configs..."
    else
      logger --fatal "directory not found: ${pkg_dir}"
      exit 1
    fi

    local src_files src_dirs
    local src_file src_dirs src_dir target

    src_files="$(find "$pkg_dir" -mindepth 1 -type f)"
    src_dirs="$(
      find "$pkg_dir" -mindepth 1 -type d \
        | awk '{ print gsub("/", "/"), $0 }' \
        | sort -nr \
        | cut -d ' ' -f 2
    )"

    if [[ -z "$src_files" && -z "$src_dirs" ]]; then
      continue
    fi

    # シンボリックリンクの削除
    if [[ -n "$src_files" ]]; then
      while read -r src_file; do
        target="${HOME}/${src_file#"${pkg_dir}/"}"
        logger --debug "remove target config file: ${target}"

        if (( DOTFILES_UNINSTALL_DRYRUN )); then
          util::uninstall --dry-run "$src_file" "$target"
        else
          util::uninstall "$src_file" "$target"
        fi
      done <<<"$src_files"
    fi

    # 空のディレクトリを削除
    if [[ -n "$src_dirs" ]]; then
      while read -r src_dir; do
        target="${HOME}/${src_dir#"${pkg_dir}/"}"
        logger --debug "remove target dir: ${target}"

        if [[ ! -d "$target" ]]; then
          logger --debug "target dir is not exists: ${target}"
          continue
        fi

        if [[ -z "$(ls -A "$target")" ]]; then
          logger --debug "dir is empty: ${target}"
          if (( ! DOTFILES_UNINSTALL_DRYRUN )); then
            rmdir -- "$target"
          fi
          msg::rm "directory deleted: $target"
        else
          logger --debug "dir is not empty: ${target}"
        fi
      done < <(echo "$src_dirs")
    fi
  done <<<"$pkg_dirs"

  msg::ok 'configuration files uninstalled:)'
  newline
}

greet

if (( DOTFILES_UNINSTALL_DRYRUN )); then
  msg::notice 'dry-run mode is enabled.'
  msg::notice \
    'empty directories resulting from configuration removal will be removed,' \
    'but will not be shown in dry-run mode.'
fi

if msg::confirm; then
  uninstall_configs
  if (( ! DOTFILES_UNINSTALL_DRYRUN )); then
    msg::box --prompt='🛸' --base-style='success' -- 'DOTFILES UNINSTALLATION COMPLETED'
    newline
    msg 'goodbye👋'
    newline
  fi
else
  newline
  msg::box --prompt='👾' --base-style='abort' -- 'UNINSTALLATION ABORTED'
  exit 1
fi
