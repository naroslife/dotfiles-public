# CUDA 12 Setup for WSL2 Ubuntu

This directory contains scripts and tools to install, configure, and test CUDA 12 on WSL2 Ubuntu systems.

## Overview

These scripts automate the process of:
- Installing CUDA 12.9 toolkit
- Configuring environment variables
- Fixing nvidia-smi segfault issues on WSL2
- Testing CUDA functionality

## Prerequisites

### Windows Side
- Windows 10/11 with WSL2 enabled
- NVIDIA GPU (compute capability 3.5 or higher recommended)
- **NVIDIA GPU drivers installed on Windows** (NOT in WSL2)
  - Download from: https://www.nvidia.com/Download/index.aspx
  - **Minimum driver version for CUDA 12.9: 528.33 or newer**
  - Recommended driver version: 566.03 or newer
  - The driver version must support CUDA 12.9

### WSL2 Side
- Ubuntu 20.04 or 22.04
- Sudo privileges
- At least 10GB free disk space (for CUDA toolkit)
- Internet connection for downloading packages

## Important Notes

⚠️ **Do NOT install NVIDIA drivers inside WSL2!**

NVIDIA drivers are installed on Windows and shared with WSL2 automatically. Installing drivers inside WSL2 will cause conflicts.

### Common Issue: nvidia-smi Segfault

If `nvidia-smi` is segfaulting on your system, don't worry! This is a common WSL2 issue and is automatically fixed by our scripts:
- `fix-nvidia-smi.sh` - Standalone fix script (run if needed)
- `check-driver.sh` - Automatically fixes before checking driver compatibility
- `install-cuda.sh` - Automatically fixes during installation

You can also run `./fix-nvidia-smi.sh` manually before any other steps.

## Quick Start

### 0. Check Driver Compatibility (Recommended)

Before installing CUDA, verify your Windows driver supports CUDA 12.9:

```bash
cd cuda-setup
./check-driver.sh
```

This script will:
- Check your Windows NVIDIA driver version
- Verify it meets CUDA 12.9 requirements (minimum: 528.33)
- Provide detailed update instructions if needed
- Show GPU information and driver capabilities

### 1. Install CUDA

Run the automated installation script:

```bash
cd cuda-setup
./install-cuda.sh
```

This script will:
1. Check if you're running on WSL2
2. Verify Windows NVIDIA drivers are installed
3. Fix nvidia-smi if it's segfaulting
4. Install CUDA repository
5. Install CUDA 12.9 toolkit (~3GB download, ~6.5GB installed)
6. Configure environment variables in your shell RC file

**After installation, restart your shell or run:**
```bash
source ~/.bashrc  # or ~/.zshrc if using zsh
```

### 2. Verify Installation

Test that CUDA is properly configured:

```bash
./test-cuda.sh
```

This performs quick checks of:
- nvidia-smi functionality
- Environment variables (CUDA_HOME, PATH, LD_LIBRARY_PATH)
- CUDA compiler (nvcc)
- CUDA installation directories

### 3. Run Comprehensive Tests

Compile and run the full CUDA test suite:

```bash
./compile-test.sh
```

This compiles and executes `cuda-test.cu` which tests:
- Device detection and properties
- Memory allocation and transfer
- Kernel execution
- Parallel thread execution
- Vector addition

## Files

- **fix-nvidia-smi.sh** - Fixes nvidia-smi segfault on WSL2 (run this first if needed)
- **check-driver.sh** - Driver compatibility checker for CUDA 12.9 (auto-fixes nvidia-smi)
- **install-cuda.sh** - Main installation script with driver validation (auto-fixes nvidia-smi)
- **test-cuda.sh** - Quick verification script (no compilation needed)
- **compile-test.sh** - Compiles and runs the CUDA test program
- **cuda-test.cu** - Comprehensive CUDA test program
- **README.md** - This file

## Manual Installation

If you prefer to install manually:

### 1. Install CUDA Repository

```bash
wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt update
```

### 2. Install CUDA Toolkit

```bash
sudo apt install -y cuda-toolkit-12-9 cuda-libraries-12-9 cuda-libraries-dev-12-9
```

