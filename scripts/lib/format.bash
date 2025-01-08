lib_self='format.bash'

if [ -z "${BASH_VERSION:-}" ]; then
    echo "${lib_self}: error: This library must be sourced in Bash."
    return 1 2>/dev/null || exit 1
fi

SCRIPTNAME="$(basename "$0")"
LOG_DELAY=0.4

# 256 color palette
RED=166
BLUE=75
YELLOW=220
CYAN=195
PINK=175
PURPLE=105
DARKGREEN=30
FG_BASE="$CYAN"
FG_ACCENT="$PURPLE"

abort() {
    printf "\033[1;31m⛔ %s\033[0m\n" "$@" >&2
    exit 1
}

import_lib() {
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
} && import_lib

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
    local color="$FG_BASE"
    local with_progress_dots=false

    while (($# > 0)); do
        case "$1" in
            --) shift && break ;;
            -p) with_progress_dots=true ;;
            -c)
                shift
                if [[ $# -eq 0 || $1 =~ ^- ]]; then
                    log.error 'invalid options'
                    return 1
                else
                    color="$1"
                fi
                ;;
            *) break ;;
        esac
        shift
    done

    local -r msg="$*"

    if "$with_progress_dots"; then
        for i in $(seq "$length"); do
            progress_dots=$(printf "${symbol}%.0s" $(seq 1 "$i"))
            printf "\r%s> %s" "$(sgr bold "$FG_ACCENT")" "$(sgr "$color")${msg}${progress_dots}$(sgr)"
            sleep 0.2
        done
    else
        printf "%s> %s" "$(sgr bold "$FG_ACCENT")" "$(sgr "$color")$*$(sgr)"
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

draw.line() {
    # usage: draw.line [length]

    local length

    if [[ $# -ne 0 ]]; then
        if [[ ! $1 =~ ^[0-9]+$ ]]; then
            log.error 'invalid args'
            return 1
        else
            length="$1"
        fi
    else
        length=67
    fi

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
    local color="$FG_BASE"
    local logo='
    _____  _______ _______ _______ _______ _____   _______ _______ 
   |     \|       |_     _|    ___|_     _|     |_|    ___|     __|
 __|  --  |   -   | |   | |    ___|_|   |_|       |    ___|__     |
|__|_____/|_______| |___| |___|   |_______|_______|_______|_______|'

    while (($# > 0)); do
        case "$1" in
            -c)
                shift
                if [[ $# -eq 0 || $1 =~ ^- ]]; then
                    log.error 'invalid options'
                    return 1
                else
                    color="$1"
                fi
                ;;
            -u) logo='
    _______ _______ _______ _______ _______ _______ _______ _____   _____
   |   |   |    |  |_     _|    |  |     __|_     _|   _   |     |_|     |_
 __|   |   |       |_|   |_|       |__     | |   | |       |       |       |
|__|_______|__|____|_______|__|____|_______| |___| |___|___|_______|_______|' ;;
            *)
                log.error 'invalid options'
                return 1
                ;;
        esac
        shift
    done

    printf "%s\n\n" "$(sgr bold "$color")${logo}$(sgr)"
    sleep "$LOG_DELAY"
}
