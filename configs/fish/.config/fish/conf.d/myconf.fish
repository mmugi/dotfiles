# decors/fish-ghq
set -g GHQ_SELECTOR_OPTS '--reverse'

# jethrokuan/fzf
set -g FZF_DEFAULT_OPTS '--reverse --height 50%'
command -q fd; and set -g FZF_FIND_FILE_COMMAND \
        "fd --follow --hidden --exclude .git/ . \$dir | perl -pe 's#^\.\/##'"

# homebrew
command -q brew; and eval "$(/opt/homebrew/bin/brew shellenv)"

# starship
command -q starship; and starship init fish | source

# eza
if command -q eza
    alias l eza
    alias ls eza
    alias ll 'eza -alF=auto'
end
