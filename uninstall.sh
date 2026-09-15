#!/bin/sh

set -u

C_ERR=''
C_RST=''
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  C_ERR=$(printf '\033[31m')
  C_RST=$(printf '\033[0m')
fi

die() { printf '%s[x]%s %s\n' "$C_ERR" "$C_RST" "$*" >&2; exit 1; }

# zsh は関数の中で設定した trap を関数ローカルに扱うため、一時ディレクトリの
# 後始末が早すぎるタイミングで走ってしまう。
if [ -n "${ZSH_VERSION:-}" ]; then
  die "run this with sh, not zsh: sh $0"
fi

usage() {
  cat >&2 <<'USAGE'
usage: uninstall.sh [-n|--dry-run] [-h|--help]

  -n, --dry-run   削除せず、何が起きるかだけを表示する
  -h, --help      この使い方を表示する

environment:
  DOTFILES_PATH        dotfiles の置き場所 (必須)
  DOTFILES_IGNOREFILE  除外リスト (既定: ${DOTFILES_PATH}/.dotignore)
  NO_COLOR             設定されていれば色を付けない
USAGE
}

remove_paths() {
  # usage: remove_paths <manifest> <dry-run>
  #
  # 自分が張ったリンクを外し、空になったディレクトリを片付ける。それ以外は
  # 理由を出して残す。残したものがあれば件数を出して 1 を返す。
  #
  # manifest は配置先の降順で渡ってくる前提。あるパスの配下にあるものが必ず先に
  # 来るので、空になったディレクトリをその場で片付けられる。

  local manifest dry links dirs left pkg type src dst state
  manifest="$1"
  dry="$2"
  links=0
  dirs=0
  left=0

  while IFS="$DEPLOY_TAB" read -r pkg type _ src dst; do
    deploy_classify "$type" "$src" "$dst"
    state=$?

    case "$type" in
      d)
        case "$state" in
          0) continue ;;
          2) ;;
          *)
            deploy_announce removing "$pkg"
            deploy_warn "$(deploy_describe_state "$state" "$dst")"
            left=$(( left + 1 ))
            continue
            ;;
        esac

        if [ -n "$(ls -A "$dst" 2>/dev/null)" ]; then
          continue
        fi

        deploy_announce removing "$pkg"
        if [ "$dry" -eq 0 ]; then
          if ! rmdir -- "$dst" 2>/dev/null; then
            deploy_warn "failed to rmdir $(deploy_tilde "$dst")"
            left=$(( left + 1 ))
            continue
          fi
        fi
        deploy_removed "rmdir: $(deploy_tilde "$dst")"
        dirs=$(( dirs + 1 ))
        ;;
      f)
        case "$state" in
          0) ;;
          1)
            deploy_announce removing "$pkg"
            if [ "$dry" -eq 0 ]; then
              # 配置先は $HOME から組み立てるので、先頭が - になることはない。
              if ! unlink "$dst"; then
                deploy_warn "failed to unlink $(deploy_tilde "$dst")"
                left=$(( left + 1 ))
                continue
              fi
            fi
            deploy_removed "unlink: $(deploy_tilde "$dst")"
            links=$(( links + 1 ))
            ;;
          *)
            deploy_announce removing "$pkg"
            deploy_warn "$(deploy_describe_state "$state" "$dst")"
            left=$(( left + 1 ))
            ;;
        esac
        ;;
      *)
        deploy_die "internal error: unknown type in the manifest: ${type}"
        ;;
    esac
  done < "$manifest"

  if [ "$dry" -eq 0 ]; then
    deploy_progress "${links} link(s) and ${dirs} directory(ies) removed"
  else
    deploy_progress "would remove ${links} link(s) and ${dirs} directory(ies)"
  fi

  if [ "$left" -eq 0 ]; then
    return 0
  fi

  deploy_warn "${left} path(s) left in place"
  deploy_detail 'they are not owned by dotfiles; remove them by hand if you want'
  return 1
}

main() {
  local dry lib manifest
  dry=0

  while [ $# -gt 0 ]; do
    case "$1" in
      -n | --dry-run) dry=1 ;;
      -h | --help) usage; return 0 ;;
      *) usage; return 1 ;;
    esac
    shift
  done

  if [ -z "${DOTFILES_PATH:-}" ]; then
    die 'DOTFILES_PATH is not set'
  fi

  # 非対話シェルでの . は失敗した時点でシェルごと終了する。
  # そのため . "$lib" || die ができないため、読めるかどうかを先に確かめる。
  lib="${DOTFILES_PATH}/lib/shell/deploy.sh"
  if [ ! -r "$lib" ]; then
    die "library not found: ${lib}"
  fi

  # source は使えない (dash に無い)。
  # shellcheck source=lib/shell/deploy.sh
  . "$lib"

  deploy_init

  manifest="${DEPLOY_TMPDIR}/manifest"

  # 書き出す前に、一時ディレクトリが用意できていることを確かめる。set -u が無い
  # 環境で source された場合、未設定の DEPLOY_TMPDIR は空に展開され、書き出し先が
  # /manifest になる。
  deploy_require_tmpfile "$manifest"
  deploy_build_manifest | sort -r -t"$DEPLOY_TAB" -k5 > "$manifest"

  if [ ! -s "$manifest" ]; then
    deploy_warn 'nothing to uninstall'
    return 0
  fi

  remove_paths "$manifest" "$dry" || return 2

  return 0
}

main "$@"
