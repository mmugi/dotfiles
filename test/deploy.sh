#!/bin/sh
#
# install.sh / uninstall.sh のスモークテスト
#
#   sh test/deploy.sh
#   TEST_SH=/bin/dash sh test/deploy.sh
#
# スクリプトを外から叩いて確かめる。HOME と DOTFILES_PATH を一時ディレクトリへ
# 向けるので、本物のホームには触れない。TEST_SH で被験スクリプトを走らせる
# シェルを指定できる (既定: /bin/sh)。
#
# 網羅を狙ったものではなく、仕様の要点と、過去に踏んだ不具合を再発させないことを
# 確認する。

set -u

DOTFILES_ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
INSTALL="${DOTFILES_ROOT}/install.sh"
UNINSTALL="${DOTFILES_ROOT}/uninstall.sh"
LIB="${DOTFILES_ROOT}/lib/shell/deploy.sh"
TEST_SH="${TEST_SH:-/bin/sh}"

# 出力を安定させる。色は [ -t 2 ] でも落ちるが、環境の値を持ち込まない。
NO_COLOR=1
export NO_COLOR
LC_ALL=C
export LC_ALL

_tests=0
_failed=0

check() {
  # usage: check <説明> <期待値> <実際値>
  _tests=$(( _tests + 1 ))
  if [ "$2" = "$3" ]; then
    printf 'ok   %d - %s\n' "$_tests" "$1"
  else
    _failed=$(( _failed + 1 ))
    printf 'FAIL %d - %s\n      expected: [%s]\n      actual:   [%s]\n' \
      "$_tests" "$1" "$2" "$3"
  fi
}

check_match() {
  # usage: check_match <説明> <含まれるべき文字列> <実際の出力>
  case "$3" in
    *"$2"*) check "$1" 'match' 'match' ;;
    *)      check "$1" "…${2}… を含む" "$3" ;;
  esac
}

check_nomatch() {
  # usage: check_nomatch <説明> <含まれてはいけない文字列> <実際の出力>
  case "$3" in
    *"$2"*) check "$1" "…${2}… を含まない" "$3" ;;
    *)      check "$1" 'match' 'match' ;;
  esac
}

TMP=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test-XXXXXX") || exit 1
trap 'rm -rf -- "$TMP"' EXIT
trap 'rm -rf -- "$TMP"; trap - INT;  kill -INT  $$' INT
trap 'rm -rf -- "$TMP"; trap - TERM; kill -TERM $$' TERM

# ---- 足場 ------------------------------------------------------------------

new_case() {
  # usage: new_case <名前>
  # 偽のリポジトリと偽のホームを用意する。以降 $HOMEDIR と $REPO を使う。
  CASE="${TMP}/$1"
  HOMEDIR="${CASE}/home"
  REPO="${CASE}/repo"
  rm -rf "$CASE"
  mkdir -p "$HOMEDIR" "${REPO}/configs" "${REPO}/lib/shell"
  cp "$LIB" "${REPO}/lib/shell/deploy.sh"
}

