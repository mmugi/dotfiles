# shellcheck shell=bash
# shellcheck disable=SC2034

# git 同梱の git-completion を読み込む。
#
# 対象は bash のみ。
#   - zsh は標準の _git 補完を持っており、git 同梱版を重ねるには compinit の
#     制御まで踏み込む必要がある。利用者の ~/.zshrc 側の compinit と二重に
#     なりかねないので、標準の補完に任せる。
#   - fish も git 補完を同梱している。
#
# 補完スクリプトの場所はマシン固有なので、生成時に解決して焼き込む。
shells='bash'

render() {
  local completion_path=''

  util::chk -cq git || return 0

  completion_path="$(shellconf::locate 'git-completion.bash')" || return 0

  shellconf::source_if "$completion_path"
}
