#!/usr/bin/env bash

set -ueo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
  printf "\033[1;31m%s\033[0m\n" 'please run this script with bash;('
  exit 1
fi

exec_user="$(whoami)"
if [[ "$exec_user" == 'root' ]]; then
  printf "\033[1;31m%s\033[0m\n" "don't run this script as root:<"
  exit 1
fi

declare -r GITHUB_USERNAME='mmugi'
declare -r GITHUB_EMAIL='173437276+mmugi@users.noreply.github.com'

# shellcheck source=/dev/null
source "${DOTFILES_PATH:?}/lib/bash/import.sh"
import theme msg dotfiles util

_nextstep() {
  # 次にユーザーがやることを案内するだけの関数。
  # 案内の内容によって成否が変わる(衝突は失敗、パス未定義はインストール成功後の
  # 案内)ため、終了コードは呼び出し側で決める。

  [[ -z "${1:-}" ]] && { logger --error 'missing scenario'; return 1; }

  local header msg
  header="$(cat <<EOF
<@noprompt>
<hl style="warning">⚡️ next steps!</hl>

</@noprompt>
EOF
  )"

  case "$1" in
    --undefined-dotfiles-path)
      msg="$(cat <<EOF
${header}
please define <hl>DOTFILES_PATH</hl> in your shell config file.
export DOTFILES_PATH="\${HOME}/.dotfiles"
EOF
      )"
      msg::box -- "$msg"
      ;;
    --config-conflict)
      msg="$(cat <<EOF
${header}
configuration files already exist.
please do one of the following:
 -> move the configuration files out of the target directory.
 -> add them to <hl>${DOTFILES_PATH}/.dotignore</hl> to ignore them.
EOF
      )"
      msg::box -- "$msg"
      ;;
    *)
      logger --error "invalid scenario: $1"
      return 1
      ;;
  esac
}

greet() {
  local date
  local greet_msg

  date="$(date '+%Y/%m/%d %H:%M:%S %Z')"
  greet_msg="$(cat <<EOF
<@noprompt><@hl style="logo"><@b>
${DOTFILES_LOGO}

</@noprompt></@hl></@b>
hello:)
this is the dotfiles installation script.
date: ${date}
dotfiles path: <hl>${DOTFILES_PATH}</hl>
EOF
  )"
  msg::box -- "$greet_msg"
  msg::newline
}

