#!/usr/bin/env bash

set -ueo pipefail

abort() {
    printf "\033[1;31m⛔ %s\033[0m\n" "$@" >&2
    exit 1
}

trap 'abort "Error occurred. Terminating."' ERR

if [ -z "${BASH_VERSION:-}" ]; then
    abort "Bash is required to interpret this script."
fi

executing_user=$(whoami)
[[ $executing_user == root ]] && abort "Don't run this as root."
[[ ! -t 0 ]] && abort "'stdin' is not a TTY."

import_libs() {
    local -r lib_url='https://raw.githubusercontent.com/mmugi/libs/HEAD/bash/escseq.bash'
    import_failed() {
        printf "%s: %s: import failed: %s\n" "$(basename "$0")" "${FUNCNAME[1]}" "$*" >&2
        exit 1
    }
    if type curl >/dev/null 2>&1; then
        lib="$(curl -fsSL "$lib_url")" || import_failed "curl: $lib_url"
    elif type wget >/dev/null 2>&1; then
        lib="$(wget -qO - "$lib_url")" || import_failed "wget: $lib_url"
    else
        import_failed 'downloader not found'
    fi
    eval "$lib"
} && import_libs


SCRIPTNAME=$(basename "$0")
SSH_DIR="${HOME:?}/.ssh"
GITHUB_USERNAME='mmugi'
GITHUB_EMAIL='173437276+mmugi@users.noreply.github.com'
LOG_DELAY=0.4

DOTFILES_BRANCH="${DOTFILES_BRANCH:-trunk}"
DOTFILES_PATH="${HOME:?}/.dotfiles"
DOTFILES_SSH_URL="git@github.com:${GITHUB_USERNAME:?}/dotfiles.git"
DOTFILES_TARBALL_URL="https://github.com/${GITHUB_USERNAME:?}/dotfiles/archive/${DOTFILES_BRANCH:?}.tar.gz"
DOTFILES_CONFIG_DIR="${DOTFILES_PATH:?}/configs"
DOTFILES_GITHOOKS_DIR="${DOTFILES_PATH:?}/misc/git/hooks/dotfiles"
DOTFILES_BREWFILE="${DOTFILES_PATH:?}/misc/brew/Brewfile"

PLATFORM=
RELOAD_SHELL=false
CONFIGURATION_FAILED=false

# 256 color palette
RED=166
BLUE=75
YELLOW=220
CYAN=195
PINK=175
PURPLE=105
LIME=118
DARKGREEN=30
FG_BASE="$CYAN"
FG_ACCENT="$PURPLE"


###  functions  ###

newline() { echo; }

result.ok() {
    printf "%s\n" "$(sgr bold "$BLUE")OK$(sgr)"
}
result.failed() {
    printf "%s\n" "$(sgr bold "$RED")FAILED$(sgr)"
}
result.exist() {
    printf "%s\n" "$(sgr bold "$BLUE")EXIST$(sgr)"
}
result.notfound() {
    printf "%s\n" "$(sgr bold "$RED")NOTFOUND$(sgr)"
}

msg() {
    local -r length=3
    local -r symbol='.'
    local progress_dots
    local with_progress_dots=false

    case "$1" in
        --) shift ;;
        -p)
            shift
            with_progress_dots=true
            ;;
    esac

    local -r msg="$*"

    if "$with_progress_dots"; then
        for i in $(seq "$length"); do
            progress_dots=$(printf "${symbol}%.0s" $(seq 1 "$i"))
            printf "\r%s> %s" "$(sgr bold "$FG_ACCENT")" "$(sgr "$FG_BASE")${msg}${progress_dots}$(sgr)"
            sleep 0.2
        done
    else
        printf "%s> %s" "$(sgr bold "$FG_ACCENT")" "$(sgr "$FG_BASE")$*$(sgr)"
    fi
    newline
    sleep "$LOG_DELAY"
}
msg.attention() {
    printf "%s! %s\n" "$(sgr bold "$YELLOW")" "$(sgr bold "$FG_BASE")$*$(sgr)"
    sleep "$LOG_DELAY"
}
msg.complete() {
    printf "✨ %s\n\n" "$(sgr bold "$PINK")$*$(sgr)"
}
msg.warn() {
    printf "%s⚠ %s%s\n\n" "$(sgr bold "$YELLOW")" "$*" "$(sgr)" >&2
}
msg.error() {
    printf "🔥 %s\n\n" "$(sgr bold "$RED")$*$(sgr)" >&2
}
msg.nextstep() {
    printf "%s>>> %s\n" "$(sgr bold "$FG_ACCENT")" "$(sgr "$FG_BASE")Next Steps...$(sgr)"
}

