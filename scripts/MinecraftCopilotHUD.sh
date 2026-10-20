#!/usr/bin/env bash
# ==============================================================================
# Soberano Stealth Minecraft Copilot HUD (Prominence II + Baritone)
# Bound to: Super + M
# ==============================================================================
set -euo pipefail

options=(
    "⛏️  Minerar Ferro (Iron + Deepslate)"
    "💎  Minerar Diamante (Diamond + Deepslate)"
    "🪙  Minerar Ouro (Overworld + Nether)"
    "🪵  Minerar Carvão (Coal + Deepslate)"
    "🧱  Minerar Cobre (Copper)"
    "🔥  Minerar Netherite (Ancient Debris)"
    "🟢  Minerar Esmeralda (Emerald)"
    "🔴  Minerar Redstone"
    "🛑  PARAR Baritone (#stop)"
    "⏸️  Pausar (#pause)"
    "▶️  Continuar (#resume)"
    "🧭  Explorar Área (#explore)"
)

chosen=$(printf '%s\n' "${options[@]}" | fuzzel --dmenu -p "󰍉 Layla Copilot ❯ " -w 45 -l 12 || true)
[ -z "$chosen" ] && exit 0

clean=$(echo "$chosen" | sed 's/^[^\ ]*\ *//')
cmd=""

case "$clean" in
    *"Minerar Ferro"*)
        cmd="#mine iron_ore deepslate_iron_ore raw_iron_block"
        ;;
    *"Minerar Diamante"*)
        cmd="#mine diamond_ore deepslate_diamond_ore"
        ;;
    *"Minerar Ouro"*)
        cmd="#mine gold_ore deepslate_gold_ore nether_gold_ore"
        ;;
    *"Minerar Carvão"*)
        cmd="#mine coal_ore deepslate_coal_ore"
        ;;
    *"Minerar Cobre"*)
        cmd="#mine copper_ore deepslate_copper_ore"
        ;;
    *"Minerar Netherite"*)
        cmd="#mine ancient_debris"
        ;;
    *"Minerar Esmeralda"*)
        cmd="#mine emerald_ore deepslate_emerald_ore"
        ;;
    *"Minerar Redstone"*)
        cmd="#mine redstone_ore deepslate_redstone_ore"
        ;;
    *"PARAR"*)
        cmd="#stop"
        ;;
    *"Pausar"*)
        cmd="#pause"
        ;;
    *"Continuar"*)
        cmd="#resume"
        ;;
    *"Explorar"*)
        cmd="#explore"
        ;;
    *)
        # Free-form text typed by user
        raw_lower=$(echo "$chosen" | tr '[:upper:]' '[:lower:]')
        if [[ "$raw_lower" == *"ferro"* || "$raw_lower" == *"iron"* ]]; then
            cmd="#mine iron_ore deepslate_iron_ore raw_iron_block"
        elif [[ "$raw_lower" == *"diamante"* || "$raw_lower" == *"diamond"* ]]; then
            cmd="#mine diamond_ore deepslate_diamond_ore"
        elif [[ "$raw_lower" == *"ouro"* || "$raw_lower" == *"gold"* ]]; then
            cmd="#mine gold_ore deepslate_gold_ore nether_gold_ore"
        elif [[ "$raw_lower" == *"carvao"* || "$raw_lower" == *"carvão"* || "$raw_lower" == *"coal"* ]]; then
            cmd="#mine coal_ore deepslate_coal_ore"
        elif [[ "$raw_lower" == *"netherite"* || "$raw_lower" == *"debris"* ]]; then
            cmd="#mine ancient_debris"
        elif [[ "$raw_lower" == *"cobre"* || "$raw_lower" == *"copper"* ]]; then
            cmd="#mine copper_ore deepslate_copper_ore"
        elif [[ "$raw_lower" == *"esmeralda"* || "$raw_lower" == *"emerald"* ]]; then
            cmd="#mine emerald_ore deepslate_emerald_ore"
        elif [[ "$raw_lower" == *"redstone"* ]]; then
            cmd="#mine redstone_ore deepslate_redstone_ore"
        elif [[ "$raw_lower" == *"parar"* || "$raw_lower" == *"stop"* ]]; then
            cmd="#stop"
        elif [[ "$raw_lower" == *"pausar"* || "$raw_lower" == *"pause"* ]]; then
            cmd="#pause"
        elif [[ "$raw_lower" == *"continuar"* || "$raw_lower" == *"resume"* ]]; then
            cmd="#resume"
        elif [[ "$raw_lower" == *"explorar"* || "$raw_lower" == *"explore"* ]]; then
            cmd="#explore"
        elif [[ "$chosen" =~ ^-?[0-9]+\ -?[0-9]+\ -?[0-9]+$ ]]; then
            cmd="#goto $chosen"
        elif [[ "$chosen" == \#* ]]; then
            cmd="$chosen"
        else
            cmd="#$chosen"
        fi
        ;;
esac

[ -z "$cmd" ] && exit 0

# Refocus Minecraft window
hyprctl dispatch focuswindow "title:Prominence" >/dev/null 2>&1 || true
sleep 0.08

# Inject command into chat via Wayland wtype
wtype -k t
sleep 0.06
wtype "$cmd"
sleep 0.06
wtype -k Return

notify-send -u low -a "Layla MC Copilot" "⚡ Comando Injetado" "$cmd" 2>/dev/null || true
