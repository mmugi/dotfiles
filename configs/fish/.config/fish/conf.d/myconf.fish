# decors/fish-ghq
set -g GHQ_SELECTOR_OPTS '--reverse'

# jethrokuan/fzf
set -g FZF_DEFAULT_OPTS '--reverse --height 50%'
type fd >/dev/null; and set -g FZF_FIND_FILE_COMMAND \
        "fd --follow --hidden --exclude .git/ . \$dir | perl -pe 's#^\.\/##'"

# homebrew
type brew >/dev/null; and eval "$(/opt/homebrew/bin/brew shellenv)"

# starship
type starship >/dev/null; and starship init fish | source
