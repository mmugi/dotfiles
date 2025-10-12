#!/usr/bin/env bash

set -ueo pipefail

# shellcheck disable=SC2034
{
  LIB_VERSION='1.0.0';
  LIB_DEPS='esc';
  [[ ${1:-} = __META_PROBE__ ]] && return 0;
}

if [[ -t 1 ]]; then
  : "${MSG_DELAY:=0.2}"
else
  MSG_DELAY=0
fi

: "${MSG_C_BASE:=$ESC_TAG_BASE}"
: "${MSG_C_HIGHLIGHT1:=$ESC_TAG_MAIN}"
: "${MSG_C_HIGHLIGHT2:=$ESC_TAG_ACCENT2}"

newline() { printf '\n'; }

msg() {
  # スクリプトのメッセージ出力に利用する。
  # 引数にとった文字列をオプションに基づいて整形・色付けして出力する。
  # 引数に取る文字列は以下のタグを解釈する。
  #   <hl>...</hl>: プロンプトと同様の色でハイライトする。
  #
  # options:
  #   -n   末尾で改行しない。
  #
  #   -p   末尾で処理中を示すプログレスドットを出力する。
  #        > example...
  #
  #   -P   プロンプト非表示・カラーなしで出力する。
  #
  #   -r <result>
  #        処理の結果をプログレスドットのあとに出力する。
  #        $ msg -r EXAMPLE -- example
  #        > example...EXAMPLE
  #
  #   -2
  #        1段階インデントされた出力を行う。
  #        デフォルトのインデントなしの出力から別のハイライトカラーで出力する。
  #        $ msg example1; msg -2 example2
  #        > example1
  #          > example2
  #
  #   -ok, -failed, -mismatch, -exist, -notfound
  #        処理の結果をプログレスドットのあとに出力する。
  #        任意の結果を出力したい場合は、-r オプションを利用する。
  #
  #   -complete, -warn
  #        プロンプトおよび文字を用途別に装飾(カラー・属性)して出力する。

  local -r progress_dots_length=3
  local -r progress_interval=0.1
  local -r usage='usage: msg [-n][-p][-P][-r text][-ok|-failed|-exist|-notfound][-2] [--] text...'
  local progress_dots
  local bold=''
  local no_newline_no_delay=false
  local additional_newline=false
  local prompt_char='>'
  local prompt_color="$MSG_C_HIGHLIGHT1"
  local hl_color="$MSG_C_HIGHLIGHT1"
  local base_color="$MSG_C_BASE"
  local result=''
  local style_plain=false
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
        style_plain=true
        shift
        ;;
      -r)
        [[ -z ${2:-} ]] && abort "$usage"
        with_progress_dots=true
        result="$2"
        shift 2
        ;;
      -2)
        prompt_char=' >'
        prompt_color="$MSG_C_HIGHLIGHT2"
        hl_color="$MSG_C_HIGHLIGHT2"
        shift
        ;;
      # results
      -ok)
        with_progress_dots=true
        result=$(printf "%sOK%s" "${ESC_ATTR_BOLD}${ESC_FG_BLUE}" "${ESC_RESET}")
        shift
        ;;
      -failed)
        with_progress_dots=true
        result=$(printf "%sFAILED%s" "${ESC_ATTR_BOLD}${ESC_FG_RED}" "$ESC_RESET")
        shift
        ;;
      -mismatch)
        with_progress_dots=true
        result=$(printf "%sMISMATCH%s" "${ESC_ATTR_BOLD}${ESC_FG_RED}" "$ESC_RESET")
        shift
        ;;
      -exist)
        with_progress_dots=true
        result=$(printf "%sEXIST%s" "${ESC_ATTR_BOLD}${ESC_FG_BLUE}" "$ESC_RESET")
        shift
        ;;
      -notfound)
        with_progress_dots=true
        result=$(printf "%sNOTFOUND%s" "${ESC_ATTR_BOLD}${ESC_FG_RED}" "$ESC_RESET")
        shift
        ;;
      # formats
      -complete)
        prompt_char='✨️'
        base_color="$ESC_FG_PINK"
        bold=true
        additional_newline=true
        shift
        ;;
      -warn)
        prompt_char='👻'
        base_color="$ESC_FG_YELLOW"
        bold=true
        additional_newline=true
        shift
        ;;
      -*) abort "$usage" ;;
      *) break ;;
    esac
  done

  [[ $# -eq 0 ]] && abort "$usage"

  if "$style_plain"; then
    local -r msg="$*"
    local -r prompt=''
  else
    # parse tags
    local s="$*"
    s="${s//<hl>/$hl_color}"
    s="${s//<\/hl>/$base_color}"
    local -r msg="${bold:+$ESC_ATTR_BOLD}${base_color}${s}${ESC_RESET}"
    local -r prompt="${prompt_color}${prompt_char} ${ESC_RESET}"
  fi

  printf "%s" "${prompt}${msg}"
  if "$with_progress_dots"; then
    sleep "$progress_interval"
    for i in $(seq "$progress_dots_length"); do
      progress_dots="${bold}${base_color}$(printf ".%.0s" $(seq 1 "$i"))${ESC_RESET}"
      printf "\r%s" "${prompt}${msg}${progress_dots}"
      sleep "$progress_interval"
    done
    printf "\r%s" "${prompt}${msg}${progress_dots}${result}"
  fi
  if ! "$no_newline_no_delay"; then
    newline
    "$additional_newline" && newline
    sleep "$MSG_DELAY"
  fi
}
