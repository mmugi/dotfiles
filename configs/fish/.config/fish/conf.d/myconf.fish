# decors/fish-ghq
set -g GHQ_SELECTOR_OPTS '--reverse'

# homebrew
test -x /opt/homebrew/bin/brew; and /opt/homebrew/bin/brew shellenv fish | source

# fzf
if command -q fzf
    set -gx FZF_DEFAULT_OPTS_FILE ~/.config/fzf/fzfrc
    set -g FZF_ALT_C_COMMAND ''
    fzf --fish | source
end

# starship
command -q starship; and starship init fish | source

# eza
if command -q eza
    set -gx EZA_CONFIG_DIR ~/.config/eza
    alias l eza
    alias ls eza
    alias ll "eza -algF=auto --time-style='+%Y-%m-%d %H:%M'"
end
