# Soberano Dotfiles — Hyprland-Dots + Wayle Edition

Porte completo do ecossistema **[JaKooLit / Hyprland-Dots](https://github.com/LinuxBeginnings/Hyprland-Dots) (v2.3.27.7)** reescrito para rodar sobre o **[Wayle](https://github.com/wayle-rs/wayle)** em **Rust + GTK4 + Relm4 + SCSS**, otimizado para **Arch / CachyOS (AMD Ryzen 9 9950X Zen 5 / x86-64-v4)**.

## 🚀 Arquitetura

- **Compositor:** [Hyprland](https://hypr.land) (Arquitetura modular nativa em Lua `configs/` + `UserConfigs/` + `lua/`)
- **Desktop Shell & Barra:** [Wayle](https://github.com/wayle-rs/wayle) (Shell unificada em Rust substituindo Waybar, SwayNC e SwayOSD)
- **Layouts Portados:** **47 layouts** do JaKooLit (`~/.config/wayle/layouts/`) — atalho `SUPER + ALT + B`
- **Estilos Visuais Portados:** **50 estilos SCSS + Wallust** (`~/.config/wayle/styles/` & `themes/`) — atalho `SUPER + CTRL + B`
- **Motor de Cores Dinâmicas:** [Wallust](https://codeberg.org/explosion-mental/wallust) integrado ao Wayle, Rofi, Kitty, Cava, Hyprland e Wlogout
- **Menus & Launcher:** Rofi Wayland (`~/.config/hypr/rofi/`) + Quickshell Overview
- **Terminal:** [Kitty](https://sw.kovidgoyal.net/kitty/) (170+ temas + sincronização Wallust)
- **Monitor:** 1920x1080 @ 144Hz (`DP-1`)

## 📦 Instalação / Restauração

```bash
cd ~/dotfiles
./install.sh
```
