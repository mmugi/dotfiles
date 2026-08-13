#!/usr/bin/env bash
#
# scripts/ 配下のコマンドとしての振る舞いのテスト
#
#   bash test/cli.sh
#
# 関数単位の確認は test/lib.sh が見る。こちらは実際にコマンドとして起動し、
# 引数の解釈、終了コード、標準出力と標準エラー出力の分け方を確認する。

set -ueo pipefail

# shellcheck source=/dev/null
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/helper.sh"

_tmp="$(mktemp -d)"
trap 'rm -rf -- "$_tmp"' EXIT

# --- scripts/shell/shellconf.sh -----------------------------------------------

declare -r SHELLCONF="${DOTFILES_PATH}/scripts/shell/shellconf.sh"

shellconf_out() { bash "$SHELLCONF" "$@" 2>/dev/null; }

# 標準エラー出力だけを取り出す。順序に意味があり、先に 2>&1 で呼び出し元の
# 標準出力へ複製してから、標準出力を捨てる。
# shellcheck disable=SC2069
shellconf_err() { bash "$SHELLCONF" "$@" 2>&1 >/dev/null; }

# 引数の解釈
check_rc '--help は成功する' 0 bash "$SHELLCONF" --help
check_rc '未対応のシェルは失敗する' 1 bash "$SHELLCONF" --shell nushell --hook
check_rc '不正なオプションは失敗する' 1 bash "$SHELLCONF" --nosuchoption
check_rc 'シェル名が無ければ失敗する' 1 bash "$SHELLCONF" --shell
check_rc '不正な phase は失敗する' 1 bash "$SHELLCONF" --print=nope

# モードは排他。後に書いたほうが黙って勝つと、頼んだのとは違う出力を返したまま
# 成功してしまう。
check_rc '--print と --hook は競合する' 1 bash "$SHELLCONF" --print --hook
check_rc '--hook と --print も競合する' 1 bash "$SHELLCONF" --hook --print
check_rc '同じモードの重複は通る' 0 bash "$SHELLCONF" --hook --hook

# --hook
#   標準出力には rc に貼る行だけを流す。貼るものが無い場合も同じ。
check '--hook の出力は1行' '1' "$(shellconf_out --hook | wc -l | tr -d ' ')"
check '--hook は rc.bash を読む行を出す' '1' \
  "$(shellconf_out --hook | grep -c '\.config/shell/rc\.bash')"
check '--shell zsh --hook は rc.zsh を読む行を出す' '1' \
  "$(shellconf_out --shell zsh --hook | grep -c '\.config/shell/rc\.zsh')"
check_rc 'fish のフックは成功として終わる' 0 bash "$SHELLCONF" --shell fish --hook
check 'fish はフック不要で標準出力には何も出さない' '' \
  "$(shellconf_out --shell fish --hook)"
check 'fish のフック不要は標準エラー出力で知らせる' '1' \
  "$(shellconf_err --shell fish --hook | grep -c 'no hook is required' || true)"

# --print
#   標準出力に生成物だけを流すこと。この分離が崩れると、リダイレクトして
#   設定ファイルにする使い方が壊れる。
#
#   起動のたびに補助スクリプトの探索が走るため、1回の実行を両方の出力に
#   使い回す。
bash "$SHELLCONF" --print > "${_tmp}/rc.out" 2> "${_tmp}/rc.err"

check '--print の標準出力にメッセージが混ざらない' '0' \
  "$(grep -cE '^\[.\] ' "${_tmp}/rc.out" || true)"
check '--print の標準出力は生成物' '1' \
  "$(grep -c 'interactive shell configuration for bash' "${_tmp}/rc.out")"
check '--print のメッセージは標準エラー出力に出る' '1' \
  "$(( $(grep -cE '^\[.\] ' "${_tmp}/rc.err" || true) > 0 ? 1 : 0 ))"

# 生成物がそのシェルの構文として通ること
check_rc '--print の出力は bash の構文として通る' 0 bash -n "${_tmp}/rc.out"

shellconf_out --print env > "${_tmp}/env.out"
check_rc '--print env の出力は bash の構文として通る' 0 bash -n "${_tmp}/env.out"

# そのモードで効かない指定は、黙って捨てずに知らせる
check 'fish で phase を指定すると警告する' '1' \
  "$(shellconf_err --shell fish --print env | grep -c 'phase is ignored' || true)"
check 'fish で phase 未指定なら警告しない' '0' \
  "$(shellconf_err --shell fish --print | grep -c 'phase is ignored' || true)"

# 生成モードは全シェル分を書き出すため --shell を見ない。
# この確認は実際に生成するので run/ 配下を書き換えるが、生成は冪等で、
# run/ は git 管理外のため副作用にはならない。
check '生成モードでの --shell 指定を警告する' '1' \
  "$(shellconf_out --shell fish | grep -c 'shell is ignored' || true)"
check '素の生成モードでは警告しない' '0' \
  "$(shellconf_out | grep -c 'shell is ignored' || true)"

# --- 結果 ---------------------------------------------------------------------

test::summary
