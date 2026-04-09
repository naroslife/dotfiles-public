"""Constants for CUDA setup.

Contains version requirements and system paths for CUDA 12.9 setup on WSL2.
Source: https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/index.html
"""

from pathlib import Path

# CUDA version and driver requirements
CUDA_VERSION = "12.9"
MIN_WINDOWS_DRIVER = "528.33"  # Minimum Windows driver for CUDA 12.9
RECOMMENDED_DRIVER = "566.03"  # Latest stable driver

# System paths
WSL_NVIDIA_SMI_PATH = Path("/usr/lib/wsl/lib/nvidia-smi")
WINDOWS_NVIDIA_SMI_PATH = Path("/mnt/c/Windows/System32/nvidia-smi.exe")

# WSL2 detection markers
WSL_INTEROP_PATHS = [
    Path("/proc/sys/fs/binfmt_misc/WSLInterop"),
    Path("/proc/sys/fs/binfmt_misc/WSLInterop-late"),
]
PROC_VERSION_PATH = Path("/proc/version")

# Timeout for nvidia-smi calls (seconds)
NVIDIA_SMI_TIMEOUT = 3
