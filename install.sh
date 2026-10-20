#!/usr/bin/env bash
# ==============================================================================
# Soberano Dotfiles Installer & Hardware Prober
# Architected for Arch Linux / CachyOS (Minimal TTY or Post-Installation)
# Inspired by Sovereign Gentoo Install (dialog TUI + Auto-Prober)
# Stack: Hyprland (Native Lua) + Wayle (Rust) + Matugen + Fuzzel + awww + Pipewire
# ==============================================================================
set -euo pipefail

BACKTITLE="Soberano Edition — Hyprland & Wayle Desktop Installer"

# Colors for CLI fallback
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

# Check dry-run / test mode
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run|--test|-t)
            DRY_RUN=true
            ;;
    esac
done

# Check interactive mode
INTERACTIVE=true
if [ ! -t 0 ] || [ "${1:-}" = "--auto" ] || [ "${1:-}" = "-y" ] || [ "${1:-}" = "--non-interactive" ]; then
    INTERACTIVE=false
fi

if [ "$DRY_RUN" = true ]; then
    BACKTITLE="Soberano Edition — Modo de Simulação / Teste (Dry-Run)"
    info "${C_YELLOW}MODO DE SIMULAÇÃO ATIVO (--dry-run): Nenhum pacote ou arquivo será alterado.${C_RESET}"
else
    # Ensure sudo credentials
    info "Verificando privilégios sudo..."
    sudo -v
    # Keep sudo alive
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
fi

# Ensure dialog & pciutils are available before UI (if sudo available and not dry-run)
if [ "$DRY_RUN" = false ]; then
    if ! command -v dialog >/dev/null 2>&1 || ! command -v lspci >/dev/null 2>&1; then
        info "Instalando pré-requisitos para a interface (dialog, pciutils)..."
        sudo pacman -S --needed --noconfirm dialog pciutils >/dev/null 2>&1 || true
    fi
fi

# 2. Hardware Detection Engine
info "Analisando hardware da máquina..."
RAW_CPU=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs 2>/dev/null || echo "Processador Desconhecido")
CPU_MODEL=$(echo "$RAW_CPU" | sed -E "s/ [0-9]+-Core Processor//; s/ Processor//; s/ CPU//; s/@.*//" | xargs)
CPU_CORES=$(nproc --all 2>/dev/null || echo 4)
RAM_GB=$(grep MemTotal /proc/meminfo | awk '{printf "%.1f GB", $2/1024/1024}' 2>/dev/null || echo "4.0 GB")

HAS_NVIDIA=false
HAS_AMD_GPU=false
HAS_INTEL_GPU=false
IS_LAPTOP=false
IS_VM=false

NVIDIA_NAME=""
AMD_NAME=""
INTEL_NAME=""
GPU_DESC=""

get_clean_gpu_name() {
    local raw="$1"
    local m
    m=$(echo "$raw" | grep -oP "\[\K[^\]]+(?=\])" 2>/dev/null | tail -1 | sed -E "s/ Lite Hash Rate//; s/ LHR//" | xargs)
    if [ -z "$m" ]; then
        m=$(echo "$raw" | sed -E "s/.*: //; s/ \(rev .*\)//" | xargs)
    fi
    echo "$m"
}

