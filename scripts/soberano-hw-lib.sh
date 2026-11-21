#!/usr/bin/env bash
# ==============================================================================
# Soberano Hardware Layer — shared probe + safe sysfs writers
# Sourced by soberano-power-profile.sh and GameMode.sh. Never executed directly.
#
# Why this file exists:
#
#  1. "powersave" is not one governor, it is two different governors wearing the
#     same name. On intel_pstate / amd-pstate it means *dynamic* scaling. On
#     acpi-cpufreq it means *static minimum frequency* — writing it there pins the
#     CPU to its floor forever, which is a bricked desktop, not a balanced one.
#     sob_pick_governor() resolves the correct name per driver.
#
#  2. A frequency ceiling must come from each core's own cpuinfo_max_freq.
#     Writing cpu0's ceiling to every core fails with EINVAL on hybrid CPUs
#     (Intel P+E, some AMD), so the E-cores silently keep whatever clamp the
#     previous profile wrote — a permanent loss of clocks until reboot.
#
#  3. Every write is batched into one root shell. 32 cores * 4 files * sudo is
#     slow enough to be felt on the keybind.
# ==============================================================================

SOB_RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
SOB_STATE_DIR="${SOB_RUNTIME}/soberano-power"
SOB_SNAP_DIR="${SOB_STATE_DIR}/cpu-limits"
SOB_PROFILE_STATE="${SOB_RUNTIME}/soberano_power_profile.state"
SOB_DRY_RUN="${SOB_DRY_RUN:-false}"

# -----------------------------------------------------------------------------
# Core helpers
# -----------------------------------------------------------------------------
sob_read() { cat "$1" 2>/dev/null || true; }

# sob_root <snippet> — run a shell snippet as root, or print it in dry-run.
sob_root() {
    local snippet="$1"
    [ -z "$snippet" ] && return 0
    if [ "$SOB_DRY_RUN" = true ]; then
        printf '%s\n' "$snippet" | sed 's/^/  [dry] /' >&2
        return 0
    fi
    printf '%s\n' "$snippet" | sudo sh -s 2>/dev/null || true
}

sob_has_cpufreq() { [ -d /sys/devices/system/cpu/cpu0/cpufreq ]; }

# -----------------------------------------------------------------------------
# CPU identity
# -----------------------------------------------------------------------------
sob_cpu_name() {
    local n=""
    n=$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null || true)
    if [ -z "$n" ]; then
        n=$(lscpu 2>/dev/null | awk -F': +' '/Model name/ {print $2; exit}' || true)
    fi
    n=$(printf '%s' "$n" | sed -E 's/\(R\)|\(TM\)|\(tm\)|\(r\)//g; s/[[:space:]]+/ /g; s/^ //; s/ $//')
    [ -n "$n" ] || n="CPU"
    printf '%s' "$n"
}

sob_cpu_threads() { nproc 2>/dev/null || echo 1; }

# -----------------------------------------------------------------------------
# cpufreq driver / governor policy
# -----------------------------------------------------------------------------
sob_cpu_driver() {
    [ -n "${SOB_FAKE_DRIVER:-}" ] && { printf '%s' "$SOB_FAKE_DRIVER"; return 0; }
    sob_read /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver
}

sob_cpu_govs() {
    [ -n "${SOB_FAKE_GOVS:-}" ] && { printf '%s' "$SOB_FAKE_GOVS"; return 0; }
    sob_read /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors
}

sob_has_gov() {
    local want="$1" g
    for g in $(sob_cpu_govs); do
        [ "$g" = "$want" ] && return 0
    done
    return 1
}

# sob_pick_governor <eco|balanced|compute> — echoes a governor name, or nothing.
sob_pick_governor() {
    local mode="$1" driver govs g
    driver=$(sob_cpu_driver)
    govs=$(sob_cpu_govs)
    [ -z "$govs" ] && return 0

    case "$driver" in
        *pstate*)
            # powersave == dynamic here. EPP carries the actual bias.
            if [ "$mode" = "compute" ] && sob_has_gov performance; then
                printf '%s' performance; return 0
            fi
            if sob_has_gov powersave; then
                printf '%s' powersave; return 0
            fi
            ;;
    esac

    case "$mode" in
        compute)
            for g in performance conservative; do
                sob_has_gov "$g" && { printf '%s' "$g"; return 0; }
            done
            ;;
        eco)
            # powersave on acpi-cpufreq / intel_cpufreq is a static floor — exactly
            # what eco wants. On *pstate it was already resolved above.
            for g in powersave conservative; do
                sob_has_gov "$g" && { printf '%s' "$g"; return 0; }
            done
            ;;
        *)
            # Balanced on a non-pstate driver: powersave here would pin the CPU to
            # its floor, so it is never a candidate. If the kernel offers no dynamic
            # governor at all, a ceiling beats a floor — but only as a last resort.
            for g in schedutil ondemand conservative; do
                sob_has_gov "$g" && { printf '%s' "$g"; return 0; }
            done
            sob_has_gov performance && { printf '%s' performance; return 0; }
            ;;
    esac
    return 0
}