add_file() {
  # usage: add_file <パッケージ> <HOMEからの相対パス> [モード]
  local dir
  dir=$(dirname "${REPO}/configs/$1/$2")
  mkdir -p "$dir"
  printf '%s\n' "$2" > "${REPO}/configs/$1/$2"
  if [ $# -ge 3 ]; then
    chmod "$3" "${REPO}/configs/$1/$2"
  fi
}

run() {
  # usage: run <スクリプト> [引数...]
  # 出力を OUT に、終了コードを RC に入れる。
  OUT=$(HOME="$HOMEDIR" DOTFILES_PATH="$REPO" "$TEST_SH" "$@" 2>&1) && RC=0 || RC=$?
}

links()   { find "$HOMEDIR" -type l | wc -l | tr -d ' '; }
entries() { find "$HOMEDIR" -mindepth 1 | wc -l | tr -d ' '; }

# ---- install: 新規配置 -----------------------------------------------------

new_case basic
add_file vim .vimrc
add_file git .config/git/config
add_file bin .local/bin/hello 755

run "$INSTALL"
check 'install が成功する' '0' "$RC"
check 'リンクが3本張られる' '3' "$(links)"
check_match 'パッケージ名が見出しに出る' 'installing vim...' "$OUT"
check_match 'リンクの作成が link: で報告される' 'link: ~/.vimrc' "$OUT"
check_match 'ディレクトリの作成が mkdir: で報告される' 'mkdir: ~/.config' "$OUT"
check_match '要約が出る' '3 linked, 4 created, 0 unchanged' "$OUT"

check 'ホーム直下に配置される' 'symlink' \
  "$([ -L "${HOMEDIR}/.vimrc" ] && echo symlink)"
check '入れ子のパスにも配置される' 'symlink' \
  "$([ -L "${HOMEDIR}/.config/git/config" ] && echo symlink)"
check 'リンク先は絶対パス' "${REPO}/configs/vim/.vimrc" \
  "$(readlink "${HOMEDIR}/.vimrc")"
check '中間ディレクトリは実体で 700' "${HOMEDIR}/.config" \
  "$(find "${HOMEDIR}/.config" -maxdepth 0 -type d -perm 700)"
check '実行ビットはリンク越しに効く' 'executable' \
  "$([ -x "${HOMEDIR}/.local/bin/hello" ] && echo executable)"

# 回帰: configs 内のディレクトリへのリンクを d と数えると、中身の無い
#   ディレクトリが配置先に作られていた。
new_case dirlink
add_file real .config/real/file
mkdir -p "${REPO}/configs/link/.config"
ln -s "${REPO}/configs/real/.config/real" "${REPO}/configs/link/.config/alias"
run "$INSTALL"
check 'ディレクトリへのリンクはリンクとして配置される' 'symlink' \
  "$([ -L "${HOMEDIR}/.config/alias" ] && echo symlink)"

# ---- install: 冪等 ---------------------------------------------------------

new_case idempotent
add_file vim .vimrc
add_file git .config/git/config
run "$INSTALL"
check '1回目が成功する' '0' "$RC"
_before=$(entries)

run "$INSTALL"
check '2回目も成功する' '0' "$RC"
check '2回目で増減しない' "$_before" "$(entries)"
check_match '2回目は unchanged として数える' '0 linked, 0 created, 4 unchanged' "$OUT"
check_nomatch '変化が無いパッケージの見出しは出さない' 'installing vim...' "$OUT"

# ---- install: dry-run ------------------------------------------------------

new_case dryrun
add_file vim .vimrc
run "$INSTALL" --dry-run
check 'dry-run が成功する' '0' "$RC"
check 'dry-run は何も作らない' '0' "$(entries)"
check_match 'dry-run の要約は would で始まる' 'would link 1, create 0' "$OUT"
check_match 'dry-run でも行の書式は変えない' 'link: ~/.vimrc' "$OUT"

# ---- install: 衝突 ---------------------------------------------------------

# 回帰: 1件でも衝突があれば何も配置しない。以前は先に進んだ分だけ配置されていた。
new_case conflict_file
add_file vim .vimrc
add_file git .config/git/config
printf 'mine\n' > "${HOMEDIR}/.vimrc"
run "$INSTALL"
check '衝突があれば 1 で終わる' '1' "$RC"
check '衝突時は他の1件も配置しない' '1' "$(entries)"
check_match '管理外のファイルとして報告される' 'file not owned by dotfiles: ~/.vimrc' "$OUT"
check_match '件数と結末が出る' '1 conflict(s) found; nothing was installed' "$OUT"

new_case conflict_broken
add_file vim .vimrc
ln -s /nonexistent "${HOMEDIR}/.vimrc"
run "$INSTALL"
check '壊れたリンクは衝突' '1' "$RC"
check_match '壊れたリンクとして報告される' 'broken symbolic link: ~/.vimrc' "$OUT"

new_case conflict_foreign
add_file vim .vimrc
ln -s /etc/hosts "${HOMEDIR}/.vimrc"
run "$INSTALL"
check '他所を指すリンクは衝突' '1' "$RC"
check_match '所有者が違うと報告される' 'symbolic link not owned by dotfiles: ~/.vimrc' "$OUT"

# 回帰: ファイルの配置先にディレクトリがあると、衝突扱いされず黙って成功していた。
new_case conflict_type
add_file vim .vimrc
mkdir -p "${HOMEDIR}/.vimrc"
run "$INSTALL"
check 'ファイルの位置にディレクトリがあれば衝突' '1' "$RC"
check_match '種別の食い違いとして報告される' \
  'expected a file but found a directory: ~/.vimrc' "$OUT"

new_case conflict_type_dir
add_file git .config/git/config
printf 'x\n' > "${HOMEDIR}/.config"
run "$INSTALL"
check 'ディレクトリの位置にファイルがあれば衝突' '1' "$RC"
check_match '逆向きの食い違いも報告される' \
  'expected a directory but found a file: ~/.config' "$OUT"

# ---- install: 重複 ---------------------------------------------------------

new_case duplicate
add_file alpha .same
add_file beta .same
add_file alpha .uniq
run "$INSTALL"
check '重複があれば 1 で終わる' '1' "$RC"
check '重複時は何も配置しない' '0' "$(entries)"
check_match '重複した配置先が出る' 'provided by more than one package: ~/.same' "$OUT"
check_match '提供元が両方出る (1)' "${REPO}/configs/alpha/.same" "$OUT"
check_match '提供元が両方出る (2)' "${REPO}/configs/beta/.same" "$OUT"
check_match '件数と結末が出る' '1 duplicate destination(s) found' "$OUT"

# 同じ配置先のディレクトリは複数のパッケージが要求してよい。
new_case shared_dir
add_file alpha .config/alpha/conf
add_file beta .config/beta/conf
run "$INSTALL"
check '共有ディレクトリは重複扱いしない' '0' "$RC"
check_match '共有ディレクトリは1回だけ作る' '2 linked, 3 created' "$OUT"

# ---- 除外 ------------------------------------------------------------------

new_case ignore
add_file vim .vimrc
add_file vim .vim/secret
add_file vim .vim/keep
printf '# コメント\n\n.vim/secret\n' > "${REPO}/.dotignore"
run "$INSTALL"
check '除外があっても成功する' '0' "$RC"
check_match '除外が報告される' 'ignored: ~/.vim/secret' "$OUT"
check '除外されたものは配置されない' '' \
  "$([ -e "${HOMEDIR}/.vim/secret" ] && echo exists)"
check '除外されていないものは配置される' 'symlink' \
  "$([ -L "${HOMEDIR}/.vim/keep" ] && echo symlink)"

# 前方一致。正規表現ではないので . はメタ文字にならない。
# ディレクトリ配下だけを外したいときは末尾に / を付ける。
new_case ignore_prefix
add_file vim .vimrc
add_file vim .vim/colors/x
printf '.vim/\n' > "${REPO}/.dotignore"
run "$INSTALL"
check '末尾 / で配下ごと除外される' '' \
  "$([ -e "${HOMEDIR}/.vim/colors/x" ] && echo exists)"
check '中身が全部除外されたディレクトリは作らない' '' \
  "$([ -e "${HOMEDIR}/.vim" ] && echo exists)"
check '末尾 / なら同じ名前で始まる別のパスを巻き込まない' 'symlink' \
  "$([ -L "${HOMEDIR}/.vimrc" ] && echo symlink)"
# ディレクトリは入れ物でしかないので除外の報告に混ぜない。件数が「配置される
# はずだったファイルの数」と合わなくなる。
check_match '除外されたファイルが報告される' 'ignored: ~/.vim/colors/x' "$OUT"
check '除外の報告にディレクトリを混ぜない' '1' \
  "$(printf '%s\n' "$OUT" | grep -c 'ignored: ~')"

# 末尾に / を付けないと、名前がその文字列で始まるものは何でも当たる。
# 前方一致である以上こうなるので、仕様として固定しておく。
new_case ignore_noslash
add_file vim .vimrc
add_file vim .vim/colors/x
printf '.vim\n' > "${REPO}/.dotignore"
run "$INSTALL"
check '末尾 / が無いと .vimrc まで除外される' '' \
  "$([ -e "${HOMEDIR}/.vimrc" ] && echo exists)"
check_match '除外されたことは報告される' 'ignored: ~/.vimrc' "$OUT"

# 回帰: 中身の無いディレクトリを作ると、uninstall でも消えずに残る。
new_case empty_dir
add_file vim .vimrc
mkdir -p "${REPO}/configs/vim/.emptydir"
run "$INSTALL"
check 'configs 側が空のディレクトリなら作らない' '' \
  "$([ -e "${HOMEDIR}/.emptydir" ] && echo exists)"
check '空でないほうは配置される' '1' "$(links)"

new_case junk
add_file vim .vimrc
: > "${REPO}/configs/vim/.DS_Store"
: > "${REPO}/configs/vim/.vimrc.swp"
: > "${REPO}/configs/vim/backup~"
run "$INSTALL"
check '常に除外するものは配置されない' '1' "$(links)"
check_nomatch '常に除外するものは報告もしない' 'ignored:' "$OUT"

# ---- uninstall -------------------------------------------------------------

new_case roundtrip
add_file vim .vimrc
add_file git .config/git/config
add_file nvim .config/nvim/lua/init.lua
run "$INSTALL"
check '往復: install が成功する' '0' "$RC"
run "$UNINSTALL"
check '往復: uninstall が成功する' '0' "$RC"
check '往復でホームが空になる' '0' "$(entries)"
check_match 'リンクの削除が unlink: で報告される' 'unlink: ~/.vimrc' "$OUT"
check_match 'ディレクトリの削除が rmdir: で報告される' 'rmdir: ~/.config' "$OUT"
check_match '要約が出る' '3 link(s) and 4 directory(ies) removed' "$OUT"

run "$UNINSTALL"
check '何も無い状態でも成功する' '0' "$RC"
check_match '何も無ければ要約だけ' '0 link(s) and 0 directory(ies) removed' "$OUT"
check_nomatch '何も無ければ見出しを出さない' 'removing vim...' "$OUT"

# 回帰: 空ディレクトリの削除順がパッケージをまたぐと崩れ、共有ディレクトリが
#   中身より先に処理されて残っていた。
new_case order
add_file alpha .config/alpha/conf
add_file beta .config/beta/conf
add_file zeta .config/zeta/conf
run "$INSTALL"
run "$UNINSTALL"
check '共有ディレクトリも消える' '0' "$(entries)"
check_match '共有ディレクトリは最後に消える' 'rmdir: ~/.config' "$OUT"
_last=$(printf '%s\n' "$OUT" | grep 'rmdir:' | tail -1)
check '削除順は子が先、親が後' '[-] rmdir: ~/.config' "$_last"

new_case keep_foreign
add_file vim .vimrc
add_file vim .vim/conf
run "$INSTALL"
printf 'mine\n' > "${HOMEDIR}/.vim/mynote"
run "$UNINSTALL"
# 自分のリンクは全部外せているので 0。中身の残ったディレクトリは黙って残す。
# 実際の ~/.config には他ツールの設定が入っているのが普通で、報告すると
# 毎回出ることになる。
check '中身が残ったディレクトリがあっても 0 で終わる' '0' "$RC"
check '管理外のファイルは残る' 'exists' \
  "$([ -f "${HOMEDIR}/.vim/mynote" ] && echo exists)"
check '中身のあるディレクトリは残る' 'exists' \
  "$([ -d "${HOMEDIR}/.vim" ] && echo exists)"
check '自分のリンクは外れる' '' \
  "$([ -L "${HOMEDIR}/.vim/conf" ] && echo exists)"
check_nomatch '残ったディレクトリは報告しない' 'left in place' "$OUT"

new_case keep_unowned
add_file vim .vimrc
printf 'mine\n' > "${HOMEDIR}/.vimrc"
run "$UNINSTALL"
check '管理外のファイルは消さない' '2' "$RC"
check_match '理由が出る' 'file not owned by dotfiles: ~/.vimrc' "$OUT"
check_match 'やり残しが報告される' '1 path(s) left in place' "$OUT"
check '中身が保たれる' 'mine' "$(cat "${HOMEDIR}/.vimrc")"

# 回帰: 除外したものが uninstall の空ディレクトリ削除で巻き込まれていた。
new_case uninstall_ignore
add_file vim .vim/keep
add_file vim .vim/secret
printf '.vim/secret\n' > "${REPO}/.dotignore"
run "$INSTALL"
printf 'mine\n' > "${HOMEDIR}/.vim/secret"
run "$UNINSTALL"
check_match 'uninstall でも除外が報告される' 'ignored: ~/.vim/secret' "$OUT"
check '除外したものは削除対象にならない' 'exists' \
  "$([ -f "${HOMEDIR}/.vim/secret" ] && echo exists)"

new_case uninstall_dryrun
add_file vim .vimrc
add_file git .config/git/config
run "$INSTALL"
_before=$(entries)
run "$UNINSTALL" --dry-run
check 'uninstall --dry-run が成功する' '0' "$RC"
check 'dry-run は何も消さない' "$_before" "$(entries)"
check_match 'dry-run の要約は would で始まる' 'would remove 2 link(s)' "$OUT"
check_match 'dry-run でも行の書式は変えない' 'unlink: ~/.vimrc' "$OUT"

# ---- 引数と環境 ------------------------------------------------------------

new_case args
add_file vim .vimrc

run "$INSTALL" --help
check '--help は 0 で終わる' '0' "$RC"
check_match '--help は使い方を出す' 'usage: install.sh' "$OUT"

run "$INSTALL" --bogus
check '知らない引数は 1 で終わる' '1' "$RC"
check_match '知らない引数では使い方を出す' 'usage: install.sh' "$OUT"

run "$UNINSTALL" --help
check 'uninstall --help は 0 で終わる' '0' "$RC"
check_match 'uninstall --help は使い方を出す' 'usage: uninstall.sh' "$OUT"

OUT=$(HOME="$HOMEDIR" DOTFILES_PATH='' "$TEST_SH" "$INSTALL" 2>&1) && RC=0 || RC=$?
check 'DOTFILES_PATH 未設定は 1 で終わる' '1' "$RC"
check_match 'DOTFILES_PATH 未設定の理由が出る' 'DOTFILES_PATH is not set' "$OUT"

new_case nolib
add_file vim .vimrc
rm "${REPO}/lib/shell/deploy.sh"
run "$INSTALL"
check 'ライブラリが無ければ 1 で終わる' '1' "$RC"
check_match 'ライブラリの場所が出る' 'library not found:' "$OUT"

new_case noconfigs
rm -rf "${REPO}/configs"
printf 'junk\n' > "${REPO}/somefile"
run "$INSTALL"
check 'configs が無く空でもなければ 1 で終わる' '1' "$RC"
check_match '取得しない理由が出る' 'is not empty and has no configs directory' "$OUT"

new_case empty
run "$INSTALL"
check 'configs が空でも成功する' '0' "$RC"
check_match '何も無いことが報告される' 'nothing to install' "$OUT"

# ---- 出力 ------------------------------------------------------------------

new_case output
add_file vim .vimrc
run "$INSTALL"
check_nomatch 'パイプ越しにエスケープ列を出さない' "$(printf '\033')" "$OUT"

OUT=$(HOME="$HOMEDIR" DOTFILES_PATH="$REPO" NO_COLOR='' "$TEST_SH" "$INSTALL" 2>&1) \
  && RC=0 || RC=$?
check_nomatch 'tty でなければ色を付けない' "$(printf '\033')" "$OUT"

# 人間向けの出力はすべて stderr へ出す。
_stdout=$(HOME="$HOMEDIR" DOTFILES_PATH="$REPO" "$TEST_SH" "$UNINSTALL" 2>/dev/null)
check '報告は stdout に出さない' '' "$_stdout"

# ---- 一時ファイルの守り ----------------------------------------------------

cat > "${TMP}/guard.sh" <<'GUARD'
. "$1"
DEPLOY_TMPDIR="$2"
deploy_require_tmpfile "$3"
GUARD

guard() {
  # usage: guard <DEPLOY_TMPDIR に入れる値> <出力先に渡す値>
  "$TEST_SH" "${TMP}/guard.sh" "$LIB" "$1" "$2" >/dev/null 2>&1
}

check 'ガード: 一時ディレクトリが未設定なら止まる' '1' \
  "$(guard '' '/manifest'; echo $?)"
check 'ガード: 一時ディレクトリの外は止まる' '1' \
  "$(guard '/tmp/dotfiles-aaa' "${TMP}/outside"; echo $?)"
check 'ガード: .. で外へ出るのは止まる' '1' \
  "$(guard '/tmp/dotfiles-aaa' '/tmp/dotfiles-aaa/../../etc/passwd'; echo $?)"
check 'ガード: 一時ディレクトリ直下は通す' '0' \
  "$(guard '/tmp/dotfiles-aaa' '/tmp/dotfiles-aaa/manifest'; echo $?)"

# 一時ディレクトリの中でも、中身のあるファイルは潰さない。
mkdir -p "${TMP}/dotfiles-guard"
: > "${TMP}/dotfiles-guard/empty"
printf 'precious\n' > "${TMP}/dotfiles-guard/filled"
check 'ガード: 空のファイルは通す' '0' \
  "$(guard "${TMP}/dotfiles-guard" "${TMP}/dotfiles-guard/empty"; echo $?)"
check 'ガード: まだ無いファイルは通す' '0' \
  "$(guard "${TMP}/dotfiles-guard" "${TMP}/dotfiles-guard/notyet"; echo $?)"
check 'ガード: 中身のあるファイルは止まる' '1' \
  "$(guard "${TMP}/dotfiles-guard" "${TMP}/dotfiles-guard/filled"; echo $?)"
check 'ガード: 止めたファイルの中身は残る' 'precious' \
  "$(cat "${TMP}/dotfiles-guard/filled")"

# ---- 後片付け --------------------------------------------------------------

check '一時ディレクトリを残さない' '' \
  "$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'dotfiles-??????' -print 2>/dev/null)"

# ---- 結果 ------------------------------------------------------------------

printf '\n'
if [ "$_failed" -ne 0 ]; then
  printf '%d/%d failed\n' "$_failed" "$_tests"
  exit 1
fi
printf 'all %d tests passed\n' "$_tests"
