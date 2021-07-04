### git commands

function _fzf_ghq() {

    # list and move local github repository dir with fzf.

    if ! is_exists 'ghq'; then
        e_error '_fzf_ghq: ghq command not found'
        return 1
    fi

    if ! is_exists 'fzf'; then
        e_error '_fzf_ghq: fzf command not found'
        return 1
    fi

    local repository=$(ghq list | fzf --height 90% --prompt 'GHQ LIST > ' --exit-0 --preview "ls -al --full-time --color $(ghq root)/{} | awk '{if (NR==1) print \$0; else print \$6 \" \" \$9}'" --bind "$(_fzf_preview_bind)")
    local repo_full_path="$(ghq root | sed "s#\\\\#/#g")/${repository}"

    [ ! -z "$repository" ] && [ -d "$repo_full_path" ] && cd "$repo_full_path"
}

function _fzf_git_log() {
    if ! is_exists 'git'; then
        e_error '_fzf_git_log: git command not found'
        return 1
    fi

    if ! is_exists 'fzf'; then
        e_error '_fzf_git_log: fzf command not found'
        return 1
    fi

    git log --oneline --graph --color=always \
        --date=format-local:'%Y-%m-%d %H:%M:%S' \
        --format="%C(auto)%h%d %s %C(black)%C(bold)%cd" | \
    fzf --color=dark --no-sort --no-multi --no-cycle --tiebreak=index \
        --height=100% --prompt='GIT LOG GRAPH > ' \
        --preview-window=down:85%:wrap:hidden \
        --preview "_fzf_preview_git_show {}" \
        --bind "$(_fzf_preview_bind),tab:toggle-preview,ctrl-y:execute(echo {} | grep -o '[a-f0-9]\{7\}')+abort,enter:execute:(grep -o '[a-f0-9]\{7\}' | head -1 | xargs -I % sh -c 'git show --color=always % | less -R') << 'FZF-EOF'
{}
FZF-EOF"
}

function _fzf_git_log_all() {
    if ! is_exists 'git'; then
        e_error '_fzf_git_log_all: git command not found'
        return 1
    fi

    if ! is_exists 'fzf'; then
        e_error '_fzf_git_log_all: fzf command not found'
        return 1
    fi

    git log --all --oneline --graph --color=always \
        --date=format-local:'%Y-%m-%d %H:%M:%S' \
        --format="%C(auto)%h%d %s %C(black)%C(bold)%cd" | \
    fzf --color=dark --no-sort --no-multi --no-cycle --tiebreak=index \
        --height=100% --prompt='GIT LOG GRAPH > ' \
        --preview-window=down:85%:wrap:hidden \
        --preview "_fzf_preview_git_show {}" \
        --bind "$(_fzf_preview_bind),tab:toggle-preview,ctrl-y:execute(echo {} | grep -o '[a-f0-9]\{7\}')+abort,enter:execute:(grep -o '[a-f0-9]\{7\}' | head -1 | xargs -I % sh -c 'git show --color=always % | less -R') << 'FZF-EOF'
{}
FZF-EOF"
}

function _fzf_git_add() {
    if ! is_exists 'git'; then
        e_error '_fzf_git_add: git command not found'
        return 1
    fi

    if ! is_exists 'fzf'; then
        e_error '_fzf_git_add: fzf command not found'
        return 1
    fi

    git status --short | awk '{if (substr($0,2,1) !~ / /) print $0}' | \
    fzf --height 100% --prompt 'GIT ADD > ' --exit-0 \
        --preview "_fzf_preview_git_diff {}" \
        --preview-window=down:85%:wrap \
        --bind $(_fzf_preview_bind) | \
    awk '{
           if (substr($0,1,2) !~ /R/) {
             print $2
           } else {
             print $4
           }
         }' | \
    while read staged_file; do
        echo "Staged: ${staged_file}"
        git add "$staged_file"
    done
}

function _fzf_git_diff_including_staged() {
    if ! is_exists 'git'; then
        e_error '_fzf_git_diff_including_staged: git command not found'
        return 1
    fi

    if ! is_exists 'fzf'; then
        e_error '_fzf_git_diff_including_staged: fzf command not found'
        return 1
    fi

    git status --short | awk '{if(substr($0,1,2) != "??") print $0}' | \
    fzf --height 100% --exit-0 --no-multi --prompt 'GIT DIFFS > ' \
        --preview "_fzf_preview_git_diff_including_staged {}" \
        --preview-window=down:85%:wrap \
        --bind "$(_fzf_preview_bind),tab:toggle-preview" | \
    awk '{
           if (substr($0,1,2) !~ /R/) {
             print $2
           } else {
             print $4
           }
         }' | \
    xargs git diff --color=always | less -XFR
}

