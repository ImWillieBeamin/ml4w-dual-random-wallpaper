#!/usr/bin/env bash
#
# Uninstall wallpaper-rotation and restore the original wallpaper-automation.sh
#

TARGET="$HOME/.config/hypr/scripts/wallpaper-automation.sh"
BACKUP="${TARGET}.bak"

echo ":: wallpaper-rotation uninstaller"

# Stop rotation if running
marker="$HOME/.cache/ml4w/hyprland-dotfiles/wallpaper-automation"
if [ -f "$marker" ]; then
    echo ":: Stopping active rotation..."
    rm -f "$marker"
    pkill -f "wallpaper-rotation.sh" 2>/dev/null
    pkill -f "wallpaper-automation.sh" 2>/dev/null
fi

# Remove symlink
if [ -L "$TARGET" ]; then
    rm -f "$TARGET"
    echo ":: Symlink removed"
else
    echo ":: WARNING: $TARGET is not a symlink, removing anyway"
    rm -f "$TARGET"
fi

# Restore backup
if [ -f "$BACKUP" ]; then
    mv "$BACKUP" "$TARGET"
    echo ":: Original script restored from backup"
else
    echo ":: WARNING: No backup found at $BACKUP"
    echo ":: You may need to reinstall ml4w-hyprland dotfiles to restore the original script"
fi

# -----------------------------------------------------
# Restore waypaper.sh
# -----------------------------------------------------

WAYPAPER_SH="$HOME/.config/hypr/scripts/waypaper.sh"
WAYPAPER_BAK="${WAYPAPER_SH}.bak"

if [ -f "$WAYPAPER_BAK" ]; then
    mv "$WAYPAPER_BAK" "$WAYPAPER_SH"
    echo ":: waypaper.sh restored from backup"
else
    echo ":: WARNING: No waypaper.sh backup found at $WAYPAPER_BAK"
fi

# Clean up rotation history
rm -f "$HOME/.cache/ml4w/hyprland-dotfiles/rotation-history"

echo ":: Uninstall complete."
