#!/usr/bin/env bash
#  __        __    _ _                              ____       _        _   _
#  \ \      / /_ _| | |_ __   __ _ _ __   ___ _ __|  _ \ ___ | |_ __ _| |_(_) ___  _ __
#   \ \ /\ / / _` | | | '_ \ / _` | '_ \ / _ \ '__| |_) / _ \| __/ _` | __| |/ _ \| '_ \
#    \ V  V / (_| | | | |_) | (_| | |_) |  __/ |  |  _ < (_) | || (_| | |_| | (_) | | | |
#     \_/\_/ \__,_|_|_| .__/ \__,_| .__/ \___|_|  |_| \_\___/ \__\__,_|\__|_|\___/|_| |_|
#                      |_|        |_|
#
# Per-monitor wallpaper rotation for dual-monitor setups (DP-1 / DP-2)
# Drop-in replacement for ml4w wallpaper-automation.sh

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
ml4w_cache_folder="$HOME/.cache/ml4w/hyprland-dotfiles"
marker_file="$ml4w_cache_folder/wallpaper-automation"
history_file="$ml4w_cache_folder/rotation-history"

# Logging
LOG_FILE="$HOME/.cache/ml4w/hyprland-dotfiles/wallpaper-rotation.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Truncate log if over 100KB (keep last ~500 lines)
if [ -f "$LOG_FILE" ] && [ "$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)" -gt 102400 ]; then
    tail -n 500 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

exec >> "$LOG_FILE" 2>&1

_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Notifications
source "$HOME/.config/ml4w/scripts/notification-handler.sh"
APP_NAME="Wallpaper Rotation"
NOTIFICATION_ICON="preferences-desktop-wallpaper-symbolic"

# -----------------------------------------------------
# Read configuration
# -----------------------------------------------------

conf_file="$SCRIPT_DIR/rotation.conf"

_load_config() {
    SECS=0
    if [ -f "$conf_file" ]; then
        source "$conf_file"
    else
        DAYS=0
        HOURS=1
        MINUTES=0
        SECS=0
    fi
    interval=$(( DAYS * 86400 + HOURS * 3600 + MINUTES * 60 + SECS ))
    if [ "$interval" -lt 10 ]; then
        interval=10
    fi
}

_build_human_interval() {
    human_interval=""
    if [ "$DAYS" -gt 0 ]; then
        human_interval="${DAYS}d "
    fi
    if [ "$HOURS" -gt 0 ]; then
        human_interval="${human_interval}${HOURS}h "
    fi
    if [ "$MINUTES" -gt 0 ]; then
        human_interval="${human_interval}${MINUTES}m "
    fi
    if [ "$SECS" -gt 0 ]; then
        human_interval="${human_interval}${SECS}s"
    fi
    human_interval="${human_interval:-${interval}s}"
}

_load_config
_build_human_interval

# -----------------------------------------------------
# Determine wallpaper folder
# -----------------------------------------------------

wp_folder_setting="$HOME/.config/ml4w/settings/wallpaper-folder"
if [ -f "$wp_folder_setting" ]; then
    wp_folder=$(cat "$wp_folder_setting")
    # Expand ~ and $HOME
    wp_folder="${wp_folder/#\~/$HOME}"
    wp_folder="${wp_folder/\$HOME/$HOME}"
fi

# Fall back to waypaper config, then default
if [ -z "$wp_folder" ] || [ ! -d "$wp_folder" ]; then
    waypaper_conf="$HOME/.config/waypaper/config.ini"
    if [ -f "$waypaper_conf" ]; then
        wp_folder=$(grep -oP '^folder\s*=\s*\K.*' "$waypaper_conf" | tr -d ' ')
        wp_folder="${wp_folder/#\~/$HOME}"
        wp_folder="${wp_folder/\$HOME/$HOME}"
    fi
fi

if [ -z "$wp_folder" ] || [ ! -d "$wp_folder" ]; then
    wp_folder="$HOME/.config/ml4w/wallpapers"
fi

# -----------------------------------------------------
# --once mode: pick random wallpapers, apply, exit
# -----------------------------------------------------

