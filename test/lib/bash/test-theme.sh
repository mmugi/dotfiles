#!/usr/bin/env bash

set -ueo pipefail

DOTFILES_PATH=~/.dotfiles
source "${DOTFILES_PATH}/lib/bash/import.sh"
import theme

bar() { printf '%b-----------------------------%b\n' '\033[1m' '\033[m'; }
debug() { printf '%b>>> %s%b\n' '\033[32;1m' "$*" '\033[m'; }

debug 'theme not loaded'
theme::list_styles
theme::list_styles --stdout
theme::list_styles --stderr
bar

debug 'theme loading'
theme::load mmerr
bar

debug 'theme loaded'
declare -p THEME_STYLE_COMMON ||:
declare -p THEME_PALETTE ||:
declare -p THEME_STYLE ||:
declare -p STYLE_STDOUT ||:
declare -p STYLE_STDERR ||:
theme::list_styles --all
bar

debug 'theme clear'
theme::clear
declare -p THEME_STYLE_COMMON ||:
declare -p THEME_PALETTE ||:
declare -p THEME_STYLE ||:
declare -p STYLE_STDOUT ||:
declare -p STYLE_STDERR ||:
theme::list_styles --all
bar

debug 'theme duble load'
theme::load
theme::load
theme::list_styles --all
bar

debug 'compgen -A variable THEME_'
compgen -A variable 'THEME_'
debug 'compgen -A variable STYLE_'
compgen -A variable 'STYLE_'
bar

debug 'configs'
TERMCAP_COLOR_MODE=auto
LOG_LEVEL=1
LOG_TS=true
LOG_ABSPATH=true
LOG_TRACE_ABSPATH=false
LOG_TRACE_FATAL=true
LOG_TRACE_ERROR=false
LOG_TRACE_WARN=false
LOG_TRACE_INFO=false
LOG_TRACE_DEBUG=false
echo "NO_COLOR: ${NO_COLOR:-null}"
echo "TERMCAP_COLOR_MODE: ${TERMCAP_COLOR_MODE:-null}"
echo "LOG_TS: ${LOG_TS:-null}"
echo "LOG_LEVEL: ${LOG_LEVEL:-null}"
echo "LOG_ABSPATH: ${LOG_ABSPATH:-null}"
echo "LOG_TRACE_ABSPATH: ${LOG_TRACE_ABSPATH:-null}"
echo "LOG_TRACE_FATAL: ${LOG_TRACE_FATAL:-null}"
echo "LOG_TRACE_ERROR: ${LOG_TRACE_ERROR:-null}"
echo "LOG_TRACE_WARN: ${LOG_TRACE_WARN:-null}"
echo "LOG_TRACE_INFO: ${LOG_TRACE_INFO:-null}"
echo "LOG_TRACE_DEBUG: ${LOG_TRACE_DEBUG:-null}"
bar

debug 'style test'
printf "${STYLE_STDOUT['log_error']:-(style null)}log_error STDOUT${STYLE_STDOUT['rst']:-}\n"
printf "${STYLE_STDERR['log_info']:-(style null)}log_error STDERR${STYLE_STDERR['rst']:-}\n" >&2
bar

debug 'style test after clear'
theme::clear
printf "${STYLE_STDOUT['log_error']:-(style null)}log_error STDOUT${STYLE_STDOUT['rst']:-}\n"
printf "${STYLE_STDERR['log_info']:-(style null)}log_error STDERR${STYLE_STDERR['rst']:-}\n" >&2
bar

debug 'style reload'
theme::load
bar

debug EOS
