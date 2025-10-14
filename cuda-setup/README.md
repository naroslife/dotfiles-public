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
  - Minimum driver version: 450.80.02 or newer
  - The driver version must support CUDA 12.x

### WSL2 Side
- Ubuntu 20.04 or 22.04
- Sudo privileges
- At least 10GB free disk space (for CUDA toolkit)
- Internet connection for downloading packages

## Important: Driver Installation

⚠️ **Do NOT install NVIDIA drivers inside WSL2!**

NVIDIA drivers are installed on Windows and shared with WSL2 automatically. Installing drivers inside WSL2 will cause conflicts.

## Quick Start

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

- **install-cuda.sh** - Main installation script
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

**Solution:** The installation script automatically fixes this by replacing the WSL2 nvidia-smi with a symlink to the Windows version.

Manual fix:
```bash
sudo mv /usr/lib/wsl/lib/nvidia-smi /usr/lib/wsl/lib/nvidia-smi.old
sudo ln -s /mnt/c/Windows/System32/nvidia-smi.exe /usr/lib/wsl/lib/nvidia-smi
nvidia-smi
```

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

**Problem:** Error about driver/runtime version mismatch.

**Cause:** Windows NVIDIA driver is too old for CUDA 12.

**Solution:** Update Windows NVIDIA drivers to version 450.80.02 or newer (preferably 525.60 or newer for best CUDA 12 support).

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
- **Supported Ubuntu:** 20.04, 22.04
- **Minimum Driver:** 450.80.02
- **Recommended Driver:** 525.60 or newer

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
