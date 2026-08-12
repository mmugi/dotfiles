# shellcheck shell=bash

LIB_VERSION='1.0.0'
LIB_DEPS=( log msg )
[[ "${1:-}" = '__IMPORT__' ]] && return 0

# msg::chk 結果キャッシュ
#   値: 0 = 存在する / 1 = 存在しない
declare -gA _UTIL_CHK_CMD_CACHE=()

util::sysinfo() {
  local selector property
  local silent=false
  local force=false
  local usage='usage: util::sysinfo <--os | --arch> [-q] [-f]'

  while (( $# > 0 )); do
    case "$1" in
      # selectors
      --os)   selector=os ;;
      --arch) selector=arch ;;
      # options
      -q) silent=true ;;
      -f) force=true ;;
      *)
        log::error "invalid option: $1"
        return 1
        ;;
    esac
    shift
  done

  [[ -z "${selector:-}" ]] && abort "$usage"

  case "$selector" in
    os)
      [[ "$force" == 'false' && -n "${DOTFILES_SYS_OS:-}" ]] && return 0
      [[ "$silent" == 'false' ]] && msg -n -p 'detecting operating system'
      property="$(uname -o)"
      case "$property" in
        Darwin)    DOTFILES_SYS_OS='macos' ;;
        GNU/Linux) DOTFILES_SYS_OS='linux' ;;
        *)         DOTFILES_SYS_OS='unknown' ;;
      esac
      if [[ "$silent" == 'false' ]]; then
        if [[ "$DOTFILES_SYS_OS" != 'unknown' ]]; then
          msg -r --ok="$DOTFILES_SYS_OS" 'detecting operating system'
        else
          msg -r --ng="$DOTFILES_SYS_OS" 'detecting operating system'
        fi
      fi
      export DOTFILES_SYS_OS
      ;;

    arch)
      [[ "$force" == 'false' && -n "${DOTFILES_SYS_ARCH:-}" ]] && return 0
      [[ "$silent" == 'false' ]] && msg -n -p 'detecting architecture'
      property="$(uname -m)"
      DOTFILES_SYS_ARCH="$property"
      [[ "$silent" == 'false' ]] \
        && msg -r --result="$DOTFILES_SYS_ARCH" 'detecting architecture'
      export DOTFILES_SYS_ARCH
      ;;

    *)
      log::error "invalid selector: $selector"
      return 1
      ;;
  esac
}

util::chk() {
  # options
  #   -c: command
  #   -o: キャッシュを上書きする
  #   -q: 結果を出力しない

  local override=0
  local quiet=0
  local selector target

  usage() { logger --error 'usage: <-c> [-oq] target'; }

  if (( $# == 0 )); then
    usage
    return 1
  fi

  while (( $# > 0 )); do
    case "$1" in
      --) shift; break ;;
      -*)
        for (( i=1; i<${#1}; i++ )); do
          case "${1:$i:1}" in
            c) selector='command' ;;
            o) override=1 ;;
            q) quiet=1 ;;
            *)
              logger --error "invalid option: $1"
              return 1
              ;;
          esac
        done
        shift
        ;;
      *) break ;;
    esac
  done

  if [[ -z "${selector:-}" ]]; then
    usage
    return 1
  fi

  target="$*"

  case "$selector" in
    command)
      if (( ! override )) && [[ -n "${_UTIL_CHK_CMD_CACHE["$target"]:-}" ]]; then
        return "${_UTIL_CHK_CMD_CACHE["$target"]}"
      fi

      if (( ! quiet )); then
        msg "checking <hl>${target}</hl> command..."
      fi

      if type "$target" >/dev/null 2>&1; then
        _UTIL_CHK_CMD_CACHE["$target"]=0
        return 0
      else
        _UTIL_CHK_CMD_CACHE["$target"]=1
        if (( ! quiet )); then
          msg::error "command not found: ${target}"
        fi
        return 1
      fi
      ;;
    *)
      logger --error "invalid selector: ${selector}"
      return 1
      ;;
  esac
}

