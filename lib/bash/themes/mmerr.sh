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
    ['tarquoise']='#0becca'
    ['gray']='#5e6164'
  )
  declare -g -A THEME_STYLE=(
    ['normal']="$(escseq::sgr --fg-tc "${THEME_PALETTE['white']}")"
    ['highlight']="$(escseq::sgr --fg-tc "${THEME_PALETTE['pink']}")"
    ['box']="$(escseq::sgr --fg-tc "${THEME_PALETTE['blue_purple']}")"
    ['line']="$(escseq::sgr --fg-tc "${THEME_PALETTE['blue_purple']}")"

    ['success']="$(escseq::sgr --fg-tc "${THEME_PALETTE['tarquoise']}")"
    ['failed']="$(escseq::sgr --fg-tc "${THEME_PALETTE['red']}")"
    ['danger']="$(escseq::sgr --fg-tc "${THEME_PALETTE['red']}")"
    ['abort']="$(escseq::sgr --fg-tc "${THEME_PALETTE['red']}")"

    ['prompt']="$(escseq::sgr --fg-tc "${THEME_PALETTE['blue_purple']}")"
    ['prompt_header']="$(escseq::sgr --fg-tc "${THEME_PALETTE['tarquoise']}")"
    ['prompt_proc']="$(escseq::sgr --fg-tc "${THEME_PALETTE['purple']}")"
    ['prompt_notice']="$(escseq::sgr --fg-tc "${THEME_PALETTE['yellow']}")"
    ['prompt_changed']="$(escseq::sgr --fg-tc "${THEME_PALETTE['pink']}")"
    ['prompt_skip']="$(escseq::sgr --fg-tc "${THEME_PALETTE['gray']}")"
    ['prompt_ok']="$(escseq::sgr --fg-tc "${THEME_PALETTE['tarquoise']}")"
    ['prompt_warning']="$(escseq::sgr --fg-tc "${THEME_PALETTE['yellow']}")"
    ['prompt_failed']="$(escseq::sgr --fg-tc "${THEME_PALETTE['red']}")"
    ['prompt_confirm']="$(escseq::sgr --fg-tc "${THEME_PALETTE['neon_green']}")"

    ['fatal']="$(escseq::sgr --fg-tc "${THEME_PALETTE['scarlet']}")"
    ['error']="$(escseq::sgr --fg-tc "${THEME_PALETTE['red']}")"
    ['warning']="$(escseq::sgr --fg-tc "${THEME_PALETTE['yellow']}")"
    ['info']="$(escseq::sgr --fg-tc "${THEME_PALETTE['skyblue']}")"
    ['debug']="$(escseq::sgr --fg-tc "${THEME_PALETTE['gray']}")"

    ['log_timestamp']="$(escseq::sgr --default-fg)"
    ['log_filename']="$(escseq::sgr --fg-tc "${THEME_PALETTE['lavender']}")"
    ['log_ch']="$(escseq::sgr --fg-tc "${THEME_PALETTE['purple']}")"
    ['log_funcname']="$(escseq::sgr --fg-tc "${THEME_PALETTE['blue_purple']}")"
    ['log_stacktrace_function']="$(escseq::sgr --fg-tc "${THEME_PALETTE['blue_purple']}" --bold)"
    ['log_stacktrace_location']="$(escseq::sgr --fg-tc "${THEME_PALETTE['lavender']}")"
  )
}
