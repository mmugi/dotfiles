#!/bin/sh

set -u

DOTFILES_URL='git@github.com:mmugi/dotfiles.git'
DOTFILES_REPO_HTTPS='https://github.com/mmugi/dotfiles'

C_WARN=''
C_ERR=''
C_DIM=''
C_RST=''
if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  C_WARN=$(printf '\033[33m')
  C_ERR=$(printf '\033[31m')
  C_DIM=$(printf '\033[2m')
  C_RST=$(printf '\033[0m')
fi

progress() { printf '%s[>]%s %s\n' "$C_DIM"  "$C_RST" "$*" >&2; }
warn()     { printf '%s[!]%s %s\n' "$C_WARN" "$C_RST" "$*" >&2; }
die()      { printf '%s[x]%s %s\n' "$C_ERR"  "$C_RST" "$*" >&2; exit 1; }

# zsh は関数の中で設定した trap を関数ローカルに扱うため、一時ディレクトリの
# 後始末が早すぎるタイミングで走ってしまう。
if [ -n "${ZSH_VERSION:-}" ]; then
  die "run this with sh, not zsh: sh $0"
fi

usage() {
  cat >&2 <<'USAGE'
usage: install.sh [-n|--dry-run] [-v|--verbose] [-h|--help]

  -n, --dry-run   配置せず、何が起きるかだけを表示する
  -v, --verbose   触らなかったものも表示する
  -h, --help      この使い方を表示する

environment:

  DOTFILES_PATH        dotfiles の置き場所 (必須)
  DOTFILES_BRANCH      取得するブランチ (既定: trunk)
  DOTFILES_IGNOREFILE  除外リスト (既定: ${DOTFILES_PATH}/.dotignore)
  NO_COLOR             設定されていれば色を付けない
USAGE
}

git_usable() {
  # macOS の /usr/bin/git は Command Line Tools のシムで、CLT が未導入でも存在する。
  # 実行するとインストールを促すダイアログが出て失敗するため、実行せずに確かめる。
  # homebrew などで入れた git は実体なのでそのまま使える。

  local git
  git=$(command -v git 2>/dev/null) || return 1
  case "$git" in
    /usr/bin/git) xcode-select -p >/dev/null 2>&1 ;;
    *) return 0 ;;
  esac
}

pick_downloader() {
  # usage: pick_downloader
  # 使えるダウンローダ名を標準出力へ出す。見つからなければ 1 を返す。

  if git_usable; then
    printf 'git\n'
    return 0
  fi

  if command -v git >/dev/null 2>&1; then
    # git はあるが使えない。黙って切り替えると、なぜ .git が無いのか分からなくなる。
    warn 'git is unavailable (Command Line Tools are not installed).'
    warn 'falling back to an archive download; git pull will not work.'
    warn 'install the Command Line Tools and run this again to get a clone.'
  fi

  for cmd in curl wget; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf '%s\n' "$cmd"
      return 0
    fi
  done

  warn 'no downloader found; install git, curl or wget'
  return 1
}

ensure_repo() {
  # ローカルにまだ dotfiles が無ければ取得する。

  local branch tarball downloader

  # 取得済みかどうかは configs の有無で判断する。ディレクトリがあるだけでは
  # dotfiles が置かれているとは言えない (先に作っておいた場合や、取得が途中で
  # 失敗した場合がある)。
  if [ -d "${DOTFILES_PATH}/configs" ]; then
    return 0
  fi

  # configs がないのに別のもので埋まっている場合は展開しない。
  if [ -n "$(ls -A "$DOTFILES_PATH" 2>/dev/null)" ]; then
    die "${DOTFILES_PATH} is not empty and has no configs directory"
  fi

  branch="${DOTFILES_BRANCH:-trunk}"
  tarball="${DOTFILES_REPO_HTTPS}/archive/${branch}.tar.gz"

  downloader=$(pick_downloader) || die 'cannot download the repository'

  progress "downloading dotfiles into ${DOTFILES_PATH}..."

  if [ "$downloader" = git ]; then
    git clone --recursive -b "$branch" "$DOTFILES_URL" "$DOTFILES_PATH" \
      || die 'failed to clone the repository'
    return 0
  fi

  if ! command -v tar >/dev/null 2>&1; then
    die 'command not found: tar'
  fi
  if ! mkdir -p "$DOTFILES_PATH"; then
    die "failed to create ${DOTFILES_PATH}"
  fi

  case "$downloader" in
    curl) curl -fsSL "$tarball" ;;
    wget) wget -qO - "$tarball" ;;
  esac | tar xz -C "$DOTFILES_PATH" --strip-components=1

  # パイプラインの終了状態は当てにならない。curl は -f のおかげで 404 を
  # エラーにするが何も出力しないまま終わり、tar は空入力を成功として扱うため、
  # 取得に失敗してもパイプライン全体は 0 を返す (実測)。結果を直接確かめる。
  if [ ! -d "${DOTFILES_PATH}/configs" ]; then
    die "failed to download the repository from ${tarball}"
  fi
}