sob_gov_snippet() {
    local g="$1"
    [ -z "$g" ] && return 0
    printf 'for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo %s > "$f" 2>/dev/null; done' "$g"
}

# -----------------------------------------------------------------------------
# Energy Performance Preference (EPP) — only where the driver exposes it
# -----------------------------------------------------------------------------
sob_epp_supported() {
    [ -e /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ]
}

sob_epp_snippet() {
    local v="$1"
    sob_epp_supported || return 0
    case "$v" in
        performance|balance_performance|balance_power|power|default) ;;
        *) return 0 ;;
    esac
    printf 'for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo %s > "$f" 2>/dev/null; done' "$v"
}

# -----------------------------------------------------------------------------
# Turbo / boost — the knob is inverted on intel_pstate
# -----------------------------------------------------------------------------
sob_boost_kind() {
    if [ -e /sys/devices/system/cpu/cpufreq/boost ]; then
        echo boost
    elif [ -e /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
        echo no_turbo
    else
        echo none
    fi
}

sob_set_boost() { # on|off
    local want="$1" kind
    kind=$(sob_boost_kind)
    case "$kind" in
        boost)
            if [ "$want" = "on" ]; then echo 'echo 1 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null'
            else echo 'echo 0 > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null'; fi
            ;;
        no_turbo)
            if [ "$want" = "on" ]; then echo 'echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null'
            else echo 'echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null'; fi
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Per-core frequency snapshot — the fix for hybrid P/E core ceilings
# -----------------------------------------------------------------------------
sob_snapshot_limits() {
    [ "$SOB_DRY_RUN" = true ] && return 0
    [ -d "$SOB_SNAP_DIR" ] && [ -n "$(ls -A "$SOB_SNAP_DIR" 2>/dev/null)" ] && return 0
    mkdir -p "$SOB_SNAP_DIR" 2>/dev/null || return 0
    local d cpu v
    for d in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        [ -d "$d" ] || continue
        cpu=$(basename "$(dirname "$d")")
        v=$(sob_read "$d/cpuinfo_max_freq")
        [ -n "$v" ] && printf '%s' "$v" > "$SOB_SNAP_DIR/$cpu" 2>/dev/null
    done
    return 0
}