log.debug() {
    printf "%s: %s: %s: %s\n" "$(sgr bold "$DARKGREEN")DEBUG$(sgr)" "$SCRIPTNAME" "${FUNCNAME[1]}" "$*"
}
log.warn() {
    printf "%s: %s: %s: %s\n" "$(sgr bold "$YELLOW")WARN$(sgr)" "$SCRIPTNAME" "${FUNCNAME[1]}" "$*" >&2
}
log.error() {
    printf "%s: %s: %s: %s\n" "$(sgr bold "$RED")ERROR$(sgr)" "$SCRIPTNAME" "${FUNCNAME[1]}" "$*" >&2
}
log.link() {
    printf "%s: %s\n" "$(sgr bold "$BLUE")LINK$(sgr)" "$*"
}
log.mkdir() {
    printf "%s: %s\n" "$(sgr bold "$BLUE")MKDIR$(sgr)" "$*"
}
log.ignore() {
    printf "%s: %s\n" "$(sgr bold "$LIME")IGNORE$(sgr)" "$*"
}

draw.line() {
    local -r length=67
    local -r symbol='.'
    local line
    for i in $(seq "$length"); do
        line=$(printf "${symbol}%.0s" $(seq 1 "$i"))
        printf "\r%s" "$(sgr bold "$FG_ACCENT")${line}$(sgr)"
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
    printf "%s\n\n" "$(sgr bold "$FG_BASE")${logo}$(sgr)"
    sleep "$LOG_DELAY"
}

nextstep.git_ssh_unavailable() {
    newline
    draw.line
    newline
    msg.nextstep
    echo 'Please create an SSH key pair, register the public key with GitHub.'
    echo
    echo '  ssh-keygen -t ed25519'
    echo
    echo 'And then re-run this script.'
    echo "Or specify the different environment variable 'DOTFILES_DOWNLOADER'."
    echo
    echo '  Specifiable commands:'
    echo '    - curl'
    echo '    - wget'
    echo
    exit 1
}
nextstep.invalid_downloader() {
    newline
    draw.line
    newline
    msg.nextstep
    echo "Specify the different environment variable 'DOTFILES_DOWNLOADER'."
    echo
    echo '  Specifiable commands:'
    echo '    - git'
    echo '    - curl'
    echo '    - wget'
    echo
    exit 1
}
nextstep.symlink_conflict() {
    draw.line
    newline
    msg.nextstep
    echo "Please either move the target config file or configure '.dotignore', then rerun the install."
    echo
    exit 1
}
nextstep.package_manager_unavailable() {
    newline
    draw.line
    newline
    msg.nextstep
    echo 'Package manager is unavailable.'
    echo 'Check the errors, resolve the issues, and try again.'
    echo
    exit 1
}
# shellcheck disable=SC2016
nextstep.package_installation_failed() {
    newline
    draw.line
    newline
    msg.nextstep
    echo 'Package installation failed.'
    echo 'Check the errors, resolve the issues, and try again.'
    echo 'If still failes, please execute `make initialize-package-manager` and try again.'
    echo
    exit 1
}

platform_not_support() { abort "This platform is not supported: $PLATFORM"; }

cmd_exists_check() {
    local cmd
    local option_q=false

    while (( $# > 0 )); do
        case "$1" in
            --)
                shift
                cmd="$*"
                break
                ;;
            -q)
                option_q=true
                ;;
            *)
                cmd="$*"
                break
                ;;
        esac
        shift
    done

    if "$option_q"; then
        if type "$cmd" >/dev/null 2>&1; then
            return
        else
            return 1
        fi
    else
        printf "Checking the %s command..." "$(sgr bold "$FG_ACCENT")${cmd}$(sgr)"
        if type "$cmd" >/dev/null 2>&1; then
            result.exist
            return
        else
            result.notfound
            return 1
        fi
    fi
}

