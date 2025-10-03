# WSL2 AppImage & Electron App Fix

This directory contains scripts and documentation for fixing common issues when running AppImages and Electron apps on WSL2.

## Repository Structure

```
wsl-fixes/
├── README.md              - This file
├── fix-dbus-wsl.sh        - DBus session configuration
└── launch-appimage.sh     - Universal AppImage launcher
```

Scripts are symlinked to `~/.local/bin/` for PATH access and automatically loaded via `wsl-init.sh`.

## Common Issues Fixed

1. ✓ **DBus connection errors** - `Failed to connect to the bus`
2. ✓ **Missing settings.json** - `ENOENT: no such file or directory, open 'settings.json'`
3. ✓ **GPU/rendering warnings** - `dri3 extension not supported`, `libva error`
4. ✓ **Window not appearing** - App starts but no window shows

## Quick Fix

### Option 1: Use the Launcher Script (Recommended)

```bash
# Make your AppImage executable (if not already)
chmod +x ./Next-Client-1.10.0.AppImage

# Launch with the fix script
~/.local/bin/launch-appimage.sh ./Next-Client-1.10.0.AppImage
```

### Option 2: Manual Launch with Environment

```bash
# Source DBus fix
source ~/dotfiles-public/wsl-fixes/fix-dbus-wsl.sh

# Set environment variables
export MESA_LOADER_DRIVER_OVERRIDE=d3d12
export GDK_BACKEND=x11
export ELECTRON_EXTRA_LAUNCH_ARGS="--disable-gpu-sandbox --disable-software-rasterizer"

# Launch the app
./Next-Client-1.10.0.AppImage
```

## Files in This Directory

### 1. DBus Fix Script
**File:** `fix-dbus-wsl.sh`
**Symlinked to:** `~/.local/bin/fix-dbus-wsl.sh`

Ensures DBus session is properly configured for Electron apps.

**Usage:**
```bash
source ~/dotfiles-public/wsl-fixes/fix-dbus-wsl.sh
# or via symlink
source ~/.local/bin/fix-dbus-wsl.sh
```

### 2. AppImage Launcher
**File:** `launch-appimage.sh`
**Symlinked to:** `~/.local/bin/launch-appimage.sh`

Universal launcher that applies all WSL2 fixes automatically.

**Usage:**
```bash
launch-appimage.sh <path-to-appimage> [arguments]
```

**Features:**
- Auto-configures DBus session
- Sets proper display and runtime directories
- Applies GPU/rendering fixes
- Disables problematic Wayland features
- Adds Electron compatibility flags

### 3. Default Settings File
**Location:** `~/.config/Next-Client/settings.json`

Created to prevent "ENOENT: settings.json" error.

## Permanent Shell Integration

To automatically fix DBus on shell startup, add to your shell RC file:

### For Bash (~/.bashrc)
```bash
# WSL2 AppImage/Electron fixes
if [[ -f ~/.local/bin/fix-dbus-wsl.sh ]]; then
    source ~/.local/bin/fix-dbus-wsl.sh
fi
```

### For Zsh (~/.zshrc)
```bash
# WSL2 AppImage/Electron fixes
if [[ -f ~/.local/bin/fix-dbus-wsl.sh ]]; then
    source ~/.local/bin/fix-dbus-wsl.sh
fi
```

## Troubleshooting

### Issue: "Failed to connect to the bus"

**Cause:** No DBus session running or wrong address.

**Fix:**
```bash
# Start a new DBus session
eval $(dbus-launch --sh-syntax)

# Save for future use
echo "export DBUS_SESSION_BUS_ADDRESS='$DBUS_SESSION_BUS_ADDRESS'" > ~/.dbus-session
echo "export DBUS_SESSION_BUS_PID='$DBUS_SESSION_BUS_PID'" >> ~/.dbus-session
```

### Issue: "ENOENT: no such file or directory, open 'settings.json'"

**Cause:** App expects a settings file that doesn't exist.

**Fix:** Already created at `~/.config/Next-Client/settings.json`. If it's a different app:
```bash
# Create config directory
mkdir -p ~/.config/YourAppName

# Create minimal settings
echo '{}' > ~/.config/YourAppName/settings.json
```

### Issue: Window doesn't appear but app is running

