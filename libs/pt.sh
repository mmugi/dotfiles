# qiita: https://qiita.com/ko1nksm/items/d0b066268cda42ff24eb
# シェル判定
pt_shell_type_check() {
  printf '' && return 0
  if print -nr -- ''; then
    [ "${ZSH_VERSION:-}" ] && return 1 || return 2
  fi
  if [ "${POSH_VERSION:-}" ]; then
    [ "${1#*\\}" ] && return 3 || return 4
  fi
  return 9
}

( PATH=""; pt_shell_type_check "\\" ) 2>/dev/null && :

case $? in
  0) # printf がビルトインの場合
    pt() { IFS=" $IFS"; printf '%s' "${*:-}"; IFS=${IFS#?}; }
    ptn() { IFS=" $IFS"; printf '%s\n' "${*:-}"; IFS=${IFS#?}; }
    ;;
  1) # 古 zsh 用
    pt() { builtin print -nr -- "${@:-}"; }
    ptn() { builtin print -r -- "${@:-}"; }
    ;;
  2) # ksh88, mksh, OpenBSD ksh, pdksh 用
    pt() { command print -nr -- "${@:-}"; }
    ptn() { command print -r -- "${@:-}"; }
    ;;
  3) # posh 用（バグ対応版）
    pt() {
      if [ $# -eq 1 ] && [ "$1" = "-n" ]; then
        builtin echo -n -; builtin echo -n n; return 0
      fi
      IFS=" $IFS"; set -- "${*:-}\\" ""; IFS=${IFS#?}
      while [ "$1" ]; do set -- "${1#*\\\\}" "$2${2:+\\\\}${1%%\\\\*}"; done
      builtin echo -n "$2"
    }
    ptn() { [ $# -gt 0 ] && pt "$@"; builtin echo; }
    ;;
  4) # posh用
    pt() {
      if [ $# -eq 1 ] && [ "$1" = "-n" ]; then
        builtin echo -n -; builtin echo -n n; return 0
      fi
      IFS=" $IFS"; set -- "${*:-}\\" ""; IFS=${IFS#?}
      while [ "$1" ]; do set -- "${1#*\\}" "$2${2:+\\\\}${1%%\\*}"; done
      builtin echo -n "$2"
    }
    ptn() { [ $# -gt 0 ] && pt "$@"; builtin echo; }
    ;;
  9) # 未知のシェルのためのフォールバック
    pt() {
      # shellcheck disable=SC2031
      PATH="${PATH:-}:/usr/bin:/bin"
      IFS=" $IFS"; printf '%s' "$*"; IFS=${IFS#?}
      PATH=${PATH%:/usr/bin:/bin}
    }
    ptn() {
      PATH="${PATH:-}:/usr/bin:/bin"
      IFS=" $IFS"; printf '%s\n' "$*"; IFS=${IFS#?}
      PATH=${PATH%:/usr/bin:/bin}
    }
    ;;
esac
