#!/usr/bin/env bash

set -ueo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_PATH:?}/lib/bash/import.sh"
import util msg theme shellconf

if [[ -t 2 ]]; then
  # termcap.sh が参照する
  # shellcheck disable=SC2034
  TERMCAP_COLOR_MODE=always
fi

theme::load
msg::init

# シェル設定を shell/{env.d,rc.d} のレジストリから生成する。
#
# 既定では全シェル分を run/ 配下に書き出す。make install はこれを呼んだうえで
# ~/.config/shell などへシンボリックリンクを張る。
#
# --print は生成物を標準出力にのみ出す。検索過程などのメッセージは標準エラー
# 出力に流すため、そのままパイプやリダイレクトで持ち出せる。設定を配置できない
# 環境や、手元とは別のシェル向けの設定が欲しいときに使う。

usage() {
  cat <<EOF
usage: $(basename "$0") [--shell <name>] [--print [rc|env] | --hook]

  (no options)      全シェル分の設定を生成する (--shell は効かない)
  --shell <name>    対象シェルを指定する (default: bash)
                     対応シェル: ${SHELLCONF_SUPPORTED_SHELLS[*]}
  --print [phase]   生成せず標準出力に出力する (phase: rc | env, default: rc)
                     fish は env と rc を分けないため phase は無視される
  --hook            rc に貼る1行フックの文面を出力する
  -h, --help        このヘルプを表示する

--print と --hook は排他。両方を指定した場合はエラーで停止する。
EOF
}

shell='bash'
mode=''
phase='rc'

# 明示的に指定されたかどうか。
# そのモードで効かない指定を黙って捨てないよう、既定値との区別に使う。
shell_given=0
phase_given=0

select_mode() {
  # usage: select_mode <mode>
  #
  # モードは3つのうち1つだけを選ぶ。後に書いたほうが黙って勝つと、頼んだのとは
  # 違う出力を返したまま成功してしまうため、食い違いはエラーで止める。

  if [[ -n "$mode" && "$mode" != "$1" ]]; then
    msg::error "conflicting options: --${mode} and --${1}"
    usage
    exit 1
  fi

  mode="$1"
}

while (( $# > 0 )); do
  case "$1" in
    --shell | --shell=*)
      shell_given=1
      if [[ "$1" =~ ^--shell= ]]; then
        shell="${1#--shell=}"
      elif [[ -z "${2:-}" ]]; then
        msg::error 'missing shell name'
        exit 1
      else
        shell="$2"
        shift
      fi
      ;;
    --print | --print=*)
      select_mode 'print'
      if [[ "$1" =~ ^--print= ]]; then
        phase="${1#--print=}"
        phase_given=1
      elif [[ "${2:-}" =~ ^(rc|env)$ ]]; then
        phase="$2"
        phase_given=1
        shift
      fi
      ;;
    --hook)
      select_mode 'hook'
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      msg::error "invalid option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

# モードを指定するオプションが無ければ生成モード
: "${mode:=generate}"

supported=0
for s in "${SHELLCONF_SUPPORTED_SHELLS[@]}"; do
  [[ "$s" == "$shell" ]] && { supported=1; break; }
done
if (( ! supported )); then
  msg::error "unsupported shell: ${shell} (supported: ${SHELLCONF_SUPPORTED_SHELLS[*]})"
  exit 1
fi

if [[ ! "$phase" =~ ^(rc|env)$ ]]; then
  msg::error "invalid phase: ${phase} (rc | env)"
  exit 1
fi

case "$mode" in
  generate)
    # このモードは全シェル分を書き出すため --shell を見ない。
    # 指定が効いていないことに気づけるよう、黙って捨てずに知らせる。
    if (( shell_given )); then
      # 本文が - で始まるため、msg のオプション解釈を -- で打ち切る。
      msg::warning -- '--shell is ignored here. every supported shell is generated.'
    fi

    msg 'generating shell configuration...'
    shellconf::generate_all
    msg::ok 'shell configuration generated:)'
    ;;

  print)
    # 標準出力には生成物だけを流す。メッセージはすべて標準エラー出力へ。
    {
      if [[ "$shell" == 'fish' ]]; then
        # fish の conf.d は env と rc を分けないため1ファイルにまとめている。
        if (( phase_given )); then
          msg::warning 'phase is ignored for fish. printing the whole configuration.'
        fi
        msg 'generating configuration for <hl>fish</hl>...'
      else
        msg "generating <hl>${phase}</hl> configuration for <hl>${shell}</hl>..."
      fi
    } >&2

    if [[ "$shell" == 'fish' ]]; then
      config="$(shellconf::generate_fish)"
    elif [[ "$phase" == 'env' ]]; then
      config="$(shellconf::generate_env "$shell")"
    else
      config="$(shellconf::generate_rc "$shell")"
    fi

    {
      if [[ -t 1 ]]; then
        if [[ "$shell" == 'fish' ]]; then
          msg::notice 'save the following as <hl>~/.config/fish/conf.d/00-dotfiles.fish</hl>.'
        else
          msg::notice "save the following as <hl>~/.config/shell/${phase}.${shell}</hl>."
        fi
      else
        msg::notice 'stdout is redirected. writing the generated configuration directly to it.'
      fi
    } >&2

    printf '%s\n' "$config"
    ;;

  hook)
    if [[ "$shell" == 'fish' ]]; then
      # このモードの標準出力は rc に貼る行だけを流す。貼るものが無い場合も
      # 同じで、知らせは標準エラー出力へ回す。
      { msg::notice 'fish loads <hl>conf.d</hl> automatically. no hook is required.'; } >&2
      exit 0
    fi

    rcfile="$(shellconf::hook_rcfile "$shell")"

    { msg::notice "add the following line to <hl>${rcfile/#"${HOME}"/\~}</hl>."; } >&2
    shellconf::hook_block "$shell"
    ;;
esac
