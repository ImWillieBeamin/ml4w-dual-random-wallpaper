#!/usr/bin/env bash
#
# Install wallpaper-rotation as a drop-in replacement for wallpaper-automation.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME/.config/hypr/scripts/wallpaper-automation.sh"
SOURCE="$SCRIPT_DIR/wallpaper-rotation.sh"
BACKUP="${TARGET}.bak"

echo ":: wallpaper-rotation installer"

# Make the rotation script executable
chmod +x "$SOURCE"

# Back up original if it exists and isn't already a symlink
if [ -f "$TARGET" ] && [ ! -L "$TARGET" ]; then
    cp "$TARGET" "$BACKUP"
    echo ":: Backed up original to $BACKUP"
elif [ -L "$TARGET" ]; then
    echo ":: Target is already a symlink ($(readlink "$TARGET")), removing it"
fi

# Remove existing file/symlink and create new symlink
rm -f "$TARGET"
ln -s "$SOURCE" "$TARGET"

echo ":: Symlink created: $TARGET -> $SOURCE"

# -----------------------------------------------------
# Replace waypaper.sh to route --random through rotation
# -----------------------------------------------------

WAYPAPER_SH="$HOME/.config/hypr/scripts/waypaper.sh"
WAYPAPER_BAK="${WAYPAPER_SH}.bak"

# Back up original waypaper.sh if it exists and isn't already our replacement
if [ -f "$WAYPAPER_SH" ]; then
    # Check if it's already our replacement (contains wallpaper-rotation.sh reference)
    if ! grep -q "wallpaper-rotation.sh" "$WAYPAPER_SH"; then
        cp "$WAYPAPER_SH" "$WAYPAPER_BAK"
        echo ":: Backed up waypaper.sh to $WAYPAPER_BAK"
    else
        echo ":: waypaper.sh is already patched, skipping backup"
    fi
fi

cat > "$WAYPAPER_SH" << 'WAYPAPER_EOF'
#!/usr/bin/env bash
# Patched by wallpaper-rotation installer
# --random is routed through wallpaper-rotation for per-monitor support
# All other invocations pass through to the real waypaper binary

if [ "$1" = "--random" ]; then
    exec "$HOME/dev/wallpaper-rotation/wallpaper-rotation.sh" --once
fi

if [ -f /usr/bin/waypaper ]; then
    waypaper $1 &
elif [ -f "$HOME/.local/bin/waypaper" ]; then
    "$HOME/.local/bin/waypaper" $1 &
else
    echo ":: waypaper not found"
fi
WAYPAPER_EOF
chmod +x "$WAYPAPER_SH"
echo ":: waypaper.sh replaced (--random now uses per-monitor rotation)"

echo ":: Installation complete. Press Super+Alt+W to toggle rotation."
