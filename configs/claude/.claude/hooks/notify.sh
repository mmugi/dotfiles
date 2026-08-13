#!/usr/bin/env bash

set -ueo pipefail

# Claude Code のフックから呼ばれ、デスクトップ通知を出す。
# フックの入力 JSON は標準入力で渡される。
#
# usage: notify.sh <notification|stop>
#
# lib/bash の共通ライブラリは読み込まない。import.sh は DOTFILES_PATH を要求するが
# フックの実行環境にその変数は無く、msg/theme は標準出力へ書くためフックの
# 出力仕様と衝突する。リポジトリの作法からは外れるが、単体で完結させる。

readonly APP_NAME='Claude Code'

_json_field() {
  # 入力 JSON から値を取り出す。
  # jq は Homebrew 依存なので、無い環境では空文字を返して呼び出し側の
  # 既定値に委ねる。通知そのものは jq の有無に関わらず必ず出す。
  local payload="$1"
  local filter="$2"

  command -v jq >/dev/null 2>&1 || return 0
  jq -r "$filter" <<<"$payload" 2>/dev/null || true
}

_notify() {
  # このスクリプトで唯一の環境依存箇所。
  # 対応環境を増やすときは、ここに case の枝を追加する(Linux なら notify-send)。
  # 未検証の実装を先に置くことはしないため、今は Darwin のみ。
  # 未対応の環境では通知を諦めるが、フックは失敗させない。
  local title="$1"
  local subtitle="$2"
  local body="$3"
  local sound="$4"

  case "$(uname -s)" in
    Darwin)
      # 値は AppleScript へ引数で渡す。文字列連結でスクリプトを組み立てると、
      # 本文に含まれる引用符やバックスラッシュで構文が壊れる。
      osascript \
        -e 'on run {bodyText, titleText, subText, soundName}' \
        -e 'display notification bodyText with title titleText subtitle subText sound name soundName' \
        -e 'end run' \
        -- "$body" "$title" "$subtitle" "$sound"
      ;;
    *)
      return 0
      ;;
  esac
}

main() {
  local event="${1:-}"
  local payload cwd subtitle title body sound

  # stdin が空でもフックを失敗させたくないため、読めなくても続行する。
  payload="$(cat || true)"

  # どのプロジェクトの通知かがひと目で分かるよう、作業ディレクトリ名を添える。
  cwd="$(_json_field "$payload" '.cwd // empty')"
  if [[ -n "$cwd" ]]; then
    subtitle="$(basename -- "$cwd")"
  else
    subtitle=''
  fi

  case "$event" in
    notification)
      # 本文はフック入力に委ねる。取れなければ空のまま通知する。
      title="${APP_NAME} Notification"
      body="$(_json_field "$payload" '.message // empty')"
      sound='Ping'
      ;;
    stop)
      title="${APP_NAME} Stop"
      body='Response completed'
      sound='Submarine'
      ;;
    *)
      printf 'usage: %s <notification|stop>\n' "$(basename -- "$0")" >&2
      return 1
      ;;
  esac

  _notify "$title" "$subtitle" "$body" "$sound"
}

main "$@"
