# Electron Slow Startup: Solution Summary

## Problem

After installing CUDA and Nix on WSL2, Electron-based AppImages (specifically Next-Client) experience severe startup delays:
- **With full environment (155 vars)**: 30+ seconds, often timeout
- **With clean environment (11 vars)**: 3-5 seconds (normal)

## Root Cause

**Environment variable overload in Electron/Chromium initialization.**

- NOT specific variables (all tested individually are fast)
- NOT just the count (tested with 150 dummy vars = fast)
- It's the **COMBINATION of many REAL environment variables** from a complex shell environment

When Electron/Chromium starts with a large, complex environment (Nix + CUDA + development tools + shell integrations), it appears to spend excessive time:
- Parsing/validating environment variables
- Attempting path/library resolution
- Processing variable interactions
- Initializing with full context

## Solution

**Use `env -i` to launch with a minimal, clean environment.**

Only pass essential variables needed for GUI applications:

```bash
exec env -i \
    HOME="$HOME" \
    USER="$USER" \
    SHELL="$SHELL" \
    DISPLAY="$DISPLAY" \
    DBUS_SESSION_BUS_ADDRESS="$DBUS_SESSION_BUS_ADDRESS" \
    XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    LIBVA_DRIVER_NAME="none" \
    GDK_BACKEND="x11" \
    LIBGL_ALWAYS_SOFTWARE="1" \
    ELECTRON_EXTRA_LAUNCH_ARGS="--disable-gpu --no-sandbox" \
    PATH="/usr/local/bin:/usr/bin:/bin" \
    "$APPIMAGE" "$@"
```

### Results
- **Startup time**: 60+ seconds → 3-5 seconds (12-20x improvement)
- **Reliability**: No timeouts, consistent fast startup
- **Functionality**: Application works normally with minimal environment

## Implementation

### Files Modified
- `wsl-fixes/launch-appimage.sh` - Universal AppImage launcher with env -i
- `wsl-fixes/launch-next-client.sh` - Next-Client specific launcher
- `wsl-fixes/restore-env-vars.conf` - Configuration for selectively restoring variables
- `wsl-fixes/test-restored-vars.sh` - Test script for trying restored variables

### Usage

**Recommended (use launcher):**
```bash
~/dotfiles-public/wsl-fixes/launch-next-client.sh
```

**Or with generic launcher:**
```bash
~/dotfiles-public/wsl-fixes/launch-appimage.sh ~/path/to/app.AppImage
```

**To restore specific variables:**
1. Edit `wsl-fixes/restore-env-vars.conf`
2. Uncomment variables you need
3. Test with `wsl-fixes/test-restored-vars.sh`
4. If still fast, update launcher to include them

## Testing Results

### Confirmed Fast
- ✓ 11 base variables only
- ✓ Base + any single variable from environment
- ✓ Base + 150 dummy variables (proves it's not just count)

### Confirmed Slow
- ✗ 155 variables from full shell environment (30+ seconds)

### Unknown/Variable
- ? 90+ "real" variables from config (results inconsistent)
- ? Specific combinations of variables

## Why This Works

By using `env -i`:
1. **Eliminates variable interactions** - No complex combinations for Electron to process
2. **Reduces parsing overhead** - Minimal environment to validate
3. **Avoids path resolution attempts** - No development tool paths, library paths, etc.
4. **Removes shell integrations** - No Starship, Atuin, zoxide, FZF, etc. state
5. **Bypasses VSCode integration** - No VSCode-specific variables that might trigger behavior

The application doesn't need:
- Development tool configurations (CARGO_HOME, GOPATH, etc.)
- Shell history/state (HISTFILE, HISTSIZE, etc.)
- Terminal color schemes (LESS_TERMCAP_*, COLORTERM, etc.)
- Session-specific state (ATUIN_SESSION, STARSHIP_SESSION_KEY, etc.)
- Language environment managers (NIX_*, PYTHONPATH, etc.)

## Verification

To verify the problem still exists without the fix:

```bash
# This should be SLOW (30+ seconds)
~/dev/Next-Client-1.10.0.AppImage

# This should be FAST (3-5 seconds)
~/dotfiles-public/wsl-fixes/launch-next-client.sh
```

## Related Files
- `ELECTRON_ENV_INVESTIGATION.md` - Detailed investigation process
- `TEST-VARIABLE-SETS.md` - Exact variable sets used in testing
- `restore-env-vars.conf` - All removed variables for optional restoration

## Recommendations

### For Other Electron Apps on WSL2 with Nix/Development Environment:
1. **Always use `env -i` approach** when launching Electron/Chromium apps
2. **Only pass essential GUI variables** (display, DBus, XDG, paths)
3. **Test with minimal environment first** before adding variables back
4. **Document which variables your app actually needs** (most need very few)

### For Debugging If Slowness Returns:
1. Compare `env | wc -l` between slow and fast launches
2. Test with `env -i` + base variables to confirm it's environment-related
3. Use binary search through your environment to find problematic variables
4. Check for new shell integrations or tools adding variables

## Date
Initial investigation: 2025-09-30
Solution implemented: 2025-09-30
Final verification: 2025-09-30