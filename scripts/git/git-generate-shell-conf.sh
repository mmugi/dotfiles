#!/usr/bin/env bash

set -ueo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_PATH}/lib/bash/import.sh"
import util msg theme

if [[ -t 2 ]]; then
  TERMCAP_COLOR_MODE=always
fi

msg::init
theme::load

# gitに内包される git-completion / git-prompt をsourceし、PS1をexportする
# シェル設定を生成し、標準出力にそのままコピー&ペーストできる形式で出力します。
#
# 対応シェルを追加する場合:
#   1. GIT_SHELL_CONF_SUPPORTED_SHELLS にシェル名を追加する
#   2. `_git_shell_conf_render_<シェル名>()` を実装する

declare -ra GIT_SHELL_CONF_SUPPORTED_SHELLS=( bash )

usage() {
  cat <<EOF
usage: $(basename "$0") [--shell <name>]

  --shell <name>   出力するシェルの種類を指定します (default: bash)
                    対応シェル: ${GIT_SHELL_CONF_SUPPORTED_SHELLS[*]}
EOF
}

_git_shell_conf_search_dirs() {
  # git-completion.bash / git-prompt.sh が配置されていそうなディレクトリの候補を列挙する
  local -a dirs=()
  local exec_path git_bin git_bin_dir brew_prefix

  if exec_path="$(git --exec-path 2>/dev/null)"; then
    dirs+=(
      "$exec_path"
      "${exec_path}/../../share/git-core"
    )
  fi

  if git_bin="$(command -v git 2>/dev/null)"; then
    git_bin_dir="$(dirname "$(realpath "$git_bin")")"
    dirs+=(
      "${git_bin_dir}/../share/git-core"
      "${git_bin_dir}/../../share/git-core"
    )
  fi

  if util::chk -cq brew && brew_prefix="$(brew --prefix git 2>/dev/null)"; then
    dirs+=(
      "${brew_prefix}/share/git-core"
      "${brew_prefix}/etc/bash_completion.d"
    )
  fi

  dirs+=(
    /opt/homebrew/share/git-core
    /opt/homebrew/etc/bash_completion.d
    /usr/local/share/git-core
    /usr/local/etc/bash_completion.d
    /usr/share/git-core
    /usr/share/doc/git/contrib/completion
    /usr/share/bash-completion/completions
    /etc/bash_completion.d
    /opt/local/share/git-core
    /opt/local/etc/bash_completion.d
  )

  local dir resolved
  local -A seen=()
  for dir in "${dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    resolved="$(cd "$dir" 2>/dev/null && pwd -P)" || continue
    [[ -n "${seen["$resolved"]:-}" ]] && continue
    seen["$resolved"]=1
    printf '%s\n' "$resolved"
  done
}

_git_shell_conf_locate() {
  # usage: _git_shell_conf_locate <filename>
  # 結果は GIT_SHELL_CONF_RESULT にセットされる。
  # (内部の標準出力への書き込みが混ざらないようにグローバル変数で受け渡す)

  local filename="$1"
  local -a search_dirs=() found=()
  local dir hit

  GIT_SHELL_CONF_RESULT=

  while IFS= read -r dir; do
    search_dirs+=( "$dir" )
  done < <(_git_shell_conf_search_dirs)

  (( ${#search_dirs[@]} == 0 )) && return 1

  while IFS= read -r -d '' hit; do
    found+=( "$hit" )
  done < <(find "${search_dirs[@]}" -maxdepth 3 -type f -name "$filename" -print0 2>/dev/null)

  case "${#found[@]}" in
    0) return 1 ;;
    1) GIT_SHELL_CONF_RESULT="${found[0]}" ;;
    *)
      msg::notice "multiple candidates found for ${filename}."
      GIT_SHELL_CONF_RESULT="$(msg::select --ps="select ${filename}: " "${found[@]}")" || return 1
      ;;
  esac

  return 0
}

_git_shell_conf_render_bash() {
  local completion_path="$1"
  local prompt_path="$2"

  cat <<EOF
# >>> git shell integration (bash) >>>
if [[ -f "${completion_path}" ]]; then
  source "${completion_path}"
fi

if [[ -f "${prompt_path}" ]]; then
  source "${prompt_path}"
fi

export GIT_PS1_SHOWDIRTYSTATE=1
export GIT_PS1_SHOWSTASHSTATE=1
export GIT_PS1_SHOWUNTRACKEDFILES=1
export GIT_PS1_SHOWUPSTREAM='auto'

export PS1='\u@\h \w\$(__git_ps1 " (%s)")\\\$ '
# <<< git shell integration (bash) <<<
EOF
}

shell='bash'

while (( $# > 0 )); do
  case "$1" in
    --shell | --shell=*)
      if [[ "$1" =~ ^--shell= ]]; then
        shell="${1#--shell=}"
      elif [[ -z "${2:-}" ]]; then
        msg::error 'missing shell name'
        exit 1
      else
        shell="$2"
        shift
      fi
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      msg::error "invalid option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

supported=0
for s in "${GIT_SHELL_CONF_SUPPORTED_SHELLS[@]}"; do
  [[ "$s" == "$shell" ]] && { supported=1; break; }
done
if (( ! supported )); then
  msg::error "unsupported shell: ${shell} (supported: ${GIT_SHELL_CONF_SUPPORTED_SHELLS[*]})"
  exit 1

fi

# 検索過程のメッセージは標準エラー出力に流し、標準出力には
# 生成されたシェル設定のみが出力されるようにする
# (そのまま `>> ~/.bashrc` のようにリダイレクトして利用できるようにするため)
{
  util::chk -c git

  msg "searching for <hl>git-completion.bash</hl>..."
  if _git_shell_conf_locate 'git-completion.bash'; then
    completion_path="$GIT_SHELL_CONF_RESULT"
  else
    msg::error 'git-completion.bash not found.'
    exit 1
  fi

  msg "searching for <hl>git-prompt.sh</hl>..."
  if _git_shell_conf_locate 'git-prompt.sh'; then
    prompt_path="$GIT_SHELL_CONF_RESULT"
  else
    msg::error 'git-prompt.sh not found.'
    exit 1
  fi

  msg "generating shell configuration for <hl>${shell}</hl>..."
  config="$("_git_shell_conf_render_${shell}" "$completion_path" "$prompt_path")"
  msg::notice "add the following lines to your <hl>~/.bashrc</hl> (or equivalent)."
} >&2

printf '%s\n' "$config"
