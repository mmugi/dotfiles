# shared environment variables
set -gx XDG_CONFIG_HOME ~/.config

# homebrew
test -x /opt/homebrew/bin/brew; and /opt/homebrew/bin/brew shellenv fish | source

# aliases
alias l ls
alias la 'ls -AF'
alias ll 'ls -AFhl'

# eza
if command -q eza
    set -gx EZA_CONFIG_DIR ~/.config/eza
    alias l eza
    alias ls eza
    alias la 'eza -aF=auto'
    alias ll "eza -algF=auto --time-style='+%Y-%m-%d %H:%M'"
end

# fzf
if command -q fzf
    test -r ~/.config/fzf/fzfrc; and set -gx FZF_DEFAULT_OPTS_FILE ~/.config/fzf/fzfrc
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

# zoxide
command -q zoxide; and zoxide init fish | source
