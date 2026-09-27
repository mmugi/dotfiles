#!/usr/bin/env bash

set -ueo pipefail

# Claude Code のステータスラインを組み立てる。
# settings.json の statusLine から呼ばれ、セッションの状態が JSON で標準入力に渡る。
#
#   <project> on <branch><flags> · <model> · ctx <n>% · 5h <n>% (until <日時>) · 7d <n>% (until <日時>)
#
# ctx / 5h / 7d はいずれも消費率。
#
# 更新のたびに起動されるため、外部プロセスは jq と git の2つに抑える。日時の整形は
# date を呼ばず bash の printf '%()T' で済ませる。

# mapfile と printf '%()T' に bash 4.2 以上が必要
(( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 2) )) || exit 0

# 色は starship の palettes.mypalette を参照
C_RST='' C_BRANCH='' C_STAGED='' C_MODIFIED='' C_DIM='' C_WARN='' C_ERR=''
if [[ -z "${NO_COLOR:-}" ]]; then
  # 出力先は端末ではなく Claude なので [ -t 1 ] では判定できない。NO_COLOR だけを見る。
  C_RST=$'\033[0m'
  C_BRANCH=$'\033[38;2;148;140;243m'   # purple #948cf3
  C_STAGED=$'\033[38;2;11;236;202m'    # green  #0becca
  C_MODIFIED=$'\033[38;2;236;148;173m' # pink   #ec94ad
  C_DIM=$'\033[38;2;94;97;100m'        # gray   #5e6164
  C_WARN=$'\033[38;2;252;220;0m'       # yellow #fcdc00
  C_ERR=$'\033[38;2;234;89;80m'        # red    #ea5950
fi

# 項目の区切り。Claude 本体が mode を出す行と同じ「空白・中黒・空白」に合わせる。
SEP=" ${C_DIM}·${C_RST} "

# プロジェクトとブランチをつなぐ語。中黒で割ると別々の項目に見えるが、この2つは
# 「いまどこにいるか」をひと続きで答えるので、区切りではなく語でつなぐ。
ON=" ${C_DIM}on${C_RST} "

_paint() {
  # usage: _paint <色> <文字列>
  printf '%s%s%s' "$1" "$2" "$C_RST"
}

_usage_color() {
  # 消費率で色を決める。多いほど危ない。
  (( $1 < 50 )) && { printf '%s' "$C_STAGED"; return; }
  (( $1 < 80 )) && { printf '%s' "$C_WARN"; return; }
  printf '%s' "$C_ERR"
}

_until() {
  # usage: _until <リセット時刻の epoch 秒>
  # '(until 09/22 04:06)' を出す。空なら何も出さない。過ぎた時刻は jq 側で落としてある。
  local when
  [[ -n "$1" ]] || return 0
  printf -v when '%(%m/%d %H:%M)T' "$1"
  printf '(until %s)' "$when"
}

_gauge() {
  # usage: _gauge <ラベル> <消費率> <添える文字列>
  printf '%s%s%s' \
    "$(_paint "$C_DIM" "$1 ")" \
    "$(_paint "$(_usage_color "$2")" "${2}%")" \
    "${3:+ $(_paint "$C_DIM" "$3")}"
}

_git_section() {
  # 現在のブランチと作業ツリーの汚れ具合を出す。git 管理外なら何も出さず 1 を返す。
  #
  # ブランチと変更有無を別々に問い合わせると git を2回起動することになるため、
  # --branch 付きの porcelain v2 で一度にまとめて受け取る。
  # --no-optional-locks は Claude Code 公式のステータスライン向け指針。更新のたびに
  # index を書き直して、利用者が同時に叩いた git とロックを奪い合うのを避ける。

  local out line head='' oid='' staged='' modified='' untracked=''

  out="$(git --no-optional-locks status --porcelain=v2 --branch \
    --untracked-files=normal 2>/dev/null)" || return 1

  while IFS= read -r line; do
    case "$line" in
      '# branch.head '*) head="${line#\# branch.head }" ;;
      '# branch.oid '*)  oid="${line#\# branch.oid }" ;;
      '?'*)              untracked=1 ;;
      1\ * | 2\ *)
        # 3文字目から XY。X がステージ済み、Y が作業ツリーの変更を表す。
        [[ "${line:2:1}" != . ]] && staged=1
        [[ "${line:3:1}" != . ]] && modified=1
        ;;
      u\ *) modified=1 ;;
    esac
  done <<<"$out"

  # detached HEAD ではブランチ名の代わりに (detached) が入る。short sha を出す。
  # --branch が成功する限り branch.head は必ず出る (コミットゼロでも main と出る) ので、
  # 名前が取れない場合を用意する必要はない。
  [[ "$head" == '(detached)' ]] && head="${oid:0:7}"

  printf '%s%s%s%s' "$(_paint "$C_BRANCH" "$head")" \
    "${modified:+${C_MODIFIED}*${C_RST}}" \
    "${staged:+${C_STAGED}+${C_RST}}" \
    "${untracked:+${C_DIM}?${C_RST}}"
}

main() {
  local fields model ctx five five_at week week_at project cwd
  local out='' place branch

  _add_section() {
    [[ -n "$out" ]] && out+="$SEP"
    out+="$1"
  }

  # 標準入力の JSON から表示に要る値を1行ずつ受け取る。欠損・null は空行になり、
  # 百分率の丸めは jq に任せる。mapfile は IFS を見ないので空行が潰れず、
  # jq が無い環境や入力が壊れている場合は空配列のまま git だけに縮退する。
  mapfile -t fields < <(jq -r '
  # ウィンドウが切れた直後は resets_at が過去になりうる。時刻の判断は now を持つ
  # ここで済ませ、過ぎたものは空にして渡す。
  def future: if type == "number" and . > now then . else "" end;
  [
    .model.display_name // "",
    .context_window.used_percentage // "",
    .rate_limits.five_hour.used_percentage // "",
    (.rate_limits.five_hour.resets_at // "" | future),
    .rate_limits.seven_day.used_percentage // "",
    (.rate_limits.seven_day.resets_at // "" | future),
    .workspace.project_dir // "",
    .workspace.current_dir // ""
  ] | map(if type == "number" then round else . end) | .[]' 2>/dev/null || true)

  model="${fields[0]-}"   ctx="${fields[1]-}"      five="${fields[2]-}"
  five_at="${fields[3]-}" week="${fields[4]-}"     week_at="${fields[5]-}"
  project="${fields[6]-}" cwd="${fields[7]-}"

  place="${project:+$(_paint "$C_DIM" "${project##*/}")}"
  branch="$(_git_section)" || branch="${cwd:+$(_paint "$C_BRANCH" "${cwd##*/}")}"
  place+="${branch:+${place:+$ON}$branch}"

  [[ -n "$place" ]] && _add_section "$place"
  [[ -n "$model" ]] && _add_section "$(_paint "$C_DIM" "$model")"
  [[ -n "$ctx" ]]   && _add_section "$(_gauge ctx "$ctx" '')"
  [[ -n "$five" ]]  && _add_section "$(_gauge 5h "$five" "$(_until "$five_at")")"
  [[ -n "$week" ]]  && _add_section "$(_gauge 7d "$week" "$(_until "$week_at")")"
  [[ -n "$out" ]]   && printf '%s\n' "$out"

  return 0
}

main
