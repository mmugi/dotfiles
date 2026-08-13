# shellcheck shell=bash

# import.sh がsource時に読み取る変数
# shellcheck disable=SC2034
{
  LIB_VERSION='1.0.0'
  LIB_DEPS=( core log msg util dotfiles )
  LIB_REQUIRES_BASH='>=4.1'
}
[[ "${1:-}" = '__IMPORT__' ]] && return 0

# シェル設定ジェネレータ <shellconf.sh>
#
# シェルごとに書き分けていた設定を、シェル非依存のレジストリ1本から生成する。
#
# 解こうとしている問題:
#   - ツールを1つ入れるたびに bash/zsh/fish の設定を手で同期する必要があること
#   - ツールが提示する snippet が $SHELL 基準で、tmux 上の fish と食い違うこと
#
# どちらも「シェルごとのコードを人間が書き分けている」ことが原因なので、
# 対象シェルを引数で受け取り、そのシェル用のコードを出力する形に寄せる。
# $SHELL は一切参照しない。
#
# レジストリは <root>/shell/{env.d,rc.d}/*.sh。各エントリは以下を定義する。
#
#   guard='starship'        # 省略可。実行時のコマンド存在チェックを自動で巻く
#   shells='bash zsh fish'  # 省略可。既定は全シェル
#   render() { ... }        # $1 に対象シェル名。そのシェル用のコードを stdout へ
#
# エントリはサブシェルで source するため、エントリ間で変数名や関数名が衝突しない。

# shellcheck disable=SC2034
{
  declare -ga SHELLCONF_SUPPORTED_SHELLS=( bash zsh fish )

  declare -g SHELLCONF_OUTPUT_DIR="${DOTFILES_RUNTIME_DIR:?}/shell"

  # 生成物が読むローカル上書き。dotfiles は一切管理しない。
  # git に入れたくないマシン固有の設定の置き場。
  declare -g SHELLCONF_LOCAL_DIR="${HOME}/.config/shell"
}

# --------------------------------------------------------------------------
# レジストリ探索
# --------------------------------------------------------------------------

