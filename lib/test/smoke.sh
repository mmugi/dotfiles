#!/usr/bin/env bash
#
# lib/bash のスモークテスト
#
#   bash lib/test/smoke.sh
#
# 網羅を狙ったものではなく、「import できて主要関数が壊れていない」ことと、
# 過去に踏んだ不具合を再発させないことを確認する。

set -ueo pipefail

DOTFILES_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
export DOTFILES_PATH

# 出力を安定させる
export MSG_DELAY=0
export TERMCAP_COLOR_MODE=never

# 色の有無はテスト内で TERMCAP_COLOR_MODE で切り替える。NO_COLOR は
# TERMCAP_COLOR_MODE より優先されるため、実行環境の値を持ち込まない。
unset NO_COLOR

# shellcheck source=/dev/null
source "${DOTFILES_PATH}/lib/bash/import.sh"
import core escseq termcap trap theme log msg util dotfiles shellconf
theme::load
msg::init

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

# --- import -------------------------------------------------------------------

check 'すべてのライブラリが読み込まれている' \
  '10' "${#IMPORT_IMPORTED_LIBS[@]}"

check 'ライブラリバージョンが記録されている' \
  '1.0.0' "${IMPORT_IMPORTED_LIBS['core']}"

check 'バージョン比較: 1.10.0 > 1.9.0' \
  '1' "$(import::_version_compare '1.10.0' '1.9.0')"

check_rc 'bashバージョン要求を満たす' 0 import::_version_satisfies '>=4.0'
check_rc 'bashバージョン要求を満たさない' 1 import::_version_satisfies '<4.0'
check_rc '不正なバージョン要求は失敗する' 1 import::_version_satisfies 'x.y.z'

# --- escseq -------------------------------------------------------------------

check 'escseq::sgr --bold' \
  "$(printf '\033[1m')" "$(escseq::sgr --bold)"

check 'escseq::sgr 真彩色(16進)' \
  "$(printf '\033[38;2;255;0;0m')" "$(escseq::sgr --fg-tc '#ff0000')"

check 'escseq::sgr 真彩色(R:G:B)' \
  "$(printf '\033[38;2;255;0;0m')" "$(escseq::sgr --fg-tc '255:0:0')"

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

# 回帰: 色なしfdでは nameref 経由でスタイルマップがクリアされる
STYLE_STDOUT=( ['dummy']='x' )
theme::_apply_styles 1
check '色なしfdでスタイルマップが空になる' '0' "${#STYLE_STDOUT[@]}"
# shellcheck disable=SC2154  # 定義されていないことを確認するテスト
check 'init_map というグローバル変数を作らない' '' "$(declare -p init_map 2>/dev/null || true)"

TERMCAP_COLOR_MODE=always theme::_apply_styles 1
check '色ありfdでスタイルが入る' '1' "$(( ${#STYLE_STDOUT[@]} > 0 ? 1 : 0 ))"
theme::load

# --- trap ---------------------------------------------------------------------

# サブシェルにするとカウンタの更新が親に戻らないため、このシェルで実行して
# trap::restore_handler で後片付けする(この時点でEXITトラップは未使用)。
trap -- 'true' EXIT
trap::save_handler 'EXIT' 'INT'
trap::concat 'EXIT' 'echo injected'
check 'trap::concat が既存ハンドラを保持する' \
  "trap -- 'echo injected;true' EXIT" "$(trap -p EXIT)"
trap::restore_handler
check 'trap::restore_handler が元に戻す' \
  "trap -- 'true' EXIT" "$(trap -p EXIT)"
check 'trap::restore_handler が未設定シグナルを解除する' '' "$(trap -p INT)"
trap -- - EXIT

# --- log ----------------------------------------------------------------------

check 'logger --info が出力される' \
  '1' "$(LOG_LEVEL=1 logger --info 'hello' 2>&1 | grep -c 'hello')"

check 'logger --debug は既定レベルで抑制される' \
  '0' "$(LOG_LEVEL=1 logger --debug 'hidden' 2>&1 | grep -c 'hidden')"

check 'LOG_LEVEL=-1 でログ無効' \
  '0' "$(LOG_LEVEL=-1 logger --error 'quiet' 2>&1 | grep -c 'quiet')"

