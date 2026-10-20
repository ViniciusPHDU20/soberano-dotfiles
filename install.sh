#!/usr/bin/env bash
# ==============================================================================
# Soberano Dotfiles Installer & Hardware Prober
# Architected for Arch Linux / CachyOS (Minimal TTY or Post-Installation)
# Stack: Hyprland (Native Lua) + Wayle (Rust) + Matugen + Fuzzel + awww + Pipewire
# ==============================================================================
set -euo pipefail

# Colors
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_GREEN="\033[1;32m"
C_BLUE="\033[1;34m"
C_YELLOW="\033[1;33m"
C_RED="\033[1;31m"
C_CYAN="\033[1;36m"

info()    { printf "${C_BLUE}::${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$*"; }
success() { printf "${C_GREEN}✓${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$*"; }
warn()    { printf "${C_YELLOW}⚠${C_RESET} %s\n" "$*"; }
error()   { printf "${C_RED}✗${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$*"; exit 1; }

# 1. Safety Checks
if [ "$EUID" -eq 0 ]; then
    error "Este instalador NÃO deve ser executado diretamente como root. Execute como seu usuário normal com permissões sudo."
fi

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

clear 2>/dev/null || true
cat << "EOF"
  ____       _                               
 / ___|  ___ | |__   ___ _ __ __ _ _ __   ___  
 \___ \ / _ \| '_ \ / _ \ '__/ _` | '_ \ / _ \ 
  ___) | (_) | |_) |  __/ | | (_| | | | | (_) |
 |____/ \___/|_.__/ \___|_|  \__,_|_| |_|\___/ 
      Dotfiles & Hardware Adaptation Suite
EOF

printf "\n"
info "Verificando privilégios sudo..."
sudo -v
# Keep sudo alive during script execution
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# 2. Hardware Detection Engine
info "Analisando hardware da máquina..."
HAS_NVIDIA=false
HAS_AMD_GPU=false
HAS_INTEL_GPU=false
IS_LAPTOP=false
IS_VM=false

# Check PCI devices
if command -v lspci >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm pciutils >/dev/null 2>&1; then
    PCI_DISPLAYS=$(lspci 2>/dev/null | grep -iE "(vga|3d|display)" || true)
    if echo "$PCI_DISPLAYS" | grep -qi "nvidia"; then
        HAS_NVIDIA=true
    fi
    if echo "$PCI_DISPLAYS" | grep -qiE "(amd|radeon|ati)"; then
        HAS_AMD_GPU=true
    fi
    if echo "$PCI_DISPLAYS" | grep -qi "intel"; then
        HAS_INTEL_GPU=true
    fi
    if echo "$PCI_DISPLAYS" | grep -qiE "(vmware|virtualbox|qemu|virtio|bochs)"; then
        IS_VM=true
    fi
fi

# Detect chassis / battery
if ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
    IS_LAPTOP=true
fi

printf "${C_CYAN}┌── Diagnóstico de Hardware detectado:${C_RESET}\n"
printf "${C_CYAN}│${C_RESET} • GPU NVIDIA:      %s\n" "$([ "$HAS_NVIDIA" = true ] && echo -e "${C_GREEN}Sim${C_RESET}" || echo "Não")"
printf "${C_CYAN}│${C_RESET} • GPU AMD:         %s\n" "$([ "$HAS_AMD_GPU" = true ] && echo -e "${C_GREEN}Sim${C_RESET}" || echo "Não")"
printf "${C_CYAN}│${C_RESET} • GPU Intel:       %s\n" "$([ "$HAS_INTEL_GPU" = true ] && echo -e "${C_GREEN}Sim${C_RESET}" || echo "Não")"
printf "${C_CYAN}│${C_RESET} • Form-factor:     %s\n" "$([ "$IS_LAPTOP" = true ] && echo -e "${C_YELLOW}Notebook/Laptop${C_RESET}" || echo "Desktop")"
printf "${C_CYAN}│${C_RESET} • Máquina Virtual: %s\n" "$([ "$IS_VM" = true ] && echo -e "${C_YELLOW}Sim${C_RESET}" || echo "Não")"
printf "${C_CYAN}└──${C_RESET}\n\n"

# 3. Pacotes Base e Ferramentas de Compilação
info "[1/6] Sincronizando pacotes essenciais do sistema..."
BASE_PKGS=(
    base-devel
    git
    curl
    wget
    jq
    pciutils
)
sudo pacman -S --needed --noconfirm "${BASE_PKGS[@]}"

# 4. Bootstrap do AUR Helper (caso esteja em Arch Minimal)
info "[2/6] Verificando AUR Helper (yay/paru)..."
AUR_CMD=""
if command -v yay >/dev/null 2>&1; then
    AUR_CMD="yay"
elif command -v paru >/dev/null 2>&1; then
    AUR_CMD="paru"
else
    info "Nenhum AUR helper encontrado. Instalando 'yay-bin' automaticamente..."
    TMP_YAY=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$TMP_YAY"
    (cd "$TMP_YAY" && makepkg -si --noconfirm)
    rm -rf "$TMP_YAY"
    AUR_CMD="yay"
    success "'yay-bin' instalado com sucesso!"
fi

# 5. Instalação Dinâmica de Drivers de Vídeo
info "[3/6] Instalando drivers gráficos e aceleração de vídeo..."
GPU_PKGS=()

if [ "$HAS_NVIDIA" = true ]; then
    info "Adicionando stack NVIDIA com suporte egl-wayland..."
    # If on CachyOS, prefer its optimized packages if available, otherwise standard Arch
    GPU_PKGS+=(
        nvidia-utils
        lib32-nvidia-utils
        egl-wayland
    )
    # Install DKMS driver if no nvidia driver exists
    if ! pacman -Q nvidia >/dev/null 2>&1 && ! pacman -Q nvidia-dkms >/dev/null 2>&1 && ! pacman -Q nvidia-open >/dev/null 2>&1; then
        GPU_PKGS+=(nvidia-dkms)
    fi
fi

if [ "$HAS_AMD_GPU" = true ]; then
    info "Adicionando stack Vulkan e Mesa para AMD..."
    GPU_PKGS+=(
        mesa
        vulkan-radeon
        lib32-mesa
        lib32-vulkan-radeon
        libva-mesa-driver
    )
fi

if [ "$HAS_INTEL_GPU" = true ]; then
    info "Adicionando stack Vulkan e VA-API para Intel..."
    GPU_PKGS+=(
        mesa
        vulkan-intel
        intel-media-driver
        libva-intel-driver
    )
fi

if [ "$IS_VM" = true ]; then
    info "Adicionando drivers gráficos para ambiente virtualizado..."
    GPU_PKGS+=(
        mesa
        xf86-video-vmware
    )
fi

if [ ${#GPU_PKGS[@]} -gt 0 ]; then
    sudo pacman -S --needed --noconfirm "${GPU_PKGS[@]}"
fi

# 6. Wayland, Hyprland, Áudio e Fontes
info "[4/6] Instalando Hyprland, Portais, Áudio Pipewire e Fontes..."
SYSTEM_STACK=(
    # Compositor & Portals
    hyprland
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    qt5-wayland
    qt6-wayland
    polkit
    hyprpolkitagent

    # Audio Engine
    pipewire
    pipewire-pulse
    pipewire-alsa
    pipewire-jack
    wireplumber
    playerctl
    pavucontrol

    # Nerd Fonts & Icons
    ttf-jetbrains-mono-nerd
    ttf-meslo-nerd
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    otf-font-awesome

    # Utilities & Shell Stack
    kitty
    btop
    fastfetch
    fish
    awww
    fuzzel
    cliphist
    wl-clipboard
    grim
    slurp
    hyprpicker
    brightnessctl
    libnotify
    imagemagick
    python
    python-gobject
)
sudo pacman -S --needed --noconfirm "${SYSTEM_STACK[@]}"

# 7. Pacotes AUR (Wayle & Matugen)
info "[5/6] Instalando Wayle Shell e Theming Engine (AUR)..."
AUR_PKGS=(
    wayle-bin
    matugen-bin
)
$AUR_CMD -S --needed --noconfirm "${AUR_PKGS[@]}"

# 8. Geração da Camada de Hardware no Hyprland (`config/hardware.lua`)
info "[6/6] Gerando diretivas de hardware personalizadas para esta máquina..."
mkdir -p "$DOTFILES_DIR/config/hypr/config"

HW_LUA="$DOTFILES_DIR/config/hypr/config/hardware.lua"
cat > "$HW_LUA" << LUA_EOF
-- ==============================================================================
-- Soberano Hyprland - Hardware Adaptation Layer
-- Auto-generated by install.sh based on detected GPU and chassis
-- ==============================================================================

-- Universal Wayland Environment
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
LUA_EOF

if [ "$HAS_NVIDIA" = true ]; then
    cat >> "$HW_LUA" << LUA_EOF

-- Dedicated NVIDIA Environment & Renderer
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")
hl.config({
    cursor = {
        no_hardware_cursors = false,
    }
})
LUA_EOF
fi

if [ "$HAS_AMD_GPU" = true ] && [ "$HAS_NVIDIA" = false ]; then
    cat >> "$HW_LUA" << LUA_EOF

-- AMD Radeon Environment
hl.env("LIBVA_DRIVER_NAME", "radeonsi")
hl.env("VDPAU_DRIVER", "radeonsi")
LUA_EOF
fi

if [ "$HAS_INTEL_GPU" = true ] && [ "$HAS_NVIDIA" = false ]; then
    cat >> "$HW_LUA" << LUA_EOF

-- Intel Graphics Environment
hl.env("LIBVA_DRIVER_NAME", "iHD")
LUA_EOF
fi

if [ "$IS_LAPTOP" = true ]; then
    cat >> "$HW_LUA" << LUA_EOF

-- Laptop Touchpad Gestures
hl.config({
    input = {
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
        }
    },
    gestures = {
        workspace_swipe = true,
        workspace_swipe_fingers = 3,
    }
})
LUA_EOF
fi

success "hardware.lua gerado com sucesso!"

# 9. Vinculação de Configurações (Symlinks com Backup Seguro)
info "Vinculando diretórios em ${CONFIG_DIR}..."
mkdir -p "$CONFIG_DIR" "$CONFIG_DIR/gtk-3.0" "$CONFIG_DIR/gtk-4.0"
chmod +x "$DOTFILES_DIR"/scripts/*.sh "$DOTFILES_DIR"/scripts/*.py 2>/dev/null || true

CONFIGS=(
    hypr
    wayle
    matugen
    fuzzel
    kitty
    btop
    fastfetch
    fish
    quickshell
)

for dir in "${CONFIGS[@]}"; do
    target="${CONFIG_DIR}/${dir}"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        mv "$target" "${target}.bak.$(date +%s)"
    fi
    rm -f "$target"
    ln -sfnT "${DOTFILES_DIR}/config/${dir}" "$target"
    printf "   ${C_CYAN}→${C_RESET} %s -> %s\n" "$target" "${DOTFILES_DIR}/config/${dir}"
done

# 10. Ativação de Serviços de Usuário
info "Configurando serviços systemd do usuário..."
systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service >/dev/null 2>&1 || true
systemctl --user enable --now wayle.service >/dev/null 2>&1 || true

# 11. Finalização
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    info "Sessão do Hyprland ativa detectada! Aplicando configurações em tempo real..."
    pgrep -x awww-daemon >/dev/null 2>&1 || (awww-daemon >/dev/null 2>&1 & sleep 0.4)
    "${DOTFILES_DIR}/scripts/WallpaperSelect.sh" --restore >/dev/null 2>&1 || true
    hyprctl reload >/dev/null 2>&1 || true
    systemctl --user restart wayle.service >/dev/null 2>&1 || true
fi

printf "\n"
success "================================================================"
success "   INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
success "================================================================"
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    printf "${C_BOLD}Para iniciar sua interface gráfica completa agora mesmo:${C_RESET}\n"
    printf "   ${C_GREEN}Hyprland${C_RESET}\n\n"
    printf "Ou faça login via seu Display Manager (SDDM/GDM/Greetd).\n"
else
    printf "${C_BOLD}Todas as configurações e o Wayle foram atualizados ao vivo!${C_RESET}\n"
fi
