# WSL Setup Guide

Complete guide for configuring Windows Subsystem for Linux (WSL) to work optimally with these dotfiles.

## Prerequisites

- Windows 10 version 2004+ or Windows 11
- WSL2 installed and enabled
- A WSL2 Linux distribution (Ubuntu 20.04+ recommended)

## Quick Setup

### 1. Configure wsl.conf

WSL interop must be properly configured for seamless Windows-Linux integration. Create or edit `/etc/wsl.conf`:

```bash
sudo nano /etc/wsl.conf
```

Add the following configuration:

```ini
[boot]
systemd = true

[interop]
enabled = true
appendWindowsPath = true

[automount]
enabled = true
options = "metadata,umask=22,fmask=11"
mountFsTab = false
```

**Important:** After editing `/etc/wsl.conf`, you must restart WSL for changes to take effect:

```powershell
# In PowerShell or Command Prompt (Windows side)
wsl --shutdown

# Wait a few seconds, then restart your WSL terminal
```

### 2. Install Dotfiles

```bash
git clone https://github.com/naroslife/dotfiles-public.git ~/dotfiles-public
cd ~/dotfiles-public
./apply.sh
```

### 3. Verify Setup

Run the health check to verify everything is configured correctly:

```bash
dotfiles doctor
```

## Configuration Details

### [boot] Section

```ini
[boot]
systemd = true
```

- **systemd = true**: Enables systemd as the init system in WSL2
- Benefits: Proper service management, better compatibility with Linux software
- Required for: Many development tools, Docker, database services

### [interop] Section

```ini
[interop]
enabled = true
appendWindowsPath = true
```

- **enabled = true**: Allows running Windows executables from Linux
- **appendWindowsPath = true**: Adds Windows PATH to Linux PATH
- Benefits:
  - Run `clip.exe` for clipboard integration
  - Access Windows commands like `explorer.exe`, `code.exe`
  - Use PowerShell scripts from WSL
  - Launch Windows applications directly

Without this, dotfiles features like clipboard integration (`pbcopy`/`pbpaste`) won't work.

### [automount] Section

```ini
[automount]
enabled = true
options = "metadata,umask=22,fmask=11"
mountFsTab = false
```

- **enabled = true**: Automatically mount Windows drives under `/mnt/`
- **metadata**: Enables Linux file metadata (permissions, ownership) on Windows drives
- **umask=22**: Default permissions for directories (755)
- **fmask=11**: Default permissions for files (644)
- **mountFsTab = false**: Don't process `/etc/fstab` (prevents conflicts)

Benefits:
- Proper file permissions on shared files
- Better git compatibility (prevents spurious permission changes)
- Secure default permissions for new files

## Features Enabled by WSL Interop

Once properly configured, these dotfiles provide:

### 1. Clipboard Integration

```bash
# Copy to Windows clipboard
echo "hello" | pbcopy

# Paste from Windows clipboard
pbpaste
```

Aliases are automatically set up in `modules/wsl.nix` and `wsl-init.sh`.

### 2. Windows Command Access

```bash
# Open Windows Explorer in current directory
explorer.exe .

# Open files with Windows default application
wslview document.pdf

# Convert paths between Windows and WSL
wslpath 'C:\Users\username\file.txt'
# Output: /mnt/c/Users/username/file.txt
```

### 3. WSL Utilities

The following WSL utilities are automatically available:

- `wslview <file>` - Open file in Windows default application
- `wslpath <path>` - Convert between Windows and WSL paths
- `wslvar <var>` - Access Windows environment variables

These are provided by the `wslu` package installed in `modules/wsl.nix`.

### 4. Performance Optimizations

The dotfiles automatically apply WSL-specific optimizations:

- `WSLENV` variable for proper PATH handling
- Temporary file optimization
- Daily APT repository network switching (for enterprise users)
- DBus configuration for Electron apps
- WSLg systemd conflict resolution

## Troubleshooting

### Issue: Commands like `clip.exe` not found

**Cause:** WSL interop is disabled or Windows PATH is not appended.

**Solution:**
1. Check `/etc/wsl.conf` has `[interop]` section with `enabled = true` and `appendWindowsPath = true`
2. Restart WSL: `wsl --shutdown` (from Windows)
3. Verify: `which clip.exe` should show `/mnt/c/Windows/System32/clip.exe`

### Issue: File permission issues on shared drives

**Cause:** Missing `metadata` option in automount configuration.

