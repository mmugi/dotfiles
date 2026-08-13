# shellcheck shell=bash
# shellcheck disable=SC2034

# Homebrew の環境変数を通す。
#
# rc ではなく env に置くのは、この後のエントリが brew 配下のコマンド
# (starship, fzf など) を PATH から探すため。
#
# Apple Silicon の /opt/homebrew/bin は既定の PATH に含まれないため、
# brew 自体を PATH から見つけられるとは限らない。生成時に絶対パスを解決して
# 焼き込む。生成物は run/ 配下で git 管理外なので、マシン固有のパスが
# 混ざって困ることはない。

_brew_bin="$(command -v brew 2>/dev/null || true)"

if [[ -z "$_brew_bin" ]]; then
  for _candidate in \
    /opt/homebrew/bin/brew \
    /usr/local/bin/brew \
    /home/linuxbrew/.linuxbrew/bin/brew
  do
    if [[ -x "$_candidate" ]]; then
      _brew_bin="$_candidate"
      break
    fi
  done
fi

# 絶対パスでも command -v / type -q は実行可能かどうかを判定できる。
guard="$_brew_bin"

render() {
  [[ -z "$_brew_bin" ]] && return 0

  case "$1" in
    fish) shellconf::raw "${_brew_bin} shellenv fish | source" ;;
    *)    shellconf::raw "eval \"\$(${_brew_bin} shellenv $1)\"" ;;
  esac
}
