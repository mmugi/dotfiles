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

#util::chk() {
#  local opt_exists=false
#  local opt_selector=
#  local opt_quiet=false
#  local permission
#  local positional_args=()
#  local target
#  local msg
#  local msg_target
#  local -r msg_usage='usage: [-c|-d|-f [-e]|-l|-p permission] [-q] target'
#
#  # options
#  #   -c: command
#  #   -d: directory
#  #   -f: file
#  #   -l: symlink
#  #   -p: permission
#  #   -q: 結果を出力しない
#
#  while (( $# > 0 )); do
#    case $1 in
#      --)
#        shift
#        positional_args+=("$@")
#        set --
#        ;;
#      -*)
#        options="$1"
#        for (( i=1; i<${#options}; i++ )); do
#          case "${options:$i:1}" in
#            c)
#              [[ -n "$opt_selector" ]] && abort "$msg_usage"
#              opt_selector=c
#              ;;
#            d)
#              [[ -n "$opt_selector" ]] && abort "$msg_usage"
#              opt_selector=d
#              ;;
#            e)
#              opt_exists=true
#              ;;
#            f)
#              [[ -n "$opt_selector" ]] && abort "$msg_usage"
#              opt_selector=f
#              ;;
#            l)
#              [[ -n "$opt_selector" ]] && abort "$msg_usage"
#              opt_selector=l
#              ;;
#            p)
#              [[ -n "$opt_selector" ]] && abort "$msg_usage"
#              opt_selector=p
#              permission="$2"
#              shift
#              ;;
#            q)
#              opt_quiet=true
#              ;;
#            *)
#              abort "invalid option: ${options}"
#              ;;
#          esac
#        done
#        shift
#        ;;
#      *)
#        positional_args+=("$1")
#        shift
#        ;;
#    esac
#  done
#
#  [[ ${#positional_args[@]} -eq 0 ]] && abort "$msg_usage"
#  [[ -z "$opt_selector" ]] && abort "$msg_usage"
#
#  set -- "${positional_args[@]}"
#  target="$1"
#  msg_target="${BOLD}${FG_ACCENT2}$1${RESET}"
#
#  if [[ "$opt_selector" == 'c' ]]; then
#    msg="checking command ${BOLD}${FG_ACCENT2}${target}${RESET}"
#    if type "$target" >/dev/null 2>&1; then
#      [[ "$opt_quiet" == 'true' ]] || msg -2 -exist "$msg"
#      return 0
#    else
#      [[ "$opt_quiet" == 'true' ]] || msg -2 -notfound "$msg"
#      return 1
#    fi
#  elif [[ "$opt_selector" == 'd' ]]; then
#    msg="checking directory ${BOLD}${FG_ACCENT2}${target}${RESET}"
#    if [[ -d $target ]]; then
#      [[ "$opt_quiet" == 'true' ]] || msg -2 -exist "$msg"
#      return 0
#    else
#      [[ "$opt_quiet" == 'true' ]] || msg -2 -notfound "$msg"
#      return 1
#    fi
#  elif [[ "$opt_selector" == 'f' ]]; then
#    msg="checking file ${BOLD}${FG_ACCENT}${target}${RESET}"
#    if "$opt_exists"; then
#      if [[ -f "$target" ]]; then
#        [[ "$opt_quiet" == 'true' ]] || msg -2 -exist "$msg"
#        return 0
#      else
#        [[ "$opt_quiet" == 'true' ]] || msg -2 -notfound "$msg"
#        return 1
#      fi
#    else
#      if [[ -e "$target" ]]; then
#        [[ "$opt_quiet" == 'true' ]] || msg -2 -exist "$msg"
#        return 0
#      else
#        [[ "$opt_quiet" == 'true' ]] || msg -2 -notdounf "$msg"
#        return 1
#      fi
#    fi
#  elif [[ "$opt_selector" == 'l' ]]; then
#    msg="checking symlink ${BOLD}${FG_ACCENT}${target}${RESET}"
#    if [[ -L "$target" ]]; then
#      [[ "$opt_quiet" == 'true' ]] || msg -2 -exist "$msg"
#      return 0
#    else
#      [[ "$opt_quiet" == 'true' ]] || msg -2 -notfound "$msg"
#      return 1
#    fi
#  elif [[ "$opt_selector" == 'p' ]]; then
#    msg="checking permission ${msg_target} ${FG_BASE}(expected: ${permission})"
#    if [[ -n "$(find "$target" -maxdepth 0 -perm "$permission")" ]]; then
#      [[ "$opt_quiet" == 'true' ]] || msg -2 -ok "$msg"
#      return 0
#    else
#      [[ "$opt_quiet" == 'true' ]] || msg -2 -mismatch "$msg"
#      return 1
#    fi
#  fi
#}

util::install() {
  # usage: util::install [--dry-run] src dst
  #
  # srcに指定されたファイルをdstに指定されたパスに配置します。
  #
  # srcが通常のファイルの場合、dstに指定された先にシンボリックリンクします。
  # srcがディレクトリの場合、dstに指定されたパスのディレクトリを作成します。
  #
  # dst先にファイルやシンボリックリンクがすでに存在する場合は、1を返します。
  #
  # --dry-runオプションが指定された場合は、シンボリックリンクやディレクトリの
  # 作成は行われず、srcがdstに配置できるかどうかの0、1だけを返します。

  local dry_run=0
  local usage='usage: util::install [--dry-run] src dst'

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

  if [[ ! -e "$src" ]]; then
    logger --error "source not found: ${src}"
    return 1
  fi

  # dst配置可能(ファイル、リンクが存在しない)
  if [[ ! -e "$dst" && ! -L "$dst" ]]; then
    (( dry_run )) && return 0

    if [[ -d "$src" ]]; then
      mkdir -m 700 "$dst" || return 1
      msg::changed "directory created: $dst"
    else
      ln -s "$src" "$dst" || return 1
      msg::changed "symbolic link created: ${src} -> ${dst}"
    fi

    return 0
  fi

  # dstがすでに存在する
  local link link_path src_path
  if link="$(readlink "$dst")"; then
    link_path="$(realpath "$link")"
    src_path="$(realpath "$src")"
    if [[ "$src_path" != "$link_path" ]]; then
      msg::warning "existing distination target is not owned by dotfiles: ${dst}"
      return 1
    fi
  else
    if [[ ! -d "$dst" ]]; then
      msg::warning "already file exists: ${dst}"
      return 1
    fi
  fi

  # dstディレクトリもしくはsrcにリンクされたdstファイルがすでに存在する
  return 0
}
