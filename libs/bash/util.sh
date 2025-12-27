# shellcheck shell=bash
# shellcheck disable=SC2034
{
  LIB_VERSION='1.0.0'
  LIB_DEPS=( esc msg log )
  [[ "${1:-}" = '__META_PROBE__' ]] && return 0
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
  # srcに指定されたファイルもしくはディレクトリを
  # dstに指定されたパスに配置します。
  #
  # srcが通常のファイルの場合、dstに指定された先にシンボリックリンクします。
  # srcがディレクトリかつdstに指定された先に存在しない場合は作成し、
  # 存在する場合は正常終了します。
  #
  # dst先にファイルやリンクがすでに存在する場合は、1を返します。
  #
  # --dry-runオプションが指定された場合は、シンボリックリンクやディレクトリの
  # 作成は行われず、srcがdstに配置できるかどうかの0、1だけを返します。

  local cmd_result symlink
  local dry_run=false
  local usage='usage: util::install [--dry-run] src dst'

  if [[ $# -eq 3 ]]; then
    if [[ "$1" == '--dry-run' ]]; then
      shift
      dry_run=true
    else
      log.error "$usage"
      return 1
    fi
  elif [[ $# -ne 2 ]]; then
    log.error "$usage"
    return 1
  fi

  local src="$1"
  local dst="$2"

  if [[ ! -e "$src" ]]; then
    log.error "source not found: ${src}"
    return 1
  fi

  if [[ ! -e "$dst" && ! -L "$dst" ]]; then
    if "$dry_run"; then
      : dry-run
    else
      if [[ -d "$src" ]]; then
        if cmd_result="$(mkdir -m 700 "$dst" 2>&1)"; then
          msg::notice --mkdir "$dst"
          return
        else
          log.error "$cmd_result"
          return 1
        fi
      else
        if cmd_result="$(ln -s "$src" "$dst" 2>&1)"; then
          msg::notice --link "${src} ==> ${dst}"
        else
          log.error "$cmd_result"
          return 1
        fi
      fi
    fi
  else
    if ! symlink="$(readlink "$dst")"; then
      # not symlink
      if [[ -d "$dst" ]]; then
        : directory exists
      else
        log.warn "target already exists: ${dst}"
        return 1
      fi
    elif [[ "$src" != "$symlink" ]]; then
      log.warn "existing target is not owned by dotfiles: ${dst}"
      return 1
    elif [[ "$src" == "$symlink" ]]; then
      : symlink are managed by dotfiles
    else
      log.error "readlink error: ${cmd_result}"
      abort 'deploy failed;('
    fi
  fi
  return 0
}