if command -v lspci >/dev/null 2>&1; then
    PCI_DISPLAYS=$(lspci 2>/dev/null | grep -iE "(vga|3d|display)" || true)
    if echo "$PCI_DISPLAYS" | grep -qi "\bnvidia\b"; then
        HAS_NVIDIA=true
        RAW_NV=$(echo "$PCI_DISPLAYS" | grep -i "\bnvidia\b" | head -1)
        NVIDIA_NAME="NVIDIA $(get_clean_gpu_name "$RAW_NV")"
        GPU_DESC+="$NVIDIA_NAME "
    fi
    if echo "$PCI_DISPLAYS" | grep -qiE "\b(amd|radeon|amdgpu)\b|advanced micro devices"; then
        HAS_AMD_GPU=true
        RAW_AMD=$(echo "$PCI_DISPLAYS" | grep -iE "\b(amd|radeon|amdgpu)\b|advanced micro devices" | head -1)
        AMD_NAME="AMD $(get_clean_gpu_name "$RAW_AMD")"
        [ "$HAS_NVIDIA" = true ] && AMD_NAME+=" (iGPU)"
        GPU_DESC+="$AMD_NAME "
    fi
    if echo "$PCI_DISPLAYS" | grep -qi "\bintel\b"; then
        HAS_INTEL_GPU=true
        RAW_INTEL=$(echo "$PCI_DISPLAYS" | grep -i "\bintel\b" | head -1)
        INTEL_NAME="Intel $(get_clean_gpu_name "$RAW_INTEL")"
        [ "$HAS_NVIDIA" = true ] && INTEL_NAME+=" (iGPU)"
        GPU_DESC+="$INTEL_NAME "
    fi
    if echo "$PCI_DISPLAYS" | grep -qiE "(vmware|virtualbox|qemu|virtio|bochs)"; then
        IS_VM=true
        GPU_DESC="Ambiente Virtualizado (VM) "
    fi
fi
[ -z "$GPU_DESC" ] && GPU_DESC="Vídeo Padrão Genérico"

if ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
    IS_LAPTOP=true
fi

# Defaults
CHOSEN_GPU="AUTO"
INSTALL_GAMING=false
INSTALL_SHADERS=true
ENABLE_TOUCHPAD="$IS_LAPTOP"
CHOSEN_PRESET="10"

# Setup High-Contrast Dark Theme for Dialog (Eliminates low-contrast purple/lavender)
TMP_DIALOGRC=$(mktemp)
cat << 'EOF' > "$TMP_DIALOGRC"
use_shadow = OFF
use_colors = ON
screen_color = (WHITE,BLACK,OFF)
shadow_color = (BLACK,BLACK,OFF)
dialog_color = (WHITE,BLACK,OFF)
title_color = (YELLOW,BLACK,ON)
border_color = (WHITE,BLACK,ON)
button_active_color = (BLACK,GREEN,ON)
button_inactive_color = (WHITE,BLACK,OFF)
button_key_active_color = (BLACK,GREEN,ON)
button_key_inactive_color = (YELLOW,BLACK,OFF)
button_label_active_color = (BLACK,GREEN,ON)
button_label_inactive_color = (WHITE,BLACK,OFF)
inputbox_color = (WHITE,BLACK,OFF)
inputbox_border_color = (WHITE,BLACK,ON)
searchbox_color = (WHITE,BLACK,OFF)
searchbox_title_color = (YELLOW,BLACK,ON)
searchbox_border_color = (WHITE,BLACK,ON)
position_indicator_color = (YELLOW,BLACK,ON)
menubox_color = (WHITE,BLACK,OFF)
menubox_border_color = (WHITE,BLACK,ON)
item_color = (WHITE,BLACK,OFF)
item_selected_color = (BLACK,GREEN,ON)
tag_color = (YELLOW,BLACK,ON)
tag_selected_color = (BLACK,GREEN,ON)
tag_key_color = (YELLOW,BLACK,OFF)
tag_key_selected_color = (BLACK,GREEN,ON)
check_color = (WHITE,BLACK,OFF)
check_selected_color = (BLACK,GREEN,ON)
uarrow_color = (GREEN,BLACK,ON)
darrow_color = (GREEN,BLACK,ON)
itemhelp_color = (WHITE,BLACK,OFF)
form_active_text_color = (BLACK,GREEN,ON)
form_text_color = (WHITE,BLACK,OFF)
form_item_readonly_color = (WHITE,BLACK,OFF)
gauge_color = (WHITE,BLACK,ON)
border2_color = (WHITE,BLACK,ON)
searchbox_border2_color = (WHITE,BLACK,ON)
menubox_border2_color = (WHITE,BLACK,ON)
EOF
export DIALOGRC="$TMP_DIALOGRC"
trap 'rm -f "$TMP_DIALOGRC"' EXIT

