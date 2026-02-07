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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ml4w_cache_folder="$HOME/.cache/ml4w/hyprland-dotfiles"
marker_file="$ml4w_cache_folder/wallpaper-automation"
history_file="$ml4w_cache_folder/rotation-history"

# Notifications
source "$HOME/.config/ml4w/scripts/notification-handler.sh"
APP_NAME="Wallpaper Rotation"
NOTIFICATION_ICON="preferences-desktop-wallpaper-symbolic"

# -----------------------------------------------------
# Read configuration
# -----------------------------------------------------

conf_file="$SCRIPT_DIR/rotation.conf"
if [ -f "$conf_file" ]; then
    source "$conf_file"
else
    DAYS=0
    HOURS=1
    MINUTES=0
fi
interval=$(( DAYS * 86400 + HOURS * 3600 + MINUTES * 60 ))
if [ "$interval" -lt 10 ]; then
    interval=10
fi

# -----------------------------------------------------
# Determine wallpaper folder
# -----------------------------------------------------

wp_folder_setting="$HOME/.config/ml4w/settings/wallpaper-folder"
if [ -f "$wp_folder_setting" ]; then
    wp_folder=$(cat "$wp_folder_setting")
    # Expand $HOME if present
    wp_folder="${wp_folder/\$HOME/$HOME}"
else
    wp_folder="$HOME/.config/ml4w/wallpapers"
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
    echo ":: Wallpaper rotation stopped"
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

human_interval=""
if [ "$DAYS" -gt 0 ]; then
    human_interval="${DAYS}d "
fi
if [ "$HOURS" -gt 0 ]; then
    human_interval="${human_interval}${HOURS}h "
fi
if [ "$MINUTES" -gt 0 ]; then
    human_interval="${human_interval}${MINUTES}m"
fi
human_interval="${human_interval:-${interval}s}"

notify_user \
    --a "${APP_NAME}" \
    --i "${NOTIFICATION_ICON}" \
    --m "Wallpaper rotation started.\nInterval: ${human_interval}\nMonitors: DP-1, DP-2"
echo ":: Wallpaper rotation started (interval: ${interval}s)"

# -----------------------------------------------------
# Main loop
# -----------------------------------------------------

while [ -f "$marker_file" ]; do

    # List wallpapers (common image extensions)
    mapfile -t all_wallpapers < <(find "$wp_folder" -maxdepth 1 -type f \( \
        -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
        -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \
    \) | sort)

    total=${#all_wallpapers[@]}
    if [ "$total" -lt 2 ]; then
        echo ":: ERROR: Need at least 2 wallpapers in $wp_folder"
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
        echo ":: WARNING: Pool too small after exclusions, using full wallpaper list"
        pool=("${all_wallpapers[@]}")
    fi

    # Pick 2 random wallpapers
    mapfile -t picks < <(printf '%s\n' "${pool[@]}" | shuf -n 2)
    wp1="${picks[0]}"
    wp2="${picks[1]}"

    echo ":: DP-1: $(basename "$wp1")"
    echo ":: DP-2: $(basename "$wp2")"

    # Set DP-1
    swww img "$wp1" \
        --outputs DP-1 \
        --transition-type grow \
        --transition-step 90 \
        --transition-duration 2

    # Set DP-2
    swww img "$wp2" \
        --outputs DP-2 \
        --transition-type grow \
        --transition-step 90 \
        --transition-duration 2

    # Run the full ml4w pipeline for DP-1 (matugen, blur, lockscreen, waybar, etc.)
    "$HOME/.config/hypr/scripts/wallpaper.sh" "$wp1"

    # Re-apply DP-2 wallpaper in case wallpaper.sh's effects mode
    # called `waypaper --wallpaper` which resets all monitors
    swww img "$wp2" \
        --outputs DP-2 \
        --transition-type grow \
        --transition-step 90 \
        --transition-duration 2

    # Write history
    printf '%s\n%s\n' "$wp1" "$wp2" > "$history_file"

    echo ":: Next rotation in ${interval}s..."
    sleep "$interval" &
    wait $!
done
