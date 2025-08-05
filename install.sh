#!/usr/bin/env bash

set -ueo pipefail

SCRIPTNAME=$(basename "$0")

if [ -z "${BASH_VERSION:-}" ]; then
  printf "\033[1;31m%s\033[0m\n" 'please run this script with bash;('
  exit 1
fi

# color palettes
#DEFAULT=$(printf '\033[39m')
RED=$(printf '\033[38;5;166m')
BLUE=$(printf '\033[38;5;75m')
YELLOW=$(printf '\033[38;5;220m')
CYAN=$(printf '\033[38;5;195m')
PINK=$(printf '\033[38;5;175m')
#PINK=$(printf '\033[38;5;9m')
PURPLE=$(printf '\033[38;5;105m')
LIME=$(printf '\033[38;5;155m')
#DARKGREEN=$(printf '\033[38;5;30m')

FG_BASE="$CYAN"
FG_ACCENT="$PURPLE"
FG_ACCENT2="$LIME"

BOLD=$(printf '\033[1m')
RESET=$(printf '\033[0;39m')

abort() {
  printf "${BOLD}${RED}ABORT${RESET}: %s: line %s: %s: %s\n" \
    "$SCRIPTNAME" \
    "${BASH_LINENO[0]}" \
    "${FUNCNAME[1]:-main}" \
    "$*" >&2
  exit 1
}

exec_user=$(whoami)
[[ $exec_user == root ]] && abort "don't run this script as root"
[[ ! -t 0 ]] && abort 'stdin is not connected to a tty'

LOG_DELAY=0.2

GITHUB_USERNAME='mmugi'
GITHUB_EMAIL='173437276+mmugi@users.noreply.github.com'

DOTFILES_BRANCH="${DOTFILES_BRANCH:-trunk}"
DOTFILES_PATH="${DOTFILES_PATH:-${HOME:?}/.dotfiles}"
DOTFILES_SSH_URL="git@github.com:${GITHUB_USERNAME:?}/dotfiles.git"
DOTFILES_TARBALL_URL="https://github.com/${GITHUB_USERNAME:?}/dotfiles/archive/${DOTFILES_BRANCH:?}.tar.gz"
DOTFILES_CONFIG_DIR="${DOTFILES_PATH:?}/configs"
DOTFILES_GITHOOKS_DIR="${DOTFILES_PATH:?}/misc/git/hooks/dotfiles"


newline() { printf '\n'; }

result.ok() { printf "%s\n" "${BOLD}${BLUE}OK${RESET}"; }
result.failed() { printf "%s\n" "${BOLD}${RED}FAILED${RESET}"; }
result.mismatch() { printf "%s\n" "${BOLD}${RED}MISMATCH${RESET}"; }
result.exist() { printf "%s\n" "${BOLD}${BLUE}EXIST${RESET}"; }
result.notfound() { printf "%s\n" "${BOLD}${RED}NOTFOUND${RESET}"; }

