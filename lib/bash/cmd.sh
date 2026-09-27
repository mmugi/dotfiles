# shellcheck shell=bash

# @deps log msg

cmd::check() {
  # usage: cmd::check <command>
  #
  # コマンドが使えれば 0、使えなければ 1 を返します。
  #
  # 確認中であることと、見つからなかったことを標準出力へ出します。
  # 表示が必要ない場合はこの関数を使わず、`command -v <command>` を直接
  # 書いてください。

  if (( $# != 1 )); then
    logger --error 'usage: cmd::check <command>'
    return 1
  fi

  msg "checking ${STYLE[msg_highlight]}${1}${STYLE[normal]} command..."

  if command -v -- "$1" >/dev/null 2>&1; then
    return 0
  else
    msg::error "command not found: ${1}"
    return 1
  fi
}
