#!/usr/bin/env bash
# ==============================================================================
# Soberano Hardware Power & Performance Profile Engine
# Universal Dynamic Hardware Adaptation (AMD / Intel CPU • NVIDIA / AMD Radeon GPU)
#
# Profiles: eco | balanced | compute | game
# Usage:    soberano-power-profile.sh [--menu|--eco|--balanced|--compute|--game|
#                                      --toggle-eco|--status|--probe|--dry-run]
# ==============================================================================
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# Dry-run is resolved before the lib is sourced so every writer honours it.
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --dry-run|--dry) SOB_DRY_RUN=true ;;
        *) ARGS+=("$arg") ;;
    esac
done
export SOB_DRY_RUN
set -- ${ARGS[@]+"${ARGS[@]}"}

# shellcheck source=soberano-hw-lib.sh
. "${SCRIPTS_DIR}/soberano-hw-lib.sh"

STATE_FILE="$SOB_PROFILE_STATE"
GAME_STATE="${SOB_RUNTIME}/hypr_gamemode.state"

CPU_NAME=$(sob_cpu_name)
CPU_THREADS=$(sob_cpu_threads)
CPU_MIN_GHZ=$(sob_cpu_min_ghz)
CPU_MAX_GHZ=$(sob_cpu_max_ghz)

# -----------------------------------------------------------------------------
# State
# -----------------------------------------------------------------------------
get_current_profile() {
    if [ -f "$GAME_STATE" ]; then
        echo "game"
        return
    fi
    if [ -f "$STATE_FILE" ]; then
        local p
        p=$(cat "$STATE_FILE" 2>/dev/null || true)
        case "$p" in
            eco|balanced|compute|game) echo "$p"; return ;;
        esac
    fi
    echo "balanced"
}

set_profile_state() {
    [ "$SOB_DRY_RUN" = true ] && return 0
    printf '%s' "$1" > "$STATE_FILE" 2>/dev/null || true
}

notify() { # urgency summary body
    [ "$SOB_DRY_RUN" = true ] && return 0
    notify-send -u "$1" -a "Soberano Power" "$2" "$3" 2>/dev/null || true
}

exit_game_mode_if_active() {
    [ -f "$GAME_STATE" ] || return 0
    if [ "$SOB_DRY_RUN" = true ]; then
        printf '  [dry] GameMode.sh (desativar GameMode antes do perfil)\n' >&2
        return 0
    fi
    bash "${SCRIPTS_DIR}/GameMode.sh" >/dev/null 2>&1 || true
}

# -----------------------------------------------------------------------------
# GPU helpers
# -----------------------------------------------------------------------------
apply_gpu_eco() {
    if sob_nv_ok; then
        local lo hi
        lo=$(sob_nv_clk min); [ -z "$lo" ] && lo=210
        hi=450; [ "$hi" -lt "$lo" ] && hi=$((lo + 100))
        local pl; pl=$(sob_nv_pl min); [ -z "$pl" ] && pl=100
        sob_root "nvidia-smi -lgc ${lo},${hi} >/dev/null 2>&1 || true
nvidia-smi -pl ${pl} >/dev/null 2>&1 || true"
        command -v nvidia-settings >/dev/null 2>&1 && nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=0' >/dev/null 2>&1 || true
    fi
    sob_amd_gpu_ok && sob_root "$(sob_amd_gpu_snippet low)"
    return 0
}

apply_gpu_balanced() {
    if sob_nv_ok; then
        local pl; pl=$(sob_nv_pl max); [ -z "$pl" ] && pl=200
        sob_root "nvidia-smi -rgc >/dev/null 2>&1 || true
nvidia-smi -pl ${pl} >/dev/null 2>&1 || true"
        command -v nvidia-settings >/dev/null 2>&1 && nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=0' >/dev/null 2>&1 || true
    fi
    sob_amd_gpu_ok && sob_root "$(sob_amd_gpu_snippet auto)"
    return 0
}

apply_gpu_compute() {
    if sob_nv_ok; then
        local pl; pl=$(sob_nv_pl max); [ -z "$pl" ] && pl=200
        sob_root "nvidia-smi -rgc >/dev/null 2>&1 || true
nvidia-smi -pl ${pl} >/dev/null 2>&1 || true"
        command -v nvidia-settings >/dev/null 2>&1 && nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=1' >/dev/null 2>&1 || true
    fi
    sob_amd_gpu_ok && sob_root "$(sob_amd_gpu_snippet high)"
    return 0
}

# -----------------------------------------------------------------------------
# Profiles
# -----------------------------------------------------------------------------
apply_eco() {
    exit_game_mode_if_active
    sob_snapshot_limits

    local gov
    gov=$(sob_pick_governor eco)

    sob_root "$(sob_set_boost off)
$(sob_gov_snippet "$gov")
$(sob_epp_snippet power)
$(sob_floor_snippet)"

    sob_set_platform_profile power-saver
    apply_gpu_eco

    set_profile_state eco
    notify low "🌿 Perfil: ECO SILENCIOSO (${CPU_MIN_GHZ} GHz)" \
        "${CPU_NAME} travado a ${CPU_MIN_GHZ} GHz • GPU Fria / Min TDP • Zero Ruído"
}

