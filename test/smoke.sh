#!/usr/bin/env bash
#
# lib/bash のスモークテスト
#
#   bash test/smoke.sh
#
# 網羅を狙ったものではなく、「import できて主要関数が壊れていない」ことと、
# 過去に踏んだ不具合を再発させないことを確認する。

set -ueo pipefail

DOTFILES_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export DOTFILES_PATH

# 出力を安定させる
export TERMCAP_COLOR_MODE=never

# 時刻は実行ごとに、位置はこのファイルを編集するたびに変わる。書式を比べる
# テストでは落としておき、既定で出ること自体は環境から外した子シェルで確かめる。
export LOG_INFO_TS=0
export LOG_INFO_FILE=0

# 色の有無はテスト内で TERMCAP_COLOR_MODE で切り替える。NO_COLOR は
# TERMCAP_COLOR_MODE より優先されるため、実行環境の値を持ち込まない。
unset NO_COLOR

# shellcheck source=/dev/null
source "${DOTFILES_PATH}/lib/bash/import.sh"
import escseq termcap theme log msg cmd
theme::load

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

_tmp="$(mktemp -d)"
trap 'rm -rf -- "$_tmp"' EXIT

# --- import -------------------------------------------------------------------

check 'すべてのライブラリが読み込まれている' \
  '6' "${#IMPORT_IMPORTED_LIBS[@]}"

check 'ライブラリの読み込み元パスが記録されている' \
  "${DOTFILES_PATH}/lib/bash/log.sh" "${IMPORT_IMPORTED_LIBS['log']}"

check_rc 'bashバージョン要求を満たす' 0 import::_version_satisfies '4.0'
check_rc 'bashバージョン要求を満たさない' 1 import::_version_satisfies '99.0'

# 境界。major と minor の優先順を取り違えると通ってしまう。
check_rc 'バージョン比較: 5.3 は 5.3 以上' 0 import::_version_satisfies '5.3' '5.3'
check_rc 'バージョン比較: 5.3 は 5.4 未満' 1 import::_version_satisfies '5.4' '5.3'
check_rc 'バージョン比較: 5.3 は 4.9 以上' 0 import::_version_satisfies '4.9' '5.3'
check_rc 'バージョン比較: 4.9 は 5.0 未満' 1 import::_version_satisfies '5.0' '4.9'
check_rc 'minorを省略した要求を判定できる' 0 import::_version_satisfies '5' '5.0'

# 要求の形式チェック。満たさないのではなく書き誤りとして停止するため、判定は
# 子シェルで行う。
check '不正なバージョン要求は停止する' '1' \
  "$(import::_version_satisfies 'x.y.z' 2>&1 | grep -c 'invalid version requirement')"
check '未実装の桁を含む要求は停止する' '1' \
  "$(import::_version_satisfies '5.3.1' 2>&1 | grep -c 'invalid version requirement')"

# 回帰: バージョン要素の先頭ゼロ。基数を 10# で固定しないと 08 や 09 が8進数として
#   解釈され、算術エラーで比較が失敗する。
check_rc '先頭ゼロを含むバージョンを判定できる' 0 \
  import::_version_satisfies '1.08' '1.9'

# メタ情報はライブラリをsourceせず、先頭のコメントから読む。
#   回帰: 以前はメタ情報の取得にもsourceを使っていたため、ガード行を書き忘れた
#   ライブラリの本体が依存解決の前に実行され、さらに二重に読み込まれていた。
_metadir="${_tmp}/metalibs"
mkdir -p "$_metadir"

printf '%s\n' '# @deps termcap' '' 'echo body' > "${_metadir}/sidefx.sh"
printf '%s\n' '# @author someone' '# @deps termcap' '# @totally-unknown xyz' '' \
  'echo body' > "${_metadir}/unknown.sh"
printf '%s\n' '# @requires-bash 9.0' '' 'this is a ((( syntax error )))' \
  > "${_metadir}/newsyntax.sh"

