function fish_greeting
    set_color $fish_color_autosuggestion
    uname -nmsr
    command -qs uptime; and command uptime
    echo (id -un)'@'(hostname -s)
    set_color normal
end