util::install() {
  # usage: util::install [--check] src dst
  #
  # srcに指定されたファイルをdstに指定されたパスに配置します。
  #
  # srcが通常のファイルの場合、dstに指定された先にシンボリックリンクします。
  # srcがディレクトリの場合、dstに指定されたパスのディレクトリを作成します。
  #
  # dst先にファイルやシンボリックリンクがすでに存在する場合は、1を返します。
  #
  # --checkオプションが指定された場合は、シンボリックリンクやディレクトリの
  # 作成は行われず、srcがdstに配置できるかどうかの0、1だけを返します。
  # 成功時(配置可能な場合)にメッセージは表示されません。プレビュー表示では
  # なく、事前の衝突検証を目的としたオプションです。

  local check=0
  local usage='usage: util::install [--check] src dst'

  if (( $# == 3 )); then
    if [[ "$1" == '--check' ]]; then
      shift
      check=1
    else
      logger --error "$usage"
      return 1
    fi
  elif (( $# != 2 )); then
    logger --error "$usage"
    return 1
  fi

  local src="$1"
  local dst="$2"

  if [[ ! -e "$src" ]]; then
    logger --error "source not found: ${src}"
    return 1
  fi

  # dst配置可能(ファイル、リンクが存在しない)
  if [[ ! -e "$dst" && ! -L "$dst" ]]; then
    (( check )) && return 0

    if [[ -d "$src" ]]; then
      mkdir -m 700 "$dst" || return 1
      msg::changed "directory created: $dst"
    else
      ln -s "$src" "$dst" || return 1
      msg::changed "symbolic link created: ${dst} -> ${src}"
    fi

    return 0
  fi

  # dstがすでに存在する
  local link_target link_path src_path
  if [[ -L "$dst" ]]; then
    # リンク先が相対パスの場合、readlink の出力をそのまま realpath に渡すと
    # カレントディレクトリ基準で解決されてしまうため、dst 自体を解決する。
    if ! link_path="$(realpath "$dst" 2>/dev/null)"; then
      link_target="$(readlink "$dst")"
      msg::warning "broken symbolic link already exists: ${dst} -> ${link_target}"
      return 1
    fi
    src_path="$(realpath "$src")"
    if [[ "$src_path" != "$link_path" ]]; then
      msg::warning "symbolic link already exists, not owned by dotfiles: ${dst} -> ${link_path}"
      return 1
    fi
  else
    if [[ ! -d "$dst" ]]; then
      msg::warning "file already exists: ${dst}"
      return 1
    fi
  fi

  # dstディレクトリもしくはsrcにリンクされたdstファイルがすでに存在する
  return 0
}

util::uninstall() {
  # usage: util::uninstall [--dry-run] src dst
  #
  # dstに指定されたシンボリックリンクを解除します。
  #
  # dstがsrcを指すシンボリックリンクである場合のみ解除の対象とします。
  # dstが存在しない場合は何もせず0を返します。
  #
  # dstがシンボリックリンクでない場合、もしくはsrcを指していない場合は
  # 1を返します。
  #
  # --dry-runオプションが指定された場合、シンボリックリンクの解除は
  # 行われませんが、解除される旨のメッセージは表示されます。
  # util::install --check とは異なり、衝突有無の事前検証ではなく
  # 削除対象のプレビュー表示を目的としているため、この挙動です。

  local dry_run=0
  local usage='usage: util::uninstall [--dry-run] src dst'

  if (( $# == 3 )); then
    if [[ "$1" == '--dry-run' ]]; then
      shift
      dry_run=1
    else
      logger --error "$usage"
      return 1
    fi
  elif (( $# != 2 )); then
    logger --error "$usage"
    return 1
  fi

  local src="$1"
  local dst="$2"

  # dstが存在しない
  if [[ ! -e "$dst" && ! -L "$dst" ]]; then
    logger --debug "target does not exist: ${dst}"
    return 0
  fi

  if [[ ! -L "$dst" ]]; then
    if [[ -d "$dst" ]]; then
      msg::warning "directory is not a symbolic link: ${dst}"
    else
      msg::warning "file is not a symbolic link: ${dst}"
    fi
    return 1
  fi

  # リンク先が相対パスの場合でも正しく解決するため、readlink の出力ではなく
  # dst 自体を realpath に渡す。リンク切れの場合は解決に失敗する。
  local link_target link_path src_path
  if ! link_path="$(realpath "$dst" 2>/dev/null)"; then
    link_target="$(readlink "$dst")"
    msg::warning "broken symbolic link: ${dst} -> ${link_target}"
    return 1
  fi
  src_path="$(realpath "$src")"

  if [[ "$link_path" != "$src_path" ]]; then
    msg::warning "symbolic link is not owned by dotfiles: ${dst} -> ${link_path}"
    return 1
  fi

  if (( ! dry_run )); then
    unlink -- "$dst" || return 1
  fi
  msg::rm "symbolic link unlinked: ${dst} -> ${link_path}"

  return 0
}