function _fzf_git_checkout() {
    if ! is_exists 'git'; then
        e_error '_fzf_git_checkout: git command not found'
        return 1
    fi

    if ! is_exists 'fzf'; then
        e_error '_fzf_git_checkout: fzf command not found'
        return 1
    fi

    git branch --all --color=always | grep -v HEAD | cut -c 3- | \
        fzf --no-multi --height 100% --prompt 'GIT CHECKOUT > ' \
            --preview "git log --color=always {}" \
            --preview-window=down:70%:wrap \
            --bind "$(_fzf_preview_bind),tab:toggle-preview" | \
        (read result; [ -n "$result" ] && git checkout "$result")
}

### fzf preview commands

function _fzf_preview_bind() {
    local bind="alt-j:preview-down,alt-k:preview-up,alt-d:preview-half-page-down,alt-u:preview-half-page-up"
    echo "$bind"
}

function _fzf_preview_git_show() {
    if ! is_exists 'git'; then
        e_error '_fzf_preview_git_show: git command not found'
        return 1
    fi

    local commit_id=$(echo -- "$@" | grep -o "[a-f0-9]\{7\}") \
    && git show --color=always "$commit_id"
}

function _fzf_preview_git_diff() {
    if ! is_exists 'git'; then
        e_error '_fzf_preview_git_diff: git command not found'
        return 1
    fi

    local git_status_short_format=$(echo "$@" | awk '{print substr($0,1,2)}')
    local git_index_status=$(echo "$git_status_short_format" | awk '{print substr($0,1,1)}')
    local git_workingtree_status=$(echo "$git_status_short_format" | awk '{print substr($0,2,1)}')
    local file=$(echo "$@" | awk '{print $2}')
    local rename_file=$(echo "$@" | awk '{print $4}')
    local red=$'\e[37;31m'
    local color_reset=$'\e[m'

    if [ "$git_status_short_format" == '??' ]; then
        echo "Untracked: ${file}"
        echo '----'
        if [ ! -d "$file" ]; then
            if is_exists 'bat'; then
                bat --plain --color=always "$file"
            else
                cat "$file"
            fi
        else
            ls -al --color=always "$file"
        fi
    else
        echo "$git_status_short_format" | grep R >/dev/null \
          && file="$rename_file"

        if [ "$git_workingtree_status" == 'D' ]; then
            echo "${red}deleted: ${file}${color_reset}"
        else
            git diff --color=always "$file"
        fi
    fi
}

function _fzf_preview_git_diff_including_staged() {
    if ! is_exists 'git'; then
        e_error '_fzf_preview_git_diff_including_staged: git command not found'
        return 1
    fi

    local git_status_short_format=$(echo "$@" | awk '{print substr($0,1,2)}')
    local git_index_status=$(echo "$git_status_short_format" | awk '{print substr($0,1,1)}')
    local git_workingtree_status=$(echo "$git_status_short_format" | awk '{print substr($0,2,1)}')
    local file=$(echo "$@" | awk '{print $2}')
    local rename_file=$(echo "$@" | awk '{print $4}')
    local staged_color=$'\e[37;42m' # backgound/green
    local not_staged_color=$'\e[37;41m' # background/red
    local green=$'\e[37;32m'
    local red=$'\e[37;31m'
    local color_reset=$'\e[m'

    echo "$@"
    echo

    if [ "$git_index_status" != ' ' ]; then
        echo ${staged_color}'<<<<<<<<<< STAGED <<<<<<<<<<'${color_reset}

        if [ "$git_index_status" == 'R' ]; then
            echo "${green}renamed: ${file} -> ${rename_file}${color_reset}"
            file="$rename_file"
            git diff --staged --color=always --diff-filter=R "$file"
        elif [ "$git_index_status" == 'D' ]; then
            echo "${green}deleted: ${file}${color_reset}"
        elif [ "$git_index_status" == 'A' ]; then
            echo "${green}new file: ${file}${color_reset}"
        else
            git diff --staged --color=always "$file"
        fi
        echo
    fi

    if [ "$git_workingtree_status" != ' ' ]; then
        echo ${not_staged_color}'>>>>>>>>>> NOT STAGED >>>>>>>>>>'${color_reset}

        if [ "$git_workingtree_status" == 'D' ]; then
            echo "${red}deleted: ${file}"
        else
            git diff --color=always "$file"
        fi
        echo
    fi
}

export -f _fzf_preview_git_show
export -f _fzf_preview_git_diff
export -f _fzf_preview_git_diff_including_staged