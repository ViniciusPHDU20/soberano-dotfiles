#!/usr/bin/env bash
# ==============================================================================
# SetupSwap - Creates a 32GB NVMe Swapfile and disables systemd-oomd
# Prevents Overwatch 2 and heavy games from being killed on memory spikes.
# ==============================================================================
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Este script precisa ser executado como root (sudo)." >&2
    exit 1
fi

SWAPFILE="/swapfile"
SWAP_SIZE="32G"

echo "=== Configurando Swap de 32GB no NVMe ==="

if [ ! -f "$SWAPFILE" ]; then
    echo "Alocando arquivo de swap de $SWAP_SIZE em $SWAPFILE..."
    fallocate -l "$SWAP_SIZE" "$SWAPFILE" 2>/dev/null || dd if=/dev/zero of="$SWAPFILE" bs=1M count=32768 status=progress
    chmod 600 "$SWAPFILE"
    mkswap "$SWAPFILE"
else
    echo "Arquivo $SWAPFILE já existe."
    chmod 600 "$SWAPFILE"
fi

# Ativa o swapfile se ainda não estiver ativo
if ! swapon --show | grep -q "$SWAPFILE"; then
    echo "Ativando $SWAPFILE..."
    swapon --priority 10 "$SWAPFILE"
fi

# Garante persistência no /etc/fstab
if ! grep -q "^[[:space:]]*$SWAPFILE" /etc/fstab 2>/dev/null; then
    echo "Adicionando $SWAPFILE ao /etc/fstab..."
    echo "$SWAPFILE none swap defaults,pri=10 0 0" >> /etc/fstab
fi

# Ajusta parâmetros de memória do kernel para jogos pesados
echo "Otimizando parâmetros de swap do kernel..."
sysctl -w vm.swappiness=60 >/dev/null 2>&1 || true
sysctl -w vm.vfs_cache_pressure=50 >/dev/null 2>&1 || true

cat << 'EOF' > /etc/sysctl.d/99-gaming-swap.conf
vm.swappiness = 60
vm.vfs_cache_pressure = 50
EOF

# Desativa o systemd-oomd que estava matando o processo do jogo aos 90%
echo "Desativando systemd-oomd agressivo..."
systemctl stop systemd-oomd 2>/dev/null || true
systemctl disable systemd-oomd 2>/dev/null || true
systemctl mask systemd-oomd 2>/dev/null || true

echo "=== Sucesso! Swap total atual: ==="
swapon --show
free -h