check_rc 'logger はレベル指定なしで失敗する' 1 logger 'no level'

# --- msg ----------------------------------------------------------------------

check 'msg 基本出力' '[>] hello' "$(msg 'hello')"
check 'msg インラインタグが除去される' '[>] a b c' "$(msg 'a <hl>b</hl> c')"
check 'msg --no-prompt' 'hello' "$(msg --no-prompt 'hello')"
check 'msg -n は改行しない' '1' "$(( $(msg -n 'x' | wc -l) == 0 ? 1 : 0 ))"
check 'msg --raw はそのまま出す' '<hl>raw</hl>' "$(msg -r --no-prompt '<hl>raw</hl>')"
check 'msg::ok のプロンプト' '[^] done' "$(msg::ok 'done')"
check 'msg::error のプロンプト' '[;] oops' "$(msg::error 'oops')"

check 'msg::newline は改行だけ出す' '1' "$(msg::newline | wc -l | tr -d ' ')"
check '名前空間なしの newline は定義しない' '' "$(type -t newline 2>/dev/null || true)"

# 回帰: width属性なしの <@indent> が set -u で落ちない
check '<@indent> 属性なし' '[>] x' "$(msg '<@indent>x</@indent>')"

# <@indent> はブロックタグで、行頭のインデント描画は BEGIN_LINE 時点で
# 行われる。そのため開始タグと同じ行には効かず、次の行から適用される。
check '<@indent width> は次の行から効く' \
  "$(printf '    [>] x\n[>] y')" \
  "$(msg "$(printf '<@indent width="4">\nx\n</@indent>\ny')")"

# 回帰: 1行内のブロック閉じタグが set -e でスクリプトを落とさない
check '<@b> を1行で開閉' '[>] x' "$(msg '<@b>x</@b>')"
check_rc '対応漏れの閉じタグでも継続する' 0 msg 'text </@b> more'

# 回帰: 閉じ忘れ inline タグの後もスタイルが正しく復帰する
_ctl="$(TERMCAP_COLOR_MODE=always msg '<b>B<it>I</it>C</b>' | od -c | grep -c '1  m' || true)"
_aft="$(TERMCAP_COLOR_MODE=always msg "$(printf 'l1 <hl>x\nl2 <b>B<it>I</it>C</b>')" \
        | tail -1 | od -c | grep -c '1  m' || true)"
check '閉じ忘れタグの後もstyleが復帰する' "$_ctl" "$_aft"

