#!/usr/bin/env bash

set -Eueo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
  printf "\033[1;31m%s\033[0m\n" 'please run this script with bash;('
  exit 1
fi

# shellcheck source=/dev/null
source "${DOTFILES_PATH:?}/libs/bash/import.sh"

import dotfiles esc log msg util

readonly GITHUB_USERNAME='mmugi'
readonly GITHUB_EMAIL='173437276+mmugi@users.noreply.github.com'

exec_user="$(whoami)"
[[ "$exec_user" == 'root' ]] && abort "don't run this script as root"
[[ ! -t 0 ]] && abort 'stdin is not connected to a tty'

_nextstep() {
  [[ -z "${1:-}" ]] && abort 'scenario argument is required'
  msg::line "$DOTFILES_LOGO_WIDTH"
  newline
  printf ' %s%s%s\n\n' \
    "${ESC_ATTR_BOLD}${ESC_C_COMPLETE}*${ESC_C_BASE}" \
    " next steps! " \
    "${ESC_ATTR_BOLD}${ESC_C_COMPLETE}*${ESC_RESET}"
  case "$1" in
    --undefined-dotfiles-path)
      cat <<'EOF'
Please define it in your shell config file:

  export DOTFILES_PATH="$HOME/.dotfiles"
EOF
      exit 0
      ;;
    --symlink-conflict)
      cat <<EOF
Configuration files are already present.
Please do one of the following:

  - Move the configuration files out of the target directory.
  - Configure '${DOTFILES_PATH}/.dotignore' to ignore them.
EOF
      exit 1
      ;;
    *)
      abort "invalid scenario: $1"
      ;;
  esac
}

#set_platform() {
#  local silent=false
#  local os
#  [[ "${1:-}" == '-q' ]] && silent=true
#  [[ "$silent" == 'false' ]] && msg -n -p 'detecting platform'
#  os="$(uname -o)"
#  case "$os" in
#    Darwin)    DOTFILES_PLATFORM='macos' ;;
#    GNU/Linux) DOTFILES_PLATFORM='linux' ;;
#    *) newline; abort "unknown os: $os" ;;
#  esac
#  [[ "$silent" == 'false' ]] && msg -r --result="$DOTFILES_PLATFORM" 'detecting platform'
#}

greet() {
  local -r greeting_messages=(
    'hello:)'
    'this is the dotfiles installation script.'
    "date: <b><hl>$(date '+%Y/%m/%d %H:%M:%S %Z')</hl></b>"
    "DOTFILES_PATH: <b><hl>${DOTFILES_PATH}</hl></b>"
  )
  msg::line "$DOTFILES_LOGO_WIDTH"
  msg -b --no-prompt "$DOTFILES_LOGO"
  newline
  for msg in "${greeting_messages[@]}"; do
    msg "$msg"
  done
  #set_platform
  newline
  msg::line "$DOTFILES_LOGO_WIDTH"
  newline
}

configure_git_for_dotfiles() {
  if [[ -d "${DOTFILES_PATH}/.git" ]]; then
    msg 'starting git configuration for dotfiles.'
  else
    return 0
  fi

  msg -p 'installing git-hooks'

  local src dst src_hooks hookfile
  local install_hooks_failed=false

  src_hooks="$(find "$DOTFILES_GITHOOKS_DIR" -mindepth 1 -type f)"
  while read -r src; do
    hookfile="$(basename "$src")"
    dst="${DOTFILES_PATH}/.git/hooks/${hookfile}"
    util::install "$src" "$dst" || install_hooks_failed=true
  done < <(echo "$src_hooks")

  if [[ "$install_hooks_failed" == 'true' ]]; then
    abort 'hooks installation failed.'
  fi

  msg -p 'configuring git username'

  local username user_email
  local configure_git_failed=false
  local -r gitconfig_local="${DOTFILES_PATH}/.git/config"

  if username=$(git config --file "$gitconfig_local" user.name); then
    if ! [[ "$username" == "$GITHUB_USERNAME" ]]; then
      log.warn "user.name already configured: ${username}"
    fi
  else
    git config --file "$gitconfig_local" user.name "$GITHUB_USERNAME"
    msg -2 "user.name: ${ESC_ATTR_BOLD}<hl>${GITHUB_USERNAME}</hl>"
  fi

  msg -p 'configuring git user email'

  if user_email=$(git config --file "$gitconfig_local" user.email); then
    if ! [[ "$user_email" == "$GITHUB_EMAIL" ]]; then
      log.warn "user.email already configured: ${user_email}"
    fi
  else
    git config --file "$gitconfig_local" user.email "$GITHUB_EMAIL"
    msg -2 "user.email: ${ESC_ATTR_BOLD}<hl>${GITHUB_EMAIL}</hl>"
  fi

  if [[ "$configure_git_failed" == 'true' ]]; then
    abort 'git configuration failed.'
  fi

  msg::complete 'git configured for dotfiles:)'
}