shellconf::registry_dirs() {
  # usage: shellconf::registry_dirs <phase>
  #
  # 指定フェーズ (env | rc) のレジストリディレクトリを1行ずつ出力する。
  #
  # dotfiles::config_dirs と同じく、公開リポジトリに加えてプライベート
  # オーバーレイも探索対象にする。公開リポジトリに置かないシェル設定を
  # 合流させるための拡張点。

  if (( $# != 1 )); then
    core::error 'usage: shellconf::registry_dirs <phase>'
    return 1
  fi

  local phase="$1"
  local root dir

  for root in "${DOTFILES_PATH:?}" "${DOTFILES_PRIVATE_PATH:-}"; do
    [[ -z "$root" ]] && continue
    dir="${root}/shell/${phase}.d"
    [[ -d "$dir" ]] && printf '%s\n' "$dir"
  done

  return 0
}

shellconf::entries() {
  # usage: shellconf::entries <phase>
  #
  # 指定フェーズのエントリファイルを、ファイル名順にマージして出力する。
  #
  # ファイル名の数値プレフィックスが読み込み順になる。探索ルートをまたいで
  # 名前順に並べるため、~/.me/shell/rc.d/40-private.sh は公開側の 30 と 50 の
  # 間に挟まる。PATH を通してから、それに依存するツールを初期化する、と
  # いった順序はこれで表現する。

  if (( $# != 1 )); then
    core::error 'usage: shellconf::entries <phase>'
    return 1
  fi

  local phase="$1"
  local dir

  while read -r dir; do
    find "$dir" -mindepth 1 -maxdepth 1 -type f -name '*.sh'
  done < <(shellconf::registry_dirs "$phase") \
    | awk -F/ '{ print $NF "\t" $0 }' \
    | sort -k1,1 \
    | cut -f2-

  return 0
}

# --------------------------------------------------------------------------
# 出力ヘルパ
#
# エントリの render() から呼ぶ。対象シェルは _SHELLCONF_SHELL から読むため、
# 呼び出し側でシェル名を引き回さなくてよい。
# --------------------------------------------------------------------------

shellconf::_squote_posix() {
  # POSIX シェルのシングルクォート文字列に変換する
  local s="$1"
  printf "'%s'" "${s//\'/\'\\\'\'}"
}

shellconf::_squote_fish() {
  # fish のシングルクォート文字列に変換する。
  # fish はシングルクォート内で \\ と \' だけをエスケープとして解釈する。
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\'/\\\'}"
  printf "'%s'" "$s"
}

shellconf::raw() {
  # usage: shellconf::raw <line>...
  # 渡された行をそのまま出力する。ヘルパで表現できないものはこれを使う。
  printf '%s\n' "$@"
}

shellconf::eval_init() {
  # usage: shellconf::eval_init <command> [init args...]
  #
  # `<command> init <shell>` 形式の初期化コードを、対象シェルの流儀で出力する。
  # starship / zoxide / direnv などはこれ1行で済む。

  if (( $# < 1 )); then
    core::error 'usage: shellconf::eval_init <command> [init args...]'
    return 1
  fi

  local cmd="$1"; shift
  local extra=''
  (( $# > 0 )) && extra=" $*"

  # 生成物に埋め込むコードなので、$() はここでは展開させない
  # shellcheck disable=SC2016
  case "${_SHELLCONF_SHELL:?}" in
    fish) printf '%s init fish%s | source\n' "$cmd" "$extra" ;;
    *)    printf 'eval "$(%s init %s%s)"\n' "$cmd" "$_SHELLCONF_SHELL" "$extra" ;;
  esac
}

shellconf::export() {
  # usage: shellconf::export <name> <value>
  #
  # 値はリテラルとして埋め込む。生成はマシンごとに行われ、生成物は run/ 配下で
  # git 管理外なので、"$HOME" などは呼び出し側で展開して渡してよい。

  if (( $# != 2 )); then
    core::error 'usage: shellconf::export <name> <value>'
    return 1
  fi

  local name="$1" value="$2"

  case "${_SHELLCONF_SHELL:?}" in
    fish) printf 'set -gx %s %s\n' "$name" "$(shellconf::_squote_fish "$value")" ;;
    *)    printf 'export %s=%s\n' "$name" "$(shellconf::_squote_posix "$value")" ;;
  esac
}

shellconf::path_prepend() {
  # usage: shellconf::path_prepend <dir>
  #
  # PATH の先頭に追加する。既に含まれている場合は何もしない。
  # tmux 上でシェルが入れ子に起動する構成では、この重複排除が無いと PATH が
  # 際限なく伸びる。

  if (( $# != 1 )); then
    core::error 'usage: shellconf::path_prepend <dir>'
    return 1
  fi

  local dir="$1"

  case "${_SHELLCONF_SHELL:?}" in
    # fish_add_path は既定でユニバーサル変数を触る。セッションをまたいで
    # 蓄積されると始末が悪いので -g でグローバルに閉じる。
    fish) printf 'fish_add_path -gp %s\n' "$(shellconf::_squote_fish "$dir")" ;;
    *)    printf '__dotfiles_path_prepend %s\n' "$(shellconf::_squote_posix "$dir")" ;;
  esac
}

shellconf::source_if() {
  # usage: shellconf::source_if <file>
  # 読める場合だけ source する。$? を汚さないよう if 文で出力する。

  if (( $# != 1 )); then
    core::error 'usage: shellconf::source_if <file>'
    return 1
  fi

  local file="$1"

  case "${_SHELLCONF_SHELL:?}" in
    fish)
      printf 'if test -r %s\n' "$(shellconf::_squote_fish "$file")"
      printf '  source %s\n' "$(shellconf::_squote_fish "$file")"
      printf 'end\n'
      ;;
    *)
      printf 'if [ -r %s ]; then\n' "$(shellconf::_squote_posix "$file")"
      printf '  . %s\n' "$(shellconf::_squote_posix "$file")"
      printf 'fi\n'
      ;;
  esac
}

# --------------------------------------------------------------------------
# 描画
# --------------------------------------------------------------------------

shellconf::_indent() {
  # 標準入力を2スペース字下げする。空行は字下げしない。
  #
  # 物理行をそのまま字下げするため、エントリは1論理行を1物理行で出力すること。
  # 複数行にまたがる文字列リテラルを出力すると、リテラルの中身に字下げが
  # 混入する。改行はシェルごとのエスケープ ($'\n' など) で表す。
  local line
  # 末尾に改行が無い最終行も取りこぼさない
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" ]]; then
      printf '\n'
    else
      printf '  %s\n' "$line"
    fi
  done
}

shellconf::_guard_open() {
  # usage: shellconf::_guard_open <shell> <command>
  case "$1" in
    fish) printf 'if type -q %s\n' "$2" ;;
    *)    printf 'if command -v %s >/dev/null 2>&1; then\n' "$2" ;;
  esac
}

shellconf::_guard_close() {
  case "$1" in
    fish) printf 'end\n' ;;
    *)    printf 'fi\n' ;;
  esac
}

shellconf::render_entry() {
  # usage: shellconf::render_entry <entry_file> <shell>
  #
  # エントリを読み込んで対象シェル用のコードを出力する。
  # 対象外のシェル、または render が何も出力しない場合は無出力で0を返す。
  #
  # エントリはサブシェルで source する。エントリ同士、およびエントリと
  # 呼び出し側で名前が衝突しないようにするため。

  if (( $# != 2 )); then
    core::error 'usage: shellconf::render_entry <entry_file> <shell>'
    return 1
  fi

  local entry="$1" shell="$2"

  if [[ ! -r "$entry" ]]; then
    logger --error "entry not readable: ${entry}"
    return 1
  fi

  (
    guard=''
    shells=''
    render() { :; }

    declare -g _SHELLCONF_SHELL="$shell"

    # shellcheck source=/dev/null
    if ! source "$entry"; then
      logger --error "failed to load entry: ${entry}"
      exit 1
    fi

    if [[ -n "$shells" ]]; then
      local -a want=()
      local s hit=0
      read -r -a want <<<"$shells"
      for s in "${want[@]}"; do
        [[ "$s" == "$shell" ]] && { hit=1; break; }
      done
      (( hit )) || exit 0
    fi

    local body
    if ! body="$(render "$shell")"; then
      logger --error "render failed: ${entry} (${shell})"
      exit 1
    fi

    [[ -z "$body" ]] && exit 0

    printf '# %s\n' "${entry#"${DOTFILES_PATH}/"}"

    if [[ -n "$guard" ]]; then
      shellconf::_guard_open "$shell" "$guard"
      shellconf::_indent <<<"$body"
      shellconf::_guard_close "$shell"
    else
      printf '%s\n' "$body"
    fi

    printf '\n'
  )
}

shellconf::_render_phase() {
  # usage: shellconf::_render_phase <phase> <shell>
  local phase="$1" shell="$2"
  local entry rc=0

  while read -r entry; do
    [[ -z "$entry" ]] && continue
    shellconf::render_entry "$entry" "$shell" || rc=1
  done < <(shellconf::entries "$phase")

  return "$rc"
}

shellconf::_header() {
  # usage: shellconf::_header <shell> <what>
  local comment='#'
  cat <<EOF
${comment} ${2} for ${1}
${comment}
${comment} generated by 'make shell-conf' from ${DOTFILES_PATH}/shell/
${comment} do not edit. machine local overrides go to ${SHELLCONF_LOCAL_DIR}/.
EOF
}

shellconf::generate_env() {
  # usage: shellconf::generate_env <shell>
  #
  # 環境変数のみを含むファイルを出力する。非対話のログインシェルでも読ませたい
  # 場合に ~/.profile などから直接 source できるよう、rc とは分けている。
  #
  # 対象は bash / zsh。fish は conf.d が env と rc を分けないため
  # generate_fish がまとめて扱う。

  local shell="$1"
  local body

  body="$(shellconf::_render_phase 'env' "$shell")" || return 1

  shellconf::_header "$shell" 'shell environment'
  printf '\n'

  # 二重読み込みの抑止。rc 側はこの変数を見て source を省く。
  # 生成物側で評価される変数なので、ここでは展開させない
  # shellcheck disable=SC2016
  printf 'if [ -z "${__DOTFILES_ENV_LOADED:-}" ]; then\n'
  printf '  __DOTFILES_ENV_LOADED=1\n'
  printf '\n'

  # PATH の重複排除。bash 3.2 でも動く書き方に留める。
  {
    cat <<'PREAMBLE'
__dotfiles_path_prepend() {
  case ":${PATH}:" in
    *":$1:"*) ;;
    *) PATH="$1:${PATH}"; export PATH ;;
  esac
}
PREAMBLE
    printf '\n'
    printf '%s\n' "$body"
    printf '\n'
    printf '# machine local override\n'
    _SHELLCONF_SHELL="$shell" shellconf::source_if "${SHELLCONF_LOCAL_DIR}/env.local.sh"
  } | shellconf::_indent

  printf 'fi\n'
}

shellconf::generate_rc() {
  # usage: shellconf::generate_rc <shell>
  # 対話シェル用。冒頭で env を読むため、rc に1行フックするだけで環境変数も揃う。

  local shell="$1"
  local body

  body="$(shellconf::_render_phase 'rc' "$shell")" || return 1

  shellconf::_header "$shell" 'interactive shell configuration'
  printf '\n'

  # 生成物側で評価される変数なので、ここでは展開させない
  # shellcheck disable=SC2016
  printf 'if [ -z "${__DOTFILES_ENV_LOADED:-}" ]; then\n'
  _SHELLCONF_SHELL="$shell" shellconf::source_if "${SHELLCONF_LOCAL_DIR}/env.${shell}" \
    | shellconf::_indent
  printf 'fi\n'
  printf '\n'

  printf '%s\n' "$body"
  printf '\n'
  printf '# machine local override\n'
  _SHELLCONF_SHELL="$shell" shellconf::source_if "${SHELLCONF_LOCAL_DIR}/rc.local.sh"
}

shellconf::generate_fish() {
  # fish の conf.d は全セッションで走る。env 相当は無条件、rc 相当は
  # status is-interactive で囲んで1ファイルにまとめる。

  local env_body rc_body

  env_body="$(shellconf::_render_phase 'env' 'fish')" || return 1
  rc_body="$(shellconf::_render_phase 'rc' 'fish')" || return 1

  shellconf::_header 'fish' 'shell configuration'
  printf '\n'

  printf '%s\n' "$env_body"
  printf '\n'
  printf '# machine local override\n'
  _SHELLCONF_SHELL='fish' shellconf::source_if "${SHELLCONF_LOCAL_DIR}/env.local.fish"
  printf '\n'

  printf 'if status is-interactive\n'
  {
    printf '%s\n' "$rc_body"
    printf '\n'
    printf '# machine local override\n'
    _SHELLCONF_SHELL='fish' shellconf::source_if "${SHELLCONF_LOCAL_DIR}/rc.local.fish"
  } | shellconf::_indent
  printf 'end\n'
}

# --------------------------------------------------------------------------
# 生成物の配置先
# --------------------------------------------------------------------------

shellconf::outputs() {
  # usage: shellconf::outputs
  #
  # 「生成物のパス <TAB> ホームからの相対配置先」を1行ずつ出力する。
  # install と uninstall が同じ集合を見る必要があるため、ここに置いている。

  printf '%s\t%s\n' \
    "${SHELLCONF_OUTPUT_DIR}/env.bash" '.config/shell/env.bash' \
    "${SHELLCONF_OUTPUT_DIR}/rc.bash" '.config/shell/rc.bash' \
    "${SHELLCONF_OUTPUT_DIR}/env.zsh" '.config/shell/env.zsh' \
    "${SHELLCONF_OUTPUT_DIR}/rc.zsh" '.config/shell/rc.zsh' \
    "${SHELLCONF_OUTPUT_DIR}/dotfiles.fish" '.config/fish/conf.d/00-dotfiles.fish'
}

shellconf::generate_all() {
  # usage: shellconf::generate_all
  # SHELLCONF_OUTPUT_DIR に全シェル分を書き出す。

  mkdir -p "$SHELLCONF_OUTPUT_DIR" || return 1

  local shell
  for shell in bash zsh; do
    shellconf::generate_env "$shell" > "${SHELLCONF_OUTPUT_DIR}/env.${shell}" || return 1
    msg::changed "generated: ${SHELLCONF_OUTPUT_DIR}/env.${shell}"
    shellconf::generate_rc "$shell" > "${SHELLCONF_OUTPUT_DIR}/rc.${shell}" || return 1
    msg::changed "generated: ${SHELLCONF_OUTPUT_DIR}/rc.${shell}"
  done

  shellconf::generate_fish > "${SHELLCONF_OUTPUT_DIR}/dotfiles.fish" || return 1
  msg::changed "generated: ${SHELLCONF_OUTPUT_DIR}/dotfiles.fish"

  return 0
}

# --------------------------------------------------------------------------
# 1行フック
# --------------------------------------------------------------------------

shellconf::hook_rcfile() {
  # usage: shellconf::hook_rcfile <shell>
  # そのシェルでフックを書き足す先を出力する。fish は conf.d が自動で
  # 読み込むためフック不要で、1を返す。

  case "$1" in
    bash) printf '%s\n' "${HOME}/.bashrc" ;;
    zsh)  printf '%s\n' "${HOME}/.zshrc" ;;
    *)    return 1 ;;
  esac
}