# 3. Interactive Dialog Interface (Gentoo-Style)
if [ "$INTERACTIVE" = true ] && command -v dialog >/dev/null 2>&1; then
    # Screen 1: Welcome & Hardware Diagnosis
    DIAG_MSG="\Zb\Z2Diagnóstico da máquina concluído com sucesso!\ZB\Zn\n\n"
    DIAG_MSG+=" • \Zb\Z7Processador:\Zn     $CPU_MODEL (${CPU_CORES}t)\n"
    DIAG_MSG+=" • \Zb\Z7Memória RAM:\Zn     $RAM_GB\n"
    if [ -n "$NVIDIA_NAME" ]; then
        DIAG_MSG+=" • \Zb\Z7GPU Dedicada:\Zn   $NVIDIA_NAME\n"
    fi
    if [ -n "$AMD_NAME" ]; then
        DIAG_MSG+=" • \Zb\Z7GPU Integrada:\Zn  $AMD_NAME\n"
    fi
    if [ -n "$INTEL_NAME" ]; then
        DIAG_MSG+=" • \Zb\Z7GPU Integrada:\Zn  $INTEL_NAME\n"
    fi
    if [ "$IS_VM" = true ]; then
        DIAG_MSG+=" • \Zb\Z7Aceleração:\Zn     Ambiente Virtual (VM)\n"
    fi
    DIAG_MSG+=" • \Zb\Z7Tipo de Máquina:\Zn $([ "$IS_LAPTOP" = true ] && echo "Notebook (Touchpad)" || echo "Desktop")\n"
    DIAG_MSG+=" • \Zb\Z7Virtualização:\Zn   $([ "$IS_VM" = true ] && echo "Sim (VM)" || echo "Não (Físico)")\n\n"
    DIAG_MSG+="Pressione \Zb\Z2<OK>\ZB\Zn para avançar para o instalador."

    dialog --colors --cr-wrap \
        --backtitle "$BACKTITLE" \
        --title "\Zb\Z3 Diagnóstico de Hardware Detectado \ZB\Zn" \
        --msgbox "$(printf "%b" "$DIAG_MSG")" \
        16 74

    # Screen 2: GPU Drivers Selection
    GPU_RADIO=(
        "NVIDIA_HYBRID" "Híbrido NVIDIA + AMD/Intel (iGPU + dGPU)" "$([ "$HAS_NVIDIA" = true ] && [ "$HAS_AMD_GPU" = true -o "$HAS_INTEL_GPU" = true ] && echo "on" || echo "off")"
        "NVIDIA_ONLY"   "Apenas NVIDIA proprietário (nvidia-utils + dkms)" "$([ "$HAS_NVIDIA" = true ] && [ "$HAS_AMD_GPU" = false -a "$HAS_INTEL_GPU" = false ] && echo "on" || echo "off")"
        "AMD_ONLY"      "Apenas AMD (Mesa + Vulkan-Radeon + VA-API)" "$([ "$HAS_NVIDIA" = false ] && [ "$HAS_AMD_GPU" = true ] && echo "on" || echo "off")"
        "INTEL_ONLY"    "Apenas Intel (Mesa + Vulkan-Intel + Media Driver)" "$([ "$HAS_NVIDIA" = false ] && [ "$HAS_INTEL_GPU" = true ] && echo "on" || echo "off")"
        "VM"            "Ambiente Virtualizado (VMware / QEMU / VirGL)" "$([ "$IS_VM" = true ] && echo "on" || echo "off")"
        "GENERIC"       "Drivers Genéricos Mesa / Compatibilidade" "off"
    )

    CHOSEN_GPU=$(dialog --colors \
        --backtitle "$BACKTITLE" \
        --title "\Zb\Z3 Seleção de Drivers de Vídeo \ZB\Zn" \
        --radiolist \
"Selecione o perfil de aceleração gráfica para sua placa de vídeo:\n(Pré-selecionado de acordo com seu hardware)" \
        16 74 6 \
        "${GPU_RADIO[@]}" \
        3>&1 1>&2 2>&3) || CHOSEN_GPU="AUTO"

    # Screen 3: Optional Components Checklist
    COMPONENTS=$(dialog --colors \
        --backtitle "$BACKTITLE" \
        --title "\Zb\Z3 Componentes e Módulos do Sistema \ZB\Zn" \
        --checklist \
"Escolha os pacotes e recursos que deseja instalar no seu sistema:\nUse [Espaço] para marcar/desmarcar e [Enter] para confirmar." \
        16 74 6 \
        "CORE"     "Hyprland Lua + Wayle Shell + Matugen Engine" "on" \
        "AUDIO"    "Pipewire + PulseAudio + Wireplumber + Pavucontrol" "on" \
        "FONTS"    "Nerd Fonts (JetBrainsMono, Meslo) + Emojis" "on" \
        "TOOLS"    "Kitty + Btop + Fastfetch + Fish + Grim/Slurp" "on" \
        "SHADERS"  "Shaders GLSL para Hyprland (Super + Alt + S)" "$([ "$INSTALL_SHADERS" = true ] && echo "on" || echo "off")" \
        "GAMING"   "Stack Gamer (Steam, Gamemode, MangoHud, Wine)" "$([ "$INSTALL_GAMING" = true ] && echo "on" || echo "off")" \
        3>&1 1>&2 2>&3) || true

    if echo "$COMPONENTS" | grep -qw "GAMING"; then INSTALL_GAMING=true; fi
    if echo "$COMPONENTS" | grep -qw "SHADERS"; then INSTALL_SHADERS=true; else INSTALL_SHADERS=false; fi

    # Screen 4: Initial Wayle Bar Layout Selection
    PRESET_CHOICES=(
        "10" "Stealth Zen (Workspaces + App + Bandeja + Relógio)" "on"
        "1"  "Floating Pill Top (Pílula Flutuante Suave • Gaps 10/8)" "off"
        "2"  "Block-Prefix Chips (Padrão Wayle Nativo • Gaps 8/8)" "off"
        "3"  "Full-Width Top Blade (Lâmina Cyberpunk • Gaps 2px)" "off"
        "4"  "Floating macOS Dock (Dock Inferior Flutuante)" "off"
        "5"  "Split Dual-Wings HUD (Asas nos Cantos • Centro Livre)" "off"
        "6"  "Dynamic Island Capsule (Cápsula Central • Round 14px)" "off"
        "7"  "Island Floating Clusters (Ilhas Transparentes)" "off"
        "8"  "Audiophile Soundstage (Foco CAVA & Player Musical)" "off"
        "9"  "Glassmorphism Frost (Vidro Fosco Translúcido 50%)" "off"
    )

    CHOSEN_PRESET=$(dialog --colors \
        --backtitle "$BACKTITLE" \
        --title "\Zb\Z3 Layout Inicial da Barra Wayle \ZB\Zn" \
        --radiolist \
"Escolha o layout e geometria visual da barra para iniciar seu desktop:\n(Você poderá trocar a qualquer momento usando Super + Ctrl + B)" \
        18 74 10 \
        "${PRESET_CHOICES[@]}" \
        3>&1 1>&2 2>&3) || CHOSEN_PRESET="10"

    # Screen 5: Final Confirmation
    CONFIRM_MSG="Deseja iniciar a instalação com as seguintes opções?\n\n"
    CONFIRM_MSG+=" • \Zb\Z7Perfil GPU:\Zn        $CHOSEN_GPU\n"
    CONFIRM_MSG+=" • \Zb\Z7Preset Wayle:\Zn      Preset $CHOSEN_PRESET\n"
    CONFIRM_MSG+=" • \Zb\Z7Stack Gamer:\Zn       $([ "$INSTALL_GAMING" = true ] && echo "Sim" || echo "Não")\n"
    CONFIRM_MSG+=" • \Zb\Z7Shaders GLSL:\Zn      $([ "$INSTALL_SHADERS" = true ] && echo "Sim" || echo "Não")\n"
    CONFIRM_MSG+=" • \Zb\Z7Gestos Touchpad:\Zn   $([ "$ENABLE_TOUCHPAD" = true ] && echo "Ativo" || echo "Desativado")\n\n"

    if [ "$DRY_RUN" = true ]; then
        CONFIRM_MSG+="\Zb\Z3[MODO DE TESTE / DRY-RUN ATIVO]\ZB\Zn\nNenhum pacote será instalado e nenhuma alteração será feita."
    else
        CONFIRM_MSG+="Seus arquivos antigos terão backup automático antes da substituição."
    fi

    dialog --colors --cr-wrap \
        --backtitle "$BACKTITLE" \
        --title "\Zb\Z2 Confirmar Instalação \ZB\Zn" \
        --yesno "$(printf "%b" "$CONFIRM_MSG")" \
        16 74 || {
            dialog --clear; clear; echo "Instalação cancelada pelo usuário."; exit 0;
        }
    dialog --clear