apply_balanced() {
    exit_game_mode_if_active

    local gov
    gov=$(sob_pick_governor balanced)

    sob_root "$(sob_set_boost on)
$(sob_restore_snippet)
$(sob_gov_snippet "$gov")
$(sob_epp_snippet balance_performance)"

    sob_set_platform_profile balanced
    apply_gpu_balanced

    sob_root "sysctl -w vm.swappiness=60 >/dev/null 2>&1 || true
sysctl -w vm.compaction_proactiveness=20 >/dev/null 2>&1 || true
sysctl -w vm.stat_interval=1 >/dev/null 2>&1 || true"

    set_profile_state balanced
    notify normal "⚖️ Perfil: BALANCEADO" \
        "${CPU_NAME} Dinâmico (${CPU_MIN_GHZ}–${CPU_MAX_GHZ} GHz) • GPU Auto • Desktop Suave"
}

apply_compute() {
    exit_game_mode_if_active

    local gov
    gov=$(sob_pick_governor compute)

    sob_root "$(sob_set_boost on)
$(sob_ceiling_snippet)
$(sob_gov_snippet "$gov")
$(sob_epp_snippet performance)"

    sob_set_platform_profile performance
    apply_gpu_compute

    sob_root "sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true"

    set_profile_state compute
    notify normal "⚡ Perfil: COMPUTAÇÃO BRUTA" \
        "${CPU_THREADS} Threads em 100% Performance • GPU Desbloqueada • Desktop Ativo"
}

apply_game() {
    if [ ! -f "$GAME_STATE" ]; then
        if [ "$SOB_DRY_RUN" = true ]; then
            printf '  [dry] GameMode.sh (ativar GameMode)\n' >&2
        else
            bash "${SCRIPTS_DIR}/GameMode.sh"
        fi
    fi
    # Deliberately does not overwrite STATE_FILE: GameMode is a layer, and the
    # profile underneath it must survive the round trip.
}

# -----------------------------------------------------------------------------
# Menu
# -----------------------------------------------------------------------------
show_menu() {
    local current
    current=$(get_current_profile)

    local options=(
        "🌿  Eco Silencioso (${CPU_MIN_GHZ} GHz • GPU Fria / Min TDP • Zero Ruído)"
        "⚖️  Balanceado (Padrão Diário • Clocks Dinâmicos • Efeitos ON)"
        "⚡  Computação / Render (${CPU_THREADS} Threads no Máximo • Desktop ON)"
        "🎮  Modo Escovar Bit (Jogos Competitivos • Zero Overhead • Tearing ON)"
    )

    local menu_lines=() opt
    for opt in "${options[@]}"; do
        if { [[ "$opt" == *"Eco"* ]] && [ "$current" = "eco" ]; } \
        || { [[ "$opt" == *"Balanceado"* ]] && [ "$current" = "balanced" ]; } \
        || { [[ "$opt" == *"Computação"* ]] && [ "$current" = "compute" ]; } \
        || { [[ "$opt" == *"Escovar Bit"* ]] && [ "$current" = "game" ]; }; then
            menu_lines+=("👉 $opt")
        else
            menu_lines+=("   $opt")
        fi
    done

    local chosen
    chosen=$(printf '%s\n' "${menu_lines[@]}" | fuzzel --dmenu -p "⚡ Perfil de Energia ❯ " -w 58 -l 6 2>/dev/null || true)
    [ -z "$chosen" ] && exit 0

    case "$chosen" in
        *Eco*)          apply_eco ;;
        *Balanceado*)   apply_balanced ;;
        *Computação*)   apply_compute ;;
        *Escovar*)      apply_game ;;
    esac
}

# -----------------------------------------------------------------------------
# Entrypoint
# -----------------------------------------------------------------------------
case "${1:-menu}" in
    --eco|eco)             apply_eco ;;
    --balanced|balanced)   apply_balanced ;;
    --compute|compute)     apply_compute ;;
    --game|game)           apply_game ;;
    --toggle-eco)
        if [ "$(get_current_profile)" = "eco" ]; then
            apply_balanced
        else
            apply_eco
        fi
        ;;
    --status|status)
        get_current_profile
        ;;
    --probe)
        sob_probe
        ;;
    --menu|menu|"")
        if [ "$SOB_DRY_RUN" = true ]; then
            printf '== PLANO ECO ==\n' >&2; apply_eco
            printf '\n== PLANO BALANCEADO ==\n' >&2; apply_balanced
            printf '\n== PLANO COMPUTAÇÃO ==\n' >&2; apply_compute
        else
            show_menu
        fi
        ;;
    *)
        show_menu
        ;;
esac