deploy() {
    # USAGE: deploy [--dry-run] src dst
    #
    # srcに指定されたファイルもしくはディレクトリをdstに指定されたパスに配置します。
    #
    # srcが通常のファイルの場合、dstに指定された先にシンボリックリンクします。
    # srcがディレクトリかつdstに指定された先に存在しない場合は作成し、存在する場合は正常終了します。
    # dst先にファイルやリンクがすでに存在する場合は、1を返します。
    #
    # --dry-runオプションが指定された場合は、シンボリックリンクやディレクトリの作成は行われず、srcがdstに配置できない場合に1を返します。

    local cmd_result
    local symlink
    local dry_run=false

    if [[ $# -eq 3 ]]; then
        if [[ $1 = --dry-run ]]; then
            shift
            dry_run=true
        else
            log.error 'usage: deploy [--dry-run] src dst'
            return 1
        fi
    elif [[ $# -ne 2 ]]; then
        log.error 'usage: deploy [--dry-run] src dst'
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
            :
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

appendline() {
    # usage: dst_file line
    #
    # dst_file に line が含まれるかどうかをgrepで検索します。
    # 見つからなかった場合、line で指定された行をファイルの末尾に追記します。
    # grepで検索するため、前後の文字列は考慮されないので注意してください。

    if [[ $# -ne 2 ]]; then
        log.error 'invalid args'
        return 1
    fi

    local dst="$1"
    local line="$2"
    local input

    if [[ ! -f $dst ]]; then
        log.warn "file not found: $dst"
        touch "$dst"
        printf "%s: %s\n" "$(sgr bold "$BLUE")CREATE$(sgr)" "$dst"
    fi

    if ! grep -Fq "$line" "$dst" >/dev/null 2>&1; then
        if echo "$line" >>"$dst"; then
            printf "%s: echo '%s' >>%s\n" "$(sgr bold "$BLUE")APPEND$(sgr)" "$line" "$dst"
        else
            return 1
        fi
        RELOAD_SHELL=true
    fi
}

greet() {
    local -r greeting_messages=(
              'Hello:)'
              'This is the dotfiles installation script.'
              "Date: $(LANG=C date)"
              "Download Branch: $DOTFILES_BRANCH")
    draw.line
    draw.logo
    for msg in "${greeting_messages[@]}"; do
        msg "$msg"
    done
    newline
    draw.line
    newline
}

platform_detection() {
    local os
    msg -p 'Detecting platform'
    os=$(uname -o)
    case "$os" in
        Darwin)    PLATFORM='mac' ;;
        GNU/Linux) PLATFORM='linux' ;;
        *)         PLATFORM='unknown' ;;
    esac
    [[ $PLATFORM = unknown ]] && abort "Unkown OS: $os"
    printf "Platform detected: %s\n\n" "$(sgr bold "$FG_ACCENT")${PLATFORM}$(sgr)"
}

download_dotfiles() {
    local input
    local cmd_result
    local test_user
    local git_ssh_test_result

    download_failed() { abort 'Dotfiles download failed;('; }

    if [[ -z ${GITHUB_USERNAME:-} ]]; then
        log.error "'GITHUB_UESRNAME' is not set"
        download_failed
    fi
    if [[ -z ${DOTFILES_PATH:-} ]]; then
        log.error "'DOTFILES_PATH' is not set"
        download_failed
    fi
    if [[ -z ${DOTFILES_BRANCH:-} ]]; then
        log.error "'DOTFILES_PATH' is not set"
        download_failed
    fi
    if [[ -z ${DOTFILES_SSH_URL:-} ]]; then
        log.error "'DOTFILES_SSH_URL' is not set"
        download_failed
    fi
    if [[ -z ${SSH_DIR:-} ]]; then
        log.error "'SSH_DIR' is not set"
        download_failed
    fi

    msg "Starting download of dotfiles to '${DOTFILES_PATH}'"

    if [[ -e $DOTFILES_PATH ]]; then
        msg.complete "Dotfiles already exists;)"
        return
    fi

    msg -p 'Checking DOTFILES_DOWNLOADER'
    if [[ -z ${DOTFILES_DOWNLOADER:-} ]]; then
        if cmd_exists_check 'git'; then
            DOTFILES_DOWNLOADER='git'
        elif cmd_exists_check 'curl'; then
            DOTFILES_DOWNLOADER='curl'
        elif cmd_exists_check 'wget'; then
            DOTFILES_DOWNLOADER='wget'
        else
            log.error "'DOTFILES_DOWNLOADER' not found: git, curl, wget"
            download_failed
        fi
        printf "Downloader detected: %s\n" "$(sgr bold "$FG_ACCENT")$DOTFILES_DOWNLOADER$(sgr)"
    else
        if cmd_exists_check "$DOTFILES_DOWNLOADER"; then
            printf "Specified downloader: %s\n" "$(sgr bold "$FG_ACCENT")${DOTFILES_DOWNLOADER}$(sgr)"
        else
            log.error "invalid downloader 'DOTFILES_DOWNLOADER': $DOTFILES_DOWNLOADER"
            nextstep.invalid_downloader
        fi
    fi

    if [[ $DOTFILES_DOWNLOADER = git ]]; then
        if cmd_result=$(git --version 2>&1); then
            echo "$cmd_result"
        else
            log.error "$cmd_result"
            download_failed
        fi

        msg -p 'Checking Git SSH connection'
        echo -n 'Checking Git config user.name...'
        if test_user=$(git config user.name); then
            result.exist
        else
            result.notfound
            read -rp "Please enter the GitHub username for testing [${GITHUB_USERNAME}]: " test_user
            [[ -z $test_user ]] && test_user="$GITHUB_USERNAME"
        fi
        printf "GitHub username for testing: %s\n" "$(sgr bold "$FG_ACCENT")${test_user}$(sgr)"
        echo -n 'Testing SSH connection to git@github.com...'
        git_ssh_test_result=$(ssh -o StrictHostKeyChecking=no -T git@github.com 2>&1) || true

        if echo "$git_ssh_test_result" | grep -q "$test_user"; then
            result.ok
        else
            result.failed
            log.error "$git_ssh_test_result"

            # gitコマンドは存在するが、SSH接続に問題があった場合
            msg -p 'Checking SSH configs'
            echo -n "SSH directory '${SSH_DIR}'..."
            if [[ -e $SSH_DIR ]]; then
                result.ok
                echo -n "SSH directory permission '${SSH_DIR}'..."
                if [[ -z $(find "$SSH_DIR" -maxdepth 0 -perm 700 -type d) ]]; then
                    result.failed
                    chmod 700 "$SSH_DIR" && msg "Changed '${SSH_DIR}' permission to 700."
                else
                    result.ok
                fi
            else
                result.failed
                mkdir -m 700 "$SSH_DIR" || return 1
                msg "Created directory '$SSH_DIR'."
            fi
            nextstep.git_ssh_unavailable
        fi
    fi

    msg -p "Downloading dotfiles with ${DOTFILES_DOWNLOADER}"

    if [[ $DOTFILES_DOWNLOADER = git ]]; then
        if ! git clone --recursive -b "$DOTFILES_BRANCH" "$DOTFILES_SSH_URL" "$DOTFILES_PATH"
        then
            download_failed
        fi
    elif [[ $DOTFILES_DOWNLOADER =~ curl|wget ]]; then
        if ! cmd_exists_check 'tar'; then
            log.error 'tar command is required'
            download_failed
        fi
        mkdir "$DOTFILES_PATH" || return 1
        case "$DOTFILES_DOWNLOADER" in
            curl) curl -L "$DOTFILES_TARBALL_URL" ;;
            wget) wget -O - "$DOTFILES_TARBALL_URL" ;;
        esac | tar xvz -C "$DOTFILES_PATH" --strip-components=1 || download_failed
    elif [[ -z ${DOTFILES_DOWNLOADER:-} ]]; then
        log.error 'DOTFILES_DOWNLOADER is not set'
        download_failed
    else
        log.error "unknown downloader: ${DOTFILES_DOWNLOADER}"
        nextstep.invalid_downloader
    fi
    msg.complete 'Dotfiles download completed:)'
}

configure_dotfiles_repository() {
    if ! cmd_exists_check -q 'git' || ! [[ -d ${DOTFILES_PATH:?}/.git ]]; then
        return
    fi

    local cmd_result

    local src_hooks
    local src
    local dst
    local hook_filename
    local deploy_hook_failed=false

    msg 'Starting dotfiles repository configuration.'

    msg -p 'Installing Git-hooks to dotfiles'
    src_hooks=$(find "$DOTFILES_GITHOOKS_DIR" -mindepth 1 -type f)
    while read -r src; do
        hook_filename=$(basename "$src")
        dst="${DOTFILES_PATH:?}/.git/hooks/${hook_filename}"
        if ! deploy "$src" "$dst"; then
            deploy_hook_failed=true
        fi
    done < <(echo "$src_hooks")
    "$deploy_hook_failed" && abort 'Hooks deployment failed;('

    local -r gitconfig_local="${DOTFILES_PATH}/.git/config"
    local username
    local email

    msg -p 'Applying default configs'
    if cmd_result=$(git config --file "$gitconfig_local" user.name); then
        [[ $cmd_result != "$GITHUB_USERNAME" ]] && log.warn 'user.name already configured'
        username="$cmd_result"
    else
        git config --file "$gitconfig_local" user.name "$GITHUB_USERNAME"
        username="$GITHUB_USERNAME"
    fi
    if cmd_result=$(git config --file "$gitconfig_local" user.email); then
        [[ $cmd_result != "$GITHUB_EMAIL" ]] && log.warn 'user.email already configured'
        email="$cmd_result"
    else
        git config --file "${DOTFILES_PATH}/.git/config" user.email "$GITHUB_EMAIL"
        email="$GITHUB_EMAIL"
    fi
    printf "%s: %s\n" "$(sgr bold "$BLUE")user.name$(sgr)" "$username"
    printf "%s: %s\n" "$(sgr bold "$BLUE")user.email$(sgr)" "$email"

    msg.complete 'Dotfiles repository configured:)'
}

confirm_init() {
    if [[ -n ${DOTFILES_INIT:-} ]]; then
        msg.attention 'The DOTFILES_INIT option has been selected.'
        msg.attention 'The following tasks may be executed in the subsequent steps:'
        newline
        echo '  * Installation and initial setup of package management software'
        echo '  * Installation of software'
        echo '  * Modification of software settings'
        newline
        printf "Press %s to continue or press any other key to skip.\n" "$(sgr bold)RETURN/ENTER$(sgr)"
        IFS='' read -sr -n 1 -p 'Ready?' input && newline

        if [[ -n $input ]]; then
            unset DOTFILES_INIT
            msg.warn 'Skip initialization:P'
        else
            newline
            return
        fi
    fi
}

initialize_os() {
    [[ -z ${DOTFILES_INIT:-} ]] && return

    if [[ $PLATFORM = mac ]]; then
        initialize_macos || abort 'macOS initialization failed;('
    else
        platform_not_support
    fi

    msg.complete 'OS initialization complete:)'
}

initialize_macos() {
    [[ -z ${DOTFILES_INIT:-} ]] && return

    local arc
    local cmd_result
    local apple_silicon=false
    local rosetta_available=false
    local initialize_failed=false

    msg -p 'Checking the machine type'
    arc=$(uname -m)
    if [[ $arc = x86_64 ]]; then
        printf "Processor: %s\n" "$(sgr bold "$FG_ACCENT")${arc}$(sgr)"
    elif [[ $arc = arm64 ]]; then
        printf "Processor: %s\n" "$(sgr bold "$FG_ACCENT")${arc}$(sgr)"
        apple_silicon=true
    else
        log.error "unknown machine type: $arc"
        return 1
    fi

    if gcc --version >/dev/null 2>&1; then
        msg 'Command line developer tools are already installed.'
    else
        msg -p 'Installing command line developer tools for xcode'
        if ! xcode-select --install; then
            log.error 'command line developer tools for xcode install failed'
            initialize_failed=true
        else
            msg 'Command line developer tools for xcode installation complete!'
        fi
    fi

    if "$apple_silicon"; then
        if ! cmd_result=$(/usr/sbin/sysctl hw.optional.arm64 | awk '{print $2}'); then
            initialize_failed=true
        elif [[ $cmd_result -eq 1 ]]; then
            rosetta_available=true
        fi

        if "$rosetta_available"; then
            msg 'Rosetta is already installed.'
        else
            msg -p 'Installing Rosetta'
            if ! sudo softwareupdate --install-rosetta; then
                log.error 'rosetta installation failed'
                initialize_failed=true
            else
                msg 'Rosetta installation complete!'
            fi
        fi
    fi

    if "$initialize_failed"; then
        return 1
    fi
}

initialize_package_manager() {
    [[ -z ${DOTFILES_INIT:-} ]] && return 0

    msg -p 'Initializing the package manager'
    if [[ $PLATFORM = mac ]]; then
        initialize_package_manager_homebrew || abort 'Homebrew initialization failed;('
    else
        platform_not_support
    fi

    msg.complete 'Package manager initialization complete:)'
}

initialize_package_manager_homebrew() {
    local config_path
    local cmd

    if ! cmd_exists_check 'brew'; then
        msg -p 'Installing Homebrew'
        if ! /bin/bash -c \
             "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)";
        then
            abort 'Homebrew installation fialed;('
        fi
        msg 'Homebrew installation successful!'
    fi

    # shellcheck disable=SC2016
    case "$SHELL" in
        *zsh)  config_path="${HOME}/.zprofile" ;;
        *)
            log.error "not supported shell: $SHELL"
            return 1
            ;;
    esac

    if ! grep -q "$cmd" "$config_path" >/dev/null 2>&1; then
        msg -p 'Configuring Homebrew'
        msg -p "Write command to add Homebrew to PATH"
        appendline "$config_path" 'eval "$(/opt/homebrew/bin/brew shellenv)"' || return 1
        RELOAD_SHELL=true
    fi
    eval "$cmd" || return 1
    msg -p 'Checking system with brew doctor'
    brew doctor
}

