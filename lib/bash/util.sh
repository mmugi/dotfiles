# shellcheck shell=bash

# @deps log msg

util::has_cmd() {
  # usage: util::has_cmd [-q] <command>
  #
  # コマンドが使えれば 0、使えなければ 1 を返します。
  #
  # options
  #   -q: 確認中と not found のメッセージを出しません。

  local quiet=0
  local target i

  while (( $# > 0 )); do
    case "$1" in
      --) shift; break ;;
      -*)
        for (( i=1; i<${#1}; i++ )); do
          case "${1:$i:1}" in
            q) quiet=1 ;;
            *)
              logger --error "invalid option: $1"
              return 1
              ;;
          esac
        done
        shift
        ;;
      *) break ;;
    esac
  done

  target="$*"

  if [[ -z "$target" ]]; then
    # usage は関数ではなく文字列で持つ。関数内で定義した関数はグローバルに
    # なり、呼び出し側の usage を上書きしてしまう。
    logger --error 'usage: util::has_cmd [-q] <command>'
    return 1
  fi

  if (( ! quiet )); then
    # 強調の終わりは base を出し直して閉じる (rst だと地の色に落ちる)。
    msg "checking ${STYLE[msg_highlight]}${target}${STYLE[normal]} command..."
  fi

  if type "$target" >/dev/null 2>&1; then
    return 0
  fi

  if (( ! quiet )); then
    msg::error "command not found: ${target}"
  fi
  return 1
}
