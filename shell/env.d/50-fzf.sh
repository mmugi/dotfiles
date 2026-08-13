# shellcheck shell=bash

# fzf の既定オプション。
# fzf を起動する側が読む変数なので、対話シェルに限らず効かせたい。
# よって rc ではなく env に置く。

render() {
  shellconf::export FZF_DEFAULT_OPTS '--reverse --height 50%'
}