msg() {
  local -r progress_dots_length=3
  local -r progress_interval=0.1
  local -r usage='usage: msg [-n][-p][-P][-r text][-ok|-failed|-exist|-notfound][-2] [--] text...'
  local no_newline_no_delay=false
  local plain_style=false
  local progress_dots
  local prompt_char='>'
  local prompt_color="${FG_ACCENT}"
  local result=''
  local with_progress_dots=false

  while (( $# > 0 )); do
    case $1 in
      --)
        shift
        break
        ;;
      -n)
        no_newline_no_delay=true
        shift
        ;;
      -p)
        with_progress_dots=true
        shift
        ;;
      -P)
        plain_style=true
        shift
        ;;
      -r)
        [[ -z ${2:-} ]] && abort "$usage"
        with_progress_dots=true
        result="$2"
        shift 2
        ;;
      -ok)
        with_progress_dots=true
        result=$(result.ok)
        shift
        ;;
      -failed)
        with_progress_dots=true
        result=$(result.failed)
        shift
        ;;
      -mismatch)
        with_progress_dots=true
        result=$(result.mismatch)
        shift
        ;;
      -exist)
        with_progress_dots=true
        result=$(result.exist)
        shift
        ;;
      -notfound)
        with_progress_dots=true
        result=$(result.notfound)
        shift
        ;;
      -2)
        prompt_char=' >'
        prompt_color="$FG_ACCENT2"
        shift
        ;;
      -*) abort "$usage";;
      *) break;;
    esac
  done

  [[ $# -eq 0 ]] && abort "$usage"

  if "$plain_style"; then
    local -r msg="$*"
    local -r prompt=''
  else
    local -r msg="${FG_BASE}$*${RESET}"
    local -r prompt="${BOLD}${prompt_color}${prompt_char} ${RESET}"
  fi

  printf "%s" "${prompt}${msg}"
  if "$with_progress_dots"; then
    sleep "$progress_interval"
    for i in $(seq "$progress_dots_length"); do
      progress_dots="${FG_BASE}$(printf ".%.0s" $(seq 1 "$i"))${RESET}"
      printf "\r%s" "${prompt}${msg}${progress_dots}"
      sleep "$progress_interval"
    done
    printf "\r%s" "${prompt}${msg}${progress_dots}${result}"
  fi
  if ! "$no_newline_no_delay"; then
    newline
    sleep "$LOG_DELAY"
  fi
}

msg.title() { printf "%s\n\n" "${BOLD}${PINK}* ${FG_BASE}$* ${PINK}*${RESET}"; }
msg.nextstep() { msg.title 'Next Steps!'; }
#msg.attention() {
#  printf "%s! %s\n" "$(sgr bold "$YELLOW")" "$(sgr bold "$FG_BASE")$*$(sgr)"
#  sleep "$LOG_DELAY"
#}
msg.complete() { printf "✨ %s\n\n" "${BOLD}${PINK}$*${RESET}"; }
msg.warn() { printf "%s\n\n" "${BOLD}${YELLOW}⚠ $*${RESET}" >&2; }
#msg.error() {
#  printf "🔥 %s\n\n" "$(sgr bold "$RED")$*$(sgr)" >&2
#}

#log.debug() {
#  printf "%s: %s: %s: %s\n" \
#    "$(sgr bold "$DARKGREEN")DEBUG$(sgr)" "$SCRIPTNAME" "${FUNCNAME[1]}" "$*"
#}
log.info() {
  printf "%s: %s: line %s: %s: %s\n" \
    "${BOLD}${BLUE}INFO${RESET}" \
    "$SCRIPTNAME" \
    "${BASH_LINENO[0]}" \
    "${FUNCNAME[1]}" \
    "$*" >&2
}
log.warn() {
  printf "%s: %s: line %s: %s: %s\n" \
    "${BOLD}${YELLOW}WARN${RESET}" \
    "$SCRIPTNAME" \
    "${BASH_LINENO[0]}" \
    "${FUNCNAME[1]}" \
    "$*" >&2
}
log.error() {
  printf "%s: %s: line %s: %s: %s\n" \
    "${BOLD}${RED}ERROR${RESET}" \
    "${SCRIPTNAME}" \
    "${BASH_LINENO[0]}" \
    "${FUNCNAME[1]:-main}" \
    "$*" >&2
}
log.link() { printf "%s: %s\n" "${BOLD}${BLUE}LINK${RESET}" "$*"; }
log.mkdir() { printf "%s: %s\n" "${BOLD}${BLUE}MKDIR${RESET}" "$*"; }
log.ignore() { printf "%s: %s\n" "${BOLD}${LIME}IGNORE${RESET}" "$*"; }

draw.line() {
  local -r length=67
  local -r symbol='.'
  local line
  for i in $(seq "$length"); do
    line=$(printf "${symbol}%.0s" $(seq 1 "$i"))
    printf "\r%s" "${FG_ACCENT}${line}${RESET}"
    sleep 0.002
  done
  newline
}
draw.logo() {
  local -r logo='
    _____  _______ _______ _______ _______ _____   _______ _______
   |     \|       |_     _|    ___|_     _|     |_|    ___|     __|
 __|  --  |   -   | |   | |    ___|_|   |_|       |    ___|__     |
|__|_____/|_______| |___| |___|   |_______|_______|_______|_______|'
  printf "%s\n\n" "${BOLD}${FG_BASE}${logo}${RESET}"
  sleep "$LOG_DELAY"
}

nextstep.support_downloader() {
  newline
  draw.line
  newline
  msg.nextstep
  cat <<EOF
Specify the different environment variable 'DOTFILES_DOWNLOADER'.

  Specifiable commands:
    - git
    - curl
    - wget
EOF
  exit 1
}
nextstep.git_ssh_unavailable() {
  newline
  draw.line
  newline
  msg.nextstep
  cat <<EOF
Please create an SSH key pair, register the public key with GitHub.

  ssh-keygen -t ed25519

And then re-run this script.
Or specify the different environment variable 'DOTFILES_DOWNLOADER'.

  Specifiable commands:
    - curl
    - wget
EOF
  exit 1
}
nextstep.symlink_conflict() {
  draw.line
  newline
  msg.nextstep
  echo "Please either move the target config file or configure '${DOTFILES_PATH}/.dotignore', then re-run the install."
  exit 1
}

chk() {
  local opt_exists=false
  local opt_selector=
  local opt_quiet=false
  local permission
  local positional_args=()
  local target
  local msg
  local msg_target
  local -r msg_usage='usage: [-c|-d|-f [-e]|-l|-p] [-q] target'

  while (( $# > 0 )); do
    case $1 in
      --)
        shift
        positional_args+=("$@")
        set --
        ;;
      -*)
        options="$1"
        for (( i=1; i<${#options}; i++ )); do
          case ${options:$i:1} in
            c)
              [[ -n $opt_selector ]] && abort "$msg_usage"
              opt_selector=c
              ;;
            d)
              [[ -n $opt_selector ]] && abort "$msg_usage"
              opt_selector=d
              ;;
            e)
              opt_exists=true
              ;;
            f)
              [[ -n $opt_selector ]] && abort "$msg_usage"
              opt_selector=f
              ;;
            l)
              [[ -n $opt_selector ]] && abort "$msg_usage"
              opt_selector=l
              ;;
            p)
              [[ -n $opt_selector ]] && abort "msg_usage"
              opt_selector=p
              permission="$2"
              shift
              ;;
            q)
              opt_quiet=true
              ;;
            *)
              abort "invalid option: $options"
              ;;
          esac
        done
        shift
        ;;
      *)
        positional_args+=("$1")
        shift
        ;;
    esac
  done

  [[ ${#positional_args[@]} -eq 0 ]] && abort "$msg_usage"
  [[ -z $opt_selector ]] && abort "$msg_usage"

  set -- "${positional_args[@]}"
  target="$1"
  msg_target="${BOLD}${FG_ACCENT2}$1${RESET}"

  if [[ $opt_selector = c ]]; then
    msg="checking command ${BOLD}${FG_ACCENT2}${target}${RESET}"
    if type "$target" >/dev/null 2>&1; then
      "$opt_quiet" || msg -2 -exist "$msg"
      return 0
    else
      "$opt_quiet" || msg -2 -notfound "$msg"
      return 1
    fi
  elif [[ $opt_selector = d ]]; then
    msg="checking directory ${BOLD}${FG_ACCENT2}${target}${RESET}"
    if [[ -d $target ]]; then
      "$opt_quiet" || msg -2 -exist "$msg"
      return 0
    else
      "$opt_quiet" || msg -2 -notfound "$msg"
      return 1
    fi
  elif [[ $opt_selector = f ]]; then
    msg="checking file ${BOLD}${FG_ACCENT}${target}${RESET}"
    if "$opt_exists"; then
      if [[ -f $target ]]; then
        "$opt_quiet" || msg -2 -exist "$msg"
        return 0
      else
        "$opt_quiet" || msg -2 -notfound "$msg"
        return 1
      fi
    else
      if [[ -e $target ]]; then
        "$opt_quiet" || msg -2 -exist "$msg"
        return 0
      else
        "$opt_quiet" || msg -2 -notdounf "$msg"
        return 1
      fi
    fi
  elif [[ $opt_selector = l ]]; then
    msg="checking symlink ${BOLD}${FG_ACCENT}${target}${RESET}"
    if [[ -L $target ]]; then
      "$opt_quiet" || msg -2 -exist "$msg"
      return 0
    else
      "$opt_quiet" || msg -2 -notfound "$msg"
      return 1
    fi
  elif [[ $opt_selector = p ]]; then
    msg="checking permission $msg_target ${FG_BASE}(expected: $permission)"
    if [[ -n $(find "$target" -maxdepth 0 -perm "$permission") ]]; then
      "$opt_quiet" || msg -2 -ok "$msg"
      return 0
    else
      "$opt_quiet" || msg -2 -mismatch "$msg"
      return 1
    fi
  fi
}

deploy() {
  # usage: deploy [--dry-run] src dst
  #
  # srcに指定されたファイルもしくはディレクトリをdstに指定されたパスに配置します。
  #
  # srcが通常のファイルの場合、dstに指定された先にシンボリックリンクします。
  # srcがディレクトリかつdstに指定された先に存在しない場合は作成し、存在する場合は正常終了します。
  # dst先にファイルやリンクがすでに存在する場合は、1を返します。
  #
  # --dry-runオプションが指定された場合はシンボリックリンクやディレクトリの作成は行われず
  # srcがdstに配置できない場合に1を返します。

  local cmd_result
  local dry_run=false
  local symlink
  local usage='usage: deploy [--dry-run] src dst'

  if [[ $# -eq 3 ]]; then
    if [[ $1 = --dry-run ]]; then
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

  if [[ ! -e $src ]]; then
    log.error "source not found: $src"
    return 1
  fi

  if [[ ! -e $dst && ! -L $dst ]]; then
    if "$dry_run"; then
      : dry run
    else
      if [[ -d $src ]]; then
        if cmd_result=$(mkdir -m 700 "$dst" 2>&1); then
          log.mkdir "$dst"
          return
        else
          log.error "$cmd_result"
          return 1
        fi
      else
        if cmd_result=$(ln -s "$src" "$dst" 2>&1); then
          log.link "$src ==> $dst"
        else
          log.error "$cmd_result"
          return 1
        fi
      fi
    fi
  else
    if ! symlink=$(readlink "$dst"); then
      # not symlink
      if [[ -d $dst ]]; then
        : directory exists
      else
        log.warn "target already exists: $dst"
        return 1
      fi
    elif [[ $src != "$symlink" ]]; then
      log.warn "existing target is not owned by dotfiles: $dst"
      return 1
    elif [[ $src = "$symlink" ]]; then
      : symlink are managed by dotfiles
    else
      log.error "readlink error: $cmd_result"
      abort 'Deploy failed;('
    fi
  fi
  return 0
}

greet() {
  local -r greeting_messages=(
    'hello:)'
    'this is the dotfiles installation script.'
    "date: ${FG_ACCENT}$(date '+%Y/%m/%d %H:%M:%S %Z')${RESET}"
    "branch: ${FG_ACCENT}${DOTFILES_BRANCH}${RESET}"
    "path: ${FG_ACCENT}${DOTFILES_PATH}${RESET}"
  )
  draw.line
  draw.logo
  for msg in "${greeting_messages[@]}"; do
    msg "$msg"
  done
  newline
  draw.line
  newline
}

set_platform() {
  local os
  msg -n -p 'detecting platform'
  os=$(uname -o)
  case $os in
    Darwin)    PLATFORM='mac';;
    GNU/Linux) PLATFORM='linux';;
    *) newline; abort "unknown os: $os";;
  esac
  msg -P "${BOLD}${FG_ACCENT}${PLATFORM}${RESET}"
}

set_downloader() {
  msg -n -p 'detecting downloader'
  if chk -cq curl; then
    DOWNLOADER='curl'
  elif chk -cq wget; then
    DOWNLOADER='wget'
  else
    abort 'downloader not found: curl or wget'
  fi
  msg -P "${BOLD}${FG_ACCENT}${DOWNLOADER}${RESET}"
}

download_dotfiles() {
  local -r ssh_dir="${HOME:?}/.ssh"
  local -r msg_download_complete='dotfiles download completed:)'

  if [[ -e $DOTFILES_PATH ]]; then
    msg 'dotfiles already exists.'
    msg.complete "$msg_download_complete"
    return
  fi

  msg -n -p 'detecting dotfiles downloader'

  if [[ -z ${DOTFILES_DOWNLOADER:-} ]]; then
    if chk -cq 'git'; then
      DOTFILES_DOWNLOADER='git'
    else
      DOTFILES_DOWNLOADER="$DOWNLOADER"
    fi
    msg -P "${BOLD}${FG_ACCENT}${DOTFILES_DOWNLOADER}${RESET}"
  else
    newline
    msg -2 "DOTFILES_DOWNLOADER is set: ${BOLD}${FG_ACCENT2}${DOTFILES_DOWNLOADER}${RESET}"
    if ! chk -c "$DOTFILES_DOWNLOADER"; then
      abort "downloader not found: $DOTFILES_DOWNLOADER"
    fi
  fi

  if [[ ! $DOTFILES_DOWNLOADER =~ ^(git|curl|wget)$ ]]; then
    log.error "not supported downloader: $DOTFILES_DOWNLOADER"
    nextstep.support_downloader
  fi

  if [[ $DOTFILES_DOWNLOADER = git ]]; then
    local git_ssh_test_result
    local git_version
    local git_test_user

    msg -p 'checking ssh connection'

    git_version=$(git --version 2>&1)
    msg -2 "$git_version"

    msg -2 -n -p 'checking git config user.name'

    if git_test_user=$(git config user.name); then
      result.exist
    else
      result.notfound
      read -rp "please enter the github username for testing [${GITHUB_USERNAME}]: " git_test_user
      [[ -z $git_test_user ]] && git_test_user="$GITHUB_USERNAME"
    fi

    msg -2 "github username for testing: ${BOLD}${FG_ACCENT2}${git_test_user}${RESET}"
    msg -2 -n -p 'testing ssh connection to git@github.com'

    git_ssh_test_result=$(ssh -o StrictHostKeyChecking=no -T git@github.com 2>&1) || true

    if ! echo "$git_ssh_test_result" | grep -q "$git_test_user"; then
      result.failed
      log.error "$git_ssh_test_result"

      local -r msg_ssh_dir="${BOLD}${FG_ACCENT2}${ssh_dir}${RESET}"

      # gitコマンドは存在するが、ssh接続に問題があった場合
      msg -p 'checking ssh configs'
      if chk -d "$ssh_dir"; then
        if ! chk -p 700 "$ssh_dir"; then
          chmod 700 "$ssh_dir"
          msg -2 "changed ${msg_ssh_dir} ${FG_BASE}permission to 700"
        fi
      else
        mkdir -m 700 "$ssh_dir"
        msg -2 "created directory ${msg_ssh_dir}"
      fi
      nextstep.git_ssh_unavailable
    fi
    result.ok
  fi

  msg -p "downloading dotfiles with ${DOTFILES_DOWNLOADER}"
  msg -2 "path: ${BOLD}${FG_ACCENT2}${DOTFILES_PATH}"

  if [[ $DOTFILES_DOWNLOADER = git ]]; then
    git clone --recursive -b "$DOTFILES_BRANCH" "$DOTFILES_SSH_URL" "$DOTFILES_PATH"
  elif [[ $DOTFILES_DOWNLOADER =~ curl|wget ]]; then
    chk -cq 'tar' || abort 'tar command is required'
    mkdir "$DOTFILES_PATH"
    case "$DOTFILES_DOWNLOADER" in
      curl) curl -fsSL "$DOTFILES_TARBALL_URL" ;;
      wget) wget -qO - "$DOTFILES_TARBALL_URL" ;;
    esac | tar xvz -C "$DOTFILES_PATH" --strip-components=1
  else
    abort "invalid downloader: $DOTFILES_DOWNLOADER"
  fi

  msg.complete 'dotfiles download completed:)'
}

