#!/usr/bin/env bash
# ==============================================================================
# Soberano Dotfiles - Auto-Updater & Zero-Breakage Upgrade Engine
# Synchronizes local dotfiles with remote repository, preserves machine/runtime
# state, syncs symlinks & systemd units, rebuilds changed Rust tools, and
# reloads active desktop services selectively.
# ==============================================================================
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

BACKGROUND=false
for arg in "$@"; do
    case "$arg" in
        --background|--auto|--silent|--quiet|-q)
            BACKGROUND=true
            ;;
    esac
done

IS_TTY=false
if [ -t 1 ]; then
    IS_TTY=true
fi

notify() {
    local title="$1"
    local msg="$2"
    local urgency="${3:-normal}"
    if [ "$IS_TTY" = true ]; then
        printf ":: [%s] %s\n" "$title" "$msg"
    fi
    # In background timer mode, suppress noisy "checking / up to date" popups
    if [ "$BACKGROUND" = true ] && [ "$urgency" = "low" ]; then
        return 0
    fi
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" -a "Soberano Dotfiles" "$title" "$msg" 2>/dev/null || true
    fi
}

# Single-instance lock (prevents systemd timer / Wayle click / CLI collisions)
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/soberano-update.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    [ "$IS_TTY" = true ] && printf ":: Outra atualização do Soberano Dotfiles já está em andamento.\n"
    exit 0
fi

notify "Soberano Dotfiles" "Verificando atualizações no GitHub..." "low"

export GIT_TERMINAL_PROMPT=0

# 1. Verify Git Repository & Connectivity
if [ ! -d "$DOTFILES_DIR/.git" ]; then
    notify "Soberano Dotfiles" "Erro: Diretório $DOTFILES_DIR não é um repositório git." "critical"
    exit 1
fi

if ! curl -fsS --head --request GET https://github.com --max-time 4 >/dev/null 2>&1; then
    notify "Soberano Dotfiles" "Sem conexão ou GitHub inacessível no momento." "low"
    exit 0
fi

cd "$DOTFILES_DIR"

# Recover from any aborted prior rebase/merge state
if [ -d ".git/rebase-merge" ] || [ -d ".git/rebase-apply" ]; then
    git rebase --abort 2>/dev/null || true
fi
if [ -f ".git/MERGE_HEAD" ]; then
    git merge --abort 2>/dev/null || true
fi

BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [ -z "$BRANCH" ]; then
    notify "Soberano Dotfiles" "Repositório em detached HEAD; atualização automática ignorada." "normal"
    exit 0
fi

# 2. Fetch Remote Changes
git -c gc.auto=0 fetch origin "$BRANCH" --quiet 2>/dev/null || exit 0
REMOTE=$(git rev-parse "origin/$BRANCH" 2>/dev/null || true)

if [ -z "$REMOTE" ]; then
    notify "Soberano Dotfiles" "Não foi possível contactar origin/$BRANCH." "low"
    exit 0
fi

BEHIND=$(git rev-list --count "HEAD..origin/$BRANCH" 2>/dev/null || echo "0")

if [ "$BEHIND" -eq 0 ]; then
    SHORT_LOCAL=$(git rev-parse --short HEAD 2>/dev/null || echo "ok")
    notify "Soberano Dotfiles" "✓ Seu sistema já está na versão mais recente (${SHORT_LOCAL})." "low"
    exit 0
fi

# 3. Backup Runtime / Machine-Specific State Before Pulling
notify "Atualização Detectada" "Aplicando ${BEHIND} atualização(ões) do Soberano Dotfiles..." "normal"

BACKUP_DIR=$(mktemp -d)
trap 'rm -rf "$BACKUP_DIR"' EXIT

RUNTIME_FILES=(
    "config/btop/themes/matugen.theme"
    "config/fish/fish_variables"
    "config/fuzzel/colors.ini"
    "config/hypr/config/colors_dynamic.lua"
    "config/hypr/config/gaps_dynamic.lua"
    "config/hypr/config/monitors.lua"
    "config/hypr/config/hardware.lua"
    "config/kitty/themes/matugen.conf"
    "config/wayle/config.toml"
)
LOCAL_BINARIES=(
    "scripts/display-picker-rs"
    "scripts/wallpaper-picker-rs"
    "scripts/soberano-cockpit-bar-rs"
)