_import_in_child() {
  # import の失敗は exit するため、親から切り離して子bashで実行する。
  DOTFILES_IMPORT_PATH="$_metadir" bash -c \
    "source '${DOTFILES_PATH}/lib/bash/import.sh'; import ${1}" 2>/dev/null
}

check 'ライブラリ本体が一度だけ実行される' 'body' "$(_import_in_child sidefx)"
check '未知のディレクティブを無視する' 'body' "$(_import_in_child unknown)"

# 回帰: @requires-bash の判定はライブラリをparseする前に行う。満たさない場合に
#   本体の構文エラーが表面化してはならない。
check '要求bashを満たさないライブラリは本体をparseしない' '1' \
  "$(DOTFILES_IMPORT_PATH="$_metadir" bash -c \
      "source '${DOTFILES_PATH}/lib/bash/import.sh'; import newsyntax" 2>&1 \
      | grep -c 'bash 9.0 is required')"

# メタ情報の走査は最初のコメント以外の行で終わる。走査範囲がファイル全体に広がると、
# 関数本体のコメント (msg.sh の <@indent> など) をディレクティブと誤認しうる。
printf '%s\n' '# @deps termcap' '' 'echo body' '# @deps nonexistent_lib' \
  > "${_metadir}/latedirective.sh"

check 'コード行より後のディレクティブは読まない' 'body' \
  "$(_import_in_child latedirective)"

# 依存は再帰的に解決し、依存元より先に読み込む。
printf '%s\n' '# @deps chain_mid' '' 'echo top' > "${_metadir}/chain_top.sh"
printf '%s\n' '# @deps chain_leaf' '' 'echo mid' > "${_metadir}/chain_mid.sh"
printf '%s\n' 'echo leaf' > "${_metadir}/chain_leaf.sh"

check '依存を再帰的に解決し、依存元より先に読み込む' 'leaf mid top' \
  "$(_import_in_child chain_top | tr '\n' ' ' | sed 's/ $//')"

check '読み込み済みライブラリは再importしない' 'body' \
  "$(_import_in_child 'sidefx sidefx')"

# 循環依存はローダの安全装置。検出できないと無限再帰になる。
printf '%s\n' '# @deps circ_b' > "${_metadir}/circ_a.sh"
printf '%s\n' '# @deps circ_a' > "${_metadir}/circ_b.sh"

check '循環依存を検出して停止する' '1' \
  "$(DOTFILES_IMPORT_PATH="$_metadir" bash -c \
      "source '${DOTFILES_PATH}/lib/bash/import.sh'; import circ_a" 2>&1 \
      | grep -c 'circular library dependency detected: circ_a circ_b -> circ_a')"

check '存在しないライブラリはエラーで停止する' '1' \
  "$(DOTFILES_IMPORT_PATH="$_metadir" bash -c \
      "source '${DOTFILES_PATH}/lib/bash/import.sh'; import nonexistent_lib" 2>&1 \
      | grep -c 'library file not found: nonexistent_lib')"

# 検索パス。DOTFILES_IMPORT_PATH は :区切りの文字列のまま保つ。配列にすると
# export できず、子プロセスへ引き継げない。
_altdir="${_tmp}/altlibs"
_altdir2="${_tmp}/altlibs2"
mkdir -p "$_altdir" "$_altdir2"
printf '%s\n' 'echo alt' > "${_altdir}/altlib.sh"
printf '%s\n' 'echo first' > "${_altdir}/dup.sh"
printf '%s\n' 'echo second' > "${_altdir2}/dup.sh"

check '検索パスは左から優先される' "${_altdir}/dup.sh" \
  "$(import::_find_library_file dup "${_altdir}:${_altdir2}")"
check_rc '検索パスに無いライブラリは見つからない' 1 \
  import::_find_library_file dup "$_altdir2/nowhere"