**Solution:**
1. Add `options = "metadata,umask=22,fmask=11"` to `[automount]` section in `/etc/wsl.conf`
2. Restart WSL: `wsl --shutdown` (from Windows)
3. Verify: `mount | grep /mnt/c` should show metadata option

### Issue: Git shows all files as modified

**Cause:** File permissions not properly handled on Windows drives.

**Symptoms:**
```bash
git status
# Shows all files as modified even though they weren't changed
```

**Solution:**
1. Ensure `metadata,umask=22,fmask=11` is in `/etc/wsl.conf` automount options
2. Restart WSL
3. For existing repositories on Windows drives, add to `.git/config`:
   ```ini
   [core]
   filemode = false
   ```

### Issue: Systemd services don't start

**Cause:** Systemd not enabled in WSL.

**Solution:**
1. Add `systemd = true` to `[boot]` section in `/etc/wsl.conf`
2. Restart WSL: `wsl --shutdown` (from Windows)
3. Verify: `systemctl --version` should work without errors

### Issue: WSL_MESSAGES daily reminders not showing

**Cause:** This is expected behavior - messages only show once per day.

**Solution:** This is intentional. To force show messages:
```bash
rm ~/.cache/wsl-messages-last-shown
# Open new shell
```

### Issue: AppImage or Electron apps won't launch

**Cause:** Missing DBus configuration or display settings.

**Solution:**
See [wsl-fixes/README.md](../wsl-fixes/README.md) for comprehensive AppImage/Electron troubleshooting.

Quick fix:
```bash
launch-appimage.sh your-app.AppImage
```

## Testing Your Setup

### 1. Check wsl.conf is loaded

```bash
# Should show your configuration
cat /etc/wsl.conf
```

### 2. Test interop

```bash
# Should work without errors
clip.exe --help
explorer.exe .
```

### 3. Test clipboard

```bash
echo "test" | pbcopy
pbpaste
# Should output: test
```

### 4. Test WSL utilities

```bash
# Convert Windows path
wslpath 'C:\Windows'
# Should output: /mnt/c/Windows

# Get Windows username
wslvar USERNAME
```

### 5. Run health check

```bash
dotfiles doctor
```

Should show: ✓ WSL optimizations applied

## Advanced Configuration

### Custom Windows PATH

If you want to customize which Windows paths are included:

```ini
[interop]
enabled = true
appendWindowsPath = false
```

Then manually set PATH in your shell configuration:

```bash
export PATH="$PATH:/mnt/c/Windows/System32:/mnt/c/Program Files/Your App"
```

### Network Configuration

For enterprise environments with changing networks:

```bash
# Run APT network switch (automatically runs daily)
apt-network-switch
```

See `scripts/apt-network-switch.sh` for details.

### GPU Acceleration (WSLg)

For GUI applications with GPU acceleration:

```bash
# Check WSLg is available
echo $DISPLAY
# Should output: :0 or similar

# Test with a GUI app
xeyes  # If installed
```

### Performance Tuning

Create `.wslconfig` in your Windows user directory (`C:\Users\YourName\.wslconfig`):

```ini
[wsl2]
memory=8GB          # Limits VM memory
processors=4        # Number of processors
swap=4GB           # Swap space
localhostForwarding=true
```

Restart WSL after changes: `wsl --shutdown`

## Complete Example wsl.conf

Here's a complete `/etc/wsl.conf` with all recommended settings:

```ini
# Boot configuration
[boot]
systemd = true

# Windows interoperability
[interop]
enabled = true
appendWindowsPath = true

# Automatic drive mounting
[automount]
enabled = true
options = "metadata,umask=22,fmask=11"
mountFsTab = false

# Network configuration
[network]
generateHosts = true
generateResolvConf = true

# User configuration
[user]
default = your-username
```

Replace `your-username` with your actual WSL username.

## References

- [WSL Configuration Documentation](https://docs.microsoft.com/en-us/windows/wsl/wsl-config)
- [WSLg (GUI Apps)](https://github.com/microsoft/wslg)
- [WSL Best Practices](https://docs.microsoft.com/en-us/windows/wsl/setup/environment)
- [Dotfiles WSL Integration](../README.md#wsl-integration)
- [WSL Fixes for Electron Apps](../wsl-fixes/README.md)

## Getting Help

If you encounter issues:

1. Run `dotfiles doctor` to check your setup
2. Check this guide's troubleshooting section
3. Review [wsl-fixes/README.md](../wsl-fixes/README.md) for app-specific issues
4. Open an issue on the dotfiles repository
