# shellcheck shell=bash
# shellcheck disable=SC2034

# fish プラグイン (fish_plugins 参照) が読む設定。
#
# プラグイン側が参照する変数なので、エクスポートせず fish のグローバル変数に
# とどめる。他シェルには対応物が無いため fish 限定にする。
#
# 入れ子の引用符が多いため、ヘルパを介さずクォート付きヒアドキュメントで
# そのまま書き出す。
shells='fish'

render() {
  cat <<'FISH'
# decors/fish-ghq
set -g GHQ_SELECTOR_OPTS '--reverse'

# jethrokuan/fzf
if type -q fd
  set -g FZF_FIND_FILE_COMMAND "fd --follow --hidden --exclude .git/ . \$dir | perl -pe 's#^\.\/##'"
end
FISH
}