# 回帰: 初期化時に配列へ固定していた頃は、読み込み後に設定し直した値が効かず、
#   既定のパスも失われていた。
check '初期化後に設定した検索パスが反映される' 'alt' \
  "$(bash -c "source '${DOTFILES_PATH}/lib/bash/import.sh'
              DOTFILES_IMPORT_PATH='${_altdir}'
              import altlib" 2>/dev/null)"

check '検索パスを足しても既定のパスは残る' 'ok' \
  "$(DOTFILES_IMPORT_PATH="$_altdir" bash -c \
      "source '${DOTFILES_PATH}/lib/bash/import.sh'; import cmd && echo ok" 2>/dev/null)"

# 回帰: 配列は export できないため、子プロセスで追加パスが失われていた。
check '検索パスが子プロセスに引き継がれる' 'alt' \
  "$(DOTFILES_IMPORT_PATH="$_altdir" bash -c \
      "source '${DOTFILES_PATH}/lib/bash/import.sh' >/dev/null 2>&1
       bash -c \"source '${DOTFILES_PATH}/lib/bash/import.sh'; import altlib\"" 2>/dev/null)"

# 既定のパスが末尾に加わることは、未検出時のエラーが示す検索パスで確かめる。
check '未検出のエラーが検索パスを示す' '1' \
  "$(DOTFILES_IMPORT_PATH="$_altdir" bash -c \
      "source '${DOTFILES_PATH}/lib/bash/import.sh'; import nonexistent_lib" 2>&1 \
      | grep -c "searched: ${_altdir}:${DOTFILES_PATH}/lib/bash")"

# --- escseq -------------------------------------------------------------------

check 'escseq::sgr --bold' \
  "$(printf '\033[1m')" "$(escseq::sgr --bold)"

check 'escseq::sgr 真彩色(16進)' \
  "$(printf '\033[38;2;255;0;0m')" "$(escseq::sgr --fg-tc '#ff0000')"

check 'escseq::sgr 真彩色(R:G:B)' \
  "$(printf '\033[38;2;255;0;0m')" "$(escseq::sgr --fg-tc '255:0:0')"

# 前景と背景の違いは先頭のコードだけ。表から引く値を取り違えると入れ替わる。
check 'escseq::sgr 背景の真彩色' \
  "$(printf '\033[48;2;0;0;255m')" "$(escseq::sgr --bg-tc '#0000ff')"

check 'escseq::sgr 8bit色' \
  "$(printf '\033[38;5;42m')" "$(escseq::sgr --fg-256 42)"

check 'escseq::sgr 引数なしはreset' \
  "$(printf '\033[0m')" "$(escseq::sgr)"

check_rc 'escseq::sgr 不正オプションは失敗する' 1 escseq::sgr --nosuchoption
check_rc 'escseq::sgr 不正な16進は失敗する' 1 escseq::sgr --fg-tc 'zzzzzz'
check_rc 'escseq::sgr 引数不足は失敗する' 1 escseq::sgr --fg-tc

# 回帰: escseq::sgr が呼び出し側の IFS を破壊しない
_ifs_before="$IFS"
escseq::sgr --bold >/dev/null
check 'escseq::sgr が IFS を保つ' "$(printf '%q' "$_ifs_before")" "$(printf '%q' "$IFS")"

# --- termcap ------------------------------------------------------------------

check_rc 'TERMCAP_COLOR_MODE=never で色なし' 1 termcap::is_color_supported 1
check_rc 'TERMCAP_COLOR_MODE=always で色あり' 0 \
  env TERMCAP_COLOR_MODE=always bash -c \
    "source '${DOTFILES_PATH}/lib/bash/import.sh'; import termcap; termcap::is_color_supported 1"

# --- theme --------------------------------------------------------------------

check_rc 'theme::load 既定テーマ' 0 theme::load
check_rc 'theme::load 存在しないテーマ' 1 theme::load nosuchtheme

# 回帰: 前回の内容が残らないよう nameref 経由でクリアされる
STYLE=( ['dummy']='x' )
theme::_apply_styles 1
check '前回のキーが残らない' '' "${STYLE[dummy]:-}"
# shellcheck disable=SC2154  # 定義されていないことを確認するテスト
check 'init_map というグローバル変数を作らない' '' "$(declare -p init_map 2>/dev/null || true)"

