#!/usr/bin/env bash
# ==============================================================================
# Soberano Monitor & Refresh Rate Manager (Hyprland + Fuzzel)
# Intuitive display configurator matching Super + W aesthetic
# Bound to: Super + M | Super + Shift + M
# ==============================================================================
set -euo pipefail

MONITORS_LUA="${HOME}/dotfiles/config/hypr/config/monitors.lua"

# 1. Fetch connected monitors from Hyprland
MONITORS_JSON=$(hyprctl monitors -j 2>/dev/null || echo "[]")
if [ "$MONITORS_JSON" = "[]" ] || [ -z "$MONITORS_JSON" ]; then
    notify-send -u critical -a "Soberano Displays" "Erro" "Nenhum monitor detectado pelo Hyprland."
    exit 1
fi

# 2. Select monitor if multiple are connected
TARGET_MON=$(python3 - "$MONITORS_JSON" <<'PY'
import sys, json

try:
    monitors = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)

if len(monitors) == 1:
    print(monitors[0]["name"])
else:
    # Multiple monitors: list them
    lines = []
    for m in monitors:
        name = m.get("name", "Unknown")
        desc = m.get("description", "")
        w = m.get("width", 1920)
        h = m.get("height", 1080)
        r = m.get("refreshRate", 60)
        lines.append(f"{name} — {desc} ({w}x{h}@{r:.0f}Hz)")
    print("PROMPT:" + "\n".join(lines))
PY
)

if [[ "$TARGET_MON" == PROMPT:* ]]; then
    PROMPT_LIST="${TARGET_MON#PROMPT:}"
    chosen_mon=$(printf '%s\n' "$PROMPT_LIST" | fuzzel --dmenu -p "󰍹 Selecionar Monitor ❯ " -w 56 -l 6 || true)
    [ -z "$chosen_mon" ] && exit 0
    TARGET_MON="${chosen_mon%% *}"
fi

[ -z "$TARGET_MON" ] && exit 0

# 3. Extract monitor details and available modes
MODES_DATA=$(python3 - "$MONITORS_JSON" "$TARGET_MON" <<'PY'
import sys, json, re

monitors = json.loads(sys.argv[1])
target = sys.argv[2]
mon = next((m for m in monitors if m["name"] == target), None)
if not mon:
    sys.exit(1)

cur_w = mon.get("width", 1920)
cur_h = mon.get("height", 1080)
cur_r = mon.get("refreshRate", 60.0)
cur_scale = mon.get("scale", 1.0)
desc = mon.get("description", target)

modes_raw = mon.get("availableModes", [])
parsed = []

for m in modes_raw:
    # Format e.g. "1920x1080@165.00Hz"
    match = re.match(r"(\d+)x(\d+)@([0-9.]+)Hz", m)
    if match:
        w, h, r = int(match.group(1)), int(match.group(2)), float(match.group(3))
        parsed.append((w, h, r, m))

# Sort by width desc, height desc, refreshRate desc
parsed.sort(key=lambda x: (x[0], x[1], x[2]), reverse=True)

# Remove duplicates while preserving order
seen = set()
unique_modes = []
for w, h, r, orig in parsed:
    # Round rate to 2 decimals
    key = (w, h, round(r, 2))
    if key not in seen:
        seen.add(key)
        unique_modes.append((w, h, r))

# Mark current
print(f"DESC:{desc}")
print(f"CURRENT:{cur_w}x{cur_h}@{cur_r:.2f}")
print(f"SCALE:{cur_scale}")

for w, h, r in unique_modes:
    is_cur = (w == cur_w and h == cur_h and abs(r - cur_r) < 0.5)
    cur_mark = "👉 " if is_cur else "   "
    
    # Extra label
    tag = ""
    if r >= 144:
        tag = "⚡ Alta Taxa / Gamer"
    elif r >= 100:
        tag = "🚀 Fluido"
    elif r >= 75:
        tag = "✨ Suave"
    elif r >= 60:
        tag = "🖥️ Padrão"

    print(f"MODE:{cur_mark}{w}x{h} @ {r:.2f}Hz  {tag}|{w}x{h}@{r:.2f}")
PY
)

[ -z "$MODES_DATA" ] && exit 0

