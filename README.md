## `~/dev/wallpaper-rotation/` — 4 files

| File | Purpose |
|------|---------|
| `wallpaper-rotation.sh` | Main script — drop-in replacement for `wallpaper-automation.sh` |
| `rotation.conf` | Interval config (`DAYS=0`, `HOURS=1`, `MINUTES=0`) |
| `install.sh` | Backs up original, creates symlink |
| `uninstall.sh` | Removes symlink, restores original |

### How it works

1. **Toggle** — same marker file pattern as the original (`~/.cache/ml4w/hyprland-dotfiles/wallpaper-automation`), so `Super+Alt+W` and gamemode integration work transparently
2. **Each tick** — picks 2 random wallpapers (excluding the last 2 used), sets DP-1 and DP-2 independently via `swww img --outputs`
3. **Pipeline** — calls `wallpaper.sh` with DP-1's wallpaper so matugen colors, blur, lockscreen, waybar, dock, and rofi all update
4. **DP-2 re-apply** — after the pipeline finishes (in case effects mode's `waypaper --wallpaper` reset all monitors), DP-2's wallpaper is re-applied
5. **Clean shutdown** — trap handler removes marker file; `sleep` runs in background so signals are caught immediately (no orphaned processes)

### To install

```bash
cd ~/dev/wallpaper-rotation && bash install.sh
```
