# shellcheck shell=bash
# shellcheck disable=SC2034

mmerr::setup() {
  declare -g -A THEME_PALETTE=(
    ['black']='#050a15'
    ['gray']='#6e7174'
    ['white']='#eff7fe'

    ['red']='#ea5950'
    ['yellow']='#fcdc00'
    ['lime']='#c7f761'
    ['mint']='#c9f9dc'
    ['turquoise']='#0becca'
    ['sky']='#7dbbfa'
    ['blue']='#417cff'
    ['dusk']='#6874b3'
    ['navy']='#222641'
    ['iris']='#5f5fff'
    ['purple']='#948cf3'
    ['rebeccapurple']='#663399'
    ['pink']='#ec94ad'
    ['rose']='#ff5890'
    ['folly']='#fe0045'

    ['bg_dusk']='#404c8b'
  )
  declare -g -A THEME_STYLE=(
    ['normal']="$(escseq::sgr --default-fg)"
    ['success']="$(escseq::sgr --fg-tc "${THEME_PALETTE['turquoise']}")"
    ['failed']="$(escseq::sgr --fg-tc "${THEME_PALETTE['red']}")"

    ['msg_prefix']="$(escseq::sgr --fg-tc "${THEME_PALETTE['purple']}")"
    ['msg_highlight']="$(escseq::sgr --fg-tc "${THEME_PALETTE['purple']}")"
    ['msg_header']="$(escseq::sgr --fg-tc "${THEME_PALETTE['purple']}")"
    ['msg_notice']="$(escseq::sgr --fg-tc "${THEME_PALETTE['blue']}")"
    ['msg_changed']="$(escseq::sgr --fg-tc "${THEME_PALETTE['pink']}")"
    ['msg_ok']="$(escseq::sgr --fg-tc "${THEME_PALETTE['turquoise']}")"
    ['msg_warn']="$(escseq::sgr --fg-tc "${THEME_PALETTE['yellow']}")"
    ['msg_error']="$(escseq::sgr --fg-tc "${THEME_PALETTE['red']}")"
    ['msg_skipped']="$(escseq::sgr --fg-tc "${THEME_PALETTE['gray']}")"
    ['msg_confirm']="$(escseq::sgr --fg-tc "${THEME_PALETTE['lime']}")"

    ['log_fatal']="$(escseq::sgr --fg-tc "${THEME_PALETTE['folly']}")"
    ['log_error']="$(escseq::sgr --fg-tc "${THEME_PALETTE['red']}")"
    ['log_warn']="$(escseq::sgr --fg-tc "${THEME_PALETTE['yellow']}")"
    ['log_notice']="$(escseq::sgr --fg-tc "${THEME_PALETTE['blue']}")"
    ['log_info']="$(escseq::sgr --default-fg)"
    ['log_debug']="$(escseq::sgr --default-fg --faint)"
    ['log_timestamp']="$(escseq::sgr --default-fg --faint)"
    ['log_stacktrace_location']="$(escseq::sgr --fg-tc "${THEME_PALETTE['purple']}")"
  )
}