install_packages() {
    [[ -z ${DOTFILES_INIT:-} ]] && return

    msg -p 'Installing packages'
    if [[ $PLATFORM = mac ]]; then
        install_packages_mac || nextstep.package_installation_failed
    else
        platform_not_support
    fi
    msg.complete 'Package intallation complete:)'
}

install_packages_mac() {
    local -r package_manager='brew'

    if [[ -z ${DOTFILES_BREWFILE:-} ]]; then
        log.error "'DOTFILES_BREWFILE' is not set"
        return 1
    fi

    if ! cmd_exists_check -q "$package_manager"; then
        log.error "command not found: $package_manager"
        return 1
    fi

    brew bundle --no-lock --file "$DOTFILES_BREWFILE"
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
    local pkg_dirs
    local pkg_dir
    local pkg
    local src_configs
    local src
    local config_relpath_fromhome
    local dst
    local conflict=false

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
            log.error 'usage: check_ignore config_relpath_from_home'
            deploy_configs_failed
        fi

        config_relpath_from_home="$1"

        [[ -s $ignorefile ]] || return
        while read -r pattern; do
            [[ -z $pattern || $pattern =~ ^# ]] && continue
            [[ $config_relpath_from_home =~ ^"$pattern" ]] && return
        done < "$ignorefile"
        return 1
    }

    msg 'Starting config deployment.'

    if [[ -z ${DOTFILES_CONFIG_DIR:-} ]]; then
        log.error "'DOTFILES_CONFIG_DIR' is not set"
        deploy_configs_failed
    fi

    if ! pkg_dirs=$(find "$DOTFILES_CONFIG_DIR" -mindepth 1 -maxdepth 1 -type d 2>&1); then
        log.error "$pkg_dirs"
        deploy_configs_failed
    elif [[ -z $pkg_dirs ]]; then
        msg.warn "Package directory not found:/"
        return
    fi

    msg -p 'Checking symlink destinations'

    while read -r pkg_dir; do
        if [[ ! -d $pkg_dir ]]; then
            log.error "package directry not found: $pkg_dir"
            deploy_configs_failed
        fi
        if ! src_configs=$(find "$pkg_dir" -mindepth 1 2>&1); then
            log.error "$src_configs"
            deploy_configs_failed
        elif [[ -z $src_configs ]]; then
            log.warn "package directory is empty: $pkg_dir"
            continue
        fi
        while read -r src; do
            config_relpath_fromhome="${src#"${pkg_dir}/"}"
            dst="${HOME}/${config_relpath_fromhome:?}"
            if check_ignore "$config_relpath_fromhome"; then
                continue
            else
                deploy --dry-run "$src" "$dst" || conflict=true
            fi
        done < <(echo "$src_configs")
    done < <(echo "$pkg_dirs")

    if "$conflict"; then
        msg.warn 'Conflicting files detected:/'
        nextstep.symlink_conflict
    fi

    while read -r pkg_dir; do
        if [[ -d $pkg_dir ]]; then
            pkg=$(basename "$pkg_dir")
            msg "Deploying configs: $pkg"
        else
            log.error "package directry not found: $pkg_dir"
            deploy_configs_failed
        fi
        if ! src_configs=$(find "$pkg_dir" -mindepth 1 2>&1); then
            log.error "$src_configs"
            deploy_configs_failed
        elif [[ -z $src_configs ]]; then
            continue
        fi
        while read -r src; do
            config_relpath_fromhome="${src#"${pkg_dir}/"}"
            dst="${HOME}/${config_relpath_fromhome:?}"
            if [[ $src =~ \.swp$ ]]; then
                continue
            elif check_ignore "$config_relpath_fromhome"; then
                log.ignore "~/${config_relpath_fromhome}"
                continue
            else
                deploy "$src" "$dst" || deploy_configs_failed
            fi
        done < <(echo "$src_configs")
    done < <(echo "$pkg_dirs")
    msg.complete 'Config deployment is complete:)'
}

configure_apps() {
    [[ -z ${DOTFILES_INIT:-} ]] && return

    msg 'Starting application configuration.'
    msg.attention 'Configuring the following applications:'
    newline
    echo '  * Shell'
    echo '  * Git'
    echo '  * Starship'
    echo '  * Tmux Plugin Manager'
    newline

    if [[ $PLATFORM = mac ]]; then
        configure_fish
        configure_git
        configure_starship
        configure_tpm
    else
        platform_not_support
    fi

    #msg.complete 'All application configuration complete;)'
}

configure_fish() {
    [[ -z ${DOTFILES_INIT:-} ]] && return

    configuration_skip() { msg.warn 'Skip fish configuration:P'; }
    configuration_failed() {
        CONFIGURATION_FAILED=true
        msg.error 'Fish configuration failed;('
    }

    local fish_theme='Dracula'

    msg 'Configuring Fish Shell.'

    msg -p 'Checking requirements'
    if ! cmd_exists_check 'fish' ||
       ! cmd_exists_check 'curl' ||
       ! cmd_exists_check 'fzf'
    then
        log.warn 'requirements are not met'
        configuration_skip && return
    fi

    msg -p 'Configuring theme'
    fish -c "fish_config theme choose '${fish_theme}'"

    msg -p 'Installing fisher'
    fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher' || return 1

    msg -p 'Installing fish packages'
    fish -c 'fisher update'

    msg.complete 'Fish configuration complete!'
}

configure_git() {
    # globalにuser.name, user.emailを設定します。
    # また、~/.config/git/ 配下の末尾が .dotfiles となっているコンフィグファイルを
    # インポートする設定をgit config --global で設定します。

    [[ -z ${DOTFILES_INIT:-} ]] && return

    configuration_skip() { msg.warn 'Skip git configuration:P'; }
    configuration_failed() {
        CONFIGURATION_FAILED=true
        msg.error 'Git configuration failed;('
    }

    local gitconfigs
    local config
    local gitconfig_username
    local gitconfig_email

    msg -p 'Configuring Git user settings'

    if ! cmd_exists_check 'git'; then
        configuration_skip
        return
    fi

    echo -n 'Checking user.name...'
    if gitconfig_username=$(git config --global user.name); then
        result.ok
    else
        result.notfound
        read -rp "Configuring user.name [${GITHUB_USERNAME}]: " gitconfig_username
        [[ -z $gitconfig_username ]] && gitconfig_username="$GITHUB_USERNAME"
        git config --global user.name "$gitconfig_username" || return 1
        gitconfig_username=$(git config --global user.name) || return 1
    fi
    printf "%s: %s\n" "$(sgr bold "$BLUE")user.name$(sgr)" "$gitconfig_username"

    echo -n 'Checking user.email...'
    if gitconfig_email=$(git config --global user.email); then
        result.ok
    else
        result.notfound
        read -rp "Configuring user.email [${GITHUB_EMAIL}]: " gitconfig_email
        [[ -z $gitconfig_email ]] && gitconfig_email="$GITHUB_EMAIL"
        git config --global user.email "$gitconfig_email" || return 1
        gitconfig_email=$(git config --global user.email) || return 1
    fi
    printf "%s: %s\n" "$(sgr bold "$BLUE")user.email$(sgr)" "$gitconfig_email"

    msg -p 'Configuring Git to include config files managed by dotfiles'

    gitconfigs=$(find "${HOME}/.config/git" -type l | grep -E 'dotfiles$')

    if [[ -z $gitconfigs ]]; then
        log.error 'git config links not found'
        configuration_failed
        return
    fi

    local -r includes=$(git config --global include.path)
    while read -r config; do
        if ! echo "$includes" | grep -Fq "$config" >/dev/null 2>&1; then
            git config --global include.path "$config" || return 1
            printf "%s: %s\n" "$(sgr bold "$BLUE")INCLUDE$(sgr)" "$config"
        fi
    done < <(echo "$gitconfigs")

    msg.complete 'Git configuration complete!'
}

configure_starship() {
    [[ -z ${DOTFILES_INIT:-} ]] && return

    configuration_skip() { msg.warn 'Skip starship configuration:P'; }
    configuration_failed() {
        CONFIGURATION_FAILED=true
        msg.error 'Starship configuration failed;('
    }

    local config_path
    local cmd

    msg -p 'Configuring Starship'

    if ! cmd_exists_check 'starship'; then
        configuration_skip
        return
    fi

    # shellcheck disable=SC2016
    case "$SHELL" in
        *zsh)
            config_path="${HOME}/.zshrc"
            cmd='eval "$(starship init zsh)"'
            ;;
        *)
            log.error "not supported shell: $SHELL"
            configuration_failed
            return
            ;;
    esac

    appendline "$config_path" "$cmd" || return 1
    msg.complete 'Starship configuration complete!'
}