fi

# Dry-run early exit (Safety lock: never modifies anything)
if [ "$DRY_RUN" = true ]; then
    if [ "$INTERACTIVE" = true ] && command -v dialog >/dev/null 2>&1; then
        REPORT_MSG="\Zb\Z2Simulação concluída com sucesso!\ZB\Zn\n\n"
        REPORT_MSG+="Aqui está o que o instalador realizaria na máquina real:\n\n"
        REPORT_MSG+=" • \Zb\Z7Perfil de GPU:\Zn       $CHOSEN_GPU\n"
        REPORT_MSG+=" • \Zb\Z7Stack de Drivers:\Zn    $([ "$CHOSEN_GPU" = "NVIDIA_HYBRID" -o "$CHOSEN_GPU" = "NVIDIA_ONLY" ] && echo "nvidia-utils, egl-wayland" || echo "mesa, vulkan")\n"
        REPORT_MSG+=" • \Zb\Z7Stack Gráfica:\Zn       Hyprland + Wayle + Matugen + Pipewire + Fontes\n"
        REPORT_MSG+=" • \Zb\Z7Layout da Barra:\Zn     Preset $CHOSEN_PRESET\n"
        REPORT_MSG+=" • \Zb\Z7Stack Gamer:\Zn         $([ "$INSTALL_GAMING" = true ] && echo "Steam, Gamemode, Mangohud, Wine" || echo "Ignorado")\n"
        REPORT_MSG+=" • \Zb\Z7Shaders Hyprland:\Zn    $([ "$INSTALL_SHADERS" = true ] && echo "Ativados (Super + Alt + S)" || echo "Ignorado")\n"
        REPORT_MSG+=" • \Zb\Z7Vinculação Dotfiles:\Zn 9 diretórios em ~/.config (com backup preventivo)\n\n"
        REPORT_MSG+="\Zb\Z2Status do Sistema:\ZB\Zn 100% Intacto (Zero alterações realizadas).\n\n"
        REPORT_MSG+="Para aplicar a instalação real quando desejar, basta rodar:\n"
        REPORT_MSG+="   \Zb./install.sh\ZB"

        dialog --colors --cr-wrap \
            --backtitle "$BACKTITLE" \
            --title "\Zb\Z2 Relatório de Simulação (Dry-Run Concluído) \ZB\Zn" \
            --msgbox "$(printf "%b" "$REPORT_MSG")" \
            20 76
        dialog --clear
        clear
    else
        printf "\n"
        success "================================================================"
        success "   RELATÓRIO DE SIMULAÇÃO (DRY-RUN CONCLUÍDO)"
        success "================================================================"
        printf " • Perfil de GPU:     %s\n" "$CHOSEN_GPU"
        printf " • Preset Wayle:      Preset %s\n" "$CHOSEN_PRESET"
        printf " • Stack Gamer:       %s\n" "$([ "$INSTALL_GAMING" = true ] && echo "Sim" || echo "Não")"
        printf " • Shaders GLSL:      %s\n" "$([ "$INSTALL_SHADERS" = true ] && echo "Sim" || echo "Não")"
        printf " • Status:            100%% Intacto (Modo de teste)\n\n"
    fi
    exit 0
