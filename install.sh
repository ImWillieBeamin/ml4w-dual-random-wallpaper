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
echo ":: Installation complete. Press Super+Alt+W to toggle rotation."