shellconf::hook_target() {
  # usage: shellconf::hook_target <shell>
  #
  # フックが読み込む先を出力する。貼る側 (hook_block) と判定する側
  # (hook_installed) が同じ値を見るように、ここを唯一の定義とする。

  case "$1" in
    bash) printf '%s\n' "${SHELLCONF_LOCAL_DIR}/rc.bash" ;;
    zsh)  printf '%s\n' "${SHELLCONF_LOCAL_DIR}/rc.zsh" ;;
    *)    return 1 ;;
  esac
}

shellconf::hook_block() {
  # usage: shellconf::hook_block <shell>
  #
  # 利用者が rc に貼る1行を出力する。dotfiles は ~/.bashrc を所有しない。
  # 配置先の rc がどう管理されていても、利用者が足すのはこれだけで揃う。
  #
  # 目印のコメントは付けない。囲むべき中身が1行しかなく、読み込み先の
  # パスがそのまま出所を示すため。読み込んだ先の冒頭には、どこから生成された
  # ファイルかを書いてある。

  local target
  target="$(shellconf::hook_target "$1")" || return 1

  # $HOME はリテラルで埋め込む。ホームの位置が変わっても、rc を別のマシンへ
  # 持っていっても壊れないようにするため。
  target="${target/#"${HOME}"/\$HOME}"

  printf '[ -r "%s" ] && . "%s"\n' "$target" "$target"
}

