# shellcheck shell=bash

# @deps log msg

# util::chk 結果キャッシュ
#   値: 0 = 存在する / 1 = 存在しない
declare -gA _UTIL_CHK_CMD_CACHE=()

util::chk() {
  # options
  #   -c: command
  #   -o: キャッシュを上書きする
  #   -q: 結果を出力しない

  local override=0
  local quiet=0
  local selector target i
  # 関数内で定義した関数はグローバルになり呼び出し側の usage を上書きするため、
  # 他の util:: 関数と同じく文字列で持つ。
  local usage='usage: util::chk <-c> [-oq] target'

  if (( $# == 0 )); then
    logger --error "$usage"
    return 1
  fi

  while (( $# > 0 )); do
    case "$1" in
      --) shift; break ;;
      -*)
        for (( i=1; i<${#1}; i++ )); do
          case "${1:$i:1}" in
            c) selector='command' ;;
            o) override=1 ;;
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

  if [[ -z "${selector:-}" ]]; then
    logger --error "$usage"
    return 1
  fi

  target="$*"

  case "$selector" in
    command)
      if (( ! override )) && [[ -n "${_UTIL_CHK_CMD_CACHE["$target"]:-}" ]]; then
        return "${_UTIL_CHK_CMD_CACHE["$target"]}"
      fi

      if (( ! quiet )); then
        # 強調の終わりは base を出し直して閉じる (rst だと地の色に落ちる)。
        msg "checking ${STYLE[msg_highlight]}${target}${STYLE[normal]} command..."
      fi

      if type "$target" >/dev/null 2>&1; then
        _UTIL_CHK_CMD_CACHE["$target"]=0
        return 0
      else
        _UTIL_CHK_CMD_CACHE["$target"]=1
        if (( ! quiet )); then
          msg::error "command not found: ${target}"
        fi
        return 1
      fi
      ;;
    *)
      logger --error "invalid selector: ${selector}"
      return 1
      ;;
  esac
}
