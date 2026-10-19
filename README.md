# Soberano Dotfiles

Arquitetura enxuta e de baixa latência para **CachyOS / Arch Linux** construída do zero sobre **Hyprland (Lua Nativo)**, **Wayle (`wayle-bin` em Rust/GTK4)**, **Matugen (`matugen-bin` Material Design 3)**, **Fuzzel** e **awww**.

## Stack Principal

| Componente | Binário | Papel |
| :--- | :--- | :--- |
| **Compositor** | `Hyprland` (`hyprland.lua`) | Gerenciador de janelas Wayland configurado 100% em Lua nativo (`1920x1080@144Hz`, VRR, Direct Scanout) |
| **Desktop Shell** | `wayle` (`wayle-bin`) | Barra, Centro de Notificações, OSD, Cava, Áudio, Rede, Clima e Integração Nativa com Matugen + awww |
| **Motor de Cores** | `matugen` (`matugen-bin`) | Extração Material Design 3 (`tonal-spot`, `vibrant`, `expressive`, `fidelity`, etc.) sincronizando Wayle, Hyprland, Kitty, Fuzzel, Btop e GTK3/4 |
| **App Launcher & Menus** | `fuzzel` | Launcher Wayland nativo em C (~3 MB RAM) estilizado dinamicamente pelo Matugen |
| **Wallpaper Engine** | `awww` (`awww-daemon`) | Transições suaves a 144 FPS controladas diretamente pelo Wayle (`~2.7 MB RAM`) |
| **Terminal & Monitor** | `kitty` + `btop` | Sincronizados em tempo real via `SIGUSR1` e templates Matugen |

## Estrutura do Repositório

```text
soberano-dotfiles/
├── config/
│   ├── hypr/               # Configuração modular em Lua nativo
│   ├── wayle/              # Configuração pura do Wayle (schema 0.7.0) + Matugen
│   ├── matugen/            # Templates Material Design 3 (Hyprland, Kitty, Fuzzel, Btop, GTK)
│   ├── fuzzel/             # Launcher Wayland ultraleve
│   ├── kitty/              # Terminal acelerado por GPU
│   ├── btop/               # Monitor de recursos com tema Matugen
│   ├── fastfetch/
│   ├── fish/
│   └── quickshell/         # Workspace Overview (Super + A)
├── scripts/
│   ├── WallpaperSelect.sh        # Seletor de Wallpaper + Matugen (Super + W / Super + Alt + W)
│   ├── MatugenSchemeSelect.sh    # Seletor de Esquema Material You (Super + Alt + B)
│   ├── WayleBarPresetSelect.sh   # Seletor de Layout Nativo do Wayle (Super + Ctrl + B)
│   ├── HyprAnimationsSelector.sh # Seletor de Perfis de Animação (Super + Alt + A)
│   ├── GameMode.sh               # Modo Competitivo Ryzen 9 9950X + NVIDIA (Super + G / F1)
│   ├── OverviewToggle.sh         # Expose de Workspaces (Super + A)
│   └── KeyBinds.sh               # HUD Visual de Atalhos (Super + K / Super + H)
├── wallpapers/
└── install.sh
```

## Atalhos Principais

* `SUPER + Return`: Terminal (`kitty`)
* `SUPER + D`: Launcher de Aplicativos (`fuzzel`)
* `SUPER + W`: Seletor de Wallpaper + Matugen
* `SUPER + ALT + W`: Wallpaper Aleatório + Matugen
* `SUPER + ALT + B`: Seletor de Esquema de Cores do Matugen (`tonal-spot`, `vibrant`, `expressive`, etc.)
* `SUPER + CTRL + B`: Seletor de Layout Nativo da Barra Wayle (Floating Pill, Block-Prefix, Full-Width, Bottom Dock, Icon-Square)
* `SUPER + ALT + A`: Seletor de Animações do Hyprland
* `SUPER + V`: Histórico de Clipboard (`cliphist` + `fuzzel`)
* `SUPER + G` / `SUPER + F1`: GameMode Extremo (CPU Performance + GPU Max Clock + Tearing ON)
* `SUPER + Z`: Painel de Configurações do Wayle
* `SUPER + A`: Visão Geral de Workspaces (`quickshell`)
* `SUPER + K` / `SUPER + H`: Cheat-Sheet Visual de Atalhos