shellconf::hook_installed() {
  # usage: shellconf::hook_installed <shell>
  # そのシェルの rc に既にフックが入っているかを判定する。
  # 導入済みのマシンで毎回案内を出さないために使う。
  #
  # 判定は目印のコメントではなく読み込み先のパスで行う。rc は利用者のもので
  # あり、書き方を変えられる (source を使う、既存の if にたたむ、$HOME を
  # 展開して書く) ことを前提にする必要があるため。ホームからの相対部分だけを
  # 見れば、どの書き方でも一致する。

  local rcfile target
  rcfile="$(shellconf::hook_rcfile "$1")" || return 1
  target="$(shellconf::hook_target "$1")" || return 1

  [[ -r "$rcfile" ]] || return 1

  grep -qF -- "${target#"${HOME}"}" "$rcfile"
}

# --------------------------------------------------------------------------
# 生成時のファイル探索
# --------------------------------------------------------------------------

shellconf::search_dirs() {
  # git 同梱のシェル補助スクリプト (git-prompt.sh / git-completion.*) が
  # 置かれていそうなディレクトリの候補を列挙する。

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

shellconf::locate() {
  # usage: shellconf::locate <filename>
  #
  # 候補ディレクトリから filename を探し、見つかったパスを標準出力に出す。
  # 見つからない場合は1を返す。
  #
  # 複数見つかった場合、対話的に実行されていれば選ばせる。非対話では先頭を
  # 採用する。install から呼ばれるため、tty を前提にできない。
  #
  # ここで見つけたパスは生成物に絶対パスとして焼き込まれる。生成物は run/
  # 配下で git 管理外なので、マシン固有のパスが混ざって問題にならない。

  if (( $# != 1 )); then
    core::error 'usage: shellconf::locate <filename>'
    return 1
  fi

  local filename="$1"
  local -a search_dirs=() found=()
  local dir hit

  while IFS= read -r dir; do
    search_dirs+=( "$dir" )
  done < <(shellconf::search_dirs)

  (( ${#search_dirs[@]} == 0 )) && return 1

  while IFS= read -r -d '' hit; do
    found+=( "$hit" )
  done < <(find "${search_dirs[@]}" -maxdepth 3 -type f -name "$filename" -print0 2>/dev/null)

  case "${#found[@]}" in
    0) return 1 ;;
    1) printf '%s\n' "${found[0]}" ;;
    *)
      if [[ -t 0 ]]; then
        msg::notice "multiple candidates found for ${filename}." >&2
        msg::select --ps="select ${filename}: " "${found[@]}" || return 1
      else
        printf '%s\n' "${found[0]}"
      fi
      ;;
  esac

  return 0
}
