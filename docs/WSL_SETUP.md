# WSL Setup and Configuration Guide

This guide covers WSL-specific setup for dotfiles, including interop configuration, troubleshooting, and optimization.

## Quick Setup

### Essential wsl.conf Configuration

Create or edit `/etc/wsl.conf` with the following settings:

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

**After modifying `/etc/wsl.conf`, restart WSL:**

```powershell
# In PowerShell or Command Prompt (Windows side)
wsl --shutdown

# Then restart your WSL distribution
wsl
```

## Configuration Sections Explained

### [boot] - System Initialization

```ini
[boot]
systemd = true
```

**Why it matters:**
- Enables systemd as the init system in WSL
- Required for modern Linux services and Docker
- Provides better compatibility with standard Linux distributions
- Enables `systemctl` commands for service management

**Verification:**
```bash
ps -p 1 -o comm=
# Should output: systemd
```

### [interop] - Windows Integration

```ini
[interop]
enabled = true
appendWindowsPath = true
```

**Why it matters:**
- `enabled = true`: Allows running Windows executables from WSL (e.g., `notepad.exe`, `clip.exe`)
- `appendWindowsPath = true`: Makes Windows commands available in WSL PATH
- Required for clipboard integration (`clip.exe`, `powershell.exe`)
- Enables seamless Windows ↔ Linux interoperability

**Verification:**
```bash
# Test Windows executable access
clip.exe --help
echo $PATH | grep -i "windows"
```

### [automount] - File System Mounting

```ini
[automount]
enabled = true
options = "metadata,umask=22,fmask=11"
mountFsTab = false
```

**Why it matters:**
- `metadata`: Preserves Linux file permissions on Windows filesystems (crucial for git, ssh keys)
- `umask=22,fmask=11`: Sets default file permissions (755 for dirs, 644 for files)
- Prevents git from showing spurious file permission changes
- Ensures SSH keys have correct permissions (0600/0700)

**Verification:**
```bash
# Check mount options
mount | grep -i "c:"
# Should show: metadata in options

# Test file permissions
touch /mnt/c/test.txt
ls -l /mnt/c/test.txt
# Should show: -rw-r--r-- (644)
```

## Dotfiles Integration

The dotfiles automatically detect WSL and configure:

1. **Clipboard Integration** (wsl-init.sh, modules/wsl.nix):
   ```bash
   alias pbcopy='clip.exe'
   alias pbpaste='powershell.exe -command "Get-Clipboard" | head -n -1'
   ```

2. **Windows PATH Integration** (modules/environment.nix):
   ```bash
   export PATH="$PATH:/mnt/c/Windows/System32"
   ```

3. **Browser Handling** (modules/environment.nix):
   ```bash
   export BROWSER="wslview"  # Opens links in Windows browser
   ```

4. **Performance Optimizations** (modules/wsl.nix):
   - APT repository switching for corporate networks
   - Optimized DNS configuration
   - Network detection scripts

## Troubleshooting

### Clipboard Not Working

**Symptoms:**
- `pbcopy`/`pbpaste` commands not found
- `clip.exe` not accessible

**Solutions:**
1. Verify interop is enabled:
   ```bash
   grep "enabled.*true" /etc/wsl.conf
   ```

2. Check Windows PATH is appended:
   ```bash
   echo $PATH | grep -i windows
   ```

3. Test `clip.exe` directly:
   ```bash
   echo "test" | clip.exe
   ```

4. Restart WSL:
   ```powershell
   wsl --shutdown
   ```

5. Verify wsl-init.sh is sourced:
   ```bash
   # Check if aliases exist
   alias pbcopy
   alias pbpaste
   ```

### File Permission Issues

**Symptoms:**
- Git shows all files as modified
- SSH keys don't work (permissions too open)
- Shell scripts not executable

**Solutions:**
1. Add `metadata` option to `/etc/wsl.conf`:
   ```ini
   [automount]
   options = "metadata,umask=22,fmask=11"
   ```

2. Remount drives (or restart WSL):
   ```powershell
   wsl --shutdown
   ```

3. Reset permissions on SSH keys:
   ```bash
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/id_*
   chmod 644 ~/.ssh/*.pub
   ```

4. For git repositories on `/mnt/c`, consider moving them to WSL filesystem:
   ```bash
   # Better performance and permission handling
   cp -r /mnt/c/projects ~/projects
   ```

### Systemd Not Starting

**Symptoms:**
- `systemctl` commands fail
- Docker daemon won't start
- Services unavailable