configure_dotfiles() {
  [[ -d ${DOTFILES_PATH}/.git ]] || return

  local cmd_result
  local src_hooks
  local src
  local dst
  local hook_filename
  local deploy_hook_failed=false
  local git_config_failed=false
  local -r gitconfig_local="${DOTFILES_PATH}/.git/config"

  msg -p 'installing git-hooks to dotfiles'

  src_hooks=$(find "${DOTFILES_GITHOOKS_DIR:?}" -mindepth 1 -type f)
  while read -r src; do
    hook_filename=$(basename "$src")
    dst="${DOTFILES_PATH:?}/.git/hooks/${hook_filename}"
    deploy "$src" "$dst" || deploy_hook_failed=true
  done < <(echo "$src_hooks")
  "$deploy_hook_failed" && abort 'hooks deployment failed;('

  msg -p 'configuring local git configs'

  if cmd_result=$(git config --file "$gitconfig_local" user.name); then
    if [[ $cmd_result = "${GITHUB_USERNAME:?}" ]]; then
      msg -2 "user.name: ${BOLD}${FG_ACCENT2}$cmd_result"
    else
      git_config_failed=true
      log.warn "user.name already configured: $cmd_result"
    fi
  else
    git config --file "$gitconfig_local" user.name "${GITHUB_USERNAME:?}"
  fi

  if cmd_result=$(git config --file "$gitconfig_local" user.email); then
    if [[ $cmd_result = "${GITHUB_EMAIL:?}" ]]; then
      msg -2 "user.email: ${BOLD}${FG_ACCENT2}$cmd_result"
    else
      git_config_failed=true
      log.warn "user.email already configured: $cmd_result"
    fi
  else
    git config --file "$gitconfig_local" user.email "${GITHUB_EMAIL:?}"
  fi

  if "$git_config_failed"; then
    msg.warn 'please verify that the configuration has been completed successfully:<'
  else
    msg.complete 'git settings configured for dotfiles:)'
  fi
}

