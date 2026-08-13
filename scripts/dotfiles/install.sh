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
import theme msg dotfiles util shellconf

# フックがまだ入っていないシェル。install_shell_configs が積み、
# 最後の案内で参照する。
declare -a SHELL_HOOK_PENDING=()

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
    --duplicate-config)
      msg="$(cat <<EOF
${header}
the same destination is provided by more than one config root.
a private overlay adds configuration files, it does not replace them.
please do one of the following:
 -> remove the duplicate from one of the config roots.
 -> add it to <hl>${DOTFILES_PATH}/.dotignore</hl> to ignore them.
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

    --shell-hook)
      # dotfiles は ~/.bashrc を所有しない。既存の設定ファイルを書き換えずに
      # 済むよう、利用者が足すのは1行フックだけにしている。
      #
      # 貼り付けてもらう部分なので <@noprompt> で囲み、行頭にプロンプトが
      # 付かないようにする。
      local shell rcfile hooks=''

      for shell in "${SHELL_HOOK_PENDING[@]}"; do
        rcfile="$(shellconf::hook_rcfile "$shell")"
        hooks+=$'\n'" -> ${rcfile/#"${HOME}"/\~}"$'\n'
        hooks+="$(shellconf::hook_block "$shell")"$'\n'
      done
      hooks+=$'\n'

      msg="$(cat <<EOF
${header}
add the dotfiles hook to your shell config file.
<@noprompt>${hooks}</@noprompt>
run <hl>make shell-hook TARGET_SHELL=NAME</hl> to print it again.
fish needs no hook. conf.d is loaded automatically.
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
  local duplicate=0

  # 配置先ごとに、それを提供する探索ルート側のパスを覚えておく。
  # util::install --check はリンクを作らないため、複数のルートが同じ配置先を
  # 持っていても衝突として検出できない。ここで自前に突き合わせる。
  local -A provided_by=()

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
      fi

      # ディレクトリは各ルートに存在してよい (どのルートも .config などを
      # 持つ)。重複として扱うのはファイルだけ。
      if [[ ! -d "$src" ]]; then
        if [[ -n "${provided_by["$dst"]:-}" ]]; then
          msg::warning "provided by multiple config roots: ${dst}"
          msg --no-prompt --indent 5 -- "${provided_by["$dst"]}"
          msg --no-prompt --indent 5 -- "${src}"
          duplicate=1
          continue
        fi
        provided_by["$dst"]="$src"
      fi

      util::install --check "$src" "$dst" || conflict=1
    done <<<"$src_configs"
  done <<<"$pkg_dirs"

  # 原因が異なるため、警告も next step も別々に出す。
  # duplicate はコンフィグ側の重複、conflict は配置先に既にあるファイルとの衝突。
  if (( duplicate )); then
    msg::warning 'duplicate destinations detected:/'
  fi

  if (( conflict )); then
    msg::warning 'conflicting files detected:/'
  fi

  if (( duplicate || conflict )); then
    msg::newline

    if (( duplicate )); then
      _nextstep --duplicate-config
    fi

    if (( conflict )); then
      _nextstep --config-conflict
    fi

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

install_shell_configs() {
  # シェル設定は configs/ 配下ではなく shell/{env.d,rc.d} のレジストリから
  # 生成する。configs/ の walk には乗らないため、git-hooks と同様に
  # util::install で直接配置する。
  #
  # 生成物は run/ 配下に置く。マシン固有の絶対パス (git-prompt.sh の場所など)
  # が焼き込まれるため、git 管理下に置いてはいけない。
  #
  # 生成し直すだけで配置し直しは不要になるよう、配置はシンボリックリンクで行う。

  local src relpath dst dstdir part current shell
  local conflict=0

  msg::header 'shell configuration'

  msg 'generating shell configuration...'
  if ! shellconf::generate_all; then
    logger --fatal 'failed to generate shell configuration'
    exit 1
  fi

  msg 'checking shell configuration to be installed...'

  while IFS=$'\t' read -r src relpath; do
    dotfiles::is_ignored "$relpath" && continue
    util::install --check "$src" "${HOME}/${relpath}" || conflict=1
  done < <(shellconf::outputs)

  if (( conflict )); then
    msg::warning 'conflicting files detected:/'
    msg::newline
    _nextstep --config-conflict
    exit 1
  fi

  msg 'installing shell configuration...'

  while IFS=$'\t' read -r src relpath; do
    dst="${HOME}/${relpath}"

    if dotfiles::is_ignored "$relpath"; then
      msg::skipped "skipped: ${dst}"
      continue
    fi

    # 配置先のディレクトリはレジストリ側に現れないため、ここで作る。
    # configs の配置と同じくパーミッションは 700 とする。
    #
    # mkdir -p は中間ディレクトリに -m を適用しないため、1階層ずつ作る。
    dstdir="$(dirname -- "$dst")"
    if [[ ! -d "$dstdir" ]]; then
      current="$HOME"
      while IFS= read -r part; do
        [[ -z "$part" ]] && continue
        current="${current}/${part}"
        [[ -d "$current" ]] && continue

        if ! mkdir -m 700 -- "$current"; then
          logger --fatal "failed to create directory: ${current}"
          exit 1
        fi
        msg::changed "directory created: ${current}"
      done < <(printf '%s\n' "${relpath%/*}" | tr '/' '\n')
    fi

    util::install "$src" "$dst"
  done < <(shellconf::outputs)

  # フックの案内は、まだ入っていないシェルについてだけ出す。
  # 導入済みのマシンで毎回出さないため。使わないシェルは配置先を .dotignore に
  # 書けば、配置とあわせて案内も止まる。
  for shell in bash zsh; do
    dotfiles::is_ignored ".config/shell/rc.${shell}" && continue
    shellconf::hook_installed "$shell" && continue
    SHELL_HOOK_PENDING+=( "$shell" )
  done

  msg::ok 'shell configuration installed:)'
  msg::newline
}

theme::load
msg::init

greet
configure_git_for_dotfiles
install_configs
install_shell_configs

if (( ${#SHELL_HOOK_PENDING[@]} > 0 )); then
  _nextstep --shell-hook
fi

if (( ${DOTFILES_PATH_UNDEFINED:-0} )); then
  _nextstep --undefined-dotfiles-path
else
  msg::box --prompt='🛸' --base-style='success' -- 'DOTFILES INSTALLATION COMPLETED'
fi