fi

clear 2>/dev/null || true
info "Iniciando processo de instalação do Soberano Dotfiles..."

# 4. Base Packages
info "[1/6] Sincronizando ferramentas essenciais..."
BASE_PKGS=(
    base-devel
    git
    curl
    wget
    jq
    pciutils
)
sudo pacman -S --needed --noconfirm "${BASE_PKGS[@]}"

# 5. AUR Helper Bootstrap (yay)
info "[2/6] Verificando AUR Helper (yay/paru)..."
AUR_CMD=""
if command -v yay >/dev/null 2>&1; then
    AUR_CMD="yay"
elif command -v paru >/dev/null 2>&1; then
    AUR_CMD="paru"
else
    info "Nenhum AUR helper encontrado. Compilando e instalando 'yay-bin' automaticamente..."
    TMP_YAY=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$TMP_YAY"
    (cd "$TMP_YAY" && makepkg -si --noconfirm)
    rm -rf "$TMP_YAY"
    AUR_CMD="yay"
    success "'yay-bin' instalado com sucesso!"
fi

# 6. GPU Packages based on selection or auto-probe
info "[3/6] Instalando drivers de vídeo e aceleração ($CHOSEN_GPU)..."
GPU_PKGS=()

case "$CHOSEN_GPU" in
    NVIDIA_HYBRID|NVIDIA_ONLY)
        GPU_PKGS+=(nvidia-utils lib32-nvidia-utils egl-wayland)
        if ! pacman -Q nvidia >/dev/null 2>&1 && ! pacman -Q nvidia-dkms >/dev/null 2>&1 && ! pacman -Q nvidia-open >/dev/null 2>&1; then
            GPU_PKGS+=(nvidia-dkms)
        fi
        if [ "$CHOSEN_GPU" = "NVIDIA_HYBRID" ]; then
            GPU_PKGS+=(mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon)
        fi
        ;;
    AMD_ONLY)
        GPU_PKGS+=(mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon libva-mesa-driver)
        ;;
    INTEL_ONLY)
        GPU_PKGS+=(mesa vulkan-intel intel-media-driver libva-intel-driver)
        ;;
    VM)
        GPU_PKGS+=(mesa xf86-video-vmware)
        ;;
    *)
        # Auto fallback
        if [ "$HAS_NVIDIA" = true ]; then
            GPU_PKGS+=(nvidia-utils lib32-nvidia-utils egl-wayland)
            if ! pacman -Q nvidia >/dev/null 2>&1 && ! pacman -Q nvidia-dkms >/dev/null 2>&1; then
                GPU_PKGS+=(nvidia-dkms)
            fi
        fi
        if [ "$HAS_AMD_GPU" = true ]; then
            GPU_PKGS+=(mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon)
        fi
        if [ "$HAS_INTEL_GPU" = true ]; then
            GPU_PKGS+=(mesa vulkan-intel intel-media-driver)
        fi
        ;;