BACKED_UP_RUNTIME=()
for rel in "${RUNTIME_FILES[@]}" "${LOCAL_BINARIES[@]}"; do
    if git ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
        if [ -f "$DOTFILES_DIR/$rel" ] && ! git diff --quiet HEAD -- "$rel" 2>/dev/null; then
            mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
            cp -a "$DOTFILES_DIR/$rel" "$BACKUP_DIR/$rel"
            BACKED_UP_RUNTIME+=("$rel")
            git checkout -- "$rel" 2>/dev/null || true
        fi
    fi
done

# Stash only remaining non-runtime local modifications (if any)
STASHED=false
BEFORE_STASH=$(git rev-parse -q --verify refs/stash 2>/dev/null || echo "")
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    git stash push -m "soberano-auto-update" --quiet 2>/dev/null || true
    AFTER_STASH=$(git rev-parse -q --verify refs/stash 2>/dev/null || echo "")
    if [ "$BEFORE_STASH" != "$AFTER_STASH" ]; then
        STASHED=true
    fi
fi

restore_runtime_backups() {
    local changed_files="${1:-}"
    local wayle_upstream_changed=false
    if printf '%s\n' "$changed_files" | grep -qx "config/wayle/config.toml"; then
        wayle_upstream_changed=true
    fi

    for rel in "${BACKED_UP_RUNTIME[@]}"; do
        [ -f "$BACKUP_DIR/$rel" ] || continue

        # Skip restoring precompiled binaries if their Rust crate source changed upstream
        case "$rel" in
            scripts/wallpaper-picker-rs)
                if printf '%s\n' "$changed_files" | grep -q "^tools/wallpaper-picker-rs/"; then
                    continue
                fi
                ;;
            scripts/display-picker-rs)
                if printf '%s\n' "$changed_files" | grep -q "^tools/display-picker-rs/"; then
                    continue
                fi
                ;;
            scripts/soberano-cockpit-bar-rs)
                if printf '%s\n' "$changed_files" | grep -q "^tools/soberano-cockpit-bar-rs/"; then
                    continue
                fi
                ;;
        esac

        if [ "$rel" = "config/wayle/config.toml" ] && [ "$wayle_upstream_changed" = true ] && [ -f "$DOTFILES_DIR/config/wayle/config.toml" ]; then
            # Keep new upstream Wayle schema/modules while preserving client wallpaper, theme & location
            python3 - "$BACKUP_DIR/config/wayle/config.toml" "$DOTFILES_DIR/config/wayle/config.toml" "$DOTFILES_DIR" <<'PY' || true
import re, sys

old_path, new_path, dotfiles_dir = sys.argv[1], sys.argv[2], sys.argv[3]
with open(old_path, "r", encoding="utf-8", errors="ignore") as f:
    old_txt = f.read()
with open(new_path, "r", encoding="utf-8", errors="ignore") as f:
    new_txt = f.read()

new_txt = re.sub(r"/home/[^/\"]*/dotfiles", dotfiles_dir, new_txt)

for key in ("wallpaper", "cycling-directory", "matugen-scheme", "theming-monitor", "location"):
    m = re.search(rf'^({re.escape(key)}\s*=\s*"[^"]*")', old_txt, flags=re.MULTILINE)
    if m:
        new_txt = re.sub(rf'^{re.escape(key)}\s*=\s*"[^"]*"', lambda _: m.group(1), new_txt, count=1, flags=re.MULTILINE)

with open(new_path, "w", encoding="utf-8") as f:
    f.write(new_txt)
PY
            continue
        fi

        mkdir -p "$DOTFILES_DIR/$(dirname "$rel")"
        cp -a "$BACKUP_DIR/$rel" "$DOTFILES_DIR/$rel"
    done
}