**Cause:** GPU/rendering issues or display not configured.

**Fix 1 - Use software rendering:**
```bash
export LIBGL_ALWAYS_SOFTWARE=1
./YourApp.AppImage
```

**Fix 2 - Check DISPLAY:**
```bash
echo $DISPLAY  # Should show :0 or similar
export DISPLAY=:0  # If not set
```

**Fix 3 - Use Mesa D3D12 driver (for WSLg):**
```bash
export MESA_LOADER_DRIVER_OVERRIDE=d3d12
./YourApp.AppImage
```

### Issue: "dri3 extension not supported"

**Cause:** GPU acceleration issues with WSLg.

**Fix:** This is usually just a warning. If it causes problems:
```bash
# Disable hardware acceleration
export LIBGL_ALWAYS_SOFTWARE=1

# Or use the d3d12 driver
export MESA_LOADER_DRIVER_OVERRIDE=d3d12
```

### Issue: AppImage won't execute

**Cause:** File not executable or FUSE not available.

**Fix:**
```bash
# Make executable
chmod +x YourApp.AppImage

# If FUSE issues, extract and run
./YourApp.AppImage --appimage-extract
./squashfs-root/AppRun
```

## Environment Variables Reference

| Variable | Purpose | Recommended Value |
|----------|---------|-------------------|
| `DBUS_SESSION_BUS_ADDRESS` | DBus connection | Auto-set by dbus-launch |
| `DISPLAY` | X11 display server | `:0` (WSLg default) |
| `XDG_RUNTIME_DIR` | Runtime files | `/run/user/$(id -u)` |
| `GDK_BACKEND` | GTK backend | `x11` (not wayland) |
| `MESA_LOADER_DRIVER_OVERRIDE` | Mesa driver | `d3d12` (for WSLg) |
| `LIBGL_ALWAYS_SOFTWARE` | Software rendering | `1` (if GPU issues) |
| `ELECTRON_EXTRA_LAUNCH_ARGS` | Electron flags | `--disable-gpu-sandbox` |

## Testing Your Setup

### Test DBus
```bash
# Check if DBus is configured
echo $DBUS_SESSION_BUS_ADDRESS

# Test DBus connection
dbus-send --session --print-reply \
  --dest=org.freedesktop.DBus \
  /org/freedesktop/DBus \
  org.freedesktop.DBus.ListNames
```

### Test X11 Display
```bash
# Check DISPLAY
echo $DISPLAY

# Test with xeyes (if installed)
xeyes

# Or test with a simple X client
xclock
```

### Test AppImage Mounting
```bash
# Extract AppImage contents (test FUSE)
./YourApp.AppImage --appimage-extract

# Should create squashfs-root/ directory
ls -la squashfs-root/
```

## Common Apps That Need These Fixes

- Electron apps (VS Code, Discord, Slack, etc.)
- AppImage applications
- Chrome/Chromium-based apps
- Apps using GTK/Qt with DBus

## Create an Alias

Add to your shell RC file for convenience:

```bash
alias nextclient='launch-appimage.sh ~/path/to/Next-Client-1.10.0.AppImage'
```

Then just run:
```bash
nextclient
```

## Advanced: Debugging AppImage Issues

### Enable Electron Debug Output
```bash
export ELECTRON_ENABLE_LOGGING=1
export ELECTRON_LOG_FILE=~/electron-debug.log
./YourApp.AppImage
```

### Check AppImage Contents
```bash
# Extract without running
./YourApp.AppImage --appimage-extract

# Inspect
ls -la squashfs-root/
cat squashfs-root/*.desktop
```

### Run with strace
```bash
strace -e trace=open,openat ./YourApp.AppImage 2>&1 | grep -i settings
```

## Additional Resources

- [Electron WSL2 Issues](https://github.com/microsoft/WSL/issues)
- [WSLg Documentation](https://github.com/microsoft/wslg)
- [AppImage Documentation](https://docs.appimage.org/)

## Notes

- These fixes are specifically for WSL2 with WSLg (Windows 11 or Windows 10 with WSLg backport)
- Some warnings (like libva errors) are cosmetic and can be ignored
- GPU acceleration works best with recent Windows drivers and WSLg updates
- The launcher script is safe to use with any AppImage or Electron app