esac

if [ ${#GPU_PKGS[@]} -gt 0 ]; then
    sudo pacman -S --needed --noconfirm "${GPU_PKGS[@]}"
fi

# 7. Desktop System Stack
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

if [ "$INSTALL_GAMING" = true ]; then
    info "Adicionando suite Gamer (Steam, Gamemode, Mangohud)..."
    SYSTEM_STACK+=(steam gamemode lib32-gamemode mangohud lib32-mangohud)
fi

sudo pacman -S --needed --noconfirm "${SYSTEM_STACK[@]}"

# 8. AUR Packages (Wayle & Matugen)
info "[5/6] Instalando Wayle Shell e Matugen (AUR)..."
AUR_PKGS=(
    wayle-bin
    matugen-bin
)
$AUR_CMD -S --needed --noconfirm "${AUR_PKGS[@]}"

# 9. Hardware Configuration Layer (`config/hardware.lua`)
info "[6/6] Gerando diretivas de hardware personalizadas..."
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

if [ "$HAS_NVIDIA" = true ] || [[ "$CHOSEN_GPU" =~ NVIDIA ]]; then
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

if [ "$ENABLE_TOUCHPAD" = true ]; then
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

# 10. Symlinks & Permissions
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

# 11. Apply Chosen Wayle Bar Preset
info "Aplicando preset selecionado ($CHOSEN_PRESET)..."
"$DOTFILES_DIR/scripts/WayleBarPresetSelect.sh" "$CHOSEN_PRESET" >/dev/null 2>&1 || true

# 12. User Services
info "Configurando serviços systemd do usuário..."
systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service >/dev/null 2>&1 || true
systemctl --user enable --now wayle.service >/dev/null 2>&1 || true

# 13. Live Session Reload
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    info "Sessão do Hyprland ativa detectada! Aplicando configurações em tempo real..."
    pgrep -x awww-daemon >/dev/null 2>&1 || (awww-daemon >/dev/null 2>&1 & sleep 0.4)
    "${DOTFILES_DIR}/scripts/WallpaperSelect.sh" --restore >/dev/null 2>&1 || true
    hyprctl reload >/dev/null 2>&1 || true
    systemctl --user restart wayle.service >/dev/null 2>&1 || true
fi

# 14. Finished Screen
if [ "$INTERACTIVE" = true ] && command -v dialog >/dev/null 2>&1; then
    dialog --colors \
        --backtitle "$BACKTITLE" \
        --title "\Zb\Z2 Instalação Concluída com Sucesso! \ZB\Zn" \
        --msgbox \
"\Zb\Z2O Soberano Dotfiles está pronto para uso!\ZB\Zn

\ZbPrincipais Atalhos:\Zn
 • \ZbSuper + Q:\Zn         Abrir Terminal Kitty
 • \ZbSuper + Espaço:\Zn    Lançador de Aplicativos (Fuzzel)
 • \ZbSuper + W:\Zn         Galeria de Wallpapers GTK4 (Cinema Studio)
 • \ZbSuper + Ctrl + B:\Zn  Seletor de Presets da Barra Wayle
 • \ZbSuper + Alt + S:\Zn   Alternar Shaders GLSL de Tela
 • \ZbSuper + M:\Zn         Cheat-Sheet de Teclas e Comandos

$([ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && echo "Para iniciar seu desktop agora mesmo, digite:\n   \Zb\Z2Hyprland\ZB\Zn" || echo "Sua sessão atual foi 100% atualizada sem reiniciar!")" \
        18 74
    dialog --clear
    clear
else
    printf "\n"
    success "================================================================"
    success "   INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
    success "================================================================"
    if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        printf "${C_BOLD}Para iniciar sua interface gráfica completa agora mesmo:${C_RESET}\n"
        printf "   ${C_GREEN}Hyprland${C_RESET}\n\n"
    else
        printf "${C_BOLD}Todas as configurações e o Wayle foram atualizados ao vivo!${C_RESET}\n"
    fi
fi
