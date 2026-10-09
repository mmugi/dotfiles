#!/usr/bin/env bash
#
# bash 用のプロンプト設定を生成し、標準出力にそのままコピー&ペーストできる形式で出力します。
# (git-completionのシェル設定生成は scripts/git/git-completion-conf.sh を参照)
#
# gitに内包される git-prompt が見つかった場合、それをsourceしてgit連携のPS1を
# exportする設定を出力します。見つからない場合、gitのブランチ情報を含まない
# デフォルトのPS1を出力します。

set -ueo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_PATH:?}/lib/bash/import.sh"
import cmd msg theme

if [[ -t 2 ]]; then
  # shellcheck disable=SC2034
  TERMCAP_COLOR_MODE=always
fi

theme::load

hl="${STYLE[msg_highlight]}"
base="${STYLE[normal]}"

find_git_prompt() {
  # git-prompt のパスを出力する。見つからなければ 1 を返す。
  # 使っている git に付属するものを先に探す。Homebrew は exec-path が
  # バージョン付きの Cellar を指すため、バージョンを含まない opt 側を見る。
  local exec_path brew_prefix candidate
  local -a candidates=()

  if exec_path="$(git --exec-path 2>/dev/null)"; then
    candidates+=(
      # Debian / Ubuntu
      "${exec_path}/git-sh-prompt"
      # RHEL 系 (Rocky Linux など)
      "${exec_path%/*/*}/share/git-core/contrib/completion/git-prompt.sh"
      # Apple の Command Line Tools / Xcode
      "${exec_path%/*/*}/share/git-core/git-prompt.sh"
    )
  fi

  if command -v brew >/dev/null 2>&1 && brew_prefix="$(brew --prefix git 2>/dev/null)"; then
    candidates+=( "${brew_prefix}/etc/bash_completion.d/git-prompt.sh" )
  fi

  for candidate in "${candidates[@]}"; do
    if [[ -r "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

generate_prompt_conf() {
  local mode="$1"
  local default_ps1='[\D{%FT%T%z}] \u@\h \w \[\e[38;2;148;140;243m\]>\[\e[m\] '

  case "$mode" in
    default)
      cat <<EOF
# shell prompt
export PS1='${default_ps1}'
EOF
      ;;

    git)
      local prompt_path
      printf -v prompt_path '%q' "$2"

      # git-prompt が消えたとき (git の更新など) に __git_ps1 を呼ばないよう、
      # PS1 の設定も読み込みの成否で分ける
      cat <<EOF
# shell prompt
if [[ -r ${prompt_path} ]]; then
  source ${prompt_path}

  export GIT_PS1_SHOWDIRTYSTATE=1
  export GIT_PS1_SHOWSTASHSTATE=1
  export GIT_PS1_SHOWUNTRACKEDFILES=1
  export GIT_PS1_SHOWUPSTREAM='auto'

  export PS1='[\D{%FT%T%z}] \u@\h \w\$(__git_ps1 " \[\e[2m\](%s)\[\e[22m\]") \[\e[38;2;148;140;243m\]>\[\e[m\] '
else
  export PS1='${default_ps1}'
fi
EOF
      ;;

    *)
      msg::error "invalid mode: ${mode}"
      return 1
      ;;
  esac
}

# `{ ... } >&2` ブロックの内側ではfd 1がfd 2にダップされるため、
# ブロックに入る前に本来のstdoutがttyかを判定しておく
stdout_is_tty=0
[[ -t 1 ]] && stdout_is_tty=1

# 検索過程のメッセージは標準エラー出力に流し、標準出力には
# 生成されたシェル設定のみが出力されるようにする
# (そのまま `>> ~/.bashrc` のようにリダイレクトして利用できるようにするため)
{
  git_prompt_path=

  if cmd::check git; then
    msg "searching for git-prompt..."
    if ! git_prompt_path="$(find_git_prompt)"; then
      msg::warn 'git-prompt not found.'
    fi
  fi

  if [[ -n "$git_prompt_path" ]]; then
    msg "generating git-aware prompt configuration..."
    config="$(generate_prompt_conf 'git' "$git_prompt_path")"
  else
    msg "generating default prompt configuration..."
    config="$(generate_prompt_conf 'default')"
  fi

  if (( stdout_is_tty )); then
    msg::notice "add the following lines to your ${hl}~/.bashrc${base} (or equivalent)."
  else
    msg::notice 'stdout is redirected. writing the generated configuration directly to it.'
  fi
} >&2

printf '%s\n' "$config"

if (( ! stdout_is_tty )); then
  msg::ok 'configuration written.' >&2
fi
