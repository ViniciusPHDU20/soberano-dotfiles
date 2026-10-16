#!/usr/bin/env bash
# ==================================================
#  GameMode Extreme - Low Latency & High Performance
#  Optimized for AMD Ryzen 9 9950X + NVIDIA RTX 3060 Ti
# ==================================================

SCRIPTSDIR="${HOME}/dotfiles/scripts"
[ -d "$SCRIPTSDIR" ] || SCRIPTSDIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"

STATE_FILE="/tmp/hypr_gamemode.state"

notify_msg() {
    local title="$1"
    local desc="$2"
    local urgency="${3:-normal}"
    notify-send -u "$urgency" -a "GameMode" "$title" "$desc" 2>/dev/null || true
}

if [ -f "$STATE_FILE" ]; then
    # =========================================================================
    # DESATIVAR GAME MODE (Restaurar Sistema)
    # =========================================================================
    rm -f "$STATE_FILE"

    # 1. CPU: Devolve o Ryzen 9 9950X para o perfil balanceado (amd_pstate)
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set balanced >/dev/null 2>&1 || true
    fi

    # 2. GPU: Devolve o PowerMizer da RTX 3060 Ti para adaptativo
    if command -v nvidia-settings >/dev/null 2>&1; then
        nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=0' >/dev/null 2>&1 || true
    fi

    # 3. Background: Retoma o hypridle se existir
    pkill -CONT -x hypridle 2>/dev/null || true

    # 4. Hyprland: Recarrega as configuracoes completas do Lua (animacoes, blur, sombras)
    hyprctl reload >/dev/null 2>&1

    # 5. Restaura o Wallpaper e daemons visuais
    if [ -f "$SCRIPTSDIR/WallpaperCmd.sh" ]; then
        . "$SCRIPTSDIR/WallpaperCmd.sh"
    fi
    if [ -x "${SCRIPTSDIR}/WallpaperDaemon.sh" ]; then
        "${SCRIPTSDIR}/WallpaperDaemon.sh" >/dev/null 2>&1 &
    fi
    sleep 0.1
    if [ -x "${SCRIPTSDIR}/WallustSwww.sh" ]; then
        "${SCRIPTSDIR}/WallustSwww.sh" >/dev/null 2>&1 &
    fi
    if [ -x "${SCRIPTSDIR}/Refresh.sh" ]; then
        "${SCRIPTSDIR}/Refresh.sh" >/dev/null 2>&1 &
    fi

    notify_msg "🚀 GameMode: DESATIVADO" "CPU Balanced • GPU Auto • Visual e Wallpapers Restaurados" "normal"
    exit 0
else
    # =========================================================================
    # ATIVAR GAME MODE (Modo Competitivo / Desempenho Maximo)
    # =========================================================================
    touch "$STATE_FILE"

    # 1. CPU: Trava o Ryzen 9 9950X no perfil PERFORMANCE (Sem drop de clock / sem micro-stutter)
    if command -v powerprofilesctl >/dev/null 2>&1; then
        powerprofilesctl set performance >/dev/null 2>&1 || true
    fi

    # 2. GPU: Trava a RTX 3060 Ti no modo PREFER MAXIMUM PERFORMANCE (1)
    if command -v nvidia-settings >/dev/null 2>&1; then
        nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=1' >/dev/null 2>&1 || true
    fi

    # 3. Background: Pausa hypridle (tela nunca desliga no meio do jogo)
    pkill -STOP -x hypridle 2>/dev/null || true

    # 4. Background: Mata o daemon do wallpaper (economiza VRAM e ciclos de GPU)
    if [ -f "$SCRIPTSDIR/WallpaperCmd.sh" ]; then
        . "$SCRIPTSDIR/WallpaperCmd.sh"
        [ -n "$WWW_CMD" ] && "$WWW_CMD" kill >/dev/null 2>&1 || true
    fi
    pkill -x swww-daemon 2>/dev/null || true

    # 5. Hyprland: Desativa tudo que gera overhead de composicao e ativa menor latencia
    hyprctl eval "hl.config({ 
        animations = { enabled = false },
        decoration = { 
            shadow = { enabled = false }, 
            blur = { enabled = false }, 
            rounding = 0 
        },
        general = { 
            gaps_in = 0, 
            gaps_out = 0, 
            border_size = 1,
            allow_tearing = true
        },
        misc = {
            vfr = false
        }
    })" >/dev/null 2>&1

    # Garante opacidade 100% direta em todas as janelas (zero alpha blending)
    hyprctl eval "hl.window_rule({ name = 'gamemode-opacity', match = { class = '.*' }, opacity = 1.0 })" >/dev/null 2>&1

    notify_msg "⚡ GameMode: ATIVADO" "CPU Performance • GPU Max Clock • Tearing ON • Efeitos OFF" "low"
    exit 0
fi