**Solutions:**
1. Verify systemd is enabled:
   ```bash
   grep "systemd.*true" /etc/wsl.conf
   ```

2. Check if systemd is running:
   ```bash
   ps -p 1 -o comm=
   ```

3. Restart WSL completely:
   ```powershell
   wsl --shutdown
   wsl
   ```

4. Check WSL version (requires WSL 2):
   ```powershell
   wsl -l -v
   # Should show "VERSION 2"
   ```

5. Update WSL if needed:
   ```powershell
   wsl --update
   ```

### Windows Commands Not Accessible

**Symptoms:**
- `notepad.exe`, `clip.exe` not found
- Windows applications won't launch from WSL

**Solutions:**
1. Verify interop enabled:
   ```bash
   cat /proc/sys/fs/binfmt_misc/WSLInterop
   # Should exist and be "enabled"
   ```

2. Check `/etc/wsl.conf`:
   ```ini
   [interop]
   enabled = true
   appendWindowsPath = true
   ```

3. Restart WSL:
   ```powershell
   wsl --shutdown
   ```

4. Test with full path:
   ```bash
   /mnt/c/Windows/System32/notepad.exe
   ```

## Testing Your Configuration

### Automated Health Check

```bash
# Run comprehensive health check
./scripts/dotfiles-doctor.sh
```

The doctor script checks:
- ✓ systemd enabled in `/etc/wsl.conf`
- ✓ interop enabled in `/etc/wsl.conf`
- ✓ appendWindowsPath enabled
- ✓ metadata option in automount
- ✓ Clipboard integration (pbcopy/pbpaste)
- ✓ Windows PATH integration

### Manual Verification

**1. Systemd:**
```bash
systemctl --version
ps -p 1 -o comm=
```

**2. Interop:**
```bash
clip.exe --help
notepad.exe
```

**3. Clipboard:**
```bash
echo "test" | pbcopy
pbpaste
```

**4. File Permissions:**
```bash
touch /tmp/test.txt
ls -l /tmp/test.txt
# Should show: -rw-r--r--
```

**5. Windows PATH:**
```bash
echo $PATH | grep -c Windows
# Should output: > 0
```

## Advanced Configuration

### Custom Windows PATH

If you want to limit which Windows paths are included:

```ini
[interop]
enabled = true
appendWindowsPath = false  # Don't auto-append Windows PATH
```

Then manually add specific paths in your shell config:
```bash
export PATH="$PATH:/mnt/c/Windows/System32:/mnt/c/Program Files/YourApp"
```

### Network Configuration

For corporate environments with proxy/firewall:

```ini
[network]
generateResolvConf = false  # Disable auto DNS generation
```

Then manually configure DNS in `/etc/resolv.conf`:
```bash
nameserver 8.8.8.8
nameserver 8.8.4.4
```

### GPU Acceleration (WSL 2)

For CUDA/GPU workloads:

```ini
[wsl2]
memory=16GB  # Limit WSL memory
processors=8  # Limit CPU cores
```

### Performance Tuning

**Limit memory and CPU usage** (create/edit `%USERPROFILE%\.wslconfig`):

```ini
[wsl2]
memory=8GB
processors=4
swap=0
localhostForwarding=true
```

**Optimize I/O performance:**
```ini
[experimental]
sparseVhd=true  # Automatically reclaim disk space
```

## Complete Example wsl.conf

```ini
# /etc/wsl.conf - Complete recommended configuration

[boot]
systemd = true
command = ""  # Optional: run command on WSL start

[interop]
enabled = true
appendWindowsPath = true

[automount]
enabled = true
root = /mnt/
options = "metadata,umask=22,fmask=11"
mountFsTab = false

[network]
generateHosts = true
generateResolvConf = true

[user]
default = yourusername  # Optional: set default user
```

## Resources

- [WSL Configuration Documentation](https://docs.microsoft.com/en-us/windows/wsl/wsl-config)
- [WSL Interop Documentation](https://docs.microsoft.com/en-us/windows/wsl/interop)
- [Dotfiles WSL Detection Code](../modules/wsl.nix)
- [WSL Initialization Script](../wsl-init.sh)
- [Diagnostic Tools](../scripts/dotfiles-doctor.sh)

## Getting Help

If you encounter issues not covered here:

1. Run diagnostic script:
   ```bash
   ./scripts/dotfiles-doctor.sh
   ```

2. Check WSL logs:
   ```powershell
   wsl --debug-shell
   ```

3. Review WSL version and status:
   ```powershell
   wsl -l -v
   wsl --status
   ```

4. Open an issue with diagnostic output