# Per-core restore: each core goes back to its own recorded ceiling.
sob_restore_snippet() {
    local f cpu v
    if [ -d "$SOB_SNAP_DIR" ] && [ -n "$(ls -A "$SOB_SNAP_DIR" 2>/dev/null)" ]; then
        for f in "$SOB_SNAP_DIR"/cpu[0-9]*; do
            [ -f "$f" ] || continue
            cpu=${f##*/cpu}
            v=$(cat "$f" 2>/dev/null || true)
            [ -n "$v" ] && printf 'echo %s > /sys/devices/system/cpu/cpu%s/cpufreq/scaling_max_freq 2>/dev/null\n' "$v" "$cpu"
        done
    else
        sob_ceiling_snippet
    fi
}

# Each core to its own hardware maximum.
sob_ceiling_snippet() {
    local d cpu v
    for d in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        [ -d "$d" ] || continue
        cpu=$(basename "$(dirname "$d")"); cpu=${cpu#cpu}
        v=$(sob_read "$d/cpuinfo_max_freq")
        [ -n "$v" ] && printf 'echo %s > /sys/devices/system/cpu/cpu%s/cpufreq/scaling_max_freq 2>/dev/null\n' "$v" "$cpu"
    done
}

# Each core to its own hardware minimum.
sob_floor_snippet() {
    local d cpu v
    for d in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        [ -d "$d" ] || continue
        cpu=$(basename "$(dirname "$d")"); cpu=${cpu#cpu}
        v=$(sob_read "$d/cpuinfo_min_freq")
        [ -n "$v" ] && printf 'echo %s > /sys/devices/system/cpu/cpu%s/cpufreq/scaling_max_freq 2>/dev/null\n' "$v" "$cpu"
    done
}

# Highest and lowest ceiling across the package — for notifications.
sob_cpu_min_ghz() {
    local d v lo=""
    for d in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        [ -d "$d" ] || continue
        v=$(sob_read "$d/cpuinfo_min_freq")
        [ -z "$v" ] && continue
        if [ -z "$lo" ] || [ "$v" -lt "$lo" ]; then lo="$v"; fi
    done
    [ -n "$lo" ] || lo=600000
    awk "BEGIN {printf \"%.2f\", $lo / 1000000}"
}

sob_cpu_max_ghz() {
    local d v hi=""
    for d in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        [ -d "$d" ] || continue
        v=$(sob_read "$d/cpuinfo_max_freq")
        [ -z "$v" ] && continue
        if [ -z "$hi" ] || [ "$v" -gt "$hi" ]; then hi="$v"; fi
    done
    [ -n "$hi" ] || hi=5000000
    awk "BEGIN {printf \"%.2f\", $hi / 1000000}"
}

# -----------------------------------------------------------------------------
# GPU: NVIDIA
# -----------------------------------------------------------------------------
sob_nv_ok() {
    command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1
}

sob_nv_clk() { # min|max
    local q="clocks.min.graphics"
    [ "$1" = "max" ] && q="clocks.max.graphics"
    nvidia-smi --query-gpu="$q" --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -dc '0-9' || true
}

sob_nv_pl() { # min|max  (watts, integer)
    local info
    info=$(nvidia-smi -q -d POWER 2>/dev/null || true)
    if [ "$1" = "min" ]; then
        printf '%s' "$info" | grep -m1 "Min Power Limit" | awk '{print $5}' | cut -d. -f1
    else
        printf '%s' "$info" | grep -m1 "Max Power Limit" | awk '{print $5}' | cut -d. -f1
    fi
}

# -----------------------------------------------------------------------------
# GPU: AMD (amdgpu sysfs DPM)
# -----------------------------------------------------------------------------
sob_amd_gpu_ok() {
    local d
    for d in /sys/class/drm/card*/device/power_dpm_force_performance_level; do
        [ -f "$d" ] && return 0
    done
    return 1
}

sob_amd_gpu_snippet() { # low|auto|high
    local lvl="$1"
    printf 'for d in /sys/class/drm/card*/device/power_dpm_force_performance_level; do [ -f "$d" ] && echo %s > "$d" 2>/dev/null; done' "$lvl"
}

# -----------------------------------------------------------------------------
# Platform profile — power-profiles-daemon first, firmware knob as fallback
# -----------------------------------------------------------------------------
sob_set_platform_profile() { # power-saver|balanced|performance
    local target="$1" ap v
    if command -v powerprofilesctl >/dev/null 2>&1; then
        if powerprofilesctl set "$target" >/dev/null 2>&1; then
            return 0
        fi
    fi
    ap=/sys/firmware/acpi/platform_profile
    [ -e "$ap" ] || return 0
    case "$target" in
        power-saver) v=low-power ;;
        performance) v=performance ;;
        *)           v=balanced ;;
    esac
    sob_root "echo $v > $ap 2>/dev/null"
}

# -----------------------------------------------------------------------------
# Probe dump — support ticket / audit output
# -----------------------------------------------------------------------------
sob_probe() {
    local epp="no" nv="no" amd="no" plat
    sob_epp_supported && epp="yes"
    if sob_nv_ok; then nv="yes ($(sob_nv_pl min)-$(sob_nv_pl max)W)"; fi
    sob_amd_gpu_ok && amd="yes"
    plat=$(sob_read /sys/firmware/acpi/platform_profile)
    [ -n "$plat" ] || plat="n/a"

    printf 'cpu        : %s\n' "$(sob_cpu_name)"
    printf 'threads    : %s\n' "$(sob_cpu_threads)"
    printf 'driver     : %s\n' "$(sob_cpu_driver)"
    printf 'governors  : %s\n' "$(sob_cpu_govs)"
    printf 'epp        : %s\n' "$epp"
    printf 'boost knob : %s\n' "$(sob_boost_kind)"
    printf 'clocks     : %s - %s GHz\n' "$(sob_cpu_min_ghz)" "$(sob_cpu_max_ghz)"
    printf 'gpu nvidia : %s\n' "$nv"
    printf 'gpu amd    : %s\n' "$amd"
    printf 'platform   : %s\n' "$plat"
    printf 'profile    : %s\n' "$(cat "$SOB_PROFILE_STATE" 2>/dev/null || echo balanced)"
}