# 回帰: 属性値にglob文字があってもトークナイザが止まらない
check 'glob文字を含む属性値' '[>] x' "$(msg '<hl style="a[b*">x</hl>')"

# 回帰: 本文のバックスラッシュを解釈しない (printf %b をやめた)
check 'msg がバックスラッシュを保つ' \
  'path\with\backslash' "$(msg --no-prompt -- 'path\with\backslash')"
check 'msg が \n を改行にしない' 'a\nb' "$(msg --no-prompt -- 'a\nb')"
check 'msg が \\ を畳まない' 'a\\b' "$(msg --no-prompt -- 'a\\b')"

# 改行したい場合の代替手段が使えること
check '<@br> で改行できる' "$(printf 'a\nb')" "$(msg --no-prompt -- 'a<@br>b')"

check_rc 'msg::_push_token_stack 引数0は失敗する' 1 msg::_push_token_stack
check_rc 'msg::_push_token_stack 引数4は失敗する' 1 msg::_push_token_stack a b c d

# --- msg::box -----------------------------------------------------------------

if (( _MSG_PYTHON3_UNAVAILABLE )); then
  # python3 が無い環境では msg::box は枠を描かず msg にフォールバックする。
  printf 'skip - msg::box の幅計算 (python3 なし。フォールバックのみ確認)\n'
  check 'python3なしでは枠を描かない' '0' \
    "$(msg::box -- 'x' | grep -c '[┌└]')"
  check 'python3なしでもメッセージは出る' '[>] x' "$(msg::box -- 'x')"
else
  check 'msg::box が枠を描く' '1' \
    "$(( $(msg::box -- 'x' | grep -c '[┌└]') == 2 ? 1 : 0 ))"

  # awk の length はロケール次第でバイト数を数えるため、表示幅の比較には
  # ライブラリ自身の幅計算を使う。全行が同じ表示幅になれば枠が揃っている。
  check 'msg::box 全角文字の幅が揃う' '1' \
    "$(msg::_calc_line_widths "$(msg::box -- '日本語' 'ab')" | sort -u | wc -l | tr -d ' ')"

  check 'msg::_calc_line_widths は入力と同じ行数を返す' \
    '3' "$(msg::_calc_line_widths "$(printf 'a\n\nbb')" | wc -l | tr -d ' ')"

  check 'msg::_calc_line_widths が全角を2幅で数える' \
    '6' "$(msg::_calc_line_widths '日本語')"

  # 回帰: box経由でもバックスラッシュが壊れない
  # (以前は msg と msg::box で %b が二重にかかり、幅計算が非印字文字で失敗していた)
  check 'msg::box がバックスラッシュを保つ' '1' \
    "$(msg::box -- 'a\bc' | grep -c 'a\\bc')"

  # --box-rendered: 整形済みの行をそのまま枠で囲む
  check 'msg::box --box-rendered が枠を描く' '1' \
    "$(( $(msg::box --box-rendered -- "$(msg::rm 'x')" | grep -c '[┌└]') == 2 ? 1 : 0 ))"

  # rm と skipped がそれぞれのプロンプトで1行ずつ出ること
  check '--box-rendered が行ごとのプロンプトを保つ' '2' \
    "$(msg::box --box-rendered -- "$(msg::rm 'a'; msg::skipped 'b')" \
       | grep -cE '\[/\] a|\[-\] b' | tr -d ' ')"

  # 色付きでも枠が揃う(幅計算がエスケープシーケンスを除去できている)
  check '--box-rendered 色付きでも幅が揃う' '1' \
    "$(msg::_calc_line_widths \
        "$(msg::_strip_escseq \
            "$(TERMCAP_COLOR_MODE=always msg::box --box-rendered -- \
                "$(TERMCAP_COLOR_MODE=always msg::rm 'removed')")")" \
       | sort -u | wc -l | tr -d ' ')"
fi

check 'msg::_strip_escseq がCSIを除去する' 'bold' \
  "$(msg::_strip_escseq "$(printf '\033[1mbold\033[0m')")"

check 'msg::_strip_escseq がSOH/STXを除去する' 'x' \
  "$(msg::_strip_escseq "$(printf '\001x\002')")"

check 'MSG_BOX=0 でboxを描かない' '0' \
  "$(MSG_BOX=0 msg::box -- 'x' | grep -c '[┌└]')"

check 'msg::_repeat_char' '-----' "$(msg::_repeat_char '-' 5)"
check 'msg::_repeat_char 負数は0扱い' '' "$(msg::_repeat_char '-' -3)"

# 回帰: 非端末では msg::line が sum(1..n) 文字を吐かない
check 'msg::line 非端末では1行ぶんだけ' '20' "$(msg::line 20 | tr -d '\n' | wc -c | tr -d ' ')"

# --- util ---------------------------------------------------------------------

check_rc 'util::chk 存在するコマンド' 0 util::chk -cq bash
check_rc 'util::chk 存在しないコマンド' 1 util::chk -cq __no_such_command__
check_rc 'util::chk セレクタなしは失敗する' 1 util::chk -q bash
check_rc 'util::chk 引数なしは失敗する' 1 util::chk

# 回帰: util::chk がグローバルな usage 関数を定義しない
util::chk -cq bash || true
check 'util::chk が usage 関数を漏らさない' '' "$(declare -F usage 2>/dev/null || true)"

# 削除済み関数
check 'util::sysinfo は削除済み' '' "$(type -t util::sysinfo 2>/dev/null || true)"

_tmp="$(mktemp -d)"
trap 'rm -rf -- "$_tmp"' EXIT

printf 'src\n' > "${_tmp}/src"

check_rc 'util::install --check 配置可能' 0 util::install --check "${_tmp}/src" "${_tmp}/dst"
check 'util::install --check は何も作らない' '0' \
  "$([[ -e "${_tmp}/dst" || -L "${_tmp}/dst" ]] && echo 1 || echo 0)"

check_rc 'util::install シンボリックリンク作成' 0 util::install "${_tmp}/src" "${_tmp}/dst"
check 'リンクが張られている' '1' "$([[ -L "${_tmp}/dst" ]] && echo 1 || echo 0)"

check_rc 'util::install 冪等' 0 util::install "${_tmp}/src" "${_tmp}/dst"

printf 'other\n' > "${_tmp}/other"
check_rc 'util::install 別ファイルが居る場合は失敗する' 1 \
  util::install "${_tmp}/src" "${_tmp}/other"

check_rc 'util::uninstall --dry-run' 0 util::uninstall --dry-run "${_tmp}/src" "${_tmp}/dst"
check 'dry-run ではリンクが残る' '1' "$([[ -L "${_tmp}/dst" ]] && echo 1 || echo 0)"

check_rc 'util::uninstall 解除' 0 util::uninstall "${_tmp}/src" "${_tmp}/dst"
check 'リンクが消えている' '0' "$([[ -e "${_tmp}/dst" || -L "${_tmp}/dst" ]] && echo 1 || echo 0)"

check_rc 'util::uninstall 存在しない対象は成功' 0 util::uninstall "${_tmp}/src" "${_tmp}/dst"
check_rc 'util::uninstall シンボリックリンク以外は失敗' 1 \
  util::uninstall "${_tmp}/src" "${_tmp}/other"

# --- dotfiles -----------------------------------------------------------------

check 'DOTFILES_CONFIG_DIR' "${DOTFILES_PATH}/configs" "$DOTFILES_CONFIG_DIR"
check 'DOTFILES_IGNOREFILE' "${DOTFILES_PATH}/.dotignore" "$DOTFILES_IGNOREFILE"
check 'DOTFILES_LOGO が定義されている' '1' \
  "$(( ${#DOTFILES_LOGO} > 0 ? 1 : 0 ))"

# dotfiles::is_ignored
#   実際の .dotignore はユーザー固有のファイルなので触らない。
#   DOTFILES_IGNOREFILE は declare -g なので、import 後に差し替えられる。
_ignorefile_orig="$DOTFILES_IGNOREFILE"
DOTFILES_IGNOREFILE="${_tmp}/dotignore"

printf '# comment\n.vimrc\n\n.config/git\n' > "$DOTFILES_IGNOREFILE"

check_rc 'is_ignored 完全一致' 0 dotfiles::is_ignored '.vimrc'
check_rc 'is_ignored 前方一致' 0 dotfiles::is_ignored '.config/git/ignore'
check_rc 'is_ignored 一致しない' 1 dotfiles::is_ignored '.config/nvim/init.lua'
check_rc 'is_ignored コメント行は無視' 1 dotfiles::is_ignored 'comment'
check_rc 'is_ignored 空行は全一致しない' 1 dotfiles::is_ignored 'anything/else'
check_rc 'is_ignored 引数なしは失敗' 1 dotfiles::is_ignored
check_rc 'is_ignored 引数過多は失敗' 1 dotfiles::is_ignored a b

: > "$DOTFILES_IGNOREFILE"
check_rc 'is_ignored 空ファイルでは何も除外しない' 1 dotfiles::is_ignored '.vimrc'

rm -f "$DOTFILES_IGNOREFILE"
check_rc 'is_ignored ファイルが無い場合も失敗しない' 1 dotfiles::is_ignored '.vimrc'

DOTFILES_IGNOREFILE="$_ignorefile_orig"

# --- shellconf ----------------------------------------------------------------

# 出力ヘルパ
#   生成物はシェルに読ませる文字列そのものなので、描画結果を固定して
#   意図しない変化に気づけるようにする。

# 期待値は生成先のシェルが評価するコードなので、ここでは展開させない
# shellcheck disable=SC2016
check 'eval_init bash' 'eval "$(starship init bash)"' \
  "$(_SHELLCONF_SHELL=bash shellconf::eval_init starship)"
# shellcheck disable=SC2016
check 'eval_init zsh' 'eval "$(starship init zsh)"' \
  "$(_SHELLCONF_SHELL=zsh shellconf::eval_init starship)"
check 'eval_init fish' 'starship init fish | source' \
  "$(_SHELLCONF_SHELL=fish shellconf::eval_init starship)"
# shellcheck disable=SC2016
check 'eval_init 追加引数' 'eval "$(zoxide init bash --cmd cd)"' \
  "$(_SHELLCONF_SHELL=bash shellconf::eval_init zoxide --cmd cd)"

check 'export posix' "export EDITOR='vim'" \
  "$(_SHELLCONF_SHELL=bash shellconf::export EDITOR 'vim')"
check 'export fish' "set -gx EDITOR 'vim'" \
  "$(_SHELLCONF_SHELL=fish shellconf::export EDITOR 'vim')"

# シングルクォートの流儀がシェルで異なる。posix は '\'' で閉じ直し、
# fish は \' でエスケープする。
check 'export posix のクォート脱出' "export X='a'\\''b'" \
  "$(_SHELLCONF_SHELL=bash shellconf::export X "a'b")"
check 'export fish のクォート脱出' "set -gx X 'a\\'b'" \
  "$(_SHELLCONF_SHELL=fish shellconf::export X "a'b")"
check 'export fish はバックスラッシュも escape する' "set -gx X 'a\\\\b'" \
  "$(_SHELLCONF_SHELL=fish shellconf::export X 'a\b')"

check 'path_prepend posix' "__dotfiles_path_prepend '/opt/bin'" \
  "$(_SHELLCONF_SHELL=bash shellconf::path_prepend '/opt/bin')"
check 'path_prepend fish' "fish_add_path -gp '/opt/bin'" \
  "$(_SHELLCONF_SHELL=fish shellconf::path_prepend '/opt/bin')"

check 'source_if posix' "$(printf "if [ -r '/x' ]; then\n  . '/x'\nfi")" \
  "$(_SHELLCONF_SHELL=bash shellconf::source_if '/x')"
check 'source_if fish' "$(printf "if test -r '/x'\n  source '/x'\nend")" \
  "$(_SHELLCONF_SHELL=fish shellconf::source_if '/x')"

check_rc 'export 引数不足は失敗する' 1 shellconf::export ONLYNAME
check_rc 'path_prepend 引数不足は失敗する' 1 shellconf::path_prepend

check '_indent は空行を字下げしない' "$(printf '  a\n\n  b')" \
  "$(printf 'a\n\nb' | shellconf::_indent)"

# エントリの描画
_reg="${_tmp}/reg"
mkdir -p "${_reg}/shell/rc.d"

cat > "${_reg}/shell/rc.d/50-guarded.sh" <<'ENTRY'
guard='somecmd'
render() { shellconf::raw 'BODY'; }
ENTRY

check 'guard で実行時チェックが巻かれる (posix)' \
  "$(printf 'if command -v somecmd >/dev/null 2>&1; then\n  BODY\nfi')" \
  "$(shellconf::render_entry "${_reg}/shell/rc.d/50-guarded.sh" bash | grep -v '^#' | sed '/^$/d')"

check 'guard で実行時チェックが巻かれる (fish)' \
  "$(printf 'if type -q somecmd\n  BODY\nend')" \
  "$(shellconf::render_entry "${_reg}/shell/rc.d/50-guarded.sh" fish | grep -v '^#' | sed '/^$/d')"

cat > "${_reg}/shell/rc.d/60-fishonly.sh" <<'ENTRY'
shells='fish'
render() { shellconf::raw 'FISHBODY'; }
ENTRY

check 'shells で対象外のシェルには何も出さない' '' \
  "$(shellconf::render_entry "${_reg}/shell/rc.d/60-fishonly.sh" bash)"
check 'shells で対象のシェルには出す' '1' \
  "$(shellconf::render_entry "${_reg}/shell/rc.d/60-fishonly.sh" fish | grep -c 'FISHBODY')"

cat > "${_reg}/shell/rc.d/70-empty.sh" <<'ENTRY'
render() { :; }
ENTRY

check 'render が無出力なら見出しも出さない' '' \
  "$(shellconf::render_entry "${_reg}/shell/rc.d/70-empty.sh" bash)"

# エントリはサブシェルで読むため、名前が呼び出し側へ漏れない
check 'エントリの guard が呼び出し側へ漏れない' '' "${guard:-}"
check 'エントリの render が呼び出し側へ漏れない' '' "$(declare -F render 2>/dev/null || true)"

check_rc '読めないエントリは失敗する' 1 \
  shellconf::render_entry "${_reg}/shell/rc.d/__nosuch__.sh" bash

# レジストリの合流
#   プライベートオーバーレイのエントリが、公開側とファイル名順で混ざること。
#   公開リポジトリに置かない設定を差し込むための性質。
_private_orig="$DOTFILES_PRIVATE_PATH"
DOTFILES_PRIVATE_PATH="$_reg"

check 'registry_dirs が両方のルートを返す' '2' \
  "$(shellconf::registry_dirs rc | wc -l | tr -d ' ')"

check 'entries がファイル名順で合流する' \
  "$(printf '50-guarded.sh\n50-prompt.sh\n60-fishonly.sh\n70-empty.sh\n70-git-completion.sh\n80-fish-plugins.sh')" \
  "$(shellconf::entries rc | while read -r _e; do basename -- "$_e"; done)"

DOTFILES_PRIVATE_PATH="$_private_orig"

check 'env.d が存在する' '1' \
  "$(( $(shellconf::registry_dirs env | wc -l) >= 1 ? 1 : 0 ))"

# 配置先とフック
check 'outputs は5件' '5' "$(shellconf::outputs | wc -l | tr -d ' ')"
check 'outputs は src と相対配置先のタブ区切り' '.config/shell/rc.bash' \
  "$(shellconf::outputs | awk -F'\t' '$1 ~ /rc\.bash$/ { print $2 }')"
check 'outputs の fish は conf.d へ向く' '.config/fish/conf.d/00-dotfiles.fish' \
  "$(shellconf::outputs | awk -F'\t' '$1 ~ /dotfiles\.fish$/ { print $2 }')"

check 'hook_rcfile bash' "${HOME}/.bashrc" "$(shellconf::hook_rcfile bash)"
check_rc 'hook_rcfile fish はフック不要' 1 shellconf::hook_rcfile fish
check_rc 'hook_block fish はフック不要' 1 shellconf::hook_block fish
check_rc 'hook_target fish はフック不要' 1 shellconf::hook_target fish

check 'hook_target bash' "${HOME}/.config/shell/rc.bash" \
  "$(shellconf::hook_target bash)"

# 利用者が rc に足すのは1行だけ。囲むべき中身が1行しかないため、目印の
# コメントは付けない。
check 'hook_block は1行' '1' "$(shellconf::hook_block bash | wc -l | tr -d ' ')"
# $HOME はリテラルで埋め込む。ホームの場所が変わっても、また rc を別の
# マシンへ持っていっても壊れないようにするため。
# shellcheck disable=SC2016
check 'hook_block の中身' '[ -r "$HOME/.config/shell/rc.zsh" ] && . "$HOME/.config/shell/rc.zsh"' \
  "$(shellconf::hook_block zsh)"

# hook_installed
#   rc は利用者のものなので、こちらが出した文面そのままとは限らない。
#   目印のコメントではなく読み込み先のパスで判定していることを確認する。
_home_orig="$HOME"
_local_orig="$SHELLCONF_LOCAL_DIR"
HOME="${_tmp}/home"
SHELLCONF_LOCAL_DIR="${HOME}/.config/shell"
mkdir -p "$HOME"

check_rc 'hook_installed rc が無ければ未導入' 1 shellconf::hook_installed bash

printf 'export FOO=1\n' > "${HOME}/.bashrc"
check_rc 'hook_installed 無関係な rc は未導入' 1 shellconf::hook_installed bash

shellconf::hook_block bash >> "${HOME}/.bashrc"
check_rc 'hook_installed 出力どおりなら導入済み' 0 shellconf::hook_installed bash

printf 'source ~/.config/shell/rc.zsh\n' > "${HOME}/.zshrc"
check_rc 'hook_installed 書き方が違っても導入済み' 0 shellconf::hook_installed zsh

HOME="$_home_orig"
SHELLCONF_LOCAL_DIR="$_local_orig"

# --- 結果 ---------------------------------------------------------------------

printf '\n'
if (( _failed )); then
  printf '%d/%d failed\n' "$_failed" "$_tests"
  exit 1
fi
printf 'all %d tests passed\n' "$_tests"
