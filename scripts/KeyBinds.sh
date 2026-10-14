#!/usr/bin/env bash
# ==============================================================================
# KeyBinds.sh - Searchable Keybindings HUD for JaKooLit + Noctalia
# Bound to: Super + Shift + K (and Super + H / Super + Shift + ?)
# ==============================================================================
set -euo pipefail

entries=(
"󰏘  Super + Alt + B               │ Escolher Estilo da Barra (13 temas)"
"󰕰  Super + Ctrl + B              │ Escolher Layout da Barra (Ilhas, Dock...)"
"󰑮  Super + Alt + A               │ Escolher Perfil de Animações (5 físicas)"
"󰸉  Super + W                     │ Menu de Papéis de Parede"
"󰒝  Super + Alt + W               │ Papel de Parede Aleatório"
"󰑓  Super + Alt + R               │ Recarregar Temas e Cores"
"󰖲  Super + Espaço / D            │ Lançador de Aplicativos"
"󰅖  Super + Q                     │ Fechar Janela Ativa"
"󰖲  Super + Espaço                │ Alternar Janela Flutuante"
"󰊓  Super + F                     │ Tela Cheia (Fullscreen Total)"
"󰊔  Super + Shift + F             │ Tela Cheia Monocle (Barra visível)"
"󰕰  Super + J                     │ Alternar Divisão Tiling (Split)"
"󰍹  Super + 1 .. 9, 0             │ Ir para Workspace 1 a 10"
"󰆍  Super + Shift + 1 .. 9, 0     │ Mover Janela para Workspace 1 a 10"
"󰍹  Super + Ctrl + 1 .. 3         │ Focar Monitor 1, 2 ou 3"
"󰍹  Super + Ctrl + Shift + 1..3   │ Mover Janela para Monitor 1, 2 ou 3"
"󰘓  Super + S                     │ Alternar Scratchpad Especial"
"󰘓  Super + Shift + S             │ Enviar Janela para Scratchpad"
"󰅍  Super + V / Alt + V           │ Histórico de Cópia (Clipboard)"
"󰨇  Super + A                     │ Visão Geral de Janelas (Overview)"
"󰈊  Super + P                     │ Seletor de Cores da Tela (Color Picker)"
"󰹑  Print                         │ Capturar Região da Tela"
"󰹑  Super + Print                 │ Capturar Tela Inteira"
"󰊗  Super + G                     │ Alternar Modo Gamer (Máximo FPS)"
"󰌾  Ctrl + Alt + L                │ Bloquear Tela"
"󰐥  Ctrl + Alt + Del             │ Menu de Sessão / Desligamento"
)

chosen=$(printf '%s\n' "${entries[@]}" | noctalia dmenu -p "󰌌 Atalhos JaKooLit (Super+Shift+K)" || true)

if [ -z "$chosen" ]; then
    exit 0
fi

# Optional: trigger action if user pressed Enter on an actionable tool
case "$chosen" in
    *"Super + Alt + B"*)
        exec "${HOME}/dotfiles/scripts/NoctaliaThemeSelector.sh"
        ;;
    *"Super + Ctrl + B"*)
        exec "${HOME}/dotfiles/scripts/NoctaliaLayoutSelector.sh"
        ;;
    *"Super + Alt + A"*)
        exec "${HOME}/dotfiles/scripts/HyprAnimationsSelector.sh"
        ;;
    *"Super + W"*)
        noctalia msg panel-toggle wallpaper >/dev/null 2>&1 || true
        ;;
    *"Super + Alt + W"*)
        noctalia msg wallpaper-random >/dev/null 2>&1 || true
        ;;
    *"Super + Alt + R"*)
        noctalia msg templates-apply >/dev/null 2>&1 || true
        ;;
    *"Super + V"*)
        noctalia msg panel-toggle clipboard >/dev/null 2>&1 || true
        ;;
    *"Super + A"*)
        exec "${HOME}/dotfiles/scripts/OverviewToggle.sh"
        ;;
    *"Super + P"*)
        hyprpicker -a -n >/dev/null 2>&1 || true
        ;;
    *"Print"*)
        noctalia msg screenshot-region >/dev/null 2>&1 || true
        ;;
    *"Super + G"*)
        exec "${HOME}/dotfiles/scripts/GameMode.sh"
        ;;
    *"Ctrl + Alt + Del"*)
        noctalia msg panel-toggle session >/dev/null 2>&1 || true
        ;;
esac