# 色が無効でもキーは揃える。欠けていると参照側が :- を書かないと set -u で落ちる。
check '色なしでもキーは揃う' '1' "$(( ${#STYLE[@]} > 0 ? 1 : 0 ))"
check '色なしでは値が空になる' '' "${STYLE[msg_highlight]}"

TERMCAP_COLOR_MODE=always theme::_apply_styles 1
check '色ありでは値が入る' '1' "$(( ${#STYLE[msg_highlight]} > 0 ? 1 : 0 ))"
theme::load

# --- log ----------------------------------------------------------------------

check 'logger --info が出力される' \
  '1' "$(LOG_LEVEL=1 logger --info 'hello' 2>&1 | grep -c 'hello')"

check 'logger --debug は既定レベルで抑制される' \
  '0' "$(LOG_LEVEL=1 logger --debug 'hidden' 2>&1 | grep -c 'hidden')"

check 'LOG_LEVEL=-1 でログ無効' \
  '0' "$(LOG_LEVEL=-1 logger --error 'quiet' 2>&1 | grep -c 'quiet')"

check_rc 'logger はレベル指定なしで失敗する' 1 logger 'no level'

# 時刻は既定で出る。このファイルは冒頭で LOG_INFO_TS=0 を export している
# ため、既定値を見るにはそれを環境から外した子シェルが要る。
check '既定では時刻を出さない' '1' \
  "$(env -u LOG_INFO_TS -u LOG_INFO_FILE bash -c "
       source '${DOTFILES_PATH}/lib/bash/import.sh'
       import log theme
       theme::load
       logger --info 'hello'" 2>&1 \
     | grep -cE '^\[  INFO\] hello$')"

# 時刻を出すと行頭に付く。書式は date -Iseconds と同じ。
check 'LOG_INFO_TS=1 で時刻が付く' '1' \
  "$(env -u LOG_INFO_FILE LOG_INFO_TS=1 bash -c "
       source '${DOTFILES_PATH}/lib/bash/import.sh'
       import log theme
       theme::load
       logger --info 'hello'" 2>&1 \
     | grep -cE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+\+[0-9:]+ \[  INFO\] hello$')"

# 回帰: `bash -c` の直下では caller が何も返さない。空のまま組み立てると
#   位置が `::`、関数名が空のメタになって、区切りだけが出ていた。
check 'caller が空でも余計な区切りを出さない' '0' \
  "$(env -u LOG_INFO_TS -u LOG_INFO_FILE bash -c "
       source '${DOTFILES_PATH}/lib/bash/import.sh'
       import log theme
       theme::load
       logger --info 'hello'" 2>&1 \
     | grep -cE '\] (::|:)')"

# 回帰: caller が何も返さないと read が EOF で非ゼロを返す。受け流さないと
#   set -e の下でシェルごと落ちて、ログが1行も出なかった。
check 'set -e 下で caller が空でも落ちない' 'AFTER' \
  "$(env -u LOG_INFO_TS -u LOG_INFO_FILE bash -c "
       set -ueo pipefail
       source '${DOTFILES_PATH}/lib/bash/import.sh'
       import log theme
       theme::load
       logger --info 'hello'
       echo 'AFTER'" 2>/dev/null)"

# 既定では位置も出る。関数の中から呼べば file:line 関数 の並びになる。
check '既定で位置が出る' '1' \
  "$(env -u LOG_INFO_TS -u LOG_INFO_FILE bash -c "
       source '${DOTFILES_PATH}/lib/bash/import.sh'
       import log theme
       theme::load
       f() { logger --info 'hello'; }; f" 2>&1 \
     | grep -cE '\[  INFO\] bash:[0-9]+ f: hello$')"

# レベル欄は6桁の右詰めを角括弧で囲む。詰め方を変えると本文の桁がずれる。
check 'レベル欄は6桁で揃える' '[  INFO] hello' \
  "$(LOG_INFO_FUNC=0 logger --info 'hello' 2>&1)"
