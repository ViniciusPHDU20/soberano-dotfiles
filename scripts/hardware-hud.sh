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

        # Output percent only (no hover tooltip, opens dropdown on click)
        printf '{"percent": %d}\n' "$CPU_USAGE"
        ;;

    ram)
        # RAM metrics in GiB
        TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        AVAIL_KB=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        USED_KB=$(( TOTAL_KB - AVAIL_KB ))
        RAM_PERCENT=$(( USED_KB * 100 / TOTAL_KB ))

        printf '{"percent": %d}\n' "$RAM_PERCENT"
        ;;

    storage)
        # Disk usage of /
        DISK_DATA=$(df -h / | tail -1)
        DISK_PERCENT=$(echo "$DISK_DATA" | awk '{print $5}' | tr -d '%')

        printf '{"percent": %d}\n' "$DISK_PERCENT"
        ;;
esac
