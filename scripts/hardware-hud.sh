#!/usr/bin/env bash
# ==============================================================================
# Soberano Hardware HUD & Dynamic Tooltip Provider
# Generates rich JSON data for Wayle bar hover miniatures and percentages
# ==============================================================================
set -euo pipefail

case "${1:-cpu}" in
    cpu)
        # Usage %
        # Read from /proc/stat
        CPU_USAGE=$(awk '{u=$2+$4; t=$2+$4+$5; if (NR==1){u1=u; t1=t;} else print int(($2+$4-u1) * 100 / (t-t1))}' \
            <(grep 'cpu ' /proc/stat) <(sleep 0.1; grep 'cpu ' /proc/stat) 2>/dev/null || echo 5)
        [ -z "$CPU_USAGE" ] && CPU_USAGE=5

        # Frequency
        FREQ_MHZ=$(grep -m1 "cpu MHz" /proc/cpuinfo | awk '{print int($4)}' 2>/dev/null || echo 4000)
        FREQ_GHZ=$(awk "BEGIN {printf \"%.2f\", $FREQ_MHZ/1000}")

        # Temperature
        TEMP="N/A"
        for s in /sys/class/hwmon/hwmon*/temp1_input; do
            if [ -f "$s" ]; then
                raw=$(cat "$s" 2>/dev/null || true)
                if [ -n "$raw" ] && [ "$raw" -gt 0 ]; then
                    TEMP="$(( raw / 1000 ))°C"
                    break
                fi
            fi
        done

        # CPU Model
        CPU_NAME=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed -E 's/ [0-9]+-Core.*//; s/ Processor//; s/ CPU//; s/@.*//' | xargs 2>/dev/null || echo "Processador")
        CORES=$(nproc 2>/dev/null || echo 8)

        # Top 2 processes
        TOP_PROC=$(ps -eo comm,%cpu --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=3 {printf "  ▸ %s: %s%%\\n", $1, $2}')

        TOOLTIP="󰍛 ${CPU_NAME} (${CORES}t)\n• Uso Atual: ${CPU_USAGE}%\n• Frequência: ${FREQ_GHZ} GHz\n• Temperatura: ${TEMP}\n• Top Processos:\n${TOP_PROC}"
        # Strip trailing newline
        TOOLTIP=$(printf "%b" "$TOOLTIP" | awk '{printf "%s%s", (NR>1 ? "\\n" : ""), $0}')

        printf '{"percent": %d, "tooltip": "%s"}\n' "$CPU_USAGE" "$TOOLTIP"
        ;;

    ram)
        # RAM metrics in GiB
        TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        AVAIL_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        USED_KB=$(( TOTAL_KB - AVAIL_KB ))

        USED_GIB=$(awk "BEGIN {printf \"%.1f\", $USED_KB/1024/1024}")
        TOTAL_GIB=$(awk "BEGIN {printf \"%.1f\", $TOTAL_KB/1024/1024}")
        RAM_PERCENT=$(( USED_KB * 100 / TOTAL_KB ))

        # Swap
        SWAP_TOTAL=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
        SWAP_FREE=$(grep SwapFree /proc/meminfo | awk '{print $2}')
        SWAP_USED=$(( SWAP_TOTAL - SWAP_FREE ))
        SWAP_GIB=$(awk "BEGIN {printf \"%.1f\", $SWAP_USED/1024/1024}")

        # Top 2 RAM consumers
        TOP_RAM=$(ps -eo comm,%mem --sort=-%mem 2>/dev/null | awk 'NR>1 && NR<=3 {printf "  ▸ %s: %s%%\\n", $1, $2}')

        TOOLTIP="󰘚 Memória do Sistema\n• Em Uso: ${USED_GIB} GiB / ${TOTAL_GIB} GiB (${RAM_PERCENT}%)\n• Swap Usado: ${SWAP_GIB} GiB\n• Top Processos:\n${TOP_RAM}"
        TOOLTIP=$(printf "%b" "$TOOLTIP" | awk '{printf "%s%s", (NR>1 ? "\\n" : ""), $0}')

        printf '{"percent": %d, "tooltip": "%s"}\n' "$RAM_PERCENT" "$TOOLTIP"
        ;;

    storage)
        # Disk usage of /
        DISK_DATA=$(df -h / | tail -1)
        DISK_SIZE=$(echo "$DISK_DATA" | awk '{print $2}')
        DISK_USED=$(echo "$DISK_DATA" | awk '{print $3}')
        DISK_AVAIL=$(echo "$DISK_DATA" | awk '{print $4}')
        DISK_PERCENT=$(echo "$DISK_DATA" | awk '{print $5}' | tr -d '%')

        TOOLTIP="󰋊 Armazenamento Principal (/)\n• Ocupado: ${DISK_USED} de ${DISK_SIZE} (${DISK_PERCENT}%)\n• Livre: ${DISK_AVAIL} disponível"
        TOOLTIP=$(printf "%b" "$TOOLTIP" | awk '{printf "%s%s", (NR>1 ? "\\n" : ""), $0}')

        printf '{"percent": %d, "tooltip": "%s"}\n' "$DISK_PERCENT" "$TOOLTIP"
        ;;
esac
