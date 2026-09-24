# shellcheck shell=bash
# shellcheck disable=SC2034

mmerr::setup() {
  declare -g -A THEME_PALETTE=(
    ['white']='#eff7fe'
    ['black']='#050a15'
    ['red']='#ea5950'
    ['scarlet']='#ff2400'
    ['pink']='#ec94ad'
    ['neon_pink']='#e26b8c'
    ['navy']='#222641'
    ['blue']='#417cff'
    ['muted_blue']='#4f6e8d'
    ['skyblue']='#7dbbfa'
    ['blue_purple']='#5f5fff'
    ['lavender']='#6874b3'
    ['purple']='#948cf3'
    ['rebeccapurple']='#663399'
    ['dark_purple']='#404c8b'
    ['yellow']='#fcdc00'
    ['neon_green']='#c7f761'
    ['mint_green']='#c9f9dc'
    ['turquoise']='#0becca'
    ['gray']='#5e6164'
  )
  declare -g -A THEME_STYLE=(
    ['normal']="$(escseq::sgr --fg-tc "${THEME_PALETTE['white']}")"
    ['logo']="$(escseq::sgr --fg-tc "${THEME_PALETTE['pink']}")"
    ['success']="$(escseq::sgr --fg-tc "${THEME_PALETTE['turquoise']}")"
    ['failed']="$(escseq::sgr --fg-tc "${THEME_PALETTE['red']}")"
    ['danger']="$(escseq::sgr --fg-tc "${THEME_PALETTE['red']}")"
    ['abort']="$(escseq::sgr --fg-tc "${THEME_PALETTE['red']}")"

    ['msg_prefix']="$(escseq::sgr --fg-tc "${THEME_PALETTE['purple']}")"
    ['msg_highlight']="$(escseq::sgr --fg-tc "${THEME_PALETTE['purple']}")"
    ['msg_header']="$(escseq::sgr --fg-tc "${THEME_PALETTE['purple']}")"
    ['msg_notice']="$(escseq::sgr --fg-tc "${THEME_PALETTE['blue']}")"
    ['msg_changed']="$(escseq::sgr --fg-tc "${THEME_PALETTE['pink']}")"
    ['msg_ok']="$(escseq::sgr --fg-tc "${THEME_PALETTE['turquoise']}")"
    ['msg_warn']="$(escseq::sgr --fg-tc "${THEME_PALETTE['yellow']}")"
    ['msg_error']="$(escseq::sgr --fg-tc "${THEME_PALETTE['red']}")"
    ['msg_skipped']="$(escseq::sgr --fg-tc "${THEME_PALETTE['gray']}")"
    ['msg_confirm']="$(escseq::sgr --fg-tc "${THEME_PALETTE['neon_green']}")"

    ['log_fatal']="$(escseq::sgr --fg-tc "${THEME_PALETTE['scarlet']}")"
    ['log_error']="$(escseq::sgr --fg-tc "${THEME_PALETTE['red']}")"
    ['log_warn']="$(escseq::sgr --fg-tc "${THEME_PALETTE['yellow']}")"
    ['log_notice']="$(escseq::sgr --fg-tc "${THEME_PALETTE['blue']}")"
    ['log_info']="$(escseq::sgr --default-fg)"
    ['log_debug']="$(escseq::sgr --faint)"
    ['log_timestamp']="$(escseq::sgr --faint)"
    ['log_stacktrace_location']="$(escseq::sgr --fg-tc "${THEME_PALETTE['purple']}")"
  )
}
