-- Auto-start config
-- if you dont use UWSM add your auto start programs here, otherwise use XDG autostart https://wiki.archlinux.org/title/XDG_Autostart

hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("wayle")
    hl.exec_cmd("qs --log-rules qt.qpa.wayland.textinput.warning=false -c overview")
    -- hl.exec_cmd(os.getenv("HOME") .. "/dotfiles/scripts/DynamicThemeWatcher.sh")
    hl.exec_cmd("xhost +SI:localuser:root")
end)