### 3. Configure Environment

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
export CUDA_HOME=/usr/local/cuda
export CUDA_PATH=/usr/local/cuda
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=/usr/lib/wsl/lib:$CUDA_HOME/lib64:${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
```

Then reload:
```bash
source ~/.bashrc
```

### 4. Fix nvidia-smi (if needed)

If nvidia-smi segfaults:

```bash
sudo mv /usr/lib/wsl/lib/nvidia-smi /usr/lib/wsl/lib/nvidia-smi.old
sudo ln -s /mnt/c/Windows/System32/nvidia-smi.exe /usr/lib/wsl/lib/nvidia-smi
```

## Troubleshooting

### nvidia-smi segfaults

**Problem:** Running `nvidia-smi` causes a segmentation fault.

**Cause:** Outdated nvidia-smi binary in WSL2 that's incompatible with Windows driver version.

**Solution:**

**Option 1: Automatic Fix (Recommended)**
```bash
./fix-nvidia-smi.sh
```
This script automatically detects and fixes the segfault by replacing the WSL2 nvidia-smi with a symlink to the Windows version.

**Option 2: Automatic Fix During Check/Install**
Both `check-driver.sh` and `install-cuda.sh` now automatically detect and fix nvidia-smi segfaults.

**Option 3: Manual Fix**
```bash
sudo mv /usr/lib/wsl/lib/nvidia-smi /usr/lib/wsl/lib/nvidia-smi.old
sudo ln -s /mnt/c/Windows/System32/nvidia-smi.exe /usr/lib/wsl/lib/nvidia-smi
nvidia-smi  # Test it works
```

**Note:** This issue is common on WSL2 and the fix is safe and recommended. The Windows nvidia-smi.exe provides the same functionality and works correctly with WSL2.

### nvcc not found

**Problem:** `nvcc: command not found`

**Cause:** PATH not configured correctly or shell not reloaded.

**Solution:**
```bash
source ~/.bashrc  # or ~/.zshrc
# Verify:
echo $PATH | grep cuda
which nvcc
```

### CUDA libraries not found

**Problem:** Programs fail to run with "error while loading shared libraries"

**Cause:** LD_LIBRARY_PATH not configured correctly.

**Solution:**
```bash
source ~/.bashrc  # or ~/.zshrc
# Verify:
echo $LD_LIBRARY_PATH | grep cuda
echo $LD_LIBRARY_PATH | grep wsl
```

### Driver version mismatch

**Problem:** Error about driver/runtime version mismatch or "driver does not support CUDA 12.9".

**Cause:** Windows NVIDIA driver is too old for CUDA 12.9.

**Solution:**
1. Run `./check-driver.sh` to verify your current driver version
2. Update Windows NVIDIA drivers to version 528.33 or newer (recommended: 566.03+)
3. After updating on Windows:
   - Restart Windows (recommended)
   - Run `wsl --shutdown` in PowerShell
   - Relaunch Ubuntu
   - Run `./check-driver.sh` again to verify

**Updating your driver:**
- **Option 1:** GeForce Experience (easiest) - Open app → Drivers → Check for updates
- **Option 2:** Manual download from https://www.nvidia.com/Download/index.aspx
- **Option 3:** Windows Update → Check for updates

### No CUDA-capable device found

**Problem:** CUDA programs can't detect the GPU.

**Cause:** Windows drivers not installed or GPU not accessible to WSL2.

**Solution:**
1. Verify GPU works on Windows
2. Check Windows NVIDIA drivers are installed (run `nvidia-smi.exe` from Windows)
3. Restart WSL2: `wsl --shutdown` in PowerShell, then restart Ubuntu

### Compilation errors

**Problem:** `nvcc` fails to compile programs.

**Cause:** Missing CUDA toolkit components or incorrect paths.

**Solution:**
```bash
# Reinstall CUDA toolkit
sudo apt install --reinstall cuda-toolkit-12-9

# Verify installation
ls -la /usr/local/cuda
ls -la /usr/local/cuda/bin/nvcc
```

## Testing Your Installation

### Quick Test

```bash
# Check driver
nvidia-smi

# Check compiler
nvcc --version

# Check environment
echo $CUDA_HOME
echo $PATH | grep cuda
```

### Compile a Simple Program

Create `test.cu`:
```cuda
#include <stdio.h>

__global__ void hello() {
    printf("Hello from GPU thread %d!\n", threadIdx.x);
}

int main() {
    hello<<<1, 5>>>();
    cudaDeviceSynchronize();
    return 0;
}
```

Compile and run:
```bash
nvcc test.cu -o test
./test
```

Expected output:
```
Hello from GPU thread 0!
Hello from GPU thread 1!
Hello from GPU thread 2!
Hello from GPU thread 3!
Hello from GPU thread 4!
```

## Environment Variables Reference

| Variable | Purpose | Example Value |
|----------|---------|---------------|
| `CUDA_HOME` | CUDA installation root | `/usr/local/cuda` |
| `CUDA_PATH` | Alternative to CUDA_HOME | `/usr/local/cuda` |
| `PATH` | Include CUDA binaries | `...:/usr/local/cuda/bin` |
| `LD_LIBRARY_PATH` | CUDA and WSL libraries | `/usr/lib/wsl/lib:/usr/local/cuda/lib64:...` |

## CUDA Toolkit Contents

After installation, CUDA 12.9 includes:

- **Compiler:** nvcc (CUDA C/C++ compiler)
- **Libraries:** cuBLAS, cuFFT, cuRAND, cuSolver, cuSPARSE, NPP, nvJPEG
- **Tools:** cuda-gdb (debugger), nvprof (profiler), cuda-memcheck
- **Samples:** Example programs (in `/usr/local/cuda/samples` if installed)
- **Documentation:** `/usr/local/cuda/doc`

## Additional Resources

- [NVIDIA CUDA Documentation](https://docs.nvidia.com/cuda/)
- [CUDA Installation Guide for Linux](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/)
- [WSL2 CUDA Guide](https://docs.nvidia.com/cuda/wsl-user-guide/)
- [CUDA Samples Repository](https://github.com/NVIDIA/cuda-samples)

## Version Information

- **CUDA Version:** 12.9
- **Supported Ubuntu:** 20.04, 22.04, 24.04
- **Minimum Windows Driver:** 528.33
- **Recommended Windows Driver:** 566.03 or newer
- **Minimum Linux Driver (native):** 525.60.13 or newer

## Support

For issues specific to these scripts, check:
1. Run `./test-cuda.sh` for diagnostic information
2. Review the Troubleshooting section above
3. Check NVIDIA's official WSL2 documentation

For CUDA-specific issues, consult:
- [NVIDIA Developer Forums](https://forums.developer.nvidia.com/)
- [CUDA Toolkit Documentation](https://docs.nvidia.com/cuda/)

## License

These scripts are provided as-is for educational and development purposes.