configure_tpm() {
    [[ -z ${DOTFILES_INIT:-} ]] && return

    configuration_skip() { msg.warn 'Skip tpm configuration:P'; }
    configuration_failed() {
        CONFIGURATION_FAILED=true
        msg.error 'Tpm configuration failed;('
    }

    msg -p 'Checking tpm requirements'

    if ! cmd_exists_check 'tmux'; then
        configuration_skip
        return
    fi
    if ! cmd_exists_check 'git'; then
        log.error 'git command required'
        configuration_failed
        return
    fi

    if [[ -d ~/.tmux/plugins/tpm ]]; then
        msg 'tpm already exists!'
    else
        msg -p 'Installing tpm'
        git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm || return 1
    fi

    msg.complete 'Tpm configuration complete!'
}

dotfiles_installation_complete() {
    draw.line
    newline
    printf "%s  🌟 DOTFILES INSTALLATION COMPLETE 🌟%s\n\n" "$(sgr bold "$PINK")" "$(sgr)"
    if cmd_exists_check -q 'fastfetch'; then
        fastfetch
        newline
    fi
    if "$RELOAD_SHELL"; then
        msg -p 'Reloading current shell'
        newline
        exec -l "${SHELL:?}"
    fi
}

dotfiles_configuration_failed() {
    draw.line
    newline
    printf "%s  🌟 DOTFILES INSTALLATION COMPLETE 🌟%s\n\n" "$(sgr bold "$YELLOW")" "$(sgr)"
    msg.warn 'Some configuration steps have failed. Please check them as required.'
    newline
    if cmd_exists_check -q 'fastfetch'; then
        fastfetch
        newline
    fi
    if "$RELOAD_SHELL"; then
        msg -p 'Reloading current shell'
        newline
        exec -l "${SHELL:?}"
    fi
}

