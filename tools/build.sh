#!/usr/bin/env bash
# ==============================================================================
# Soberano Native Tool Suite - Machine-Optimized Compiler
# Compiles custom Rust GUI engines specifically tailored to the client's CPU
# Flags: -C target-cpu=native (Cargo.toml release: opt-level=3, lto, strip)
#
# Usage:
#   build.sh [--force|-f] [--if-stale] [--no-sudo] [--only crate1[,crate2...]]
# ==============================================================================
set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_ACCENT="\033[38;2;209;128;115m"
C_GREEN="\033[38;2;140;213;176m"
C_YELLOW="\033[38;2;224;196;108m"
C_RED="\033[38;2;255;180;171m"

log_info()    { printf "${C_ACCENT}::${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$1"; }
log_success() { printf "${C_GREEN}✓${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$1"; }
log_warn()    { printf "${C_YELLOW}!${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$1"; }
log_err()     { printf "${C_RED}✗${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$1" >&2; }

ALL_CRATES=("wallpaper-picker-rs" "display-picker-rs" "soberano-cockpit-bar-rs")
FORCE=false
IF_STALE=false
NO_SUDO=false
SELECTED_CRATES=()

while [ $# -gt 0 ]; do
    case "$1" in
        --force|-f)
            FORCE=true
            ;;
        --if-stale)
            IF_STALE=true
            ;;
        --no-sudo)
            NO_SUDO=true
            ;;
        --only)
            shift
            if [ $# -gt 0 ] && [ -n "$1" ]; then
                IFS=',' read -ra _parts <<< "$1"
                for p in "${_parts[@]}"; do
                    [ -n "$p" ] && SELECTED_CRATES+=("$p")
                done
            fi
            ;;
        --only=*)
            IFS=',' read -ra _parts <<< "${1#--only=}"
            for p in "${_parts[@]}"; do
                [ -n "$p" ] && SELECTED_CRATES+=("$p")
            done
            ;;
    esac
    shift
done

