#!/usr/bin/env bash
#
# configs/claude/.claude/statusline.sh のスモークテスト
#
#   bash test/statusline.sh
#
# このスクリプトが壊れるのは、ほぼ欠損フィールドの扱い。rate_limits はサブスクの
# ウィンドウがある間しか現れず、context_window.used_percentage は初回の API
# 応答まで null になる。その状態を実機で再現するのは待つしかないため、固定の JSON を
# 流し込んで確かめる。
#
# git の見え方はリポジトリの実状態で変わり、テストのたびに出力が揺れる。ここでは
# 検証せず、場所の部分を除いた残りだけを見る。

set -ueo pipefail

DOTFILES_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly STATUSLINE="${DOTFILES_PATH}/configs/claude/.claude/statusline.sh"

# 色が混ざると比較しづらいので既定は消しておく。色そのものは専用のケースで見る。
export NO_COLOR=1

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

run() {
  # run <JSON> -- ステータスラインを1行受け取る
  printf '%s' "$1" | "$STATUSLINE"
}

tail_of() {
  # 先頭の場所セクション (プロジェクト名とブランチ) を落とす。
  # 区切りは Claude 本体に合わせた ' · '。見つからなければ全体が場所セクション。
  local line="$1"
  if [[ "$line" == *" · "* ]]; then
    printf '%s' "${line#* · }"
  fi
}

# --- 実行できること -----------------------------------------------------------

check_rc() {
  local desc="$1" expected="$2" json="$3" rc=0
  run "$json" >/dev/null 2>&1 || rc=$?
  check "$desc" "$expected" "$rc"
}

check "実行ビットが立っている" 'yes' "$([[ -x "$STATUSLINE" ]] && echo yes || echo no)"

check_rc '空の JSON でも失敗しない'   0 '{}'
check_rc '空の入力でも失敗しない'     0 ''
check_rc '壊れた JSON でも失敗しない' 0 '{"model":'

# --- 欠損フィールド -----------------------------------------------------------

check 'すべて揃えば4セクション出る' \
  'Opus 5 · ctx 72% · 5h 12% · 7d 40%' \
  "$(tail_of "$(run '{"model":{"display_name":"Opus 5"},
                      "context_window":{"used_percentage":72},
                      "rate_limits":{"five_hour":{"used_percentage":12},
                                     "seven_day":{"used_percentage":40}}}')")"

check 'ctx の used_percentage が null なら ctx だけ消える' \
  'Opus 5 · 5h 12%' \
  "$(tail_of "$(run '{"model":{"display_name":"Opus 5"},
                      "context_window":{"used_percentage":null},
                      "rate_limits":{"five_hour":{"used_percentage":12}}}')")"

check 'rate_limits ごと無ければレート制限が消える' \
  'Opus 5 · ctx 72%' \
  "$(tail_of "$(run '{"model":{"display_name":"Opus 5"},
                      "context_window":{"used_percentage":72}}')")"

check 'five_hour だけなら 7d が消える' \
  'Opus 5 · 5h 12%' \
  "$(tail_of "$(run '{"model":{"display_name":"Opus 5"},
                      "rate_limits":{"five_hour":{"used_percentage":12}}}')")"

check 'seven_day だけなら 5h が消える' \
  'Opus 5 · 7d 40%' \
  "$(tail_of "$(run '{"model":{"display_name":"Opus 5"},
                      "rate_limits":{"seven_day":{"used_percentage":40}}}')")"

# model が空のとき、jq の出力を read や @tsv で受けると空フィールドが潰れて以降の値が
# 1つずつ前へずれる。mapfile は IFS を見ないので潰れない。受け方を変えると再発する。
check 'model が無くても後続の値がずれない' \
  'ctx 80% · 5h 10%' \
  "$(tail_of "$(run '{"context_window":{"used_percentage":80},
                      "rate_limits":{"five_hour":{"used_percentage":10}}}')")"

# --- 値の整形 -----------------------------------------------------------------

check '小数の百分率は整数に丸める' \
  'ctx 73% · 5h 12%' \
  "$(tail_of "$(run '{"context_window":{"used_percentage":72.6},
                      "rate_limits":{"five_hour":{"used_percentage":12.4}}}')")"

# 0 は「値が無い」ではなく「消費 0%」。ここを取り違えるとセッション開始直後に消える。
check 'ctx 0% は省略せず出す' \
  'ctx 0%' \
  "$(tail_of "$(run '{"context_window":{"used_percentage":0}}')")"

check 'モデル名の空白がそのまま残る' \
  'Claude Opus 5' \
  "$(tail_of "$(run '{"model":{"display_name":"Claude Opus 5"}}')")"

# --- プロジェクト名とリセット時刻 ---------------------------------------------

# プロジェクト名はブランチと同じセクションに入るため tail_of では切り出せない。
# ブランチはリポジトリの実状態で変わるので、'<project> on ' で始まることだけ見る。
check 'プロジェクト名とブランチを on でつなぐ' 'yes' \
  "$([[ "$(run '{"workspace":{"project_dir":"/Users/x/my repo"}}')" == 'my repo on '* ]] \
    && echo yes || echo no)"

# resets_at は絶対時刻なので、実行時に「いまから N 秒後」を組み立てる。期待値の日時も
# スクリプトと同じ組み込み printf で作り、実行環境のタイムゾーンに左右されないようにする。
_now="$(date +%s)"
_at=$(( _now + 7530 ))
printf -v _when '%(%m/%d %H:%M)T' "$_at"

