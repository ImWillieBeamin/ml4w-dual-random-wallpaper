# ml4w-dual-wallpaper

Per-monitor wallpaper rotation for dual-monitor Hyprland setups running [ml4w-hyprland](https://github.com/mylinuxforwork/dotfiles).

By default, ml4w's `waypaper --random` picks one wallpaper and sets it on **all** monitors. This project gives each monitor its own random wallpaper — both for the timed rotation (`Super+Alt+W`) and the one-shot keybind (`Super+Shift+W`).

## Dependencies

| Package | Purpose |
|---------|---------|
| [ml4w-hyprland](https://github.com/mylinuxforwork/dotfiles) | Dotfiles framework this integrates with |
| [Hyprland](https://hyprland.org/) | Wayland compositor |
| [swww](https://github.com/LGFae/swww) | Wallpaper daemon (provides per-output `--outputs` flag) |
| [waypaper](https://github.com/anufrievroman/waypaper) | Wallpaper GUI selector |
| [matugen](https://github.com/InioX/matugen) | Material You color generation from wallpaper |
| [ImageMagick](https://imagemagick.org/) | Blur and resize for lockscreen/waybar backgrounds |

**Optional:** [pywalfox](https://github.com/Frewacom/pywalfox) (Firefox theme sync), [SwayNotificationCenter](https://github.com/ErikReider/SwayNotificationCenter) (notification styling)

## Files

| File | Purpose |
|------|---------|
| `wallpaper-rotation.sh` | Main script — drop-in replacement for `wallpaper-automation.sh` |
| `rotation.conf` | Interval config (`DAYS=0`, `HOURS=1`, `MINUTES=0`) |
| `install.sh` | Backs up originals, creates symlink, patches `waypaper.sh` |
| `uninstall.sh` | Restores all originals from backups |

## How it works

1. **Toggle** (`Super+Alt+W`) — same marker file pattern as the original (`~/.cache/ml4w/hyprland-dotfiles/wallpaper-automation`), so the keybind and gamemode integration work transparently
2. **Each tick** — picks 2 random wallpapers (excluding the last 2 used), sets DP-1 and DP-2 independently via `swww img --outputs`
3. **Pipeline** — calls `wallpaper.sh` with DP-1's wallpaper so matugen colors, blur, lockscreen, waybar, dock, and rofi all update
4. **DP-2 re-apply** — after the pipeline finishes (in case effects mode's `waypaper --wallpaper` resets all monitors), DP-2's wallpaper is re-applied
5. **One-shot** (`Super+Shift+W`) — `--once` mode picks 2 random wallpapers, applies them, runs the pipeline, and exits immediately (no loop, no marker file)
6. **Clean shutdown** — trap handler removes marker file; `sleep` runs in background so signals are caught immediately

### What install.sh does

- Backs up `wallpaper-automation.sh` and symlinks it to `wallpaper-rotation.sh`
- Backs up `waypaper.sh` and replaces it with a wrapper that routes `--random` through `wallpaper-rotation.sh --once` (per-monitor), while passing all other invocations (GUI, `--wallpaper`) through to the real `waypaper` binary

### Wallpaper folder resolution

The script reads the wallpaper folder from `~/.config/ml4w/settings/wallpaper-folder`. If that path doesn't exist, it falls back to waypaper's `~/.config/waypaper/config.ini`, then to `~/.config/ml4w/wallpapers`.

## Install

```bash
cd ~/dev/wallpaper-rotation && bash install.sh
```

## Uninstall

```bash
cd ~/dev/wallpaper-rotation && bash uninstall.sh
```

Restores both `wallpaper-automation.sh` and `waypaper.sh` from their `.bak` backups.