# Default mode: interactive terminal rebuilds all; non-interactive defaults to --if-stale
if [ ${#SELECTED_CRATES[@]} -eq 0 ]; then
    SELECTED_CRATES=("${ALL_CRATES[@]}")
    if [ "$FORCE" = false ] && [ "$IF_STALE" = false ]; then
        if [ ! -t 0 ] || [ ! -t 1 ]; then
            IF_STALE=true
        else
            FORCE=true
        fi
    fi
else
    # Explicit --only always builds the requested crates unless --if-stale was also passed
    if [ "$IF_STALE" = false ]; then
        FORCE=true
    fi
fi

is_binary_broken() {
    local bin_path="$1"
    if [ ! -x "$bin_path" ]; then
        return 0
    fi
    local rc=0
    WAYLAND_DISPLAY="" DISPLAY="" timeout 1 "$bin_path" --help >/dev/null 2>&1 || rc=$?
    # 132 = SIGILL (incompatible CPU instructions), 139 = SIGSEGV, 127 = missing loader/lib
    if [ "$rc" -eq 132 ] || [ "$rc" -eq 139 ] || [ "$rc" -eq 127 ]; then
        return 0
    fi
    return 1
}

crate_needs_build() {
    local crate="$1"
    local src_dir="$SCRIPT_DIR/$crate"
    local bin_path="$DOTFILES_DIR/scripts/$crate"

    [ -d "$src_dir" ] || return 1
    if [ "$FORCE" = true ]; then
        return 0
    fi
    if is_binary_broken "$bin_path"; then
        return 0
    fi
    # Check if any source or manifest file is newer than the compiled binary
    if find "$src_dir/src" "$src_dir/Cargo.toml" "$src_dir/Cargo.lock" -maxdepth 4 -type f -newer "$bin_path" 2>/dev/null | grep -q .; then
        return 0
    fi
    return 1
}

link_crate_binaries() {
    local crate="$1"
    local bin_path="$DOTFILES_DIR/scripts/$crate"
    [ -x "$bin_path" ] || return 0
    ln -sf "$bin_path" "$HOME/.local/bin/$crate"
    if [ "$crate" = "display-picker-rs" ]; then
        ln -sf "$bin_path" "$HOME/.local/bin/soberano-monitors"
        ln -sf "$bin_path" "$HOME/.local/bin/monitor-select"
    fi
}

mkdir -p "$HOME/.local/bin" "$DOTFILES_DIR/scripts"

TO_BUILD=()
for crate in "${SELECTED_CRATES[@]}"; do
    if crate_needs_build "$crate"; then
        TO_BUILD+=("$crate")
    else
        link_crate_binaries "$crate"
    fi
done

if [ ${#TO_BUILD[@]} -eq 0 ]; then
    log_success "Ferramentas nativas já atualizadas e compatíveis com esta CPU."
    exit 0
fi

# 1. Detect Host Microarchitecture
CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs 2>/dev/null || echo "Processador Nativo")
CPU_CORES=$(nproc 2>/dev/null || echo 4)
CPU_FLAGS=$(grep -m1 "flags" /proc/cpuinfo | cut -d: -f2 2>/dev/null || true)

VECTOR_EXT=""
echo "$CPU_FLAGS" | grep -qw "avx512f" && VECTOR_EXT+=" AVX-512"
echo "$CPU_FLAGS" | grep -qw "avx2"    && VECTOR_EXT+=" AVX2"
echo "$CPU_FLAGS" | grep -qw "fma"     && VECTOR_EXT+=" FMA"
echo "$CPU_FLAGS" | grep -qw "aes"     && VECTOR_EXT+=" AES-NI"
echo "$CPU_FLAGS" | grep -qw "sha_ni"  && VECTOR_EXT+=" SHA-NI"
[ -z "$VECTOR_EXT" ] && VECTOR_EXT=" SSE4.2 / Padrão"

log_info "Alvo de Compilação Nativa (${TO_BUILD[*]}):"
printf "   • CPU:        %s (%s threads)\n" "$CPU_MODEL" "$CPU_CORES"
printf "   • Vetores:   %s\n" "$VECTOR_EXT"
printf "   • RUSTFLAGS:  -C target-cpu=native\n\n"

# 2. Check Compiler Toolchain & GTK4 Development Libraries (never hang on sudo in background)
MISSING_PKGS=()
if ! command -v cargo >/dev/null 2>&1 || ! command -v rustc >/dev/null 2>&1; then
    MISSING_PKGS+=("rust")
fi
for pkg in gtk4 gtk4-layer-shell; do
    if ! pacman -Q "$pkg" >/dev/null 2>&1; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    if [ "$NO_SUDO" = true ] || [ ! -t 0 ]; then
        log_err "Dependências ausentes para compilação em segundo plano (${MISSING_PKGS[*]}). Instale via: sudo pacman -S --needed ${MISSING_PKGS[*]}"
        exit 1
    fi
    if command -v pacman >/dev/null 2>&1; then
        log_warn "Instalando dependências de compilação (${MISSING_PKGS[*]})..."
        sudo pacman -S --needed --noconfirm "${MISSING_PKGS[@]}"
    fi
fi

export RUSTFLAGS="-C target-cpu=native"
export CARGO_BUILD_JOBS="$CPU_CORES"

# 3. Compile Selected Crates
for crate in "${TO_BUILD[@]}"; do
    src_dir="$SCRIPT_DIR/$crate"
    if [ -d "$src_dir" ]; then
        log_info "Compilando $crate com otimizações de microarquitetura nativa..."
        (
            cd "$src_dir"
            cargo build --release --quiet
        )
        cp -f "$src_dir/target/release/$crate" "$DOTFILES_DIR/scripts/$crate"
        chmod +x "$DOTFILES_DIR/scripts/$crate"
        link_crate_binaries "$crate"
        log_success "$crate compilado e instalado com sucesso."
    fi
done

printf "\n"
log_success "Todas as ferramentas nativas selecionadas foram construídas para a máquina do cliente!"