# 5h と 7d は同じ書式で出す。片方だけ残り時間に戻すとここが落ちる。
check '5h はリセット日時を (until ...) で添える' \
  "5h 12% (until ${_when})" \
  "$(tail_of "$(run "{\"rate_limits\":{\"five_hour\":
      {\"used_percentage\":12,\"resets_at\":${_at}}}}")")"

check '7d も同じ書式で出す' \
  "7d 40% (until ${_when})" \
  "$(tail_of "$(run "{\"rate_limits\":{\"seven_day\":
      {\"used_percentage\":40,\"resets_at\":${_at}}}}")")"

# ウィンドウが切れた直後は resets_at が過去になりうる。過ぎた日時を until で出さない。
check '過ぎたリセット時刻は添えない' \
  '5h 12%' \
  "$(tail_of "$(run "{\"rate_limits\":{\"five_hour\":
      {\"used_percentage\":12,\"resets_at\":$(( _now - 100 ))}}}")")"

# --- 色 -----------------------------------------------------------------------

esc_count() {
  # 出力に含まれる ESC の数を数える
  local out="$1" stripped
  stripped="${out//$'\033'/}"
  printf '%s' "$(( ${#out} - ${#stripped} ))"
}

_colored() {
  # 色を付けた状態で1行受け取る
  printf '%s' "$1" | env -u NO_COLOR "$STATUSLINE"
}

check 'NO_COLOR なら ESC を出さない' '0' \
  "$(esc_count "$(run '{"model":{"display_name":"Opus 5"},
                        "context_window":{"used_percentage":72}}')")"

check 'NO_COLOR が無ければ ESC を出す' 'yes' \
  "$([[ "$(esc_count "$(_colored '{"model":{"display_name":"Opus 5"}}')")" -gt 0 ]] \
    && echo yes || echo no)"

color_of() {
  # 百分率に付いた前景色の RGB を取り出す。<種別> は ctx か 5h。
  local kind="$1" json="$2" out
  out="$(_colored "$json")"
  [[ "$out" =~ ${kind}\ .\[0m.\[38\;2\;([0-9]+\;[0-9]+\;[0-9]+)m ]] || return 0
  printf '%s' "${BASH_REMATCH[1]}"
}

readonly GREEN='11;236;202'
readonly YELLOW='252;220;0'
readonly RED='234;89;80'

# ctx もレート制限も消費率で、多いほど危ない。向きが揃っていることが表示の前提なので、
# 逆向きに戻すと必ずここが落ちる。
check 'ctx 消費 20% は緑' "$GREEN"  "$(color_of ctx '{"context_window":{"used_percentage":20}}')"
check 'ctx 消費 65% は黄' "$YELLOW" "$(color_of ctx '{"context_window":{"used_percentage":65}}')"
check 'ctx 消費 90% は赤' "$RED"    "$(color_of ctx '{"context_window":{"used_percentage":90}}')"

# レート制限は ctx と同じ関数を通る。ラベルが変わっても向きが同じことだけ見る。
check '5h 消費 20% は緑' "$GREEN" "$(color_of 5h '{"rate_limits":{"five_hour":{"used_percentage":20}}}')"
check '5h 消費 90% は赤' "$RED"   "$(color_of 5h '{"rate_limits":{"five_hour":{"used_percentage":90}}}')"

# --- jq が無い環境 ------------------------------------------------------------

# jq は Homebrew 依存で、このリポジトリは jq を前提にしない。PATH を絞って
# 不在を再現する。bash と env はスクリプトの起動そのものに要る。
_tmp="$(mktemp -d)"
trap 'rm -rf -- "$_tmp"' EXIT

_nojq="${_tmp}/bin"
mkdir -p "$_nojq"
for _c in bash env git; do ln -sf "$(command -v "$_c")" "${_nojq}/${_c}"; done

check 'jq が無ければ JSON 由来の表示は出さない' '' \
  "$(tail_of "$(printf '%s' '{"model":{"display_name":"Opus 5"},
                              "context_window":{"used_percentage":72}}' \
    | env PATH="$_nojq" NO_COLOR=1 "$STATUSLINE")")"

_rc=0
printf '%s' '{"model":{"display_name":"Opus 5"}}' \
  | env PATH="$_nojq" NO_COLOR=1 "$STATUSLINE" >/dev/null 2>&1 || _rc=$?
check 'jq が無くても失敗しない' 0 "$_rc"

# --- 古い bash ----------------------------------------------------------------

# mapfile と printf '%()T' は bash 4.2 以上でないと無い。PATH の並び次第で macOS 同梱の
# 3.2 が選ばれることがあり、そのときエラーがステータスラインに出てしまっていた。
# 古い bash が手元にある環境でだけ確かめる。
# 古い bash が置かれているのは macOS の /bin/bash だけ。Linux の /bin/bash は 4.2 以上。
if [[ -x /bin/bash ]] &&
   ! /bin/bash -c '(( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 2) ))'
then
  check '古い bash では何も出さない' '' \
    "$(printf '%s' '{"model":{"display_name":"Opus 5"}}' | /bin/bash "$STATUSLINE" 2>&1 || true)"
fi

# --- 結果 ---------------------------------------------------------------------

printf '\n%d tests, %d failed\n' "$_tests" "$_failed"
(( _failed == 0 ))