MON_DESC=$(echo "$MODES_DATA" | grep "^DESC:" | cut -d: -f2- || echo "$TARGET_MON")
CURRENT_MODE=$(echo "$MODES_DATA" | grep "^CURRENT:" | cut -d: -f2- || echo "")
CURRENT_SCALE=$(echo "$MODES_DATA" | grep "^SCALE:" | cut -d: -f2- || echo "1")

# Build menu options
OPTIONS=()
declare -A MODE_MAP

# Add automatic/preferred option on top
OPTIONS+=("⚡ Automático Recomendado (preferred@max)")
MODE_MAP["⚡ Automático Recomendado (preferred@max)"]="preferred"

while IFS= read -r line; do
    if [[ "$line" == MODE:* ]]; then
        clean="${line#MODE:}"
        display_label="${clean%%|*}"
        raw_mode="${clean##*|}"
        OPTIONS+=("$display_label")
        MODE_MAP["$display_label"]="$raw_mode"
    fi
done <<< "$MODES_DATA"

CHOSEN_OPTION=$(printf '%s\n' "${OPTIONS[@]}" | fuzzel --dmenu -p "󰍹 ${TARGET_MON} Resolução & Hz ❯ " -w 64 -l 14 || true)
[ -z "$CHOSEN_OPTION" ] && exit 0

SELECTED_MODE="${MODE_MAP[$CHOSEN_OPTION]:-preferred}"

# 4. Select Scale
SCALE_OPTIONS=(
    "👉 1.00x — 100% (Padrão Nativo)"
    "   1.25x — 125% (Ideal para 1440p / 2K)"
    "   1.50x — 150% (Equilibrado para 4K)"
    "   1.75x — 175% (Texto Grande)"
    "   2.00x — 200% (HiDPI / Retina)"
)

# Highlight current scale if different
if [ "$CURRENT_SCALE" != "1" ] && [ "$CURRENT_SCALE" != "1.0" ]; then
    SCALE_OPTIONS=()
    for s in "1.00x — 100% (Padrão Nativo)" "1.25x — 125% (Ideal para 1440p / 2K)" "1.50x — 150% (Equilibrado para 4K)" "1.75x — 175% (Texto Grande)" "2.00x — 200% (HiDPI / Retina)"; do
        val="${s%%x*}"
        val=$(echo "$val" | sed 's/^👉 //; s/^   //')
        if (( $(echo "$val == $CURRENT_SCALE" | bc -l 2>/dev/null || echo 0) )); then
            SCALE_OPTIONS+=("👉 $s")
        else
            SCALE_OPTIONS+=("   $s")
        fi
    done
fi

CHOSEN_SCALE_ROW=$(printf '%s\n' "${SCALE_OPTIONS[@]}" | fuzzel --dmenu -p "󰍹 ${TARGET_MON} Escala / Scaling ❯ " -w 50 -l 6 || true)
[ -z "$CHOSEN_SCALE_ROW" ] && CHOSEN_SCALE_ROW="1.00x"

CLEAN_SCALE=$(echo "$CHOSEN_SCALE_ROW" | sed 's/^👉 //; s/^   //' | awk '{print $1}' | tr -d 'x')
[ -z "$CLEAN_SCALE" ] && CLEAN_SCALE="1"

# 5. Apply live in Hyprland
if [ "$SELECTED_MODE" = "preferred" ]; then
    APPLY_CMD="${TARGET_MON},preferred,auto,${CLEAN_SCALE}"
    DISPLAY_TEXT="Recomendado Automático (Escala ${CLEAN_SCALE}x)"
else
    APPLY_CMD="${TARGET_MON},${SELECTED_MODE},auto,${CLEAN_SCALE}"
    DISPLAY_TEXT="${SELECTED_MODE} (Escala ${CLEAN_SCALE}x)"
fi

hyprctl keyword monitor "$APPLY_CMD" >/dev/null 2>&1 || true

# 6. Persist to monitors.lua permanently
cat > "$MONITORS_LUA" <<LUA
-- ==============================================================================
-- Soberano Monitor Configuration (Auto-configured by Super + M)
-- ==============================================================================

hl.monitor({
    output   = "${TARGET_MON}",
    mode     = "${SELECTED_MODE}",
    position = "0x0",
    scale    = "${CLEAN_SCALE}",
})

-- Universal Fallback for any secondary displays or laptop screens
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
LUA

notify-send -u normal -a "Soberano Displays" "󰍹 Resolução Aplicada" "${TARGET_MON}: ${DISPLAY_TEXT}"