configure_git_for_dotfiles() {
  [[ -d "${DOTFILES_PATH}/.git" ]] || return 0

  local warnings_occurred=0

  msg::header 'git configuration for dotfiles'

  msg 'installing git-hooks...'

  local src_hooks src dst filename

  src_hooks="$(find "$DOTFILES_GITHOOKS_DIR" -mindepth 1 -type f)"
  while read -r src; do
    filename="$(basename "$src")"
    dst="${DOTFILES_PATH}/.git/hooks/${filename}"
    util::install "$src" "$dst" || warnings_occurred=1
  done <<<"$src_hooks"

  msg 'configuring git username...'

  local -r gitconfig_local="${DOTFILES_PATH}/.git/config"
  local username user_email

  if username="$(git config --file "$gitconfig_local" user.name)"; then
    if [[ "$username" != "$GITHUB_USERNAME" ]]; then
      msg::warning "user.name already configured: ${username}"
      warnings_occurred=1
    fi
  else
    git config --file "$gitconfig_local" user.name "$GITHUB_USERNAME"
    msg::changed "configured: user.name: ${GITHUB_USERNAME}"
  fi

  msg 'configuring git user email...'
  if user_email=$(git config --file "$gitconfig_local" user.email); then
    if [[ "$user_email" != "$GITHUB_EMAIL" ]]; then
      msg::warning "user.email already configured: ${user_email}"
      warnings_occurred=1
    fi
  else
    git config --file "$gitconfig_local" user.email "$GITHUB_EMAIL"
    msg::changed "configured: user.email: ${GITHUB_EMAIL}"
  fi

  if (( warnings_occurred )); then
    msg::warning 'some non-critical issues occurred:/'
  else
    msg::ok 'git configured for dotfiles:)'
  fi

  msg::newline
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
  # それらのディレクトリを作成します。
  #
  # 配置先のパスに、ファイルもしくは DOTFILES_CONFIG_DIR で管理されない
  # シンボリックリンクが既に存在する場合、全コンフィグのデプロイは中断されます。
  # 続行するには、既存のファイルを退避/削除する、もしくは
  # ${DOTFILES_PATH}/.dotignore に無視したいコンフィグを指定して再実行します。
  #
  # .dotignore ファイルは、記載されたコンフィグのパスがコンフィグ配置先の相対
  # パスと前方一致する場合に、該当パスのコンフィグ配置処理をスキップします。
  # また、空行および # から始まる行は無視されます。

  local pkg_dirs pkg_dir pkg_name config_dir
  local src_configs src config_relpath_fromhome dst
  local conflict=0

  msg::header 'configuration file installation'

  [[ -z "${DOTFILES_CONFIG_DIR:-}" ]] && logger --fatal 'DOTFILES_CONFIG_DIR is not set'

  msg 'checking configuration files to be installed...'

  # 探索ルートは公開分だけとは限らない。dotfiles::config_dirs が
  # プライベートリポジトリの configs も含めて返す。
  pkg_dirs="$(
    while read -r config_dir; do
      find "$config_dir" -mindepth 1 -maxdepth 1 -type d
    done < <(dotfiles::config_dirs)
  )"

  if [[ -z "$pkg_dirs" ]]; then
    msg::warning 'package directories not found:/'
    return 0
  fi

  while read -r pkg_dir; do
    [[ ! -d "$pkg_dir" ]] && logger --fatal "directry not found: ${pkg_dir}"

    src_configs="$(find "$pkg_dir" -mindepth 1)"

    if [[ -z "$src_configs" ]]; then
      continue
    fi

    while read -r src; do
      config_relpath_fromhome="${src#"${pkg_dir}/"}"
      dst="${HOME}/${config_relpath_fromhome}"

      if dotfiles::is_ignored "$config_relpath_fromhome"; then
        continue
      else
        util::install --check "$src" "$dst" || conflict=1
      fi
    done <<<"$src_configs"
  done <<<"$pkg_dirs"

  if (( conflict )); then
    msg::warning 'conflicting files detected:/'
    msg::newline
    _nextstep --config-conflict
    # 何も配置せずに中断するため、失敗として終了する。
    # 0で返すと make install が成功扱いになってしまう。
    exit 1
  fi

  # installation
  #
  # 同じパッケージ名が複数の探索ルートに存在しうる (公開分と private overlay)。
  # 由来ごとに見出しを出すと同じパッケージが分かれて見えるため、パッケージ名で
  # まとめる。どのルートから来たかは、リンク先のパスとして各行に出る。
  local pkg_names
  pkg_names="$(while read -r pkg_dir; do basename -- "$pkg_dir"; done <<<"$pkg_dirs" | sort -u)"

  while read -r pkg_name; do
    msg "installing <hl>${pkg_name}</hl> configs..."

    while read -r pkg_dir; do
      [[ "$(basename -- "$pkg_dir")" == "$pkg_name" ]] || continue

      src_configs="$(find "$pkg_dir" -mindepth 1)"

      if [[ -z "$src_configs" ]]; then
        msg::skipped "package directory is empty: ${pkg_dir}"
        continue
      fi

      while read -r src; do
        config_relpath_fromhome="${src#"${pkg_dir}/"}"
        dst="${HOME}/${config_relpath_fromhome}"

        if [[ "$src" =~ \.swp$ ]]; then
          continue
        elif dotfiles::is_ignored "$config_relpath_fromhome"; then
          msg::skipped "skipped: ${HOME}/${config_relpath_fromhome}"
          continue
        else
          util::install "$src" "$dst"
        fi
      done <<<"$src_configs"
    done <<<"$pkg_dirs"
  done <<<"$pkg_names"

  msg::ok 'configuration files installed:)'
  msg::newline
}

theme::load
msg::init

greet
configure_git_for_dotfiles
install_configs

if (( ${DOTFILES_PATH_UNDEFINED:-0} )); then
  _nextstep --undefined-dotfiles-path
else
  msg::box --prompt='🛸' --base-style='success' -- 'DOTFILES INSTALLATION COMPLETED'
fi
