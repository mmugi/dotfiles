#!/usr/bin/env bash

set -ueo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_PATH}/lib/bash/import.sh"
import util msg theme

if [[ -t 2 ]]; then
  # termcap.sh が参照する
  # shellcheck disable=SC2034
  TERMCAP_COLOR_MODE=always
fi

theme::load
msg::init

# gitに内包される git-completion をsourceするシェル設定を生成し、標準出力に
# そのままコピー&ペーストできる形式で出力します。
# git-completionが見つからない場合は、エラーで停止せず何も出力しません。
#
# 対応シェルを追加する場合:
#   1. GIT_COMPLETION_CONF_SUPPORTED_SHELLS にシェル名を追加する
#   2. GIT_COMPLETION_CONF_FILENAME にそのシェルの補完ファイル名を追加する
#   3. GIT_COMPLETION_CONF_RC_HINT にそのシェルの設定ファイルパスを追加する
#   4. `_git_completion_conf_render_<シェル名>()` を実装する

declare -ra GIT_COMPLETION_CONF_SUPPORTED_SHELLS=( bash )

declare -rA GIT_COMPLETION_CONF_FILENAME=(
  [bash]='git-completion.bash'
)

# 表示用の文字列なので ~ は展開しない
# shellcheck disable=SC2088
declare -rA GIT_COMPLETION_CONF_RC_HINT=(
  [bash]='~/.bashrc'
)

usage() {
  cat <<EOF
usage: $(basename "$0") [--shell <name>]

  --shell <name>   出力するシェルの種類を指定します (default: bash)
                    対応シェル: ${GIT_COMPLETION_CONF_SUPPORTED_SHELLS[*]}
EOF
}

_git_completion_conf_search_dirs() {
  # git-completion が配置されていそうなディレクトリの候補を列挙する
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

_git_completion_conf_locate() {
  # usage: _git_completion_conf_locate <filename>
  # 結果は GIT_COMPLETION_CONF_RESULT にセットされる。
  # (内部の標準出力への書き込みが混ざらないようにグローバル変数で受け渡す)

  local filename="$1"
  local -a search_dirs=() found=()
  local dir hit

  GIT_COMPLETION_CONF_RESULT=

  while IFS= read -r dir; do
    search_dirs+=( "$dir" )
  done < <(_git_completion_conf_search_dirs)

  (( ${#search_dirs[@]} == 0 )) && return 1

  while IFS= read -r -d '' hit; do
    found+=( "$hit" )
  done < <(find "${search_dirs[@]}" -maxdepth 3 -type f -name "$filename" -print0 2>/dev/null)

  case "${#found[@]}" in
    0) return 1 ;;
    1) GIT_COMPLETION_CONF_RESULT="${found[0]}" ;;
    *)
      msg::notice "multiple candidates found for ${filename}."
      GIT_COMPLETION_CONF_RESULT="$(msg::select --ps="select ${filename}: " "${found[@]}")" || return 1
      ;;
  esac

  return 0
}

_git_completion_conf_render_bash() {
  local completion_path="$1"

  cat <<EOF
# >>> git completion integration (bash) >>>
if [[ -f "${completion_path}" ]]; then
  source "${completion_path}"
fi
# <<< git completion integration (bash) <<<
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
for s in "${GIT_COMPLETION_CONF_SUPPORTED_SHELLS[@]}"; do
  [[ "$s" == "$shell" ]] && { supported=1; break; }
done
if (( ! supported )); then
  msg::error "unsupported shell: ${shell} (supported: ${GIT_COMPLETION_CONF_SUPPORTED_SHELLS[*]})"
  exit 1
fi

# `{ ... } >&2` ブロックの内側ではfd 1がfd 2にダップされるため、
# ブロックに入る前に本来のstdoutがtty/リダイレクト先を判定しておく
stdout_is_tty=0
[[ -t 1 ]] && stdout_is_tty=1

stdout_target=
if (( ! stdout_is_tty )) && util::chk -cq lsof; then
  stdout_target="$(lsof -p "$$" -a -d1 -Fn 2>/dev/null | awk '/^n/ { print substr($0, 2); exit }')"
fi

config=

# 検索過程のメッセージは標準エラー出力に流し、標準出力には
# 生成されたシェル設定のみが出力されるようにする
# (そのまま `>> ~/.bashrc` のようにリダイレクトして利用できるようにするため)
{
  filename="${GIT_COMPLETION_CONF_FILENAME[$shell]}"

  if util::chk -c git; then
    msg "searching for <hl>${filename}</hl>..."
    if _git_completion_conf_locate "$filename"; then
      msg "generating git-completion configuration for <hl>${shell}</hl>..."
      config="$(_git_completion_conf_render_bash "$GIT_COMPLETION_CONF_RESULT")"
    else
      msg::warning "${filename} not found."
    fi
  fi

  if [[ -n "$config" ]]; then
    rc_hint="${GIT_COMPLETION_CONF_RC_HINT[$shell]}"

    if (( stdout_is_tty )); then
      msg::notice "add the following lines to your <hl>${rc_hint}</hl> (or equivalent)."
    elif [[ -n "$stdout_target" ]]; then
      msg::notice "stdout is redirected to <hl>${stdout_target}</hl>. writing the generated configuration directly to it."
    else
      msg::notice 'stdout is redirected. writing the generated configuration directly to it.'
    fi
  fi
} >&2

if [[ -n "$config" ]]; then
  printf '%s\n' "$config"
  (( stdout_is_tty )) || msg::ok 'configuration written.' >&2
fi
