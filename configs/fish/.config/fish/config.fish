if status is-interactive
    # Commands to run in interactive sessions can go here
    if type -q starship
        starship init fish | source
    end
    fish_config theme choose Dracula
end
