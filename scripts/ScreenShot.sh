#!/usr/bin/env bash
# ==============================================================================
# Soberano ScreenShot Engine (grim + slurp + swappy)
# Wayland native screenshot tool tailored for 60% keyboards & high-FPS displays
# ==============================================================================

MODE="${1:---swappy}"
SAVE_DIR="${HOME}/Pictures/Screenshots"
mkdir -p "$SAVE_DIR"

case "$MODE" in
    --swappy|--area)
        # Select area and open in Swappy editor for annotations, copy, or save
        GEOM=$(slurp 2>/dev/null)
        if [ -n "$GEOM" ]; then
            grim -g "$GEOM" - | swappy -f -
        fi
        ;;

    --full-swappy|--full)
        # Capture full screen and open in Swappy editor
        grim - | swappy -f -
        ;;

    --copy|--fast)
        # Fast copy area to clipboard without GUI editor
        GEOM=$(slurp 2>/dev/null)
        if [ -n "$GEOM" ]; then
            grim -g "$GEOM" - | wl-copy --type image/png
            notify-send -a "Soberano Screenshot" -i camera-photo "Captura de Tela" "Área copiada para a área de transferência!" -t 2000
        fi
        ;;

    --full-copy)
        # Fast full screen copy to clipboard
        grim - | wl-copy --type image/png
        notify-send -a "Soberano Screenshot" -i camera-photo "Captura de Tela" "Tela cheia copiada para o clipboard!" -t 2000
        ;;

    *)
        echo "Uso: $0 [--swappy|--full-swappy|--copy|--full-copy]"
        exit 1
        ;;
esac