verify_no_duplicates() {
  # usage: verify_no_duplicates <manifest>
  # 複数のパッケージが同じ配置先を持っていないことを確かめる。見つかれば提供元と
  # 件数を報告し、1 を返す。
  # ディレクトリは複数のパッケージが同じものを必要とするのが正常なので対象にしない。

  local dups dup count type src dst
  dups=$(awk -F'\t' '$2 == "f" { print $5 }' "$1" | sort | uniq -d)

  if [ -z "$dups" ]; then
    return 0
  fi

  count=0
  while IFS= read -r dup; do
    deploy_warn "provided by more than one package: $(deploy_tilde "$dup")"
    while IFS="$DEPLOY_TAB" read -r _ type _ src dst; do
      if [ "$type" = f ] && [ "$dst" = "$dup" ]; then
        deploy_detail "$src"
      fi
    done < "$1"
    count=$(( count + 1 ))
  done <<EOF
$dups
EOF

  deploy_error "${count} duplicate destination(s) found; nothing was installed"
  return 1
}

verify_no_conflicts() {
  # usage: verify_no_conflicts <manifest>
  # 配置を妨げるものが無いことを確かめる。見つかれば理由と件数を報告し、1 を返す。

  local count type src dst state
  count=0

  while IFS="$DEPLOY_TAB" read -r _ type _ src dst; do
    deploy_classify "$type" "$src" "$dst"
    state=$?
    case "$state" in
      0 | 1 | 2) ;;
      *)
        deploy_warn "$(deploy_describe_state "$state" "$dst")"
        count=$(( count + 1 ))
        ;;
    esac
  done < "$1"

  if [ "$count" -eq 0 ]; then
    return 0
  fi

  deploy_error "${count} conflict(s) found; nothing was installed"
  deploy_detail 'move the existing files aside, or list them in .dotignore'
  return 1
}

apply_manifest() {
  # usage: apply_manifest <manifest> <dry-run> <verbose>
  #
  # 配置の直前にもう一度分類する。検査から適用までの間に状態が変わっていても、
  # 既存のものを上書きする経路が生まれない。
  #
  # 置けなかったものがあれば件数を出して 1 を返す。mkdir や ln の失敗に加えて、
  # 検査を通ったのに適用時には衝突していたものを数える。件数を終了コードに
  # 載せないのは、256 件で 0 に化けてやり残しが消えるため。

  local manifest dry verbose created linked unchanged failed pkg type src dst state
  manifest="$1"
  dry="$2"
  verbose="$3"
  created=0
  linked=0
  unchanged=0
  failed=0

  while IFS="$DEPLOY_TAB" read -r pkg type _ src dst; do
    deploy_classify "$type" "$src" "$dst"
    state=$?

    case "$state" in
      0)
        deploy_announce installing "$pkg"
        case "$type" in
          d)
            if [ "$dry" -eq 0 ]; then
              if ! mkdir -m 700 "$dst"; then
                deploy_warn "failed to mkdir $(deploy_tilde "$dst")"
                failed=$(( failed + 1 ))
                continue
              fi
            fi
            deploy_created "mkdir: $(deploy_tilde "$dst")"
            created=$(( created + 1 ))
            ;;
          f)
            if [ "$dry" -eq 0 ]; then
              if ! ln -s "$src" "$dst"; then
                deploy_warn "failed to link $(deploy_tilde "$dst")"
                failed=$(( failed + 1 ))
                continue
              fi
            fi
            deploy_created "link: $(deploy_tilde "$dst")"
            linked=$(( linked + 1 ))
            ;;
          *)
            deploy_die "internal error: unknown type in the manifest: ${type}"
            ;;
        esac
        ;;
      1 | 2)
        if [ "$verbose" -eq 1 ]; then
          deploy_announce installing "$pkg"
          if [ "$state" -eq 1 ]; then
            deploy_skipped "already linked: $(deploy_tilde "$dst")"
          else
            deploy_skipped "directory exists: $(deploy_tilde "$dst")"
          fi
        fi
        unchanged=$(( unchanged + 1 ))
        ;;
      *)
        deploy_announce installing "$pkg"
        deploy_warn "$(deploy_describe_state "$state" "$dst")"
        failed=$(( failed + 1 ))
        ;;
    esac
  done < "$manifest"

  if [ "$dry" -eq 0 ]; then
    deploy_progress "${linked} linked, ${created} created, ${unchanged} unchanged"
  else
    deploy_progress "would link ${linked}, create ${created}, leave ${unchanged} unchanged"
  fi

  if [ "$failed" -eq 0 ]; then
    return 0
  fi

  deploy_error "${failed} path(s) could not be placed"
  return 1
}

main() {
  local dry verbose lib manifest
  dry=0
  verbose=0

  while [ $# -gt 0 ]; do
    case "$1" in
      -n | --dry-run) dry=1 ;;
      -v | --verbose) verbose=1 ;;
      -h | --help) usage; return 0 ;;
      *) usage; return 1 ;;
    esac
    shift
  done

  if [ -z "${DOTFILES_PATH:-}" ]; then
    die 'DOTFILES_PATH is not set'
  fi

  ensure_repo

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
  deploy_build_manifest > "$manifest"

  if [ "$verbose" -eq 1 ]; then
    deploy_report_ignored
  fi

  if [ ! -s "$manifest" ]; then
    deploy_warn 'nothing to install'
    return 0
  fi

  verify_no_duplicates "$manifest" || return 1
  verify_no_conflicts  "$manifest" || return 1

  apply_manifest "$manifest" "$dry" "$verbose" || return 2

  return 0
}

# 処理はすべて関数に入れ、最終行で main を呼ぶ。curl | sh で通信が途中で切れても、
# 受け取ったところまでのファイルは main の定義行に到達しないため何も実行しない。
main "$@"