check 'レベル欄は最長でも6桁' '[NOTICE] hello' \
  "$(LOG_INFO_FUNC=0 logger --notice 'hello' 2>&1)"

# WARNING ではなく WARN。LOG_STACKTRACE_WARN と名前を揃える。
check 'warning は WARN と出る' '[  WARN] hello' \
  "$(LOG_INFO_FUNC=0 logger --warn 'hello' 2>&1)"
check '--warning も受ける' '[  WARN] hello' \
  "$(LOG_INFO_FUNC=0 logger --warning 'hello' 2>&1)"

# 本文もメタもレベルと同じ色で塗る。レベルによる例外は設けない。
# 行全体で比べる。シーケンスを前置した grep だと、スタイルが空のときに
# 単なる本文検索へ退化して素通りしてしまう。
#
# ライブラリは「スタイルが空なら囲まない」規則なので、期待値も同じ規則で
# 組み立てる。テーマがキーを持つ前でも後でも、同じテストが意味を持つ。
_wrap() {
  # _wrap <スタイル> <文字列>
  if [[ -n "$1" ]]; then
    printf '%s%s%s' "$1" "$2" "${STYLE_ERR[rst]}"
  else
    printf '%s' "$2"
  fi
}

TERMCAP_COLOR_MODE=always theme::load
_s_err="${STYLE_ERR[log_error]:-}"
_s_dbg="${STYLE_ERR[log_debug]:-}"
_s_inf="${STYLE_ERR[log_info]:-}"
_rst="${STYLE_ERR[rst]}"

# レベル欄は空スタイルでも必ず rst で閉じる。本文は囲むときだけ。
check 'error の本文はレベル色で塗る' \
  "[${_s_err} ERROR${_rst}] $(_wrap "$_s_err" 'BODY')" \
  "$(LOG_STACKTRACE_ERROR=0 LOG_INFO_FUNC=0 logger --error 'BODY' 2>&1)"
check 'debug の本文はレベル色で塗る' \
  "[${_s_dbg} DEBUG${_rst}] $(_wrap "$_s_dbg" 'BODY')" \
  "$(LOG_LEVEL=0 LOG_INFO_FUNC=0 logger --debug 'BODY' 2>&1)"
check 'info の本文もレベル色で塗る' \
  "[${_s_inf}  INFO${_rst}] $(_wrap "$_s_inf" 'BODY')" \
  "$(LOG_INFO_FUNC=0 logger --info 'BODY' 2>&1)"

# メタ (位置・関数名・チャンネル) もレベルと同じ色で塗り、区切りは塗らない。
# log_filename / log_ch / log_funcname の個別指定は使わない。
_color_probe() { logger --error --ch='CH' 'BODY'; }
# メタとレベル欄は空スタイルでも rst を出す。条件が付くのは本文だけ。
check 'メタはレベル色、区切りは素のまま' \
  "[${_s_err} ERROR${_rst}] ${_s_err}_color_probe${_rst} ${_s_err}[CH]${_rst}: $(_wrap "$_s_err" 'BODY')" \
  "$(LOG_STACKTRACE_ERROR=0 _color_probe 2>&1)"
