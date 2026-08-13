# shellcheck shell=bash
#
# 生成先のシェルが評価するコードを出力するため、ここで $HOME を展開しない。
# shellcheck disable=SC2016

# XDG base directory。
#
# 対話・非対話を問わず参照されるため env に置く。また、これを前提に配置先を
# 決めるものがあるので、他のエントリより先に評価されるようにしている。
#
# $HOME はリテラルで埋め込む。--print で別マシンへ持ち出したときにも、
# そのマシンのホームを指すようにするため。
#
# 既に定義されている場合は上書きしない。先に設定された値を奪うと、それを前提に
# 配置先を決めているものがずれる。

render() {
  case "$1" in
    fish)
      shellconf::raw \
        'if not set -q XDG_CONFIG_HOME' \
        '  set -gx XDG_CONFIG_HOME "$HOME/.config"' \
        'end'
      ;;
    *)
      shellconf::raw 'export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"'
      ;;
  esac
}
