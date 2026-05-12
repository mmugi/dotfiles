#!/usr/bin/env bash

set -ueo pipefail

DOTFILES_PATH=~/.dotfiles
IMPORT_DEBUG=true

bar() { printf '%b-----------------------------%b\n' '\033[1m' '\033[m'; }
debug() { printf '%b>>> %s%b\n' '\033[32;1m' "$*" '\033[m'; }

debug 'source import.sh'
source "${DOTFILES_PATH}/lib/bash/import.sh"
debug 'library import'
import log
bar

debug 'configs'
TERMCAP_COLOR_MODE=auto
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
echo "LOG_ABSPATH: ${LOG_ABSPATH:-null}"
echo "LOG_TRACE_ABSPATH: ${LOG_TRACE_ABSPATH:-null}"
echo "LOG_TRACE_FATAL: ${LOG_TRACE_FATAL:-null}"
echo "LOG_TRACE_ERROR: ${LOG_TRACE_ERROR:-null}"
echo "LOG_TRACE_WARN: ${LOG_TRACE_WARN:-null}"
echo "LOG_TRACE_INFO: ${LOG_TRACE_INFO:-null}"
echo "LOG_TRACE_DEBUG: ${LOG_TRACE_DEBUG:-null}"
bar

debug 'theme not loaded'
LOG_TRACE_ERROR=true
echo "LOG_TRACE_ERROR: ${LOG_TRACE_ERROR:-null}"
log::logger --debug -v 'log test debug'
log::logger --info -v 'log test info'
log::logger --warn -v 'log test warn'
log::logger --error -v 'log test error'
bar

debug 'theme load'
import theme
theme::load
theme::list_styles
bar

debug 'logger test'
LOG_LEVEL=0
echo "LOG_LEVEL: ${LOG_LEVEL:-null}"
log::logger --debug -v 'log test debug'
log::logger --info -v 'log test info'
log::logger --warn -v 'log test warn'
log::logger --error -v 'log test error'
#log::logger --fatal -v 'log test fatal'
bar

debug 'theme.sh re:source'
source "${DOTFILES_PATH}/lib/bash/theme.sh"
#import theme
#theme::load
theme::list_styles
bar

debug 'logger test in function'
f1() {
  log::logger --error 'f1 log'
  f2
}
f2() {
  log::logger --error 'f2 log'
}
f1
bar

debug 'config test'
LOG_TS=true
LOG_ABSPATH=false
LOG_TRACE_ABSPATH=false
LOG_LEVEL=0
LOG_TRACE_ERROR=true
LOG_TRACE_WARN=false
LOG_TRACE_INFO=true
LOG_TRACE_DEBUG=false
echo "LOG_TS: ${LOG_TS:-null}"
echo "LOG_ABSPATH: ${LOG_ABSPATH:-null}"
echo "LOG_TRACE_ABSPATH: ${LOG_TRACE_ABSPATH:-null}"
echo "LOG_LEVEL: ${LOG_LEVEL:-null}"
echo "LOG_TRACE_FATAL: ${LOG_TRACE_FATAL:-null}"
echo "LOG_TRACE_ERROR: ${LOG_TRACE_ERROR:-null}"
echo "LOG_TRACE_WARN: ${LOG_TRACE_WARN:-null}"
echo "LOG_TRACE_INFO: ${LOG_TRACE_INFO:-null}"
echo "LOG_TRACE_DEBUG: ${LOG_TRACE_DEBUG:-null}"
log::logger --debug -v 'log test debug'
log::logger --info -v 'log test info'
log::logger --warn -v 'log test warn'
log::logger --error -v 'log test error'
#log::logger --fatal -v 'log test fatal'
f1
LOG_TS=false
LOG_LEVEL=2
LOG_ABSPATH=false
LOG_TRACE_ABSPATH=true
echo "LOG_TS: ${LOG_TS:-null}"
echo "LOG_LEVEL: ${LOG_LEVEL:-null}"
echo "LOG_ABSPATH: ${LOG_ABSPATH:-null}"
echo "LOG_TRACE_ABSPATH: ${LOG_TRACE_ABSPATH:-null}"
log::logger --debug -v 'log test debug'
log::logger --info -v 'log test info'
log::logger --warn -v 'log test warn'
log::logger --error -v 'log test error'
#log::logger --fatal -v 'log test fatal'
f1
bar

debug 'style reset check'
LOG_TS=true
LOG_LEVEL=0
LOG_ABSPATH=true
LOG_TRACE_ABSPATH=true
theme::clear
log::logger --info -v 'log test info'
bar

debug 'fatal log check'
theme::load
LOG_FATAL_EXIT=false
echo "LOG_FATAL_EXIT: ${LOG_FATAL_EXIT:-null}"
log::logger --fatal -v 'log test fatal' ||:
LOG_FATAL_EXIT=true
echo "LOG_FATAL_EXIT: ${LOG_FATAL_EXIT:-null}"
log::logger --fatal -v 'log test fatal' ||:

debug EOS