deploy_configs() {
  # DOTFILES_CONFIG_DIR に指定されたディレクトリ内のパッケージごとのディレクトリを参照し、
  # コンフィグファイルのシンボリックリンクを作成します。
  #
  # パッケージごとのディレクトリに配置するコンフィグファイルは、
  # ホームディレクトリからの相対パスと同じディレクトリ構成となるように配置します。
  #
  # ディレクトリ構成例:
  #   configs
  #   ├── vim
  #   |   └── .vimrc
  #   └── starship
  #   |   ├── .config
  #   |   └── starship.toml
  #   ...
  #
  # 途中のディレクトリが存在しない場合、ディレクトリをパーミッション700で作成します。
  #
  # 配置先となるパスにファイルもしくは dotfiles 管理でないリンクが既に存在する場合、
  # 全コンフィグのデプロイは中断されます。
  # 続行するには、既存のファイルを退避/削除後する、もしくは、
  # ~/.dotignore に無視したいコンフィグを指定し再実行します。
  #
  # .dotignore ファイルに記載されたパスが、コンフィグのホームディレクトリからの
  # 相対パスと前方一致する場合は、該当パスのコンフィグ配置処理をスキップします。
  # また、空行および#から始まる行は無視されます。

  local cmd_result
  local config_relpath_fromhome
  local conflict=false
  local pkg
  local pkg_dir
  local pkg_dirs
  local src
  local src_configs
  local dst

  local -r usage='usage: check_ignore config_relpath_from_home'

  deploy_configs_failed() { abort 'Config deployment failed;('; }

  check_ignore() {
    # usage: check_ignore config_relpath_from_home
    #
    # dotfilesディレクトリに配置された .dotignore ファイルを参照し、
    # 引数として入力されたコンフィグが無視されるかどうか判定します。
    # コンフィグは、ホームディレクトリからの相対パスで指定します。
    # .dotignore に記載のパスと前方一致する場合、trueを返します。

    local ignorefile="${DOTFILES_PATH}/.dotignore"
    local config_relpath_from_home

    if [[ $# -ne 1 ]]; then
      abort 'usage: check_ignore config_relpath_from_home'
    fi

    config_relpath_from_home="$1"

    [[ -s $ignorefile ]] || return

    while read -r pattern; do
      [[ -z $pattern || $pattern =~ ^# ]] && continue
      [[ $config_relpath_from_home =~ ^${pattern} ]] && return
    done < "$ignorefile"
    return 1
  }

  [[ -z ${DOTFILES_CONFIG_DIR:-} ]] && abort 'DOTFILES_CONFIG_DIR is not set'

  msg -p 'checking configuration files to be deployed'

  if ! pkg_dirs=$(find "${DOTFILES_CONFIG_DIR:?}" -mindepth 1 -maxdepth 1 -type d 2>&1); then
    abort "$pkg_dirs"
  elif [[ -z $pkg_dirs ]]; then
    msg.warn "package directories not found:/"
    return
  fi

  while read -r pkg_dir; do
    [[ -d $pkg_dir ]] || abort "package directry not found: $pkg_dir"

    if ! src_configs=$(find "$pkg_dir" -mindepth 1 2>&1); then
      abort "$src_configs"
    elif [[ -z $src_configs ]]; then
      log.warn "package directory is empty: $pkg_dir"
      continue
    fi

    while read -r src; do
      config_relpath_fromhome="${src#"${pkg_dir}/"}"
      dst="${HOME:?}/${config_relpath_fromhome:?}"
      if check_ignore "$config_relpath_fromhome"; then
        continue
      else
        deploy --dry-run "$src" "$dst" || conflict=true
      fi
    done < <(echo "$src_configs")
  done < <(echo "$pkg_dirs")

  if "$conflict"; then
    msg.warn 'conflicting files detected:/'
    nextstep.symlink_conflict
  fi

  msg -p 'deploy configuration files'

  while read -r pkg_dir; do
    if [[ -d $pkg_dir ]]; then
      pkg=$(basename "$pkg_dir")
      msg -2 "configs: ${BOLD}${FG_ACCENT2}${pkg}${RESET}"
    else
      abort "package directry not found: $pkg_dir"
    fi

    if ! src_configs=$(find "$pkg_dir" -mindepth 1 2>&1); then
      abort "$src_configs"
    elif [[ -z $src_configs ]]; then
      continue
    fi

    while read -r src; do
      config_relpath_fromhome="${src#"${pkg_dir}/"}"
      dst="${HOME:?}/${config_relpath_fromhome:?}"
      if [[ $src =~ \.swp$ ]]; then
        continue
      elif check_ignore "$config_relpath_fromhome"; then
        log.ignore "${HOME:?}/${config_relpath_fromhome:?}"
        continue
      else
        deploy "$src" "$dst"
      fi
    done < <(echo "$src_configs")
  done < <(echo "$pkg_dirs")
  msg.complete 'deployed configuration files:)'
}

install_complete() {
  printf "🌟 %s\n" "${BOLD}${PINK}DOTFILES INSTALLATION COMPLETE!${RESET}"
  draw.line
}

greet
set_platform
set_downloader
download_dotfiles
configure_dotfiles
deploy_configs
install_complete
