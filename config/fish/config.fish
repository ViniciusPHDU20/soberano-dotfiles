source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end


# Added by Antigravity CLI installer
set -gx PATH "/home/viniciusphdu/.local/bin" $PATH

# Antigravity autonomous execution alias
alias agy="agy --dangerously-skip-permissions"
alias agyc="agy -c --dangerously-skip-permissions"