sync_symlinks_and_units() {
    mkdir -p "$CONFIG_DIR" "$CONFIG_DIR/systemd/user" "$HOME/.local/bin"

    # Ensure all config subdirectories are linked into ~/.config
    local configs=(hypr wayle matugen fuzzel kitty btop fastfetch fish quickshell swappy)
    for dir in "${configs[@]}"; do
        [ -d "$DOTFILES_DIR/config/$dir" ] || continue
        local target="${CONFIG_DIR}/${dir}"
        if [ -L "$target" ]; then
            if [ "$(readlink -f "$target" 2>/dev/null || true)" != "$(readlink -f "$DOTFILES_DIR/config/$dir")" ]; then
                ln -sfnT "$DOTFILES_DIR/config/$dir" "$target"
            fi
        elif [ ! -e "$target" ]; then
            ln -sfnT "$DOTFILES_DIR/config/$dir" "$target"
        fi
    done

    # Ensure CLI & binary symlinks in ~/.local/bin stay current
    ln -sfn "$DOTFILES_DIR/scripts/soberano-update.sh" "$HOME/.local/bin/soberano-update"
    ln -sfn "$DOTFILES_DIR/scripts/soberano-theme.sh" "$HOME/.local/bin/soberano-theme"
    ln -sfn "$DOTFILES_DIR/scripts/soberano-power-profile.sh" "$HOME/.local/bin/soberano-power-profile"
    ln -sfn "$DOTFILES_DIR/scripts/display-picker-rs" "$HOME/.local/bin/display-picker-rs" 2>/dev/null || true
    ln -sfn "$DOTFILES_DIR/scripts/display-picker-rs" "$HOME/.local/bin/soberano-monitors" 2>/dev/null || true
    ln -sfn "$DOTFILES_DIR/scripts/display-picker-rs" "$HOME/.local/bin/monitor-select" 2>/dev/null || true
    ln -sfn "$DOTFILES_DIR/scripts/wallpaper-picker-rs" "$HOME/.local/bin/wallpaper-picker-rs" 2>/dev/null || true
    ln -sfn "$DOTFILES_DIR/scripts/soberano-cockpit-bar-rs" "$HOME/.local/bin/soberano-cockpit-bar-rs" 2>/dev/null || true
    ln -sfn "$DOTFILES_DIR/scripts/soberano-livewallpaper.sh" "$HOME/.local/bin/soberano-livewallpaper" 2>/dev/null || true
    ln -sfn "$DOTFILES_DIR/scripts/soberano-livewallpaper.sh" "$HOME/.local/bin/livewallpaper" 2>/dev/null || true
    ln -sfn "$DOTFILES_DIR/scripts/soberano-hardware-menu.py" "$HOME/.local/bin/soberano-hardware-menu" 2>/dev/null || true
    ln -sfn "$DOTFILES_DIR/scripts/ScreenShot.sh" "$HOME/.local/bin/soberano-screenshot" 2>/dev/null || true
    ln -sfn "$DOTFILES_DIR/scripts/ScreenShot.sh" "$HOME/.local/bin/screenshot" 2>/dev/null || true

    # Sync updated systemd user units
    local unit_updated=false
    if [ -d "$DOTFILES_DIR/config/systemd/user" ]; then
        for unit in "$DOTFILES_DIR"/config/systemd/user/*; do
            [ -f "$unit" ] || continue
            local base
            base="$(basename "$unit")"
            local dst="$CONFIG_DIR/systemd/user/$base"
            local tmp_unit="$BACKUP_DIR/$base.unit"
            sed "s|%h/dotfiles|${DOTFILES_DIR}|g" "$unit" > "$tmp_unit"
            if [ ! -f "$dst" ] || ! cmp -s "$tmp_unit" "$dst"; then
                cp -f "$tmp_unit" "$dst"
                unit_updated=true
            fi
        done
    fi

    if [ "$unit_updated" = true ] && command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload 2>/dev/null || true
    fi
}

OLD_HEAD=$(git rev-parse HEAD)

# 4. Pull Upstream Updates
if git -c gc.auto=0 pull --rebase origin "$BRANCH" --quiet 2>/dev/null; then
    NEW_HEAD=$(git rev-parse HEAD)
    CHANGED_FILES=$(git diff --name-only "$OLD_HEAD" "$NEW_HEAD" 2>/dev/null || true)

    restore_runtime_backups "$CHANGED_FILES"

    # Safely pop non-runtime user changes; never leave conflict markers in live configs
    STASH_CONFLICT=false
    if [ "$STASHED" = true ]; then
        if ! git stash pop --quiet 2>/dev/null; then
            STASH_CONFLICT=true
            git reset --hard HEAD --quiet 2>/dev/null || true
            restore_runtime_backups "$CHANGED_FILES"
        fi
    fi

    # Fix permissions
    chmod +x "$DOTFILES_DIR"/scripts/*.sh "$DOTFILES_DIR"/scripts/*.py "$DOTFILES_DIR"/scripts/*-rs "$DOTFILES_DIR/tools/build.sh" 2>/dev/null || true

    # Sync config symlinks, ~/.local/bin links, and systemd user units
    sync_symlinks_and_units

    # Re-apply user's saved Wayle bar preset if upstream changed Wayle config or preset script
    PRESET_STATE="${XDG_CACHE_HOME:-$HOME/.cache}/soberano_wayle_preset.txt"
    WAYLE_RELOADED=false
    if printf '%s\n' "$CHANGED_FILES" | grep -qE "^(config/wayle/config\.toml|scripts/WayleBarPresetSelect\.sh)$"; then
        if [ -f "$PRESET_STATE" ]; then
            SAVED_PRESET=$(tr -d '[:space:]' < "$PRESET_STATE" 2>/dev/null || true)
            if [[ "$SAVED_PRESET" =~ ^[0-9]+$ ]] && [ -x "$DOTFILES_DIR/scripts/WayleBarPresetSelect.sh" ]; then
                "$DOTFILES_DIR/scripts/WayleBarPresetSelect.sh" "$SAVED_PRESET" >/dev/null 2>&1 || true
                WAYLE_RELOADED=true
            fi
        fi
    fi

    # Selectively compile ONLY Rust crates whose source changed (or broken/missing binaries)
    CRATES_TO_BUILD=()
    for crate in wallpaper-picker-rs display-picker-rs soberano-cockpit-bar-rs; do
        bin_path="$DOTFILES_DIR/scripts/$crate"
        rc=0
        if [ -x "$bin_path" ]; then
            WAYLAND_DISPLAY="" DISPLAY="" timeout 1 "$bin_path" --help >/dev/null 2>&1 || rc=$?
        else
            rc=127
        fi
        if printf '%s\n' "$CHANGED_FILES" | grep -q "^tools/$crate/" || [ "$rc" -eq 127 ] || [ "$rc" -eq 132 ] || [ "$rc" -eq 139 ]; then
            CRATES_TO_BUILD+=("$crate")
        fi
    done

    if [ ${#CRATES_TO_BUILD[@]} -gt 0 ] && [ -f "$DOTFILES_DIR/tools/build.sh" ]; then
        ONLY_ARG=$(IFS=','; echo "${CRATES_TO_BUILD[*]}")
        bash "$DOTFILES_DIR/tools/build.sh" --only "$ONLY_ARG" --no-sudo >/dev/null 2>&1 || true
    fi

    # Targeted reload of desktop services
    if printf '%s\n' "$CHANGED_FILES" | grep -q "^config/hypr/"; then
        if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
            hyprctl reload >/dev/null 2>&1 || true
        fi
    fi

    if [ "$WAYLE_RELOADED" = false ] && printf '%s\n' "$CHANGED_FILES" | grep -q "^config/wayle/"; then
        if command -v systemctl >/dev/null 2>&1 && systemctl --user is-active --quiet wayle.service 2>/dev/null; then
            systemctl --user restart wayle.service >/dev/null 2>&1 || true
        fi
    fi

    if printf '%s\n' "$CHANGED_FILES" | grep -q "^tools/soberano-cockpit-bar-rs/"; then
        if command -v systemctl >/dev/null 2>&1 && systemctl --user is-active --quiet soberano-cockpit-bar 2>/dev/null; then
            systemctl --user stop soberano-cockpit-bar 2>/dev/null || true
            systemctl --user reset-failed soberano-cockpit-bar 2>/dev/null || true
            systemd-run --user --unit=soberano-cockpit-bar "$HOME/.local/bin/soberano-cockpit-bar-rs" >/dev/null 2>&1 || true
        fi
    fi

    NEW_REV=$(git rev-parse --short HEAD 2>/dev/null || echo "revisão recente")
    if [ "$STASH_CONFLICT" = true ]; then
        notify "Atualizado com Aviso ($NEW_REV)" "Sistema atualizado, mas suas edições manuais em arquivos rastreados ficaram salvas no git stash (use config/hypr/config/user_binds.lua)." "normal"
    else
        notify "Soberano Dotfiles Atualizado" "Upgrade concluído para (${NEW_REV})!" "normal"
    fi
else
    git rebase --abort 2>/dev/null || true
    restore_runtime_backups ""
    if [ "$STASHED" = true ]; then
        git stash pop --quiet 2>/dev/null || true
    fi
    notify "Falha na Sincronização" "Não foi possível aplicar o rebase automático em $DOTFILES_DIR. Verifique git status." "critical"
    exit 1
fi