if [ "$1" = "--once" ]; then
    # Prevent concurrent --once invocations (e.g., keybind spam)
    LOCK_FILE="/tmp/wallpaper-rotation-once.lock"
    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        _log ":: Wallpaper change already in progress, skipping"
        exit 0
    fi

    # List wallpapers (common image extensions)
    mapfile -t all_wallpapers < <(find "$wp_folder" -maxdepth 1 -type f \( \
        -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
        -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \
    \) | sort)

    total=${#all_wallpapers[@]}
    if [ "$total" -lt 2 ]; then
        _log ":: ERROR: Need at least 2 wallpapers in $wp_folder"
        exit 1
    fi

    # Read history (last 2 used wallpapers)
    exclude1=""
    exclude2=""
    if [ -f "$history_file" ]; then
        exclude1=$(sed -n '1p' "$history_file")
        exclude2=$(sed -n '2p' "$history_file")
    fi

    # Build pool excluding history
    pool=()
    for wp in "${all_wallpapers[@]}"; do
        if [ "$wp" != "$exclude1" ] && [ "$wp" != "$exclude2" ]; then
            pool+=("$wp")
        fi
    done

    # Fallback if pool too small
    if [ "${#pool[@]}" -lt 2 ]; then
        pool=("${all_wallpapers[@]}")
    fi

    # Pick 2 random wallpapers
    mapfile -t picks < <(printf '%s\n' "${pool[@]}" | shuf -n 2)
    wp1="${picks[0]}"
    wp2="${picks[1]}"

    _log ":: DP-1: $(basename "$wp1")"
    _log ":: DP-2: $(basename "$wp2")"

    # Set DP-1
    swww img "$wp1" \
        --outputs DP-1 \
        --transition-type grow \
        --transition-step 90 \
        --transition-duration 2 >/dev/null 2>&1

    # Set DP-2
    swww img "$wp2" \
        --outputs DP-2 \
        --transition-type grow \
        --transition-step 90 \
        --transition-duration 2 >/dev/null 2>&1

    # Run the full ml4w pipeline for DP-1 (matugen, blur, lockscreen, waybar, etc.)
    "$HOME/.config/hypr/scripts/wallpaper.sh" "$wp1" >/dev/null 2>&1

    # Re-apply DP-2 wallpaper in case wallpaper.sh reset all monitors
    swww img "$wp2" \
        --outputs DP-2 \
        --transition-type grow \
        --transition-step 90 \
        --transition-duration 2 >/dev/null 2>&1

    # Write history
    printf '%s\n%s\n' "$wp1" "$wp2" > "$history_file"

    exit 0
fi

# -----------------------------------------------------
# Toggle: stop if already running
# -----------------------------------------------------

if [ -f "$marker_file" ]; then
    rm -f "$marker_file"
    notify_user \
        --a "${APP_NAME}" \
        --i "${NOTIFICATION_ICON}" \
        --m "Wallpaper rotation stopped."
    _log ":: Wallpaper rotation stopped"
    # Kill other instances of this script
    other_pids=$(pgrep -f "wallpaper-automation.sh" | grep -v "$$")
    if [ -n "$other_pids" ]; then
        kill $other_pids 2>/dev/null
    fi
    # Also match our own script name in case launched directly
    other_pids=$(pgrep -f "wallpaper-rotation.sh" | grep -v "$$")
    if [ -n "$other_pids" ]; then
        kill $other_pids 2>/dev/null
    fi
    exit 0
fi

# -----------------------------------------------------
# Start rotation
# -----------------------------------------------------

mkdir -p "$ml4w_cache_folder"
touch "$marker_file"

# Clean shutdown on signals
cleanup() {
    rm -f "$marker_file"
    exit 0
}
trap cleanup SIGTERM SIGINT SIGHUP

notify_user \
    --a "${APP_NAME}" \
    --i "${NOTIFICATION_ICON}" \
    --m "Wallpaper rotation started.\nInterval: ${human_interval}\nMonitors: DP-1, DP-2"
_log ":: Wallpaper rotation started (interval: ${interval}s)"

# -----------------------------------------------------
# Main loop
# -----------------------------------------------------

while [ -f "$marker_file" ]; do

    # Re-read config (allows live changes without restart)
    _old_interval="$interval"
    _load_config
    _build_human_interval
    if [ "$interval" != "$_old_interval" ]; then
        _log ":: Config changed: interval is now ${human_interval} (${interval}s)"
    fi

    # List wallpapers (common image extensions)
    mapfile -t all_wallpapers < <(find "$wp_folder" -maxdepth 1 -type f \( \
        -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
        -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \
    \) | sort)

    total=${#all_wallpapers[@]}
    if [ "$total" -lt 2 ]; then
        _log ":: ERROR: Need at least 2 wallpapers in $wp_folder"
        sleep "$interval"
        continue
    fi

    # Read history (last 2 used wallpapers)
    exclude1=""
    exclude2=""
    if [ -f "$history_file" ]; then
        exclude1=$(sed -n '1p' "$history_file")
        exclude2=$(sed -n '2p' "$history_file")
    fi

    # Build pool excluding history
    pool=()
    for wp in "${all_wallpapers[@]}"; do
        if [ "$wp" != "$exclude1" ] && [ "$wp" != "$exclude2" ]; then
            pool+=("$wp")
        fi
    done

    # Fallback if pool too small
    if [ "${#pool[@]}" -lt 2 ]; then
        _log ":: WARNING: Pool too small after exclusions, using full wallpaper list"
        pool=("${all_wallpapers[@]}")
    fi

    # Pick 2 random wallpapers
    mapfile -t picks < <(printf '%s\n' "${pool[@]}" | shuf -n 2)
    wp1="${picks[0]}"
    wp2="${picks[1]}"

    _log ":: DP-1: $(basename "$wp1")"
    _log ":: DP-2: $(basename "$wp2")"

    # Set DP-1
    swww img "$wp1" \
        --outputs DP-1 \
        --transition-type grow \
        --transition-step 90 \
        --transition-duration 2 >/dev/null 2>&1

    # Set DP-2
    swww img "$wp2" \
        --outputs DP-2 \
        --transition-type grow \
        --transition-step 90 \
        --transition-duration 2 >/dev/null 2>&1

    # Run the full ml4w pipeline for DP-1 (matugen, blur, lockscreen, waybar, etc.)
    "$HOME/.config/hypr/scripts/wallpaper.sh" "$wp1" >/dev/null 2>&1

    # Re-apply DP-2 wallpaper in case wallpaper.sh's effects mode
    # called `waypaper --wallpaper` which resets all monitors
    swww img "$wp2" \
        --outputs DP-2 \
        --transition-type grow \
        --transition-step 90 \
        --transition-duration 2 >/dev/null 2>&1

    # Write history
    printf '%s\n%s\n' "$wp1" "$wp2" > "$history_file"

    _log ":: Next rotation in ${human_interval} (${interval}s)..."
    sleep "$interval" &
    wait $!
done
