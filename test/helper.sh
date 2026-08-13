# shellcheck shell=bash
#
# テストの共通部分。
#
# 各テストファイルの冒頭で source する。
#
#   source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/helper.sh"
#
# 判定は check / check_rc で1件ずつ行い、結果を1行ずつ出す。
# 末尾で test::summary を呼ぶと集計して終了コードを返す。

DOTFILES_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export DOTFILES_PATH

# 出力を安定させる。
# 子プロセスとして起動するコマンドにも効かせる必要があるため export する。
export MSG_DELAY=0
export TERMCAP_COLOR_MODE=never

# 色の有無はテスト内で TERMCAP_COLOR_MODE で切り替える。NO_COLOR は
# TERMCAP_COLOR_MODE より優先されるため、実行環境の値を持ち込まない。
unset NO_COLOR

declare -i _tests=0
declare -i _failed=0

check() {
  # check <説明> <期待値> <実際値>
  local desc="$1" expected="$2" actual="$3"
  _tests=$(( _tests + 1 ))
  if [[ "$expected" == "$actual" ]]; then
    printf 'ok   %d - %s\n' "$_tests" "$desc"
  else
    _failed=$(( _failed + 1 ))
    printf 'FAIL %d - %s\n      expected: %q\n      actual:   %q\n' \
      "$_tests" "$desc" "$expected" "$actual"
  fi
}

check_rc() {
  # check_rc <説明> <期待status> <コマンド...>
  local desc="$1" expected="$2"; shift 2
  local rc=0
  "$@" >/dev/null 2>&1 || rc=$?
  check "$desc" "$expected" "$rc"
}

test::summary() {
  printf '\n'
  if (( _failed )); then
    printf '%d/%d failed\n' "$_failed" "$_tests"
    exit 1
  fi
  printf 'all %d tests passed\n' "$_tests"
}
