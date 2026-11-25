# homebrew
test -x /opt/homebrew/bin/brew; and /opt/homebrew/bin/brew shellenv fish | source

# fzf
if command -q fzf
    set -gx FZF_DEFAULT_OPTS_FILE ~/.config/fzf/fzfrc
    set -g FZF_ALT_C_COMMAND ''
    fzf --fish | source

    if command -q ghq
        function __ghq_cd
            set -l dir (ghq list --full-path | fzf); and cd $dir
            commandline -f repaint
        end
        bind ctrl-g __ghq_cd
    end
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

# zoxide
command -q zoxide; and zoxide init fish | source