# トレースは位置だけ色を付ける。関数名は地の色のまま残す。
_trace_probe() { logger --error 'boom'; }
_trace_line="$(LOG_STACKTRACE_ABSPATH=0 _trace_probe 2>&1 | grep -m1 '^    at ' || true)"
check 'トレースの位置は log_stacktrace_location で塗る' '1' \
  "$(printf '%s' "$_trace_line" \
     | grep -cF "(${STYLE_ERR[log_stacktrace_location]}")"
check 'トレースの関数名は塗らない' '1' \
  "$(printf '%s' "$_trace_line" | grep -cF 'at _trace_probe(')"

check 'log_funcname は参照しない' '0' \
  "$(grep -c 'log_funcname\|log_filename\|log_ch\b' \
       "${DOTFILES_PATH}/lib/bash/log.sh" || true)"
theme::load

# notice は warn と info の間。既定の LOG_LEVEL=1 では出て、3 では落ちる。
check 'notice は既定で出る' '1' \
  "$(logger --notice 'note' 2>&1 | grep -c 'note')"
check 'notice は LOG_LEVEL=3 で落ちる' '0' \
  "$(LOG_LEVEL=3 logger --notice 'note' 2>&1 | grep -c 'note')"

# チャンネル別レベルはファイル別より優先される。-1 を指定すれば、その
# チャンネルだけ黙らせられる (LOG_DISABLE_CH の代わり)。
_ch_probe() { logger --debug --ch="$1" 'chbody'; }
check 'チャンネル別レベルが優先される' '1' \
  "$(LOG_LEVEL=3 LOG_LEVEL_SMOKE_LOUD=0 _ch_probe loud 2>&1 | grep -c 'chbody')"
check 'チャンネル別レベル -1 で黙る' '0' \
  "$(LOG_LEVEL=0 LOG_LEVEL_SMOKE_QUIET=-1 _ch_probe quiet 2>&1 | grep -c 'chbody')"
check '指定の無いチャンネルは影響を受けない' '1' \
  "$(LOG_LEVEL=0 LOG_LEVEL_SMOKE_QUIET=-1 _ch_probe other 2>&1 | grep -c 'chbody')"

check 'LOG_DISABLE_CH は廃止済み' '0' \
  "$(grep -c 'LOG_DISABLE_CH' "${DOTFILES_PATH}/lib/bash/log.sh" || true)"

# メタは 位置 関数 [ch] の順に並び、全体をコロンで本文と区切る。
# チャンネルを末尾に置くのは、有無で後続の桁がずれないようにするため。
_fmt_probe() { logger --info --ch='ch1' 'hello'; }
check 'メタは 関数 [ch] の順' '[  INFO] _fmt_probe [ch1]: hello' \
  "$(_fmt_probe 2>&1)"

# 回帰: チャンネルの有無で関数名の開始桁が動かない。ch を先頭に置いていた
#   ころは、ch の無い行だけ関数名が左に寄っていた。
_align_probe() {
  logger --info --ch='ch1' 'with'
  logger --info 'without'
}
check 'ch の有無で関数名の桁が動かない' '2' \
  "$(_align_probe 2>&1 | grep -c '^\[  INFO\] _align_probe')"

# 回帰: 区切りを関数名に付けていたころ、関数名が出ない行では区切りごと
#   消えて、位置が本文と地続きになっていた。
check '関数名が無くても区切りは出る' '1' \
  "$(LOG_INFO_FILE=1 logger --info 'hello' 2>&1 \
     | grep -cE '^\[  INFO\] smoke\.sh:[0-9]+: hello$')"
check 'チャンネルだけでも区切りは出る' '[  INFO] [ch1]: hello' \
  "$(LOG_INFO_FUNC=0 logger --info --ch='ch1' 'hello' 2>&1)"
check 'メタが無ければ区切りも出ない' '[  INFO] hello' \
  "$(LOG_INFO_FUNC=0 logger --info 'hello' 2>&1)"

# 回帰: log は theme に依存しない。core.sh を消して escseq/theme も logger を
#   使うようにしたため、theme::load 前に logger が落ちると全体が読み込めなくなる。
check 'theme::load 前でも logger が動く' '1' \
  "$(bash -c "source '${DOTFILES_PATH}/lib/bash/import.sh'
              import log
              logger --info 'nostyle'" 2>&1 | grep -c 'nostyle')"

# 下層ライブラリのエラーも logger の書式で出る。
check 'escseq のエラーが logger 経由で出る' '1' \
  "$(escseq::sgr --nosuchoption 2>&1 | grep -c 'ERROR.*illegal option')"

check 'core::error は削除済み' '' "$(type -t core::error 2>/dev/null || true)"

# --- msg ----------------------------------------------------------------------

check 'msg 基本出力' '[>] hello' "$(msg 'hello')"
check 'msg --no-prefix' 'hello' "$(msg --no-prefix 'hello')"
check 'msg -n は改行しない' '1' "$(( $(msg -n 'x' | wc -l) == 0 ? 1 : 0 ))"
check 'msg::ok のプレフィックス' '[^] done' "$(msg::ok 'done')"
check 'msg::error のプレフィックス' '[x] oops' "$(msg::error 'oops')"
check 'msg 空文字でもプロンプトは出る' '[>] ' "$(msg -- '')"

check 'msg::newline は改行だけ出す' '1' "$(msg::newline | wc -l | tr -d ' ')"
check '名前空間なしの newline は定義しない' '' "$(type -t newline 2>/dev/null || true)"

check_rc 'msg 不正オプションは失敗する' 1 msg --nosuchoption -- 'x'
check_rc 'msg --prefix の値が無ければ失敗する' 1 msg --prefix

# 本文は解釈しない。タグに見える文字列もそのまま出る。
check 'msg はタグを解釈しない' '[>] a <hl>b</hl> c' "$(msg 'a <hl>b</hl> c')"

# 回帰: 本文のバックスラッシュを解釈しない (printf %b をやめた)
check 'msg がバックスラッシュを保つ' \
  'path\with\backslash' "$(msg --no-prefix -- 'path\with\backslash')"
check 'msg が \n を改行にしない' 'a\nb' "$(msg --no-prefix -- 'a\nb')"
check 'msg が \\ を畳まない' 'a\\b' "$(msg --no-prefix -- 'a\\b')"

# プレフィックスは最初の行だけ。続く行は同じ幅の空白で揃える。
check 'プレフィックスは最初の行だけに付く' "$(printf '[>] a\n    b')" \
  "$(msg -- "$(printf 'a\nb')")"

# 字下げの幅はプレフィックスに追従する
check '字下げはプレフィックスの幅に合わせる' "$(printf '##### a\n      b')" \
  "$(msg --prefix='#####' -- "$(printf 'a\nb')")"

# --no-prefix では字下げもしない
check '--no-prefix では字下げもしない' "$(printf 'a\nb')" \
  "$(msg --no-prefix -- "$(printf 'a\nb')")"

# 色は呼び出し側が STYLE を埋めて組み立てる。色ありでしか確認できない
#   ため、ここだけテーマを読み直す。
TERMCAP_COLOR_MODE=always theme::load

_msg_rst="${STYLE[rst]}"
_msg_hl="${STYLE[msg_highlight]}"
_msg_normal="${STYLE[normal]}"
_msg_bold="${STYLE[bold]}"

# base style は行の頭に置く。本文は書き換えない。
check '行頭に base style を置く' "${_msg_normal}x${_msg_rst}" \
  "$(msg --no-prefix -- 'x')"

# 呼び出し側が埋めたスタイルはそのまま出る。rst は素直にリセットする
# (base style に戻す、といった書き換えはしない)。
check '呼び出し側のスタイルをそのまま通す' \
  "${_msg_normal}a ${_msg_hl}b${_msg_rst} c${_msg_rst}" \
  "$(msg --no-prefix -- "a ${_msg_hl}b${_msg_rst} c")"

# --base-style は行の頭に置くだけ。本文は書き換えない。
check '--base-style は行頭に置く' \
  "${STYLE[msg_ok]}x${_msg_rst}" \
  "$(msg --no-prefix --base-style='msg_ok' -- 'x')"

# --opt=value と --opt value は同じ結果になる。
check '--base-style=X と --base-style X が一致する' \
  "$(msg --no-prefix --base-style 'msg_ok' -- 'x')" \
  "$(msg --no-prefix --base-style='msg_ok' -- 'x')"
check '--prefix=X と --prefix X が一致する' \
  "$(msg --prefix '##' -- 'x')" "$(msg --prefix='##' -- 'x')"

# 値の区切りに = を使う形でも、-- 以降の本文は巻き込まない。
check '-- 以降の本文を分割しない' '1' "$(msg -- '--a=b' | grep -c -- '--a=b')"

# 回帰: 強調を base のスタイルで閉じるとリセットを通らないため、呼び出し側が
#   重ねた属性 (bold など) が残る。rst で閉じると一緒に落ちてしまう。
_msg_out="$(msg --no-prefix -- "${_msg_bold}a ${_msg_hl}b${_msg_normal} c")"
_msg_less="${_msg_out//${_msg_bold}/}"

check 'base で閉じれば重ねた属性が残る' '1' \
  "$(( (${#_msg_out} - ${#_msg_less}) / ${#_msg_bold} ))"
check 'base で閉じればリセットは行末だけ' '1' \
  "$(( $(printf '%s' "$_msg_out" | grep -oF "$_msg_rst" | wc -l | tr -d ' ') ))"

# 複数行でも行ごとに base style を置く。
check '行ごとに base style を置く' \
  "$(printf '%sa%s\n%sb%s' "$_msg_normal" "$_msg_rst" "$_msg_normal" "$_msg_rst")" \
  "$(msg --no-prefix -- "$(printf 'a\nb')")"

# msg::notice などが色を付けるのはプレフィックスだけ。本文は既定の base に
#   なるため、呼び出し側は戻り先 (normal) を知ったうえで組み立てられる。
check 'msg::notice が色を付けるのはプレフィックスだけ' \
  "${STYLE[msg_notice]}[~]${_msg_rst} ${_msg_normal}hello${_msg_rst}" \
  "$(msg::notice 'hello')"

# -R は行を組み立てたあとに囲むため、呼び出し側が本文へ埋めたシーケンスも
#   取りこぼさない。裸のまま残すと readline が表示幅に数えて位置がずれる。
_msg_count() { printf '%s' "$2" | tr -dc "$1" | wc -c | tr -d ' '; }

_msg_r="$(msg -n -R --no-prefix -- "a ${_msg_hl}b")"

check '-R が本文のシーケンスも囲む' \
  "$(_msg_count $'\033' "$_msg_r")" "$(_msg_count $'\x01' "$_msg_r")"
check '-R の SOH と STX が対になる' \
  "$(_msg_count $'\x01' "$_msg_r")" "$(_msg_count $'\x02' "$_msg_r")"
check '-R なしでは印を付けない' '0' \
  "$(_msg_count $'\x01' "$(msg -n --no-prefix -- "a ${_msg_hl}b")")"

theme::load

# --- cmd ----------------------------------------------------------------------

check_rc 'cmd::check 存在するコマンド' 0 cmd::check bash
check_rc 'cmd::check 存在しないコマンド' 1 cmd::check __no_such_command__
check_rc 'cmd::check 引数なしは失敗する' 1 cmd::check
check_rc 'cmd::check 引数が多いと失敗する' 1 cmd::check bash sh

# 見つからないことは戻り値だけでなく表示でも知らせる。
check 'cmd::check は not found を知らせる' '1' \
  "$(cmd::check __no_such_command__ 2>&1 | grep -c 'command not found')"

# 回帰: cmd::check がグローバルな usage 関数を定義しない
cmd::check bash >/dev/null || true
check 'cmd::check が usage 関数を漏らさない' '' "$(declare -F usage 2>/dev/null || true)"

# 削除・改名済み関数
check 'util::sysinfo は削除済み' '' "$(type -t util::sysinfo 2>/dev/null || true)"
check 'util::chk は改名済み' '' "$(type -t util::chk 2>/dev/null || true)"
check 'util::has_cmd は改名済み' '' "$(type -t util::has_cmd 2>/dev/null || true)"

# --- 結果 ---------------------------------------------------------------------

printf '\n'
if (( _failed )); then
  printf '%d/%d failed\n' "$_failed" "$_tests"
  exit 1
fi
printf 'all %d tests passed\n' "$_tests"
