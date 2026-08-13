# shellcheck shell=bash
#
# このファイルが出力するのは「生成先のシェルが評価するコード」であり、
# ここで $() や $var を展開してはいけない。
# shellcheck disable=SC2016

# プロンプト。
#
# 優先順位:
#   1. starship があればそれを使う
#   2. git 同梱の git-prompt.sh が見つかれば、git 連携つきのプロンプトを組む
#   3. どちらも無ければ、git 情報を含まないプロンプトにする
#
# starship の有無だけは実行時に判定する。あとから starship を入れても
# 再生成せずに切り替わるようにするため。git-prompt.sh の場所はマシン固有なので
# 生成時に解決して焼き込む。
#
# fish は独自の fish_prompt を持っているため、starship が無い場合は
# fish の既定に任せる。PS1 相当の組み立ては行わない。

readonly _PROMPT_PURPLE='148;140;243'
readonly _PROMPT_GRAY='94;97;100'

_prompt_bash() {
  # usage: _prompt_bash <git_ps1 | plain>
  local git=''
  [[ "$1" == 'git_ps1' ]] && git='$(__git_ps1 "\[\e[38;2;'"${_PROMPT_GRAY}"'m\] (%s)\[\e[m\]")'

  printf "export PS1='%s%s%s'\n" \
    "\\[\\e[38;2;${_PROMPT_PURPLE}m\\]\\u\\[\\e[m\\]@\\[\\e[38;2;${_PROMPT_PURPLE}m\\]\\h\\[\\e[m\\]:\\[\\e[38;2;${_PROMPT_PURPLE}m\\]\\w\\[\\e[m\\]" \
    "$git" \
    "\\n\\[\\e[38;2;${_PROMPT_PURPLE}m\\]>\\[\\e[m\\] "
}

_prompt_zsh() {
  # usage: _prompt_zsh <git_ps1 | plain>
  #
  # %s は git-prompt.sh の書式指定子だが、zsh のプロンプト展開とぶつかる。
  # 関数に閉じ込めて PROMPT には現れないようにする。
  #
  # 改行は $'...' の \n で表す。出力を物理行そのままで扱う都合上 (ガードや
  # status is-interactive の字下げがかかる)、文字列リテラルを物理的に
  # 複数行にまたがらせてはいけない。

  local git=''

  if [[ "$1" == 'git_ps1' ]]; then
    shellconf::raw \
      '__dotfiles_git_ps1() { __git_ps1 " (%s)" 2>/dev/null; }'
    git='$(__dotfiles_git_ps1)'
  fi

  shellconf::raw 'setopt PROMPT_SUBST'
  printf "PROMPT=\$'%s%s%s'\n" \
    '%F{#948cf3}%n%f@%F{#948cf3}%m%f:%F{#948cf3}%~%f' \
    "$git" \
    '\n%F{#948cf3}>%f '
}

_prompt_git_options() {
  shellconf::raw \
    'export GIT_PS1_SHOWDIRTYSTATE=1' \
    'export GIT_PS1_SHOWSTASHSTATE=1' \
    'export GIT_PS1_SHOWUNTRACKEDFILES=1' \
    "export GIT_PS1_SHOWUPSTREAM='auto'"
}

render() {
  local shell="$1"

  # starship は実行時に判定する
  case "$shell" in
    fish)
      shellconf::raw 'if type -q starship'
      shellconf::eval_init starship | shellconf::_indent
      shellconf::raw 'end'
      return 0
      ;;
  esac

  local prompt_path=''
  if util::chk -cq git; then
    prompt_path="$(shellconf::locate 'git-prompt.sh')" || prompt_path=''
  fi

  shellconf::raw 'if command -v starship >/dev/null 2>&1; then'
  printf '  eval "$(starship init %s)"\n' "$shell"
  shellconf::raw 'else'

  {
    local mode='plain'

    if [[ -n "$prompt_path" ]]; then
      mode='git_ps1'
      shellconf::source_if "$prompt_path"
      _prompt_git_options
    fi

    "_prompt_${shell}" "$mode"
  } | shellconf::_indent

  shellconf::raw 'fi'
}