install_configs() {
  # DOTFILES_CONFIG_DIR で管理されるコンフィグファイルの
  # シンボリックリンクを配置します。
  #
  # DOTFILES_CONFIG_DIR には、配置するコンフィグファイルのパッケージごとに
  # ディレクトリを作成し、コンフィグファイルを配置します。
  # これらのコンフィグファイルは、ホームディレクトリからの相対パスと同じ
  # ディレクトリ構成となるように配置します。
  #
  # ディレクトリ構成例:
  #   configs
  #   ├── git
  #   |   └── .config
  #   |       └── git
  #   |           └── config
  #   ├── vim
  #   |   └── .vimrc
  #   ...
  #
  # 途中のディレクトリが存在しない場合、ディレクトリをパーミッション 700 で
  # それらのディレクトリを作成されます。
  #
  # 配置先のパスに、ファイルもしくは DOTFILES_CONFIG_DIR で管理されない
  # シンボリックリンクが既に存在する場合、全コンフィグのデプロイは中断されます。
  # 続行するには、既存のファイルを退避/削除後するもしくは
  # ${DOTFILES_PATH}/.dotignore に無視したいコンフィグを指定して再実行します。
  #
  # .dotignore ファイルは、記載されたコンフィグのパスがコンフィグ配置先の相対
  # パスと前方一致する場合に、該当パスのコンフィグ配置処理をスキップします。
  # また、空行および # から始まる行は無視されます。

  local config_relpath_fromhome
  local conflict=false
  local pkg pkg_dir pkg_dirs
  local src src_configs
  local dst

  install_configs_failed() { abort 'config installation failed;('; }

  _check_ignore() {
    # usage: _check_ignore config_relpath_from_home
    #
    # 引数として入力されたコンフィグのパスが、DOTFILES_PATH ディレクトリに配置
    # される .dotignore ファイルに含まれるかどうか判定します。
    # 引数のコンフィグは、ホームディレクトリからの相対パスで指定します。
    # .dotignore に記載のパスと前方一致する場合、trueを返します。

    local -r ignorefile="${DOTFILES_PATH}/.dotignore"
    local config_relpath_from_home

    [[ $# -ne 1 ]] && abort "_check_ignore: invalid args"

    config_relpath_from_home="$1"

    [[ -s "$ignorefile" ]] || return

    while read -r pattern; do
      [[ -z "$pattern" || "$pattern" =~ ^# ]] && continue
      [[ "$config_relpath_from_home" =~ ^$pattern ]] && return 0
    done < "$ignorefile"
    return 1
  }

  msg 'starting installation of the configuration files.'

  [[ -z "${DOTFILES_CONFIG_DIR:-}" ]] && abort 'DOTFILES_CONFIG_DIR is not set'

  msg -p 'checking configuration files to be installed'
  pkg_dirs="$(find "$DOTFILES_CONFIG_DIR" -mindepth 1 -maxdepth 1 -type d)"
  if [[ -z "$pkg_dirs" ]]; then
    msg::warn 'package directories not found:/'
    return 0
  fi

  while read -r pkg_dir; do
    [[ -d "$pkg_dir" ]] || abort "package directry not found: ${pkg_dir}"

    src_configs="$(find "$pkg_dir" -mindepth 1)"
    if [[ -z "$src_configs" ]]; then
      log.warn "package directory is empty: ${pkg_dir}"
      continue
    fi

    while read -r src; do
      config_relpath_fromhome="${src#"${pkg_dir}/"}"
      dst="${HOME}/${config_relpath_fromhome}"
      if _check_ignore "$config_relpath_fromhome"; then
        continue
      else
        util::install --dry-run "$src" "$dst" || conflict=true
      fi
    done < <(echo "$src_configs")
  done < <(echo "$pkg_dirs")

  if [[ "$conflict" == 'true' ]]; then
    msg::warn 'conflicting files detected:/'
    _nextstep --symlink-conflict
  fi

  msg -p 'starting configuration files installation'

  while read -r pkg_dir; do
    if [[ -d "$pkg_dir" ]]; then
      pkg=$(basename "$pkg_dir")
      msg -2 "configs: ${ESC_ATTR_BOLD}<hl>${pkg}</hl>"
    else
      abort "package directry not found: ${pkg_dir}"
    fi

    src_configs="$(find "$pkg_dir" -mindepth 1)"
    [[ -z "$src_configs" ]] && continue

    while read -r src; do
      config_relpath_fromhome="${src#"${pkg_dir}/"}"
      dst="${HOME}/${config_relpath_fromhome}"
      if [[ "$src" =~ \.swp$ ]]; then
        continue
      elif _check_ignore "$config_relpath_fromhome"; then
        util::log --ignore "${HOME}/${config_relpath_fromhome}"
        continue
      else
        util::install "$src" "$dst"
      fi
    done < <(echo "$src_configs")
  done < <(echo "$pkg_dirs")
  msg::complete 'configuration files installed:)'
}

# --- main ---

greet
configure_git_for_dotfiles
install_configs
msg -b -c "$ESC_C_COMPLETE" --prompt-char='>' 'DOTFILES SETUP COMPLETED!'

if [[ -n "${DOTFILES_PATH_UNDEFINED:-}" \
      && "$DOTFILES_PATH_UNDEFINED" == 'true' ]]
then
  newline
  _nextstep --undefined-dotfiles-path
fi
