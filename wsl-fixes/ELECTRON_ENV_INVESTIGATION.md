# Electron/AppImage Slow Startup Investigation

## Problem Statement

After installing CUDA 12 on WSL2, Electron-based AppImages (specifically Next-Client) experienced severe startup delays:
- **Before CUDA**: Normal startup (estimated < 10 seconds)
- **After CUDA**: 60+ second delays, often timing out entirely

## Investigation Methodology

### Initial Hypothesis
We initially suspected specific environment variables added by CUDA/Nix:
- `CUDA_HOME`
- `CUDA_PATH`
- `LD_LIBRARY_PATH`
- `LOCALE_ARCHIVE_2_27`
- `NIX_PROFILES`
- `JAVA_HOME`
- `__ETC_PROFILE_NIX_SOURCED`

### Testing Approach
1. **Individual Variable Testing**: Test each suspect variable in isolation
2. **Combination Testing**: Test groups of suspect variables together
3. **Threshold Testing**: Test with progressively more environment variables
4. **Baseline Comparison**: Compare clean environment vs full environment

## Key Findings

### Finding 1: Individual Variables Are NOT the Culprit

**Test Results:**
```bash
Baseline (7 base vars):              ✓ 2-3 seconds
+ LOCALE_ARCHIVE_2_27:               ✓ 2-3 seconds
+ LD_LIBRARY_PATH:                   ✓ 2-3 seconds
+ CUDA_HOME + CUDA_PATH:             ✓ 2-3 seconds
+ NIX_PROFILES + __ETC_PROFILE_NIX:  ✓ 2-3 seconds
+ JAVA_HOME:                         ✓ 2-3 seconds
+ ALL suspects combined:             ✓ 2-3 seconds
```

**Conclusion**: No single variable or combination of suspect variables causes the slowness.

### Finding 2: Environment Variable COUNT Threshold

**Test Results:**
```bash
Base + 0 extra vars:     ✓ FAST (2s)
Base + 10 extra vars:    ✓ FAST (3s)
Base + 12 extra vars:    ✓ FAST (3s)
Base + 15 extra vars:    ✓ FAST (2s)
Base + 18 extra vars:    ✗ SLOW (35s+ timeout)
Base + 25 extra vars:    ✗ SLOW (35s+ timeout)
Base + 50 extra vars:    ✗ SLOW (35s+ timeout)
Base + 145 extra vars:   ✗ SLOW (60s+ timeout)
```

**Critical Threshold**: Between **15-18 total environment variables**

### Finding 3: Full Environment Impact

**Environment Statistics:**
- Base variables (essential): 7
- Safe variables: ~135
- Suspect variables (CUDA/Nix): ~10
- **Total**: ~155 environment variables

**Full Environment Test:**
- With all 155 variables: **60+ seconds**, often never completes initialization
- Clean environment (7 vars): **2-3 seconds**

## CRITICAL UPDATE: It's NOT Variable Count!

### Additional Testing with Dummy Variables

Further testing revealed a surprising finding:
- **150 dummy variables (158 total)**: ✓ FAST (5s)
- **155 REAL variables**: ✗ SLOW (30s+)

**Conclusion**: The problem is NOT the number of variables, but **specific content or total byte size**.

### Environment Size Analysis

```
Real environment total size: 6,399 bytes
Number of variables: 155

Longest variables:
- PATH: 910 bytes
- LD_LIBRARY_PATH: 205 bytes
- VSCODE_GIT_ASKPASS_MAIN: 134 bytes
- LOCALE_ARCHIVE_2_27: 111 bytes
```

The extremely long `PATH` (910 bytes) and cumulative byte size appear to be the real culprits.

## Root Cause Analysis

### The Real Problem: Specific Real Variables Beyond ~10-15 Count

**Critical Discovery Through Dummy Variable Testing:**

| Test Configuration | Result |
|-------------------|--------|
| 150 dummy variables | ✓ FAST (5s) |
| 10 real variables | ✓ FAST (5s) |
| 20+ real variables | ✗ SLOW (15s+ timeout) |
| All CUDA/Nix suspects alone | ✓ FAST (2-3s) |
| All suspects combined | ✓ FAST (5s) |

**Conclusion**: The issue is with **specific real environment variables** beyond the first ~10-15, NOT:
- The total number of variables (150 dummies work fine)
- The byte size alone (PATH=910 bytes works fine alone)
- Specific suspect variables (all fast individually and combined)

### Why Some Variables Cause Slowness

The problematic behavior appears when combining:
1. **Many variables** (>15-20)
2. **Real environment variables** from the actual shell environment
3. Potentially **related variables** that interact (PATH, LD_LIBRARY_PATH, locale, Nix paths)

**Hypothesis**: Electron/Chromium may be:
- Parsing/validating certain variable combinations
- Looking for specific patterns in environment variables
- Attempting library/path resolution based on multiple variables together
- Inheriting and processing the environment across multiple child processes where cumulative real-variable interactions create exponential overhead

## Solution: Clean Environment Approach

### Implementation

Use `env -i` to start with a completely clean environment and only pass essential variables:

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
    ELECTRON_EXTRA_LAUNCH_ARGS="$FLAGS" \
    PATH="/usr/local/bin:/usr/bin:/bin" \
    "$APPIMAGE" "$@"
```

### Why This Works

- **Reduces environment from 155 → ~10 variables**
- **Stays well below the 15-18 threshold**
- **Startup time: 60s+ → 2-3 seconds** (20-30x improvement)
- Only essential GUI variables are preserved
- Application functions normally with minimal environment

## Alternative Solutions (NOT Recommended)

### Option 1: Unset Specific Variables
**Problem**: We would need to unset 135+ variables, which is:
- Fragile (breaks when new variables are added)
- Complex to maintain
- Doesn't address root cause

### Option 2: Reduce Nix/Home-Manager Variables
**Problem**: These are essential for the development environment
- Would break other tools and workflows
- Not practical for a Nix-based setup

### Option 3: Increase Threshold
**Problem**: The threshold appears to be an Electron/Chromium limitation
- Can't be configured without modifying Electron source
- Not within our control

## Recommendations

### For Electron AppImages on WSL2 with Nix/Home-Manager:

1. **Always use `env -i` approach** when launching Electron apps
2. **Only pass essential variables**:
   - Display: `DISPLAY`, `WAYLAND_DISPLAY`
   - IPC: `DBUS_SESSION_BUS_ADDRESS`, `XDG_RUNTIME_DIR`
   - Basic: `HOME`, `USER`, `SHELL`, `PATH`
   - App-specific: Electron flags, GPU settings
3. **Keep total variable count under 15** for best performance

### For Other GUI Applications:

Test whether they exhibit similar behavior:
- If yes: Apply same `env -i` approach
- If no: May not need special handling

## Files Modified

- `wsl-fixes/launch-appimage.sh`: Universal AppImage launcher with clean environment
- `wsl-fixes/launch-next-client.sh`: Next-Client specific launcher
- Both now use `env -i` approach for optimal performance

## Testing Notes

- Tests performed on: WSL2 Ubuntu 22.04, Windows 11
- CUDA Version: 12.6
- Nix Home-Manager: Flake-based configuration
- App tested: Next-Client 1.10.0 (Electron-based)
- Date: 2025-09-30

## References

- Issue started after: Commit `19b1e19` "Add CUDA 12 support for WSL2 with NVIDIA GPU"
- Solution implemented in: Commit `9d68fe9` "Use clean environment (env -i) to fix Electron slow startup"
- This investigation: Commit `[to be added]`