###  main  ###

opt_all=false
opt_deploy_configs=false
opt_initialize_package_manager=false
opt_install_packages=false
opt_configure_all_apps=false
opt_configure_fish=false
opt_configure_git=false
opt_configure_starship=false
opt_configure_tpm=false

if [[ $# -eq 0 ]]; then
    opt_all=true
else
    while (($# > 0)); do
        case "$1" in
            --all) opt_all=true && break ;;
            --initialize-package-manager) opt_initialize_package_manager=true ;;
            --install-packages) opt_install_packages=true ;;
            --deploy-configs) opt_deploy_configs=true ;;
            --configure-all-apps) opt_configure_all_apps=true ;;
            --configure-fish) opt_configure_fish=true ;;
            --configure-git) opt_configure_git=true ;;
            --configure-starship) opt_configure_starship=true ;;
            --configure-tpm) opt_configure_tpm=true ;;
            *) abort 'invalid options;(' ;;
        esac
        shift
    done
fi

if "$opt_all"; then
    greet
    platform_detection
    download_dotfiles
    configure_dotfiles_repository
    deploy_configs

    confirm_init
    initialize_os
    initialize_package_manager
    install_packages
    configure_apps

    if "$CONFIGURATION_FAILED"; then
        dotfiles_configuration_failed
    else
        dotfiles_installation_complete
    fi
else
    platform_detection
    "$opt_deploy_configs" && deploy_configs

    confirm_init
    "$opt_initialize_package_manager" && initialize_package_manager
    "$opt_install_packages" && install_packages
    if "$opt_configure_all_apps"; then
        configure_apps
    else
        "$opt_configure_fish" && configure_fish
        "$opt_configure_git" && configure_git
        "$opt_configure_starship" && configure_starship
        "$opt_configure_tpm" && configure_tpm
    fi
    exit 0
fi
