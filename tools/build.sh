#!/usr/bin/env bash
# ==============================================================================
# Soberano Native Tool Suite - Machine-Optimized Compiler
# Compiles custom Rust GUI engines specifically tailored to the client's CPU
# Flags: -C target-cpu=native -C opt-level=3 (AVX-512 / AVX2 / FMA / Zen / Intel)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_ACCENT="\033[38;2;209;128;115m"
C_GREEN="\033[38;2;140;213;176m"
C_YELLOW="\033[38;2;224;196;108m"

log_info()    { printf "${C_ACCENT}::${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$1"; }
log_success() { printf "${C_GREEN}✓${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$1"; }
log_warn()    { printf "${C_YELLOW}!${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$1"; }

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

log_info "Alvo de Compilação Nativa:"
printf "   • CPU:        %s (%s threads)\n" "$CPU_MODEL" "$CPU_CORES"
printf "   • Vetores:   %s\n" "$VECTOR_EXT"
printf "   • RUSTFLAGS:  -C target-cpu=native -C opt-level=3\n\n"

# 2. Check Compiler Toolchain
if ! command -v cargo >/dev/null 2>&1 || ! command -v rustc >/dev/null 2>&1; then
    log_warn "Cargo/Rust não detectado. Instalando rust via gerenciador de pacotes..."
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm rust
    fi
fi

# Ensure GTK4 and Layer-Shell development libraries exist
MISSING_PKGS=()
for pkg in gtk4 gtk4-layer-shell; do
    if ! pacman -Q "$pkg" >/dev/null 2>&1; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    log_warn "Instalando dependências de desenvolvimento GTK4 (${MISSING_PKGS[*]})..."
    sudo pacman -S --needed --noconfirm "${MISSING_PKGS[@]}"
fi

export RUSTFLAGS="-C target-cpu=native"
export CARGO_BUILD_JOBS="$CPU_CORES"

mkdir -p "$HOME/.local/bin" "$DOTFILES_DIR/scripts"

# 3. Compile Wallpaper Picker (GTK4 Layer-Shell)
if [ -d "$SCRIPT_DIR/wallpaper-picker-rs" ]; then
    log_info "Compilando wallpaper-picker-rs com otimizações de microarquitetura nativa..."
    (
        cd "$SCRIPT_DIR/wallpaper-picker-rs"
        cargo build --release --quiet
    )
    cp -f "$SCRIPT_DIR/wallpaper-picker-rs/target/release/wallpaper-picker-rs" "$DOTFILES_DIR/scripts/wallpaper-picker-rs"
    ln -sf "$DOTFILES_DIR/scripts/wallpaper-picker-rs" "$HOME/.local/bin/wallpaper-picker-rs"
    chmod +x "$DOTFILES_DIR/scripts/wallpaper-picker-rs"
    log_success "wallpaper-picker-rs compilado e instalado com sucesso."
fi

# 4. Compile Display & Refresh Rate Picker (GTK4 Layer-Shell)
if [ -d "$SCRIPT_DIR/display-picker-rs" ]; then
    log_info "Compilando display-picker-rs com otimizações de microarquitetura nativa..."
    (
        cd "$SCRIPT_DIR/display-picker-rs"
        cargo build --release --quiet
    )
    cp -f "$SCRIPT_DIR/display-picker-rs/target/release/display-picker-rs" "$DOTFILES_DIR/scripts/display-picker-rs"
    ln -sf "$DOTFILES_DIR/scripts/display-picker-rs" "$HOME/.local/bin/display-picker-rs"
    ln -sf "$DOTFILES_DIR/scripts/display-picker-rs" "$HOME/.local/bin/soberano-monitors"
    ln -sf "$DOTFILES_DIR/scripts/display-picker-rs" "$HOME/.local/bin/monitor-select"
    chmod +x "$DOTFILES_DIR/scripts/display-picker-rs"
    log_success "display-picker-rs compilado e instalado com sucesso."
fi

printf "\n"
log_success "Todas as ferramentas nativas foram construídas para a máquina do cliente!"
